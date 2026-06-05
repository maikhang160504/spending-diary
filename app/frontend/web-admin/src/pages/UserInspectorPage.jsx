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
          ttl: "Cleared/Expired"
        }));
        setLoading(false);
      })
      .catch((err) => {
        showToast("Failed to clear cache: " + err.message);
        setLoading(false);
      });
  };

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">User Cache Inspector</h1>
        <p className="page-desc">Query user-specific NLU states, active overrides, and reload memory buffers.</p>
      </div>

      <div className="panel" style={{ marginBottom: "24px" }}>
        <form onSubmit={handleSearch} className="search-container">
          <input
            type="text"
            className="form-input search-input monospaced"
            placeholder="Input User UUID (e.g. 1a2b3c4d-...)"
            value={userIdInput}
            onChange={(e) => setUserIdInput(e.target.value)}
            required
          />
          <button type="submit" className="btn btn-primary" disabled={loading}>
            {loading ? "Searching..." : "Inspect User"}
          </button>
        </form>
      </div>

      {error && <div style={{ color: "var(--accent-rose)", marginBottom: "16px" }}>Error: {error}</div>}

      {currentUser && (
        <div className="dashboard-grid">
          {/* User Details & Cache Status */}
          <div className="panel">
            <div className="panel-header">
              <h2 className="panel-title">Telemetry & Cache Profile</h2>
              <span className="badge badge-success">{currentUser.activeStatus}</span>
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span>User Identifier</span>
                <strong className="monospaced">{currentUser.id}</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span>User Name / Email</span>
                <strong>{currentUser.name} ({currentUser.email})</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span>Active Cache Keys (Simulated)</span>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: "4px" }}>
                  {currentUser.cacheKeys?.map(k => (
                    <span key={k} className="monospaced" style={{ fontSize: "12px", color: "var(--accent-blue-hover)" }}>{k}</span>
                  )) || <span style={{ color: "var(--text-muted)" }}>None</span>}
                </div>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span>Custom Overrides Count</span>
                <strong className="monospaced">{currentUser.overrides?.length || 0} overrides</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                <span>Cache Memory footprint</span>
                <strong className="monospaced">{currentUser.cacheSize}</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", paddingBottom: "12px" }}>
                <span>Cache Lifetime (TTL)</span>
                <strong className="monospaced">{currentUser.ttl}</strong>
              </div>
            </div>

            <button
              onClick={handleClearCache}
              className="btn btn-danger"
              style={{ width: "100%", marginTop: "12px" }}
              disabled={loading || currentUser.cacheSize === "0 KB"}
            >
              Clear & Reload Cache
            </button>
          </div>

          {/* User Corrections Log */}
          <div className="panel">
            <div className="panel-header">
              <h2 className="panel-title">Correction History Log</h2>
              <span className="badge badge-warning">{currentUser.corrections?.length || 0} logs</span>
            </div>

            <div className="table-container">
              <table className="custom-table" style={{ fontSize: "13px" }}>
                <thead>
                  <tr>
                    <th>Term Text</th>
                    <th>User Cat</th>
                    <th>AI Predicted</th>
                    <th>Timestamp</th>
                  </tr>
                </thead>
                <tbody>
                  {currentUser.corrections?.map((c, idx) => (
                    <tr key={idx}>
                      <td className="monospaced">"{c.text}"</td>
                      <td>
                        <span className="badge badge-success" style={{ fontSize: "10px" }}>{c.category}</span>
                      </td>
                      <td>
                        <span className="badge badge-danger" style={{ fontSize: "10px" }}>{c.original}</span>
                      </td>
                      <td style={{ fontSize: "11px" }}>{new Date(c.date).toISOString().replace("T", " ").substring(0, 19)}</td>
                    </tr>
                  ))}
                  {(!currentUser.corrections || currentUser.corrections.length === 0) && (
                    <tr>
                      <td colSpan="4" style={{ textAlign: "center", padding: "20px" }}>
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
        <div className="toast">
          <div className="brand-dot" style={{ background: "var(--accent-rose)", boxShadow: "0 0 10px var(--accent-rose)" }}></div>
          <span>{toastMsg}</span>
        </div>
      )}
    </div>
  );
}

export default UserInspectorPage;
