import { useState, useEffect } from "react";
import {
  getNluOverrides,
  addNluOverride,
  deleteNluOverride,
  getNluAggregations,
  curateNluAggregations,
  triggerNluTrain,
  getNluTrainStatus,
  getNluModelMeta
} from "../services/api";

function NluOpsPage() {
  const [activeTab, setActiveTab] = useState("layer1");
  const [toastMessage, setToastMessage] = useState("");
  const [loading, setLoading] = useState(false);

  // Layer 1 state
  const [layer1Rules, setLayer1Rules] = useState([]);
  const [searchExact, setSearchExact] = useState("");
  const [newKeyword, setNewKeyword] = useState("");
  const [newCategory, setNewCategory] = useState("Food");
  const [newUserId, setNewUserId] = useState("");

  // Layer 2 state
  const [autoRetrainAfterCurate, setAutoRetrainAfterCurate] = useState(true);

  // Model status state
  const [isTraining, setIsTraining] = useState(false);
  const [modelMeta, setModelMeta] = useState({
    version: "Loading...",
    trainedAt: "Loading...",
    f1Score: "Loading...",
    trainingRows: 0,
  });

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(""), 3000);
  };

  // Fetch overrides (Layer 1)
  const fetchOverrides = () => {
    setLoading(true);
    getNluOverrides()
      .then((data) => {
        setLayer1Rules(data);
        setLoading(false);
      })
      .catch((err) => {
        showToast("Error loading rules: " + err.message);
        setLoading(false);
      });
  };

  // Fetch aggregations (Layer 2)
  const fetchAggregations = () => {
    setLoading(true);
    getNluAggregations()
      .then((data) => {
        setAggregations(data.map(item => ({ ...item, approved: false })));
        setLoading(false);
      })
      .catch((err) => {
        showToast("Error loading aggregations: " + err.message);
        setLoading(false);
      });
  };

  // Fetch training status and model metadata
  const fetchTrainStatus = () => {
    getNluTrainStatus()
      .then((data) => {
        setIsTraining(data.training_active);
      })
      .catch(() => {});
    getNluModelMeta()
      .then((data) => {
        setModelMeta(data);
      })
      .catch(() => {});
  };

  // Load active tab data
  useEffect(() => {
    if (activeTab === "layer1") {
      fetchOverrides();
    } else if (activeTab === "layer2") {
      fetchAggregations();
    } else if (activeTab === "model") {
      fetchTrainStatus();
    }
  }, [activeTab]);

  // Add Exact rule
  const handleAddRule = (e) => {
    e.preventDefault();
    if (!newKeyword.trim() || !newUserId.trim()) {
      showToast("Please provide target User ID and keyword phrase.");
      return;
    }
    setLoading(true);
    addNluOverride(newUserId.trim(), newKeyword.trim().toLowerCase(), newCategory)
      .then(() => {
        setNewKeyword("");
        fetchOverrides();
        showToast("Layer 1 Exact Match rule registered in PostgreSQL!");
      })
      .catch((err) => {
        showToast("Failed to add override: " + err.message);
        setLoading(false);
      });
  };

  // Delete Exact rule
  const handleDeleteRule = (userId, keyword) => {
    setLoading(true);
    deleteNluOverride(userId, keyword)
      .then(() => {
        fetchOverrides();
        showToast("Override rule revoked successfully.");
      })
      .catch((err) => {
        showToast("Failed to delete rule: " + err.message);
        setLoading(false);
      });
  };

  // Toggle checks in Aggregation tab
  const toggleAggregateApprove = (idx) => {
    const next = [...aggregations];
    next[idx].approved = !next[idx].approved;
    setAggregations(next);
  };

  // Curation export
  const handleExportCuration = () => {
    const selected = aggregations.filter((a) => a.approved);
    if (selected.length === 0) {
      showToast("Please check at least one aggregation row to curate.");
      return;
    }
    setLoading(true);
    curateNluAggregations(selected, autoRetrainAfterCurate)
      .then((res) => {
        fetchAggregations();
        if (autoRetrainAfterCurate) {
          setIsTraining(true);
        }
        showToast(res.message || `Appended ${selected.length} samples to global CSV!`);
      })
      .catch((err) => {
        showToast("Failed to export: " + err.message);
        setLoading(false);
      });
  };

  // Trigger retraining in background
  const handleRetrain = () => {
    setLoading(true);
    triggerNluTrain()
      .then((res) => {
        setIsTraining(true);
        showToast(res.message || "Model retraining started in the NLU background pipeline!");
        setLoading(false);
      })
      .catch((err) => {
        showToast("Failed to start training: " + err.message);
        setLoading(false);
      });
  };

  const filteredRules = layer1Rules.filter((r) =>
    (r.keyword || '').toLowerCase().includes(searchExact.toLowerCase()) ||
    (r.userId || '').toLowerCase().includes(searchExact.toLowerCase()) ||
    (r.email || '').toLowerCase().includes(searchExact.toLowerCase())
  );

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">NLU & Retraining Operations</h1>
        <p className="page-desc">Oversee overrides, curate correction datasets, and trigger global model updates.</p>
      </div>

      <div className="tabs-header">
        <button
          className={`tab-btn ${activeTab === "layer1" ? "active" : ""}`}
          onClick={() => setActiveTab("layer1")}
        >
          Layer 1: Exact Overrides
        </button>
        <button
          className={`tab-btn ${activeTab === "layer2" ? "active" : ""}`}
          onClick={() => setActiveTab("layer2")}
        >
          Layer 2: Correction Curation
        </button>
        <button
          className={`tab-btn ${activeTab === "model" ? "active" : ""}`}
          onClick={() => setActiveTab("model")}
        >
          Model Versioning & Reload
        </button>
      </div>

      {loading && <div style={{ color: "var(--text-secondary)", marginBottom: "16px" }}>Querying PostgreSQL/NLU...</div>}

      {/* TAB 1: EXACT MATCH OVERRIDES */}
      {activeTab === "layer1" && (
        <div className="dashboard-grid">
          <div className="panel">
            <div className="panel-header">
              <h2 className="panel-title">Layer 1 Exact Match Rules ({filteredRules.length})</h2>
              <input
                type="text"
                className="form-input"
                placeholder="Search overrides..."
                style={{ width: "240px", padding: "6px 12px", fontSize: "13px" }}
                value={searchExact}
                onChange={(e) => setSearchExact(e.target.value)}
              />
            </div>

            <div className="table-container">
              <table className="custom-table">
                <thead>
                  <tr>
                    <th>User ID / Account</th>
                    <th>Keyword</th>
                    <th>Assigned Category</th>
                    <th>Date Added</th>
                    <th style={{ textAlign: "right" }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRules.map((rule, idx) => (
                    <tr key={idx}>
                      <td className="monospaced" style={{ fontSize: "12px" }}>
                        <div>{rule.username || 'User'}</div>
                        <div style={{ color: "var(--text-muted)", fontSize: "11px" }}>{rule.userId}</div>
                      </td>
                      <td>"{rule.keyword}"</td>
                      <td>
                        <span className="badge badge-success">{rule.categoryCode}</span>
                      </td>
                      <td style={{ fontSize: "12px" }}>{new Date(rule.date).toISOString().split("T")[0]}</td>
                      <td style={{ textAlign: "right" }}>
                        <button
                          className="btn btn-secondary"
                          style={{ padding: "4px 8px", fontSize: "12px", color: "var(--accent-rose)" }}
                          onClick={() => handleDeleteRule(rule.userId, rule.keyword)}
                        >
                          Revoke
                        </button>
                      </td>
                    </tr>
                  ))}
                  {filteredRules.length === 0 && (
                    <tr>
                      <td colSpan="5" style={{ textAlign: "center", padding: "20px" }}>
                        No override rules found.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="panel">
            <div className="panel-header">
              <h2 className="panel-title">Register Override Rule</h2>
            </div>
            <form onSubmit={handleAddRule} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
              <div className="form-group">
                <label className="form-label">Target User ID (UUID)</label>
                <input
                  type="text"
                  className="form-input monospaced"
                  placeholder="e.g. 1a2b3c4d-..."
                  value={newUserId}
                  onChange={(e) => setNewUserId(e.target.value)}
                  required
                />
              </div>

              <div className="form-group">
                <label className="form-label">Keyword Phrase</label>
                <input
                  type="text"
                  className="form-input"
                  placeholder="e.g. uống trà sữa xingfu"
                  value={newKeyword}
                  onChange={(e) => setNewKeyword(e.target.value)}
                  required
                />
              </div>

              <div className="form-group">
                <label className="form-label">Category Code</label>
                <select
                  className="form-select"
                  value={newCategory}
                  onChange={(e) => setNewCategory(e.target.value)}
                >
                  <option value="Food">Food (Ăn uống)</option>
                  <option value="Shopping">Shopping (Mua sắm)</option>
                  <option value="Transport">Transport (Di chuyển)</option>
                  <option value="Entertainment">Entertainment (Giải trí)</option>
                  <option value="Housing">Housing (Nhà ở)</option>
                  <option value="Health">Health (Sức khoẻ)</option>
                  <option value="Education">Education (Học tập)</option>
                  <option value="Travel">Travel (Du lịch)</option>
                  <option value="Others">Others (Khác)</option>
                  <option value="Salary">Salary (Lương)</option>
                  <option value="Bonus">Bonus (Thưởng/Lì xì)</option>
                  <option value="Business">Business (Kinh doanh)</option>
                  <option value="Essentials">Essentials (Thiết yếu)</option>
                  <option value="Beauty">Beauty (Làm đẹp)</option>
                  <option value="Social">Social (Xã hội)</option>
                </select>
              </div>

              <button type="submit" className="btn btn-primary" style={{ marginTop: "8px" }}>
                Add Custom Mapping
              </button>
            </form>
          </div>
        </div>
      )}

      {/* TAB 2: CORRECTION AGGREGATION & CURATION */}
      {activeTab === "layer2" && (
        <div className="panel">
          <div className="panel-header">
            <div>
              <h2 className="panel-title">Correction Aggregation Clusters (Layer 2)</h2>
              <p className="form-desc" style={{ marginTop: "4px" }}>
                Terms frequently corrected by users. Approve to append directly to the NLU training CSV.
              </p>
            </div>
            <button className="btn btn-primary" onClick={handleExportCuration} disabled={aggregations.length === 0}>
              Approve & Curation Train
            </button>
            <label style={{ display: "flex", alignItems: "center", gap: "8px", fontSize: "13px", marginTop: "8px" }}>
              <input
                type="checkbox"
                checked={autoRetrainAfterCurate}
                onChange={(e) => setAutoRetrainAfterCurate(e.target.checked)}
                style={{ width: "16px", height: "16px", accentColor: "var(--accent-emerald)" }}
              />
              Tự động retrain NLU sau khi duyệt curation
            </label>
          </div>

          <div className="table-container">
            <table className="custom-table">
              <thead>
                <tr>
                  <th style={{ width: "40px", paddingLeft: "24px" }}>Curate</th>
                  <th>Raw Correction Term</th>
                  <th>User Mapped Category</th>
                  <th>Record Type</th>
                  <th>Original AI Prediction</th>
                  <th>Anomaly Count (Votes)</th>
                  <th>Action State</th>
                </tr>
              </thead>
              <tbody>
                {aggregations.map((agg, idx) => (
                  <tr key={idx} style={{ opacity: agg.approved ? 1 : 0.85 }}>
                    <td style={{ paddingLeft: "24px" }}>
                      <input
                        type="checkbox"
                        checked={agg.approved}
                        onChange={() => toggleAggregateApprove(idx)}
                        style={{ width: "16px", height: "16px", accentColor: "var(--accent-emerald)" }}
                      />
                    </td>
                    <td className="monospaced">"{agg.text}"</td>
                    <td>
                      <span className="badge badge-success">{agg.targetCategory}</span>
                    </td>
                    <td>
                      <span className="badge badge-info">{agg.recordType || "Expense"}</span>
                    </td>
                    <td>
                      <span className="badge badge-danger">{agg.originalCategory}</span>
                    </td>
                    <td style={{ fontWeight: "700" }}>{agg.count.toLocaleString()}</td>
                    <td>
                      {agg.approved ? (
                        <span style={{ color: "var(--accent-emerald)" }}>✓ Approved to train</span>
                      ) : (
                        <span style={{ color: "var(--text-muted)" }}>Pending curation</span>
                      )}
                    </td>
                  </tr>
                ))}
                {aggregations.length === 0 && (
                  <tr>
                    <td colSpan="7" style={{ textAlign: "center", padding: "20px" }}>
                      No active corrections aggregated in PostgreSQL log yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: MODEL VERSIONING & HOT-RELOAD */}
      {activeTab === "model" && (
        <div className="dashboard-grid">
          <div className="panel">
            <div className="panel-header">
              <h2 className="panel-title">Current Model Registry</h2>
              <button className="btn btn-secondary" style={{ padding: "4px 8px", fontSize: "12px" }} onClick={fetchTrainStatus}>Refresh Status</button>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span>Model Identifier</span>
                <strong className="monospaced" style={{ color: "var(--accent-blue-hover)" }}>{modelMeta.version}</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span>Training Timestamp</span>
                <strong className="monospaced">{modelMeta.trainedAt}</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span>Classification F1-Score</span>
                <strong className="monospaced" style={{ color: "var(--accent-emerald)" }}>{modelMeta.f1Score}</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", paddingBottom: "12px" }}>
                <span>Training Pipeline Status</span>
                <strong className="monospaced">
                  {isTraining ? (
                    <span style={{ color: "var(--accent-amber-hover)" }}>● Retraining actively running...</span>
                  ) : (
                    <span style={{ color: "var(--accent-emerald)" }}>● Idle (Model loaded)</span>
                  )}
                </strong>
              </div>
            </div>
          </div>

          <div className="panel">
            <div className="panel-header">
              <h2 className="panel-title">Run Training Script</h2>
            </div>
            <div className="file-upload-zone" onClick={isTraining ? undefined : handleRetrain} style={{ opacity: isTraining ? 0.6 : 1, cursor: isTraining ? "not-allowed" : "pointer" }}>
              <div style={{ fontSize: "36px", marginBottom: "8px" }}>🚀</div>
              <h3 style={{ color: "var(--text-primary)", fontSize: "14px", marginBottom: "4px" }}>
                {isTraining ? "Retraining in progress..." : "Trigger Model Retraining"}
              </h3>
              <p className="form-desc">Triggers `retrain_all.py` on the NLU service to retrain all intent and category classifier models on disk.</p>
            </div>
            <button className="btn btn-secondary" style={{ width: "100%", borderStyle: "dashed" }} onClick={isTraining ? undefined : handleRetrain} disabled={isTraining}>
              {isTraining ? "Retraining active" : "Reload / Train NLU Service"}
            </button>
          </div>
        </div>
      )}

      {toastMessage && (
        <div className="toast">
          <div className="brand-dot" style={{ background: "var(--accent-blue)", boxShadow: "0 0 10px var(--accent-blue)" }}></div>
          <span>{toastMessage}</span>
        </div>
      )}
    </div>
  );
}

export default NluOpsPage;
