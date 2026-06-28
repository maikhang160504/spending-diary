import { useState } from "react";
import { clearUserCache } from "../services/api";

function UserCacheInspector({ userId, data, loading, onRefresh }) {
  const [clearing, setClearing] = useState(false);
  const [toastMsg, setToastMsg] = useState("");

  const showToast = (msg) => {
    setToastMsg(msg);
    setTimeout(() => setToastMsg(""), 3000);
  };

  const handleClearCache = () => {
    if (!data) return;
    setClearing(true);
    clearUserCache(userId)
      .then((res) => {
        showToast(res.message || `Cache cleared for user ${userId}`);
        onRefresh?.();
      })
      .catch((err) => {
        showToast("Failed to clear cache: " + err.message);
      })
      .finally(() => setClearing(false));
  };

  if (loading) {
    return (
      <div className="user-inspector-loading">
        <div className="user-inspector-skeleton user-inspector-skeleton-wide" />
        <div className="user-inspector-skeleton" />
        <div className="user-inspector-skeleton" />
      </div>
    );
  }

  if (!data) return null;

  const busy = loading || clearing;

  return (
    <div className="user-cache-inspector">
      <div className="user-inspector-section-head">
        <div>
          <p className="bill-surface-eyebrow">Diagnostics</p>
          <h3 className="user-inspector-section-title">User Cache Inspector</h3>
        </div>
        <span className={`user-status-pill ${data.activeStatus === "Active" ? "ok" : "off"}`}>
          {data.activeStatus}
        </span>
      </div>

      <div className="user-inspector-stat-row">
        <div className="user-inspector-stat">
          <span className="user-inspector-stat-label">Cache footprint</span>
          <strong className={`user-inspector-stat-value ${data.cacheSize !== "0 KB" ? "warn" : ""}`}>
            {data.cacheSize}
          </strong>
        </div>
        <div className="user-inspector-stat">
          <span className="user-inspector-stat-label">Correction logs</span>
          <strong className="user-inspector-stat-value">{data.corrections?.length || 0}</strong>
        </div>
        <div className="user-inspector-stat">
          <span className="user-inspector-stat-label">Memory link</span>
          <strong className="user-inspector-stat-value ok">
            <span className="user-live-dot" />
            Redis
          </strong>
        </div>
      </div>

      <div className="user-inspector-kv-list">
        <div className="user-inspector-kv">
          <span>User ID</span>
          <code>{data.id}</code>
        </div>
        <div className="user-inspector-kv">
          <span>Memory keys</span>
          <div className="user-inspector-key-stack">
            {data.cacheKeys?.length ? (
              data.cacheKeys.map((k) => (
                <code key={k} className="user-inspector-key">{k}</code>
              ))
            ) : (
              <span className="muted">No active memory buffer</span>
            )}
          </div>
        </div>
        <div className="user-inspector-kv">
          <span>Custom overrides</span>
          <strong>{data.overrides?.length || 0} mapped</strong>
        </div>
        <div className="user-inspector-kv">
          <span>Cache TTL</span>
          <strong className="mono">{data.ttl}</strong>
        </div>
      </div>

      <button
        type="button"
        className="btn btn-danger user-inspector-clear-btn"
        onClick={handleClearCache}
        disabled={busy || data.cacheSize === "0 KB"}
      >
        Clear and force reload cache
      </button>

      <div className="user-inspector-corrections">
        <div className="user-inspector-section-head compact">
          <h4 className="user-inspector-section-title">Session correction logs</h4>
          <span className="user-count-chip">{data.corrections?.length || 0}</span>
        </div>
        <div className="user-inspector-table-wrap">
          <table className="data-table user-inspector-table">
            <thead>
              <tr>
                <th>Term</th>
                <th>Category</th>
                <th>AI prediction</th>
                <th>Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {data.corrections?.map((c, idx) => (
                <tr key={idx}>
                  <td><code className="user-term-chip">"{c.text}"</code></td>
                  <td><span className="user-tag ok">{c.category}</span></td>
                  <td><span className="user-tag bad">{c.original}</span></td>
                  <td className="muted mono">
                    {new Date(c.date).toISOString().replace("T", " ").substring(0, 19)}
                  </td>
                </tr>
              ))}
              {(!data.corrections || data.corrections.length === 0) && (
                <tr>
                  <td colSpan={4} className="user-inspector-empty">No corrections logged for this user.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {toastMsg && (
        <div className="user-inspector-toast">
          <span className="user-live-dot rose" />
          <span>{toastMsg}</span>
        </div>
      )}
    </div>
  );
}

export default UserCacheInspector;
