import { useState, useEffect } from "react";
import {
  getNluOverrides,
  addNluOverride,
  deleteNluOverride,
  cleanupInvalidNluOverrides,
  getNluAggregations,
  curateNluAggregations,
  triggerNluTrain,
  getNluTrainStatus,
  getNluModelMeta,
  getNluTrainHistory,
  importNluCsv,
  reloadAiModels,
  fetchNluKaggleJobs,
  fetchNluKaggleJob,
  syncNluKaggle,
  syncNluEncoderKaggle,
  resumeNluKaggle,
  trainEncoderKaggle,
  getNluInferenceBackend,
  setNluInferenceBackend,
} from "../services/api";

const NLU_METRIC_SOURCES = {
  nlu_record: { key: "category" },
  nlu_chitchat: { key: "intent" },
  fusion: { key: "record_type" },
  nlu_action: { key: "action_type" },
  nlu_action_slots: { key: "action_slots", slots: true },
  ner: { key: "ner", ner: true },
};

function normalizePct(val) {
  if (val === undefined || val === null) return null;
  const n = Number(val);
  if (Number.isNaN(n)) return null;
  return n <= 1 ? n * 100 : n;
}

function getMetricValue(modelKey, metricKey, metricsObj) {
  const src = NLU_METRIC_SOURCES[modelKey];
  if (!src || !metricsObj) return null;
  const block = metricsObj[src.key];
  if (!block) return null;
  if (src.slots) {
    const block = metricsObj[src.key];
    const summary = block?.summary;
    if (!summary) return null;
    if (metricKey === "accuracy") return normalizePct(summary.avg_accuracy);
    if (metricKey === "f1_score") return normalizePct(summary.avg_weighted_f1);
    return null;
  }
  if (src.ner) {
    const map = { accuracy: "score", precision: "ents_p", recall: "ents_r", f1_score: "ents_f" };
    return normalizePct(block[map[metricKey]]);
  }
  const map = {
    accuracy: "accuracy",
    precision: "weighted_precision",
    recall: "weighted_recall",
    f1_score: "weighted_f1",
  };
  return normalizePct(block[map[metricKey]]);
}

const COMPARISON_ROWS = {
  tfidf: [
    { key: "nlu_record", label: "Category Model (category)", desc: "Phân loại danh mục chi tiêu tự động — TF-IDF" },
    { key: "nlu_chitchat", label: "Intent Model (intent-model)", desc: "Nhận diện ý định giao dịch / Trò chuyện — TF-IDF" },
    { key: "fusion", label: "Record Type Model (recordtype)", desc: "Phân loại Thu nhập / Chi tiêu — TF-IDF" },
    { key: "nlu_action", label: "Action Model (actiontype)", desc: "Nhận diện hành động thao tác ví — TF-IDF" },
    { key: "nlu_action_slots", label: "Action Slots (verb, category, time…)", desc: "Dự đoán slot chi tiết theo action_type (TF-IDF per field)" },
    { key: "ner", label: "Named Entity Recognition (spaCy NER)", desc: "Nhận diện thực thể tên riêng, số tiền, ngày tháng" },
  ],
  encoder: [
    { key: "nlu_record", label: "Category (PhoBERT encoder)", desc: "Phân loại danh mục chi tiêu — embedding PhoBERT" },
    { key: "nlu_chitchat", label: "Intent (PhoBERT encoder)", desc: "Record / Action / Chitchat — embedding PhoBERT" },
    { key: "fusion", label: "Record Type (PhoBERT encoder)", desc: "Thu nhập / Chi tiêu — embedding PhoBERT" },
    { key: "nlu_action", label: "Action Type (PhoBERT encoder)", desc: "SET_LIMIT, ADD_GOAL, … — embedding PhoBERT" },
  ],
};

function historyTrainType(entry) {
  return entry?.train_type || "tfidf";
}

