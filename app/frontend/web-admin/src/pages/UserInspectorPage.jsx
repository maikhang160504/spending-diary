import { useState } from "react";
import { getUserInspector, clearUserCache } from "../services/api";

function UserInspectorPage() {
  const [userIdInput, setUserIdInput] = useState("");
  const [currentUser, setCurrentUser] = useState(null);
  const [loading, setLoading] = useState(false);
  const [toastMsg, setToastMsg] = useState("");
  const [error, setError] = useState("");

  const showToast = (msg) => {
    setToastMsg(msg);
    setTimeout(() => setToastMsg(""), 3000);
  };

  const handleSearch = (e) => {
    e.preventDefault();
    if (!userIdInput.trim()) return;
    
    setLoading(true);
    setError("");
    getUserInspector(userIdInput.trim())
      .then((data) => {
        setCurrentUser(data);
        setLoading(false);
        showToast("User session telemetry fetched!");
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
        setCurrentUser(null);
      });
  };

  const handleClearCache = () => {
    if (!currentUser) return;
    setLoading(true);
    clearUserCache(currentUser.id)
      .then((res) => {
        showToast(res.message || `Cache cleared for user ${currentUser.id}`);
        // Refresh state to show cleared indicators
        setCurrentUser(prev => ({
          ...prev,
          cacheSize: "0 KB",
          ttl: "Cleared/Expired",
          cacheKeys: []
        }));
        setLoading(false);
      })
      .catch((err) => {
        showToast("Failed to clear cache: " + err.message);
        setLoading(false);
      });
  };

  return (
    <div className="page-container" style={{ padding: "30px 40px" }}>
      <div className="page-header" style={{ marginBottom: "24px" }}>
        <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px" }}>User Cache Inspector</h1>
        <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "4px" }}>
          Query user-specific NLU states, active overrides, and reload memory buffers.
        </p>
      </div>

      {/* User Inspector Telemetry Strip */}
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
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Inspected Client</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: currentUser ? "var(--accent-blue-hover)" : "var(--text-muted)", fontFamily: "var(--font-sans)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
            {currentUser ? currentUser.name : "No Target"}
          </span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Active Cache Footprint</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: currentUser && currentUser.cacheSize !== "0 KB" ? "var(--accent-amber-hover)" : "var(--text-muted)", fontFamily: "var(--font-mono)" }}>
            {currentUser ? currentUser.cacheSize : "0 KB"}
          </span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Correction Logs</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: currentUser && currentUser.corrections?.length > 0 ? "var(--accent-rose-hover)" : "var(--text-muted)", fontFamily: "var(--font-sans)" }}>
            {currentUser ? `${currentUser.corrections?.length || 0} logs` : "0 logs"}
          </span>
        </div>
        <div className="bill-stat" style={{ borderRight: "none" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Memory Connection</span>
          <span className="bill-stat-value" style={{
            fontSize: "18px",
            fontWeight: "700",
            color: "var(--accent-emerald-hover)",
            display: "flex",
            alignItems: "center",
            gap: "8px"
          }}>
            <span className="status-dot" style={{
              background: "var(--accent-emerald)",
              boxShadow: "0 0 10px var(--accent-emerald)",
              width: "8px",
              height: "8px",
              borderRadius: "50%"
            }}></span>
            Redis Active
          </span>
        </div>
      </div>

      <div className="panel" style={{
        background: "var(--bg-obsidian-900)",
        border: "1px solid var(--border-color)",
        borderRadius: "16px",
        padding: "24px",
        marginBottom: "24px",
        boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
      }}>
        <form onSubmit={handleSearch} className="search-container" style={{ display: "flex", gap: "12px", width: "100%" }}>
          <input
            type="text"
            className="form-input search-input monospaced"
            placeholder="Input Target User UUID (e.g. 1a2b3c4d-a56b-4c7d-8e9f-...)"
            style={{ background: "var(--bg-obsidian-950)", fontSize: "14px", border: "1px solid var(--border-color)", borderRadius: "8px", padding: "12px 16px", flexGrow: 1 }}
            value={userIdInput}
            onChange={(e) => setUserIdInput(e.target.value)}
            required
          />
          <button type="submit" className="btn btn-primary" disabled={loading} style={{
            background: "var(--accent-blue)",
            color: "var(--text-primary)",
            fontWeight: "600",
            padding: "0 24px",
            borderRadius: "8px",
            fontSize: "14px",
            display: "inline-flex",
            alignItems: "center",
            height: "45px"
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = "var(--accent-blue-hover)";
            e.currentTarget.style.boxShadow = "0 0 12px var(--accent-blue-glow)";
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = "var(--accent-blue)";
            e.currentTarget.style.boxShadow = "none";
          }}
          >
            {loading ? "Inspecting Telemetry..." : "Inspect User Cache"}
          </button>
        </form>
      </div>

      {error && (
        <div style={{
          color: "var(--accent-rose-hover)",
          background: "rgba(239, 68, 68, 0.08)",
          border: "1px solid rgba(239, 68, 68, 0.2)",
          borderRadius: "8px",
          padding: "12px 16px",
          marginBottom: "20px",
          fontSize: "13px"
        }}>
          <strong>Inference Cache Failure:</strong> {error}
        </div>
      )}

      {currentUser && (
        <div className="dashboard-grid" style={{ gap: "24px" }}>
          {/* User Details & Cache Status */}
          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
          }}>
            <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)" }}>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Cache & Profile Telemetry</h2>
              <span className="badge badge-success" style={{
                background: "rgba(16, 185, 129, 0.08)",
                border: "1px solid rgba(16, 185, 129, 0.3)",
                color: "var(--accent-emerald-hover)",
                padding: "4px 10px",
                borderRadius: "8px",
                fontWeight: "600",
                fontSize: "11px"
              }}>{currentUser.activeStatus}</span>
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: "16px", marginTop: "16px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>User Identifier</span>
                <strong className="monospaced" style={{ fontSize: "12px" }}>{currentUser.id}</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Profile Identity</span>
                <strong style={{ fontSize: "13px", color: "var(--text-primary)" }}>{currentUser.name} ({currentUser.email})</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)", marginTop: "4px" }}>Memory Keys</span>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: "6px" }}>
                  {currentUser.cacheKeys && currentUser.cacheKeys.length > 0 ? (
                    currentUser.cacheKeys.map(k => (
                      <span key={k} className="monospaced" style={{ fontSize: "11px", color: "var(--accent-blue-hover)", background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", padding: "2px 6px", borderRadius: "4px" }}>{k}</span>
                    ))
                  ) : (
                    <span style={{ color: "var(--text-muted)", fontSize: "13px" }}>No active memory buffer</span>
                  )}
                </div>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Custom Overrides Count</span>
                <strong className="monospaced" style={{ fontSize: "13px" }}>{currentUser.overrides?.length || 0} active mapped</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>In-memory Cache Size</span>
                <strong className="monospaced" style={{ fontSize: "13px", color: "var(--accent-amber-hover)" }}>{currentUser.cacheSize}</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", paddingBottom: "12px" }}>
                <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Cache TTL (Time To Live)</span>
                <strong className="monospaced" style={{ fontSize: "13px" }}>{currentUser.ttl}</strong>
              </div>
            </div>

            <button
              onClick={handleClearCache}
              className="btn btn-danger"
              style={{
                width: "100%",
                marginTop: "16px",
                padding: "12px",
                fontSize: "14px",
                fontWeight: "600",
                background: "var(--accent-rose)",
                color: "var(--text-primary)",
                border: "none",
                borderRadius: "8px"
              }}
              disabled={loading || currentUser.cacheSize === "0 KB"}
              onMouseEnter={(e) => {
                if (currentUser.cacheSize !== "0 KB") {
                  e.currentTarget.style.background = "var(--accent-rose-hover)";
                  e.currentTarget.style.boxShadow = "0 0 12px var(--accent-rose-glow)";
                }
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = "var(--accent-rose)";
                e.currentTarget.style.boxShadow = "none";
              }}
            >
              Clear & Force Reload Cache
            </button>
          </div>

          {/* User Corrections Log */}
          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
          }}>
            <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)" }}>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Session Correction Logs</h2>
              <span className="badge badge-warning" style={{
                background: "rgba(245, 158, 11, 0.08)",
                border: "1px solid rgba(245, 158, 11, 0.3)",
                color: "var(--accent-amber-hover)",
                padding: "4px 10px",
                borderRadius: "8px",
                fontWeight: "600",
                fontSize: "11px"
              }}>{currentUser.corrections?.length || 0} logs</span>
            </div>

            <div className="table-container" style={{ borderRadius: "12px", border: "1px solid var(--border-color)", overflow: "hidden", marginTop: "20px" }}>
              <table className="custom-table" style={{ fontSize: "13px" }}>
                <thead>
                  <tr style={{ background: "var(--bg-obsidian-950)" }}>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Term Text</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>User Category</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>AI Prediction</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Timestamp</th>
                  </tr>
                </thead>
                <tbody>
                  {currentUser.corrections?.map((c, idx) => (
                    <tr key={idx} style={{ transition: "background 0.15s ease" }}>
                      <td className="monospaced" style={{ padding: "14px 18px", color: "var(--text-primary)" }}>
                        <code style={{ background: "var(--bg-obsidian-950)", padding: "4px 8px", borderRadius: "6px", border: "1px solid var(--border-color)", fontFamily: "var(--font-mono)" }}>"{c.text}"</code>
                      </td>
                      <td style={{ padding: "14px 18px" }}>
                        <span className="badge badge-success" style={{
                          background: "rgba(16, 185, 129, 0.08)",
                          border: "1px solid rgba(16, 185, 129, 0.3)",
                          color: "var(--accent-emerald-hover)",
                          padding: "4px 8px",
                          borderRadius: "6px",
                          fontWeight: "600",
                          fontSize: "11px"
                        }}>{c.category}</span>
                      </td>
                      <td style={{ padding: "14px 18px" }}>
                        <span className="badge badge-danger" style={{
                          background: "rgba(239, 68, 68, 0.08)",
                          border: "1px solid rgba(239, 68, 68, 0.3)",
                          color: "var(--accent-rose-hover)",
                          padding: "4px 8px",
                          borderRadius: "6px",
                          fontWeight: "600",
                          fontSize: "11px"
                        }}>{c.original}</span>
                      </td>
                      <td style={{ padding: "14px 18px", fontSize: "12px", color: "var(--text-secondary)" }}>
                        {new Date(c.date).toISOString().replace("T", " ").substring(0, 19)}
                      </td>
                    </tr>
                  ))}
                  {(!currentUser.corrections || currentUser.corrections.length === 0) && (
                    <tr>
                      <td colSpan="4" style={{ textAlign: "center", padding: "40px", color: "var(--text-muted)" }}>
                        No corrections logged for this user.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {toastMsg && (
        <div className="toast" style={{
          position: "fixed",
          bottom: "30px",
          right: "30px",
          background: "var(--bg-obsidian-800)",
          border: "1px solid var(--accent-rose)",
          borderRadius: "8px",
          padding: "14px 20px",
          boxShadow: "0 10px 25px rgba(0,0,0,0.3), 0 0 15px rgba(239, 68, 68, 0.1)",
          display: "flex",
          alignItems: "center",
          gap: "10px",
          zIndex: 9999
        }}>
          <div className="brand-dot" style={{ background: "var(--accent-rose)", width: "8px", height: "8px", borderRadius: "50%" }}></div>
          <span style={{ color: "var(--text-primary)", fontSize: "13px", fontWeight: "500" }}>{toastMsg}</span>
        </div>
      )}
    </div>
  );
}

export default UserInspectorPage;