function filterHistoryByType(history, type) {
  return (history || []).filter((r) => historyTrainType(r) === type && r.status === "success");
}


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
  const [aggregations, setAggregations] = useState([]);
  const [autoRetrainAfterCurate, setAutoRetrainAfterCurate] = useState("local");

  // Model status state
  const [isTraining, setIsTraining] = useState(false);
  const [kaggleJobs, setKaggleJobs] = useState([]);
  const [activeKaggleJob, setActiveKaggleJob] = useState(null);
  const [modelMeta, setModelMeta] = useState({
    version: "Loading...",
    trainedAt: "Loading...",
    f1Score: "Loading...",
    trainingRows: 0,
  });
  const [trainHistory, setTrainHistory] = useState([]);
  const [reloadingNlu, setReloadingNlu] = useState(false);
  const [syncingKaggle, setSyncingKaggle] = useState(false);
  const [syncingEncoderKaggle, setSyncingEncoderKaggle] = useState(false);
  const [resumingKaggle, setResumingKaggle] = useState(false);
  const [trainingEncoder, setTrainingEncoder] = useState(false);
  const [inferenceBackend, setInferenceBackend] = useState("tfidf");
  const [savingBackend, setSavingBackend] = useState(false);
  const [compareTrainType, setCompareTrainType] = useState("tfidf");

  // CSV Import state
  const [csvFile, setCsvFile] = useState(null);
  const [autoRetrainCsv, setAutoRetrainCsv] = useState("local");
  const [importingCsv, setImportingCsv] = useState(false);

  const renderMetricCell = (modelKey, metricKey, trainType = compareTrainType) => {
    const filtered = filterHistoryByType(trainHistory, trainType);
    const newModel = filtered.length > 0 ? filtered[filtered.length - 1] : null;
    const oldModel = filtered.length > 1 ? filtered[filtered.length - 2] : null;

    const newVal = getMetricValue(modelKey, metricKey, newModel?.metrics);
    const oldVal = getMetricValue(modelKey, metricKey, oldModel?.metrics);
    
    if (newVal === undefined || newVal === null) {
      return <span style={{ color: "var(--text-muted)", fontSize: "13px" }}>-</span>;
    }
    
    const formattedNew = `${newVal.toFixed(1)}%`;
    if (oldVal === undefined || oldVal === null) {
      return (
        <div>
          <span style={{ color: "var(--text-primary)", fontWeight: "600", fontSize: "13px" }}>{formattedNew}</span>
        </div>
      );
    }
    
    const formattedOld = `${oldVal.toFixed(1)}%`;
    const diff = newVal - oldVal;
    const diffColor = diff > 0 ? "var(--accent-emerald-hover)" : diff < 0 ? "var(--accent-rose)" : "var(--text-muted)";
    const diffSign = diff > 0 ? `+${diff.toFixed(1)}%` : diff < 0 ? `${diff.toFixed(1)}%` : "0.0%";
    const arrow = diff > 0 ? "▲" : diff < 0 ? "▼" : "•";
    
    return (
      <div style={{ display: "flex", flexDirection: "column", gap: "2px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
          <span style={{ color: "var(--text-primary)", fontWeight: "600", fontSize: "13px" }}>{formattedNew}</span>
          <span style={{ fontSize: "11px", color: diffColor, fontWeight: "700", display: "flex", alignItems: "center", gap: "2px" }}>
            {arrow} {diffSign}
          </span>
        </div>
        <div style={{ fontSize: "11px", color: "var(--text-muted)" }}>
          Cũ: {formattedOld}
        </div>
      </div>
    );
  };

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(""), 3000);
  };

  // Fetch all NLU telemetry initially to populate stats
  const fetchAllData = () => {
    setLoading(true);
    Promise.all([
      getNluOverrides().catch(() => []),
      getNluAggregations().catch(() => []),
      getNluTrainStatus().catch(() => ({ training_active: false })),
      getNluModelMeta().catch(() => ({ version: "v1.2.0-fallback", trainedAt: "2026-06-21", f1Score: "91.2%" })),
      getNluTrainHistory().catch(() => []),
      fetchNluKaggleJobs().catch(() => []),
      getNluInferenceBackend().catch(() => ({ backend: "tfidf" })),
    ])
      .then(([overridesData, aggregationsData, statusData, metaData, historyData, kaggleJobsData, backendData]) => {
        setLayer1Rules(overridesData);
        setAggregations(aggregationsData.map(item => ({ ...item, approved: false })));
        setIsTraining(statusData.training_active);
        setModelMeta(metaData);
        setTrainHistory(historyData);
        setKaggleJobs(kaggleJobsData);
        const active = kaggleJobsData.find(job => !["completed", "failed"].includes(job.status));
        setActiveKaggleJob(active || null);
        setInferenceBackend(backendData?.backend || metaData?.inferenceBackend || "tfidf");
        const backend = backendData?.backend || metaData?.inferenceBackend || "tfidf";
        setCompareTrainType(backend === "encoder" ? "encoder" : "tfidf");
        setLoading(false);
      })
      .catch((err) => {
        showToast("Error loading telemetry data: " + err.message);
        setLoading(false);
      });
  };

  useEffect(() => {
    fetchAllData();
  }, []);

  // Poll training status if active
  useEffect(() => {
    let intervalId;
    if (isTraining) {
      intervalId = setInterval(() => {
        getNluTrainStatus()
          .then((data) => {
            if (!data.training_active) {
              setIsTraining(false);
              showToast("Model retraining completed successfully!");
              getNluModelMeta().then(meta => setModelMeta(meta)).catch(() => {});
              getNluTrainHistory().then(history => setTrainHistory(history)).catch(() => {});
            }
          })
          .catch(() => {});
      }, 5000);
    }
    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }, [isTraining]);

  // Poll NLU Kaggle jobs if there is an active job in progress
  useEffect(() => {
    let intervalId;
    const hasActiveJob = kaggleJobs.some(job => 
      !["completed", "failed"].includes(job.status)
    );
    
    if (hasActiveJob || activeKaggleJob) {
      intervalId = setInterval(() => {
        fetchNluKaggleJobs()
          .then((jobs) => {
            setKaggleJobs(jobs);
            const active = jobs.find(job => !["completed", "failed"].includes(job.status));
            
            if (activeKaggleJob && !active) {
              showToast("Kaggle NLU retraining finished!");
              getNluModelMeta().then(meta => setModelMeta(meta)).catch(() => {});
              getNluTrainHistory().then(history => setTrainHistory(history)).catch(() => {});
            }
            setActiveKaggleJob(active || null);
          })
          .catch(() => {});
      }, 5000);
    }
    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }, [kaggleJobs, activeKaggleJob]);

  // Tab switching loads specific data just in case
  const handleTabChange = (tab) => {
    setActiveTab(tab);
    if (tab === "layer1") {
      getNluOverrides().then(data => setLayer1Rules(data)).catch(() => {});
    } else if (tab === "layer2") {
      getNluAggregations().then(data => setAggregations(data.map(item => ({ ...item, approved: false })))).catch(() => {});
    } else if (tab === "model") {
      getNluTrainStatus().then(data => setIsTraining(data.training_active)).catch(() => {});
      getNluModelMeta().then(data => setModelMeta(data)).catch(() => {});
      getNluTrainHistory().then(data => setTrainHistory(data)).catch(() => {});
    }
  };

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
        // Keep ID to allow quick multiple additions for the same user
        getNluOverrides().then(data => {
          setLayer1Rules(data);
          setLoading(false);
        });
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
        getNluOverrides().then(data => {
          setLayer1Rules(data);
          setLoading(false);
        });
        showToast("Override rule revoked successfully.");
      })
      .catch((err) => {
        showToast("Failed to delete rule: " + err.message);
        setLoading(false);
      });
  };

  const handleCleanupInvalidRules = async () => {
    setLoading(true);
    try {
      const preview = await cleanupInvalidNluOverrides(false);
      if (!preview.invalidCount) {
        showToast("Không có rule Layer 1 sai cần dọn.");
        setLoading(false);
        return;
      }
      const sample = (preview.invalid || [])
        .slice(0, 3)
        .map((r) => `"${r.keyword}"`)
        .join(", ");
      const ok = window.confirm(
        `Tìm thấy ${preview.invalidCount} rule sai (tên category, OCR dài, v.v.).\n` +
          `Ví dụ: ${sample}\n\nXóa tất cả?`
      );
      if (!ok) {
        setLoading(false);
        return;
      }
      const result = await cleanupInvalidNluOverrides(true);
      const data = await getNluOverrides();
      setLayer1Rules(data);
      showToast(`Đã xóa ${result.removed} rule Layer 1 không hợp lệ.`);
    } catch (err) {
      showToast("Dọn rule thất bại: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleImportCsv = (e) => {
    e.preventDefault();
    if (!csvFile) {
      showToast("Vui lòng chọn một tập tin CSV!");
      return;
    }
    setImportingCsv(true);
    const autoRetrain = autoRetrainCsv !== "none";
    importNluCsv(csvFile, autoRetrain, autoRetrainCsv)
      .then((data) => {
        showToast(`Đã import thành công ${data.addedCount} dòng mới!`);
        setCsvFile(null);
        const fileInput = document.getElementById("nlu-csv-file-input");
        if (fileInput) fileInput.value = "";
        setImportingCsv(false);
        fetchAllData();
      })
      .catch((err) => {
        showToast("Import thất bại: " + err.message);
        setImportingCsv(false);
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
    const autoRetrain = autoRetrainAfterCurate !== "none";
    curateNluAggregations(selected, autoRetrain, autoRetrainAfterCurate)
      .then((res) => {
        getNluAggregations().then(data => {
          setAggregations(data.map(item => ({ ...item, approved: false })));
          setLoading(false);
        });
        if (autoRetrain) {
          if (autoRetrainAfterCurate === "kaggle") {
            showToast("Đã lưu curation và kích hoạt train trên Kaggle!");
            fetchNluKaggleJobs().then(setKaggleJobs).catch(() => {});
          } else {
            setIsTraining(true);
          }
        }
        showToast(res.message || `Appended ${selected.length} samples to global CSV!`);
      })
      .catch((err) => {
        showToast("Failed to export: " + err.message);
        setLoading(false);
      });
  };

  // Trigger retraining in background
  const handleRetrain = (target = "local") => {
    setLoading(true);
    triggerNluTrain(target)
      .then((res) => {
        if (target === "kaggle") {
          showToast("NLU Kaggle retraining started!");
          fetchNluKaggleJobs().then((jobs) => {
            setKaggleJobs(jobs);
            const active = jobs.find(job => !["completed", "failed"].includes(job.status));
            setActiveKaggleJob(active || null);
          }).catch(() => {});
        } else {
          setIsTraining(true);
          showToast(res.message || "Model retraining started in the NLU background pipeline!");
        }
        setLoading(false);
      })
      .catch((err) => {
        showToast("Failed to start training: " + err.message);
        setLoading(false);
      });
  };

  const handleReloadNlu = () => {
    setReloadingNlu(true);
    reloadAiModels("nlu")
      .then((res) => {
        setReloadingNlu(false);
        const ver = res.nlu_version ? ` (${res.nlu_version})` : "";
        showToast((res.message || "Model NLU đã được nạp nóng thành công!") + ver);
        fetchAllData();
      })
      .catch((err) => {
        setReloadingNlu(false);
        showToast("Tải lại model thất bại: " + err.message);
      });
  };

  const handleSyncKaggle = (trainType = "tfidf") => {
    const isEncoder = trainType === "encoder";
    if (isEncoder) setSyncingEncoderKaggle(true);
    else setSyncingKaggle(true);

    const syncFn = isEncoder ? syncNluEncoderKaggle : syncNluKaggle;
    syncFn(false)
      .then(async (res) => {
        if (isEncoder) setSyncingEncoderKaggle(false);
        else setSyncingKaggle(false);
        showToast(res.message || `Sync ${isEncoder ? "Encoder" : "TF-IDF"} OK — F1 ${res.f1_score || ""}`);
        fetchAllData();
        try {
          const reloadRes = await reloadAiModels("nlu");
          if (reloadRes?.ok) {
            showToast(`NLU đã nạp nóng sau sync (${reloadRes.nlu_version || inferenceBackend})`);
            fetchAllData();
          }
        } catch (reloadErr) {
          showToast(`Sync OK — bấm Tải lại model NLU: ${reloadErr.message}`);
        }
      })
      .catch((err) => {
        if (isEncoder) setSyncingEncoderKaggle(false);
        else setSyncingKaggle(false);
        showToast(`Sync ${isEncoder ? "Encoder" : "TF-IDF"} thất bại: ${err.message}`);
      });
  };

  const handleResumeKaggle = () => {
    setResumingKaggle(true);
    resumeNluKaggle()
      .then((res) => {
        setResumingKaggle(false);
        showToast(res.message || `Resume OK — job ${res.job_id?.slice(0, 8)}`);
        fetchNluKaggleJobs().then((jobs) => {
          setKaggleJobs(jobs);
          const active = jobs.find(job => !["completed", "failed"].includes(job.status));
          setActiveKaggleJob(active || null);
        }).catch(() => {});
      })
      .catch((err) => {
        setResumingKaggle(false);
        showToast("Resume thất bại: " + err.message);
      });
  };

  const handleTrainEncoder = () => {
    setTrainingEncoder(true);
    trainEncoderKaggle()
      .then((res) => {
        setTrainingEncoder(false);
        showToast(res.message || `Encoder Kaggle job ${res.job_id?.slice(0, 8)}`);
        fetchNluKaggleJobs().then((jobs) => {
          setKaggleJobs(jobs);
          const active = jobs.find(job => !["completed", "failed"].includes(job.status));
          setActiveKaggleJob(active || null);
        }).catch(() => {});
      })
      .catch((err) => {
        setTrainingEncoder(false);
        showToast("Encoder Kaggle failed: " + err.message);
      });
  };

  const handleInferenceBackendChange = (backend) => {
    if (backend === inferenceBackend) return;
    setSavingBackend(true);
    setNluInferenceBackend(backend)
      .then((res) => {
        setSavingBackend(false);
        setInferenceBackend(res.backend || backend);
        setCompareTrainType((res.backend || backend) === "encoder" ? "encoder" : "tfidf");
        showToast(res.message || `NLU backend → ${backend}`);
        getNluModelMeta().then(setModelMeta).catch(() => {});
      })
      .catch((err) => {
        setSavingBackend(false);
        showToast("Đổi backend thất bại: " + err.message);
      });
  };

  const isEncoderJob = (job) => {
    if (!job) return false;
    const scope = String(job.scope || "").toLowerCase();
    if (scope === "encoder" || scope === "nlu_encoder") return true;
    return String(job.kernel || "").toLowerCase().includes("encoder");
  };

  const jobScopeLabel = (job) => {
    if (isEncoderJob(job)) return "PhoBERT Encoder";
    return "TF-IDF + NER";
  };

  const activeEncoderJob =
    activeKaggleJob && isEncoderJob(activeKaggleJob) ? activeKaggleJob : null;
  const activeTfidfKaggleJob =
    activeKaggleJob && !isEncoderJob(activeKaggleJob) ? activeKaggleJob : null;
  const anyKaggleJobActive = Boolean(activeKaggleJob);

  const hasStuckJob = kaggleJobs.some(job =>
    !["completed", "failed"].includes(job.status)
  );

  const filteredRules = layer1Rules.filter((r) =>
    (r.keyword || '').toLowerCase().includes(searchExact.toLowerCase()) ||
    (r.userId || '').toLowerCase().includes(searchExact.toLowerCase()) ||
    (r.email || '').toLowerCase().includes(searchExact.toLowerCase())
  );

  return (
    <div className="page-container" style={{ padding: "30px 40px" }}>
      <div className="page-header" style={{ marginBottom: "24px" }}>
        <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px" }}>NLU & Retraining Operations</h1>
        <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "4px" }}>
          Oversee overrides, curate correction datasets, and trigger global model updates.
        </p>
      </div>

      {/* DevOps Status Strip */}
      <div className="bill-stat-strip" style={{
        marginBottom: "30px",
        background: "var(--bg-obsidian-900)",
        border: "1px solid var(--border-color)",
        borderRadius: "16px",
        padding: "20px 24px",
        display: "grid",
        gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
        gap: "20px",
        boxShadow: "inset 0 1px 0 rgba(255, 255, 255, 0.02)"
      }}>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Active Overrides</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: "var(--accent-blue-hover)", fontFamily: "var(--font-sans)" }}>{layer1Rules.length} rules</span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Correction Pool</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: "var(--accent-amber-hover)", fontFamily: "var(--font-sans)" }}>{aggregations.length} clusters</span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Model Version</span>
          <span className="bill-stat-value" style={{ fontSize: "18px", fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)", letterSpacing: "-0.5px" }}>{modelMeta.version || "Unknown"}</span>
        </div>
        <div className="bill-stat" style={{ borderRight: "none" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Pipeline Status</span>
          <span className="bill-stat-value" style={{
            fontSize: "18px",
            fontWeight: "700",
            color: isTraining ? "var(--accent-amber-hover)" : "var(--accent-emerald-hover)",
            display: "flex",
            alignItems: "center",
            gap: "8px"
          }}>
            <span className="status-dot" style={{
              background: isTraining ? "var(--accent-amber)" : "var(--accent-emerald)",
              boxShadow: isTraining ? "0 0 10px var(--accent-amber)" : "0 0 10px var(--accent-emerald)",
              animation: isTraining ? "pulse 1.5s infinite" : "none",
              width: "8px",
              height: "8px",
              borderRadius: "50%"
            }}></span>
            {isTraining ? "Retraining..." : "Operational"}
          </span>
        </div>
      </div>

      <div className="tabs-header" style={{ marginBottom: "28px" }}>
        <button
          className={`tab-btn ${activeTab === "layer1" ? "active" : ""}`}
          onClick={() => handleTabChange("layer1")}
          style={{ fontSize: "14px", padding: "12px 20px" }}
        >
          Layer 1: Exact Overrides
        </button>
        <button
          className={`tab-btn ${activeTab === "layer2" ? "active" : ""}`}
          onClick={() => handleTabChange("layer2")}
          style={{ fontSize: "14px", padding: "12px 20px" }}
        >
          Layer 2: Correction Curation
        </button>
        <button
          className={`tab-btn ${activeTab === "model" ? "active" : ""}`}
          onClick={() => handleTabChange("model")}
          style={{ fontSize: "14px", padding: "12px 20px" }}
        >
          Model Versioning & Reload
        </button>
      </div>

      {loading && (
        <div style={{ display: "flex", alignItems: "center", gap: "10px", color: "var(--text-secondary)", marginBottom: "20px", fontSize: "13px" }}>
          <span className="status-dot" style={{ background: "var(--accent-blue)", boxShadow: "0 0 8px var(--accent-blue)", animation: "pulse 1.5s infinite", width: "6px", height: "6px", borderRadius: "50%" }}></span>
          <span>Querying PostgreSQL log indices and weights...</span>
        </div>
      )}

      {/* TAB 1: EXACT MATCH OVERRIDES */}
      {activeTab === "layer1" && (
        <div className="dashboard-grid" style={{ gap: "24px" }}>
          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
          }}>
            <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)" }}>
              <div>
                <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Layer 1: Custom Map Rules</h2>
                <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>
                  Active mapping overrides forcing specific phrases directly to categories.
                </span>
              </div>
              <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  style={{ whiteSpace: "nowrap", fontSize: "13px" }}
                  disabled={loading}
                  onClick={handleCleanupInvalidRules}
                >
                  Dọn rule sai
                </button>
                <input
                  type="text"
                  className="form-input"
                  placeholder="Search overrides by term or user..."
                  style={{ width: "260px", padding: "8px 14px", fontSize: "13px", background: "var(--bg-obsidian-950)", borderRadius: "8px", border: "1px solid var(--border-color)" }}
                  value={searchExact}
                  onChange={(e) => setSearchExact(e.target.value)}
                />
              </div>
            </div>

            <div className="table-container" style={{ borderRadius: "12px", border: "1px solid var(--border-color)", overflow: "hidden", marginTop: "10px" }}>
              <table className="custom-table">
                <thead>
                  <tr style={{ background: "var(--bg-obsidian-950)" }}>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>User ID / Account</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Keyword Phrase</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Category Mapped</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Timestamp</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em", textAlign: "right" }}>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRules.map((rule, idx) => (
                    <tr key={idx} style={{ transition: "background 0.15s ease" }}>
                      <td className="monospaced" style={{ padding: "14px 18px" }}>
                        <div style={{ color: "var(--text-primary)", fontWeight: "500", fontSize: "13px" }}>{rule.username || 'Active Client'}</div>
                        <div style={{ color: "var(--text-muted)", fontSize: "11px", marginTop: "2px" }}>{rule.userId}</div>
                      </td>
                      <td style={{ padding: "14px 18px", fontSize: "13px", color: "var(--text-primary)" }}>
                        <code style={{ background: "var(--bg-obsidian-950)", padding: "4px 8px", borderRadius: "6px", border: "1px solid var(--border-color)", fontFamily: "var(--font-mono)" }}>"{rule.keyword}"</code>
                      </td>
                      <td style={{ padding: "14px 18px" }}>
                        <span className="badge badge-success" style={{
                          background: "rgba(16, 185, 129, 0.08)",
                          border: "1px solid rgba(16, 185, 129, 0.3)",
                          color: "var(--accent-emerald-hover)",
                          padding: "4px 10px",
                          borderRadius: "8px",
                          fontWeight: "600",
                          fontSize: "11px"
                        }}>
                          {rule.categoryCode}
                        </span>
                      </td>
                      <td style={{ padding: "14px 18px", fontSize: "12px", color: "var(--text-secondary)" }}>
                        {new Date(rule.date || Date.now()).toISOString().split("T")[0]}
                      </td>
                      <td style={{ padding: "14px 18px", textAlign: "right" }}>
                        <button
                          className="btn"
                          style={{
                            padding: "6px 12px",
                            fontSize: "12px",
                            color: "var(--accent-rose)",
                            background: "rgba(239, 68, 68, 0.05)",
                            border: "1px solid rgba(239, 68, 68, 0.2)",
                            borderRadius: "6px",
                            transition: "all 0.2s"
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = "rgba(239, 68, 68, 0.12)";
                            e.currentTarget.style.borderColor = "var(--accent-rose)";
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = "rgba(239, 68, 68, 0.05)";
                            e.currentTarget.style.borderColor = "rgba(239, 68, 68, 0.2)";
                          }}
                          onClick={() => handleDeleteRule(rule.userId, rule.keyword)}
                        >
                          Revoke rule
                        </button>
                      </td>
                    </tr>
                  ))}
                  {filteredRules.length === 0 && (
                    <tr>
                      <td colSpan="5" style={{ textAlign: "center", padding: "40px", color: "var(--text-muted)" }}>
                        No active exact match overrides registered.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
            height: "fit-content"
          }}>
            <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", alignItems: "center", gap: "8px" }}>
              <div className="brand-dot" style={{ background: "var(--accent-blue)" }}></div>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Register Exact Override</h2>
            </div>
            <form onSubmit={handleAddRule} style={{ display: "flex", flexDirection: "column", gap: "18px", marginTop: "16px" }}>
              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)" }}>Target User ID (UUID)</label>
                <input
                  type="text"
                  className="form-input monospaced"
                  placeholder="e.g. 8f6d7c89-a29b-..."
                  style={{ background: "var(--bg-obsidian-950)", fontSize: "13px" }}
                  value={newUserId}
                  onChange={(e) => setNewUserId(e.target.value)}
                  required
                />
                <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Override rule will apply exclusively to this client session.</span>
              </div>

              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)" }}>Keyword Phrase</label>
                <input
                  type="text"
                  className="form-input"
                  placeholder="e.g. uống trà sữa xingfu"
                  style={{ background: "var(--bg-obsidian-950)", fontSize: "13px" }}
                  value={newKeyword}
                  onChange={(e) => setNewKeyword(e.target.value)}
                  required
                />
                <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Lowercased text input to search and trigger exact match.</span>
              </div>

              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)" }}>Assigned Category Code</label>
                <select
                  className="form-select"
                  value={newCategory}
                  onChange={(e) => setNewCategory(e.target.value)}
                  style={{ background: "var(--bg-obsidian-950)", fontSize: "13px", height: "40px" }}
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

              <button type="submit" className="btn btn-primary" style={{
                marginTop: "8px",
                background: "var(--accent-blue)",
                color: "var(--text-primary)",
                fontWeight: "600",
                width: "100%",
                padding: "12px",
                border: "none",
                borderRadius: "8px"
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = "var(--accent-blue-hover)";
                e.currentTarget.style.boxShadow = "0 0 15px var(--accent-blue-glow)";
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = "var(--accent-blue)";
                e.currentTarget.style.boxShadow = "none";
              }}
              >
                Register Override Mapping
              </button>
            </form>
          </div>
        </div>
      )}

      {/* TAB 2: CORRECTION AGGREGATION & CURATION */}
      {activeTab === "layer2" && (
        <div className="panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px",
          boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
        }}>
          <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "16px" }}>
            <div>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Correction Clusters (Layer 2)</h2>
              <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>
                Interactive logs aggregated from user corrections. Approve and package them as training points to fine-tune the classifiers.
              </span>
            </div>
            
            <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: "12px" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Tự động huấn luyện:</span>
                  <select
                    value={autoRetrainAfterCurate}
                    onChange={(e) => setAutoRetrainAfterCurate(e.target.value)}
                    style={{
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid var(--border-color)",
                      color: "var(--text-primary)",
                      borderRadius: "6px",
                      padding: "6px 12px",
                      fontSize: "13px",
                      outline: "none",
                      cursor: "pointer"
                    }}
                  >
                    <option value="none">Không</option>
                    <option value="local">Cục bộ (CPU)</option>
                    <option value="kaggle">Kaggle (GPU)</option>
                  </select>
                </div>
                <button
                  className="btn btn-primary"
                  onClick={handleExportCuration}
                  disabled={aggregations.length === 0 || !aggregations.some(a => a.approved)}
                  style={{
                    background: "var(--accent-emerald)",
                    color: "var(--bg-obsidian-950)",
                    fontWeight: "600",
                    padding: "10px 18px",
                    borderRadius: "8px",
                    opacity: (!aggregations.some(a => a.approved)) ? 0.5 : 1,
                    cursor: (!aggregations.some(a => a.approved)) ? "not-allowed" : "pointer"
                  }}
                >
                  Approve & Export Curation ({aggregations.filter(a => a.approved).length})
                </button>
              </div>
            </div>
          </div>

          <div className="table-container" style={{ borderRadius: "12px", border: "1px solid var(--border-color)", overflow: "hidden", marginTop: "20px" }}>
            <table className="custom-table">
              <thead>
                <tr style={{ background: "var(--bg-obsidian-950)" }}>
                  <th style={{ width: "50px", padding: "14px 18px" }}>
                    <input
                      type="checkbox"
                      checked={aggregations.length > 0 && aggregations.every((a) => a.approved)}
                      onChange={(e) => {
                        const checked = e.target.checked;
                        setAggregations(aggregations.map((a) => ({ ...a, approved: checked })));
                      }}
                      style={{ width: "16px", height: "16px", accentColor: "var(--accent-emerald)", cursor: "pointer" }}
                    />
                  </th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Raw Text Block</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>User Mapped</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Record Type</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>AI Initial Guess</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Corrections (Votes)</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em", textAlign: "right" }}>Status</th>
                </tr>
              </thead>
              <tbody>
                {aggregations.map((agg, idx) => (
                  <tr key={idx} style={{
                    transition: "background 0.15s ease",
                    background: agg.approved ? "rgba(16, 185, 129, 0.02)" : "transparent"
                  }}>
                    <td style={{ padding: "14px 18px" }}>
                      <input
                        type="checkbox"
                        checked={agg.approved}
                        onChange={() => toggleAggregateApprove(idx)}
                        style={{ width: "16px", height: "16px", accentColor: "var(--accent-emerald)", cursor: "pointer" }}
                      />
                    </td>
                    <td className="monospaced" style={{ padding: "14px 18px", color: "var(--text-primary)" }}>
                      <code style={{ background: "var(--bg-obsidian-950)", padding: "4px 8px", borderRadius: "6px", border: "1px solid var(--border-color)", fontFamily: "var(--font-mono)" }}>"{agg.text}"</code>
                    </td>
                    <td style={{ padding: "14px 18px" }}>
                      <span className="badge badge-success" style={{
                        background: "rgba(16, 185, 129, 0.08)",
                        border: "1px solid rgba(16, 185, 129, 0.3)",
                        color: "var(--accent-emerald-hover)",
                        padding: "4px 10px",
                        borderRadius: "8px",
                        fontWeight: "600",
                        fontSize: "11px"
                      }}>
                        {agg.targetCategory}
                      </span>
                    </td>
                    <td style={{ padding: "14px 18px" }}>
                      <span className="badge" style={{
                        background: "rgba(2, 132, 199, 0.08)",
                        border: "1px solid rgba(2, 132, 199, 0.3)",
                        color: "var(--accent-blue-hover)",
                        padding: "4px 10px",
                        borderRadius: "8px",
                        fontWeight: "600",
                        fontSize: "11px",
                        textTransform: "uppercase"
                      }}>{agg.recordType || "Expense"}</span>
                    </td>
                    <td style={{ padding: "14px 18px" }}>
                      <span className="badge badge-danger" style={{
                        background: "rgba(239, 68, 68, 0.08)",
                        border: "1px solid rgba(239, 68, 68, 0.3)",
                        color: "var(--accent-rose-hover)",
                        padding: "4px 10px",
                        borderRadius: "8px",
                        fontWeight: "600",
                        fontSize: "11px"
                      }}>
                        {agg.originalCategory}
                      </span>
                    </td>
                    <td style={{ padding: "14px 18px", fontWeight: "700", fontFamily: "var(--font-mono)", fontSize: "14px", color: "var(--text-primary)" }}>
                      {agg.count.toLocaleString()}
                    </td>
                    <td style={{ padding: "14px 18px", textAlign: "right", fontSize: "13px", fontWeight: "600" }}>
                      {agg.approved ? (
                        <span style={{ color: "var(--accent-emerald)" }}>✓ Queued for Train</span>
                      ) : (
                        <span style={{ color: "var(--text-muted)" }}>Pending review</span>
                      )}
                    </td>
                  </tr>
                ))}
                {aggregations.length === 0 && (
                  <tr>
                    <td colSpan="7" style={{ textAlign: "center", padding: "40px", color: "var(--text-muted)" }}>
                      No corrections aggregated in PostgreSQL log index yet.
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
        <>
          <div className="dashboard-grid" style={{ gap: "24px" }}>
          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
          }}>
            <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", gap: "10px", alignItems: "center" }}>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)", marginRight: "auto" }}>Model Core Registry</h2>
              <button
                className="btn btn-secondary"
                style={{ padding: "6px 12px", fontSize: "12px", borderRadius: "6px" }}
                onClick={() => handleSyncKaggle("tfidf")}
                disabled={syncingKaggle || syncingEncoderKaggle || isTraining}
                title="Tải output kernel TF-IDF + NER COMPLETE về server"
              >
                {syncingKaggle ? "Đang sync TF-IDF..." : "Sync TF-IDF Kaggle"}
              </button>
              <button
                className="btn btn-secondary"
                style={{ padding: "6px 12px", fontSize: "12px", borderRadius: "6px", border: "1px solid rgba(139, 92, 246, 0.35)" }}
                onClick={() => handleSyncKaggle("encoder")}
                disabled={syncingKaggle || syncingEncoderKaggle || isTraining}
                title="Tải output kernel PhoBERT encoder COMPLETE về server"
              >
                {syncingEncoderKaggle ? "Đang sync Encoder..." : "Sync Encoder Kaggle"}
              </button>
              <button
                className="btn btn-secondary"
                style={{ padding: "6px 12px", fontSize: "12px", borderRadius: "6px", border: "1px solid var(--border-color)" }}
                onClick={handleReloadNlu}
                disabled={reloadingNlu || isTraining}
              >
                {reloadingNlu ? "Đang tải..." : "Tải lại model NLU"}
              </button>
              <button
                className="btn btn-secondary"
                style={{ padding: "6px 12px", fontSize: "12px", borderRadius: "6px" }}
                onClick={fetchAllData}
              >
                Sync Registry Status
              </button>
            </div>
            
            <div style={{ display: "flex", flexDirection: "column", gap: "16px", marginTop: "16px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Active Registry Identifier</span>
                <strong className="monospaced" style={{ color: "var(--accent-blue-hover)", fontSize: "13px" }}>{modelMeta.version}</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Pipeline Epoch / Trained At</span>
                <strong className="monospaced" style={{ fontSize: "13px" }}>{modelMeta.trainedAt}</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>NLU Inference Backend</span>
                <div style={{ display: "flex", gap: "8px", alignItems: "center" }}>
                  <select
                    value={inferenceBackend}
                    disabled={savingBackend || isTraining}
                    onChange={(e) => handleInferenceBackendChange(e.target.value)}
                    style={{
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid var(--border-color)",
                      color: "var(--text-primary)",
                      borderRadius: "6px",
                      padding: "6px 10px",
                      fontSize: "12px",
                    }}
                  >
                    <option value="tfidf">TF-IDF (mặc định)</option>
                    <option value="encoder">PhoBERT Encoder</option>
                  </select>
                </div>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Global Validation F1-Score</span>
                <strong className="monospaced" style={{ color: "var(--accent-emerald-hover)", fontSize: "13px" }}>{modelMeta.f1Score}</strong>
              </div>
              {modelMeta.pendingNote && (
                <div style={{ fontSize: "12px", color: "var(--accent-amber-hover)", padding: "8px 12px", background: "rgba(245, 158, 11, 0.08)", borderRadius: "8px", border: "1px solid rgba(245, 158, 11, 0.2)" }}>
                  {modelMeta.pendingNote}
                </div>
              )}
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Active Background Worker</span>
                <strong className="monospaced" style={{ fontSize: "13px" }}>
                  {isTraining ? (
                    <span style={{ color: "var(--accent-amber-hover)", display: "flex", alignItems: "center", gap: "6px" }}>
                      <span className="status-dot pulse" style={{ background: "var(--accent-amber)", boxShadow: "0 0 8px var(--accent-amber)", width: "6px", height: "6px", borderRadius: "50%" }}></span>
                      Pipeline retrain-all running...
                    </span>
                  ) : (
                    <span style={{ color: "var(--accent-emerald-hover)", display: "flex", alignItems: "center", gap: "6px" }}>
                      <span className="status-dot" style={{ background: "var(--accent-emerald)", boxShadow: "0 0 8px var(--accent-emerald)", width: "6px", height: "6px", borderRadius: "50%" }}></span>
                      Idle (Model ready for inference)
                    </span>
                  )}
                </strong>
              </div>
            </div>
          </div>

            {/* Trigger Train Worker Panel */}
            <div className="panel" style={{
              background: "var(--bg-obsidian-900)",
              border: "1px solid var(--border-color)",
              borderRadius: "16px",
              padding: "24px",
              display: "flex",
              flexDirection: "column",
              boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
            }}>
              <div>
                <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "16px" }}>
                  <div style={{
                    width: "8px",
                    height: "8px",
                    borderRadius: "50%",
                    background: (isTraining || anyKaggleJobActive) ? "var(--accent-emerald)" : "var(--text-muted)",
                    boxShadow: (isTraining || anyKaggleJobActive) ? "0 0 8px var(--accent-emerald)" : "none"
                  }} />
                  <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Trigger Train Worker</h2>
                </div>

                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "16px", marginBottom: "20px" }}>
                  {/* Local CPU Retrain Card */}
                  <div 
                    onClick={() => { if (!isTraining && !anyKaggleJobActive) handleRetrain("local"); }}
                    style={{
                      border: `1px solid ${isTraining ? "var(--accent-emerald)" : "var(--border-color)"}`,
                      background: isTraining ? "rgba(16, 185, 129, 0.05)" : "var(--bg-obsidian-950)",
                      borderRadius: "12px",
                      padding: "20px 16px",
                      cursor: (isTraining || anyKaggleJobActive) ? "not-allowed" : "pointer",
                      opacity: anyKaggleJobActive ? 0.5 : 1,
                      textAlign: "center",
                      transition: "all 0.2s"
                    }}
                  >
                    <div style={{ fontSize: "28px", marginBottom: "8px" }}>💻</div>
                    <h4 style={{ fontSize: "13px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "4px" }}>TF-IDF Cục bộ</h4>
                    <span style={{ fontSize: "11px", color: "var(--text-secondary)", display: "block" }}>CPU local (1-2 phút)</span>
                    <span style={{ fontSize: "10px", color: "var(--text-muted)", display: "block", marginTop: "6px", lineHeight: 1.4 }}>
                      Train TF-IDF + NER spaCy
                    </span>
                  </div>

                  {/* Kaggle GPU Retrain Card */}
                  <div 
                    onClick={() => { if (!isTraining && !anyKaggleJobActive) handleRetrain("kaggle"); }}
                    style={{
                      border: `1px solid ${activeTfidfKaggleJob ? "var(--accent-blue-hover)" : "var(--border-color)"}`,
                      background: activeTfidfKaggleJob ? "rgba(26, 115, 232, 0.05)" : "var(--bg-obsidian-950)",
                      borderRadius: "12px",
                      padding: "20px 16px",
                      cursor: (isTraining || anyKaggleJobActive) ? "not-allowed" : "pointer",
                      opacity: isTraining ? 0.5 : 1,
                      textAlign: "center",
                      transition: "all 0.2s"
                    }}
                  >
                    <div style={{ fontSize: "28px", marginBottom: "8px" }}>☁️</div>
                    <h4 style={{ fontSize: "13px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "4px" }}>TF-IDF Kaggle</h4>
                    <span style={{ fontSize: "11px", color: "var(--text-secondary)", display: "block" }}>GPU Cloud (NER spaCy)</span>
                  </div>

                  {/* PhoBERT Encoder Kaggle Card */}
                  <div 
                    onClick={() => { if (!isTraining && !anyKaggleJobActive && !trainingEncoder) handleTrainEncoder(); }}
                    style={{
                      border: `1px solid ${(activeEncoderJob || trainingEncoder) ? "var(--accent-violet)" : "var(--border-color)"}`,
                      background: (activeEncoderJob || trainingEncoder) ? "rgba(139, 92, 246, 0.05)" : "var(--bg-obsidian-950)",
                      borderRadius: "12px",
                      padding: "20px 16px",
                      cursor: (isTraining || anyKaggleJobActive || trainingEncoder) ? "not-allowed" : "pointer",
                      opacity: (isTraining || activeTfidfKaggleJob) ? 0.5 : 1,
                      textAlign: "center",
                      transition: "all 0.2s"
                    }}
                  >
                    <div style={{ fontSize: "28px", marginBottom: "8px" }}>🧠</div>
                    <h4 style={{ fontSize: "13px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "4px" }}>PhoBERT Encoder</h4>
                    <span style={{ fontSize: "11px", color: "var(--text-secondary)", display: "block" }}>Kaggle GPU (thay TF-IDF)</span>
                    <span style={{ fontSize: "10px", color: "var(--text-muted)", display: "block", marginTop: "6px", lineHeight: 1.4 }}>
                      Semantic embeddings, tránh overfitting
                    </span>
                  </div>
                </div>

                {isTraining && (
                  <div style={{ background: "rgba(16, 185, 129, 0.05)", border: "1px solid rgba(16, 185, 129, 0.2)", borderRadius: "8px", padding: "12px", fontSize: "12px", color: "var(--accent-emerald)" }}>
                    ⚙️ Đang chạy huấn luyện cục bộ trên server CPU... Vui lòng không đóng trang.
                  </div>
                )}

                {activeKaggleJob && (
                  <div style={{ background: isEncoderJob(activeKaggleJob) ? "rgba(139, 92, 246, 0.05)" : "rgba(26, 115, 232, 0.05)", border: isEncoderJob(activeKaggleJob) ? "1px solid rgba(139, 92, 246, 0.2)" : "1px solid rgba(26, 115, 232, 0.2)", borderRadius: "8px", padding: "12px", fontSize: "12px", color: isEncoderJob(activeKaggleJob) ? "#c4b5fd" : "var(--accent-blue-hover)", display: "flex", flexDirection: "column", gap: "6px" }}>
                    <div style={{ display: "flex", justifyContent: "space-between" }}>
                      <span><strong>{jobScopeLabel(activeKaggleJob)}:</strong> {activeKaggleJob.status.toUpperCase()}</span>
                      <span style={{ fontFamily: "var(--font-mono)" }}>{activeKaggleJob.id?.slice(0, 8)}</span>
                    </div>
                    <div style={{ fontSize: "11px", color: "var(--text-secondary)", lineHeight: "1.4" }}>
                      {activeKaggleJob.status === "queued" && "⏳ Đang xếp hàng chờ trên Kaggle..."}
                      {activeKaggleJob.status === "versioning_dataset" && "📦 Bước 1/5: Đang đóng gói & đồng bộ Dataset lên Kaggle..."}
                      {activeKaggleJob.status === "packaging_source" && "📦 Bước 2/5: Đang đóng gói mã nguồn text_nlu..."}
                      {activeKaggleJob.status === "pushing_kernel" && "🚀 Bước 3/5: Đang đẩy Notebook và kích hoạt GPU Worker..."}
                      {activeKaggleJob.status === "running_on_kaggle" && "⚙️ Bước 4/5: Đang chạy huấn luyện trên Kaggle GPU (Có thể mất 2-3 phút)..."}
                      {activeKaggleJob.status === "downloading_outputs" && "📥 Bước 5/5: Huấn luyện xong! Đang tải trọng số model về server..."}
                      {activeKaggleJob.status === "deploying" && "🔄 Đang giải nén & nạp nóng NLU Model vào bộ nhớ..."}
                    </div>
                  </div>
                )}

                {!isTraining && !activeKaggleJob && hasStuckJob && (
                  <div style={{
                    background: "rgba(245, 158, 11, 0.05)",
                    border: "1px solid rgba(245, 158, 11, 0.25)",
                    borderRadius: "8px",
                    padding: "12px",
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    gap: "12px",
                  }}>
                    <div>
                      <div style={{ fontSize: "12px", color: "var(--accent-amber-hover)", fontWeight: "600" }}>
                        Phát hiện job Kaggle bị treo
                      </div>
                      <div style={{ fontSize: "11px", color: "var(--text-secondary)", marginTop: "2px" }}>
                        Server đã tắt giữa chừng. Bấm Resume để tiếp tục polling và tải kết quả.
                      </div>
                    </div>
                    <button
                      className="btn"
                      onClick={handleResumeKaggle}
                      disabled={resumingKaggle}
                      style={{
                        padding: "8px 16px",
                        fontSize: "12px",
                        fontWeight: "600",
                        color: "var(--bg-obsidian-950)",
                        background: "var(--accent-amber)",
                        border: "none",
                        borderRadius: "6px",
                        cursor: resumingKaggle ? "not-allowed" : "pointer",
                        opacity: resumingKaggle ? 0.6 : 1,
                        whiteSpace: "nowrap",
                      }}
                    >
                      {resumingKaggle ? "Đang resume..." : "Resume Job"}
                    </button>
                  </div>
                )}

                {!isTraining && !activeKaggleJob && !hasStuckJob && (
                  <div style={{ fontSize: "12px", color: "var(--text-muted)", textAlign: "center", marginTop: "12px" }}>
                    Chọn một trong ba phương thức trên để bắt đầu huấn luyện lại mô hình.
                  </div>
                )}

                {kaggleJobs.length > 0 && (
                  <div style={{ marginTop: "20px" }}>
                    <h3 style={{ fontSize: "12px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "8px" }}>Lịch sử Kaggle GPU Retrain</h3>
                    <div style={{ maxHeight: "120px", overflowY: "auto", border: "1px solid var(--border-color)", borderRadius: "8px" }}>
                      <table style={{ width: "100%", borderCollapse: "collapse", fontSize: "11px" }}>
                        <thead>
                          <tr style={{ background: "var(--bg-obsidian-950)", borderBottom: "1px solid var(--border-color)" }}>
                            <th style={{ padding: "6px 10px", textAlign: "left", color: "var(--text-secondary)" }}>Loại</th>
                            <th style={{ padding: "6px 10px", textAlign: "left", color: "var(--text-secondary)" }}>Job ID</th>
                            <th style={{ padding: "6px 10px", textAlign: "left", color: "var(--text-secondary)" }}>Thời gian</th>
                            <th style={{ padding: "6px 10px", textAlign: "left", color: "var(--text-secondary)" }}>F1</th>
                            <th style={{ padding: "6px 10px", textAlign: "right", color: "var(--text-secondary)" }}>Trạng thái</th>
                          </tr>
                        </thead>
                        <tbody>
                          {kaggleJobs.slice(0, 10).map((job, i) => (
                            <tr key={i} style={{ borderBottom: "1px solid var(--border-color)", background: "transparent" }}>
                              <td style={{ padding: "6px 10px", color: "var(--text-secondary)" }}>{jobScopeLabel(job)}</td>
                              <td style={{ padding: "6px 10px", fontFamily: "var(--font-mono)", color: "var(--text-secondary)" }}>{job.id?.slice(0, 8)}</td>
                              <td style={{ padding: "6px 10px", color: "var(--text-secondary)" }}>
                                {job.created_at ? new Date(job.created_at).toLocaleString("vi-VN") : "N/A"}
                              </td>
                              <td style={{ padding: "6px 10px", fontWeight: "600", color: job.status === "completed" ? "var(--accent-emerald)" : "var(--text-secondary)" }}>
                                {job.f1_score || "-"}
                              </td>
                              <td style={{ padding: "6px 10px", textAlign: "right", fontWeight: "600", color: job.status === "completed" ? "var(--accent-emerald)" : job.status === "failed" ? "var(--accent-red)" : "var(--accent-blue-hover)" }}>
                                {job.status}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>

        {/* Import CSV Panel */}
        <div className="panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px",
          boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
          marginTop: "24px"
        }}>
          <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)" }}>
            <div>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Import New Training Data (CSV)</h2>
              <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>
                Tải lên tập tin CSV chứa mẫu huấn luyện mới để tích hợp trực tiếp vào tập dữ liệu gốc `intent_record.csv`.
              </span>
            </div>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "24px", marginTop: "20px" }}>
            {/* Formatting Guidelines */}
            <div style={{ background: "var(--bg-obsidian-950)", padding: "18px", borderRadius: "12px", border: "1px solid var(--border-color)" }}>
              <h3 style={{ color: "var(--text-primary)", fontSize: "13px", fontWeight: "600", marginBottom: "10px" }}>Hướng dẫn định dạng CSV:</h3>
              <p style={{ fontSize: "12px", color: "var(--text-secondary)", lineHeight: "1.6", margin: 0 }}>
                • Tập tin sử dụng bảng mã mã hóa <strong>UTF-8</strong>.<br />
                • Tiêu đề (Header) bắt buộc phải là: <code style={{ color: "var(--accent-blue-hover)", fontFamily: "var(--font-mono)" }}>text,label,type,is_money</code><br />
                • <strong>text</strong>: Câu mô tả chi tiêu hoặc chitchat (Ví dụ: <code style={{ fontFamily: "var(--font-mono)" }}>"Ăn trưa cơm sườn 45k"</code>)<br />
                • <strong>label</strong>: Tên danh mục (Ví dụ: <code style={{ fontFamily: "var(--font-mono)" }}>Food, Shopping, Salary, ...</code>)<br />
                • <strong>type</strong>: Loại giao dịch (<code style={{ fontFamily: "var(--font-mono)" }}>expense</code> hoặc <code style={{ fontFamily: "var(--font-mono)" }}>income</code>)<br />
                • <strong>is_money</strong>: Điền <code style={{ fontFamily: "var(--font-mono)" }}>1</code> nếu câu có chứa số tiền, điền <code style={{ fontFamily: "var(--font-mono)" }}>0</code> nếu không chứa.
              </p>
            </div>

            {/* Upload Area */}
            <form onSubmit={handleImportCsv} style={{ display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
              <div className="form-group" style={{ margin: 0 }}>
                <label className="form-label" style={{ color: "var(--text-primary)", marginBottom: "8px", display: "block" }}>Chọn tập tin dữ liệu</label>
                <input
                  id="nlu-csv-file-input"
                  type="file"
                  accept=".csv"
                  className="form-input"
                  style={{ background: "var(--bg-obsidian-950)", padding: "8px 12px" }}
                  onChange={(e) => setCsvFile(e.target.files?.[0] || null)}
                  required
                />
              </div>

              <div style={{ display: "flex", alignItems: "center", gap: "16px", marginTop: "16px" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Tự động huấn luyện:</span>
                  <select
                    value={autoRetrainCsv}
                    onChange={(e) => setAutoRetrainCsv(e.target.value)}
                    style={{
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid var(--border-color)",
                      color: "var(--text-primary)",
                      borderRadius: "6px",
                      padding: "6px 12px",
                      fontSize: "13px",
                      outline: "none",
                      cursor: "pointer"
                    }}
                  >
                    <option value="none">Không</option>
                    <option value="local">Cục bộ (CPU)</option>
                    <option value="kaggle">Kaggle (GPU)</option>
                  </select>
                </div>
              </div>

              <button
                type="submit"
                className="btn btn-primary"
                disabled={importingCsv || !csvFile}
                style={{
                  marginTop: "16px",
                  background: "var(--accent-emerald)",
                  color: "var(--bg-obsidian-950)",
                  fontWeight: "600",
                  width: "100%",
                  padding: "10px",
                  borderRadius: "8px",
                  opacity: (importingCsv || !csvFile) ? 0.6 : 1,
                  cursor: (importingCsv || !csvFile) ? "not-allowed" : "pointer"
                }}
              >
                {importingCsv ? "Đang import..." : "Bắt đầu Import dữ liệu"}
              </button>
            </form>
          </div>
        </div>

        {/* Model Comparison Table */}
        <div className="panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px",
          boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
          marginTop: "24px"
        }}>
          <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "16px" }}>
            <div>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>So Sánh Hiệu Năng Mô Hình (Diagnostics & Comparison)</h2>
              <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>
                So sánh metrics trước/sau retrain — tách riêng TF-IDF và PhoBERT encoder (cùng schema accuracy / precision / recall / F1).
              </span>
            </div>
            <div style={{ display: "flex", gap: "8px", flexWrap: "wrap", alignItems: "center" }}>
              {["tfidf", "encoder"].map((type) => (
                <button
                  key={type}
                  type="button"
                  onClick={() => setCompareTrainType(type)}
                  style={{
                    padding: "6px 14px",
                    borderRadius: "8px",
                    fontSize: "12px",
                    fontWeight: "600",
                    cursor: "pointer",
                    border: compareTrainType === type
                      ? (type === "encoder" ? "1px solid var(--accent-violet)" : "1px solid var(--accent-blue-hover)")
                      : "1px solid var(--border-color)",
                    background: compareTrainType === type
                      ? (type === "encoder" ? "rgba(139, 92, 246, 0.1)" : "rgba(26, 115, 232, 0.08)")
                      : "var(--bg-obsidian-950)",
                    color: compareTrainType === type ? "var(--text-primary)" : "var(--text-secondary)",
                  }}
                >
                  {type === "tfidf" ? "TF-IDF" : "PhoBERT Encoder"}
                </button>
              ))}
            </div>
            {(() => {
              const filtered = filterHistoryByType(trainHistory, compareTrainType);
              if (!filtered.length) return null;
              const latest = filtered[filtered.length - 1];
              const prev = filtered.length > 1 ? filtered[filtered.length - 2] : null;
              const typeLabel = compareTrainType === "encoder" ? "Encoder" : "TF-IDF";
              return (
                <div style={{ fontSize: "12px", color: "var(--text-secondary)", display: "flex", gap: "16px", flexWrap: "wrap", width: "100%" }}>
                  <span>
                    {typeLabel} mới nhất: <strong style={{ color: compareTrainType === "encoder" ? "#c4b5fd" : "var(--accent-blue-hover)" }}>Run #{latest.run_index}</strong>
                    {" "}({new Date(latest.trained_at).toLocaleDateString("vi-VN")})
                    {latest.source ? ` · ${latest.source}` : ""}
                    {latest.encoder_model ? ` · ${latest.encoder_model}` : ""}
                  </span>
                  {prev && (
                    <span>
                      Trước đó: <strong style={{ color: "var(--text-muted)" }}>Run #{prev.run_index}</strong>
                      {prev.source ? ` · ${prev.source}` : ""}
                    </span>
                  )}
                </div>
              );
            })()}
          </div>

          {filterHistoryByType(trainHistory, compareTrainType).length === 0 && (
            <div style={{ marginTop: "16px", padding: "14px", borderRadius: "8px", background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", fontSize: "12px", color: "var(--text-muted)" }}>
              Chưa có lịch sử retrain {compareTrainType === "encoder" ? "PhoBERT encoder" : "TF-IDF"} thành công. Chạy train worker tương ứng để ghi metrics.
            </div>
          )}

          <div className="table-container" style={{ borderRadius: "12px", border: "1px solid var(--border-color)", overflow: "hidden", marginTop: "16px" }}>
            <table className="custom-table">
              <thead>
                <tr style={{ background: "var(--bg-obsidian-950)" }}>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Thành Phần Mô Hình</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Accuracy (Độ chính xác)</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Precision (Độ tinh xác)</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Recall (Độ bao phủ)</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>F1-Score (Điểm F1)</th>
                </tr>
              </thead>
              <tbody>
                {(COMPARISON_ROWS[compareTrainType] || COMPARISON_ROWS.tfidf).map((sub) => (
                  <tr key={sub.key}>
                    <td style={{ padding: "14px 18px" }}>
                      <div style={{ color: "var(--text-primary)", fontWeight: "600", fontSize: "13px" }}>{sub.label}</div>
                      <div style={{ color: "var(--text-muted)", fontSize: "11px", marginTop: "2px" }}>{sub.desc}</div>
                    </td>
                    <td style={{ padding: "14px 18px" }}>{renderMetricCell(sub.key, "accuracy")}</td>
                    <td style={{ padding: "14px 18px" }}>{renderMetricCell(sub.key, "precision")}</td>
                    <td style={{ padding: "14px 18px" }}>{renderMetricCell(sub.key, "recall")}</td>
                    <td style={{ padding: "14px 18px" }}>{renderMetricCell(sub.key, "f1_score")}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {compareTrainType === "tfidf" && (() => {
            const filtered = filterHistoryByType(trainHistory, "tfidf");
            const latest = filtered.length ? filtered[filtered.length - 1] : null;
            const slots = latest?.metrics?.action_slots || modelMeta?.actionSlots;
            const fields = slots?.fields;
            if (!fields || typeof fields !== "object") return null;
            const summary = slots.summary || {};
            return (
              <div style={{ marginTop: "20px", padding: "16px", background: "var(--bg-obsidian-950)", borderRadius: "12px", border: "1px solid var(--border-color)" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "12px", flexWrap: "wrap", gap: "8px" }}>
                  <h3 style={{ margin: 0, fontSize: "14px", fontWeight: "600", color: "var(--text-primary)" }}>Action Slots — chi tiết từng field</h3>
                  <span style={{ fontSize: "11px", color: "var(--text-muted)" }}>
                    {summary.trained_fields ?? Object.keys(fields).length} fields
                    {summary.dataset_rows != null ? ` · ${summary.dataset_rows.toLocaleString()} rows CSV` : ""}
                    {summary.avg_weighted_f1 != null ? ` · avg F1 ${(summary.avg_weighted_f1 * 100).toFixed(1)}%` : ""}
                  </span>
                </div>
                <div className="table-container" style={{ borderRadius: "8px", border: "1px solid var(--border-color)", overflow: "hidden" }}>
                  <table className="custom-table">
                    <thead>
                      <tr style={{ background: "var(--bg-obsidian-900)" }}>
                        <th style={{ padding: "10px 14px", fontSize: "10px" }}>Slot field</th>
                        <th style={{ padding: "10px 14px", fontSize: "10px" }}>Loại</th>
                        <th style={{ padding: "10px 14px", fontSize: "10px" }}>Train samples</th>
                        <th style={{ padding: "10px 14px", fontSize: "10px" }}>Accuracy</th>
                        <th style={{ padding: "10px 14px", fontSize: "10px" }}>Weighted F1</th>
                      </tr>
                    </thead>
                    <tbody>
                      {Object.entries(fields).map(([name, m]) => (
                        <tr key={name}>
                          <td style={{ padding: "10px 14px", fontFamily: "var(--font-mono)", fontSize: "12px" }}>{name}</td>
                          <td style={{ padding: "10px 14px", fontSize: "12px" }}>{m.type || "—"}</td>
                          <td style={{ padding: "10px 14px", fontSize: "12px" }}>{m.train_samples ?? "—"}</td>
                          <td style={{ padding: "10px 14px", fontSize: "12px" }}>
                            {m.accuracy != null ? `${(m.accuracy * 100).toFixed(1)}%` : "—"}
                          </td>
                          <td style={{ padding: "10px 14px", fontSize: "12px" }}>
                            {m.weighted_f1 != null ? `${(m.weighted_f1 * 100).toFixed(1)}%` : "—"}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            );
          })()}
        </div>
      </>
      )}

      {toastMessage && (
        <div className="toast" style={{
          position: "fixed",
          bottom: "30px",
          right: "30px",
          background: "var(--bg-obsidian-800)",
          border: "1px solid var(--accent-blue)",
          borderRadius: "8px",
          padding: "14px 20px",
          boxShadow: "0 10px 25px rgba(0,0,0,0.3), 0 0 15px rgba(2, 132, 199, 0.1)",
          display: "flex",
          alignItems: "center",
          gap: "10px",
          zIndex: 9999
        }}>
          <div className="brand-dot" style={{ background: "var(--accent-blue)", width: "8px", height: "8px", borderRadius: "50%" }}></div>
          <span style={{ color: "var(--text-primary)", fontSize: "13px", fontWeight: "500" }}>{toastMessage}</span>
        </div>
      )}
    </div>
  );
}

export default NluOpsPage;
