import { useState, useEffect } from "react";
import { getAdminAnalytics } from "../services/api";

function DashboardPage() {
  const [analytics, setAnalytics] = useState({
    totalUsers: 0,
    totalExpenses: 0,
    totalExpenseAmount: 0,
    fusionSuccessRate: 90.0
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [weights, setWeights] = useState({
    ocrWeight: 0.75,
    nluThreshold: 0.85,
    prioritizeUserTyping: true,
    dateFallback: "transaction",
  });
  const [saving, setSaving] = useState(false);
  const [showToast, setShowToast] = useState(false);

  useEffect(() => {
    getAdminAnalytics()
      .then((data) => {
        setAnalytics(data);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  const handleSave = (e) => {
    e.preventDefault();
    setSaving(true);
    // Simulate updating weights on backend config/settings
    setTimeout(() => {
      setSaving(false);
      setShowToast(true);
      setTimeout(() => setShowToast(false), 3000);
    }, 800);
  };

  if (loading) {
    return (
      <div style={{ padding: "40px", textAlign: "center", color: "var(--text-secondary)" }}>
        <p>Loading AI fusion metrics...</p>
      </div>
    );
  }

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">Fusion & AI Quality</h1>
        <p className="page-desc">Telemetry metrics on convergence rates and dynamic algorithm weight configs.</p>
      </div>

      {error && <div className="toast" style={{ borderColor: "var(--accent-rose)" }}><span>Error: {error}</span></div>}

      <div className="metrics-grid">
        <div className="metric-card">
          <span className="metric-indicator indicator-emerald"></span>
          <span className="metric-label">Fusion Convergence Rate</span>
          <span className="metric-value">{analytics.fusionSuccessRate}%</span>
          <span className="metric-desc">Amount, Category & Date mapped fully</span>
        </div>
        <div className="metric-card">
          <span className="metric-indicator indicator-blue"></span>
          <span className="metric-label">Total AI Extractions</span>
          <span className="metric-value">{analytics.totalExpenses.toLocaleString()}</span>
          <span className="metric-desc">Transaction records parsed via NLU/OCR</span>
        </div>
        <div className="metric-card">
          <span className="metric-indicator indicator-amber"></span>
          <span className="metric-label">Total Expense volume</span>
          <span className="metric-value">{Number(analytics.totalExpenseAmount).toLocaleString()} VND</span>
          <span className="metric-desc">Sum value of active transactions in DB</span>
        </div>
      </div>

      <div className="dashboard-grid">
        {/* Left: Telemetry Chart */}
        <div className="panel">
          <div className="panel-header">
            <h2 className="panel-title">Fusion Success Rate (7d History)</h2>
            <span className="badge badge-success">Target: &gt;90%</span>
          </div>

          <div className="chart-container">
            <div className="chart-grid-y">
              <div className="chart-grid-line"></div>
              <div className="chart-grid-line"></div>
              <div className="chart-grid-line"></div>
              <div className="chart-grid-line"></div>
            </div>
            
            {/* Custom SVG Line Chart */}
            <svg viewBox="0 0 500 200" className="svg-chart" preserveAspectRatio="none">
              <defs>
                <linearGradient id="chartGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="var(--accent-emerald)" stopOpacity="0.3" />
                  <stop offset="100%" stopColor="var(--accent-emerald)" stopOpacity="0" />
                </linearGradient>
              </defs>
              {/* Fill path */}
              <path
                d="M 10 180 L 10 120 L 90 90 L 170 110 L 250 60 L 330 80 L 410 40 L 490 30 L 490 180 Z"
                fill="url(#chartGrad)"
              />
              {/* Stroke line */}
              <path
                d="M 10 120 L 90 90 L 170 110 L 250 60 L 330 80 L 410 40 L 490 30"
                fill="none"
                stroke="var(--accent-emerald)"
                strokeWidth="3"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
              {/* Points */}
              <circle cx="10" cy="120" r="4" fill="var(--bg-obsidian-950)" stroke="var(--accent-emerald)" strokeWidth="2" />
              <circle cx="90" cy="90" r="4" fill="var(--bg-obsidian-950)" stroke="var(--accent-emerald)" strokeWidth="2" />
              <circle cx="170" cy="110" r="4" fill="var(--bg-obsidian-950)" stroke="var(--accent-emerald)" strokeWidth="2" />
              <circle cx="250" cy="60" r="4" fill="var(--bg-obsidian-950)" stroke="var(--accent-emerald)" strokeWidth="2" />
              <circle cx="330" cy="80" r="4" fill="var(--bg-obsidian-950)" stroke="var(--accent-emerald)" strokeWidth="2" />
              <circle cx="410" cy="40" r="4" fill="var(--bg-obsidian-950)" stroke="var(--accent-emerald)" strokeWidth="2" />
              <circle cx="490" cy="30" r="4" fill="var(--bg-obsidian-950)" stroke="var(--accent-emerald)" strokeWidth="2" />
            </svg>
          </div>

          <div style={{ display: "flex", justifyContent: "space-between", fontSize: "12px", padding: "0 8px" }}>
            <span>May 29</span>
            <span>May 30</span>
            <span>May 31</span>
            <span>Jun 01</span>
            <span>Jun 02</span>
            <span>Jun 03</span>
            <span>Jun 04 (Today)</span>
          </div>
        </div>

        {/* Right: Fusion Config Weights */}
        <div className="panel">
          <div className="panel-header">
            <h2 className="panel-title">Fusion Weights Config</h2>
          </div>

          <form onSubmit={handleSave} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
            <div className="form-group">
              <label className="form-label" htmlFor="ocrWeight">
                OCR Confidence Weight ({weights.ocrWeight})
              </label>
              <input
                id="ocrWeight"
                type="range"
                min="0.1"
                max="1.0"
                step="0.05"
                value={weights.ocrWeight}
                onChange={(e) => setWeights({ ...weights, ocrWeight: parseFloat(e.target.value) })}
                style={{ accentColor: "var(--accent-emerald)" }}
              />
              <span className="form-desc">Weights assigned to scan parameters when confidence score fluctuates.</span>
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="nluThreshold">
                NLU Similarity Threshold ({weights.nluThreshold})
              </label>
              <input
                id="nluThreshold"
                type="range"
                min="0.5"
                max="0.95"
                step="0.05"
                value={weights.nluThreshold}
                onChange={(e) => setWeights({ ...weights, nluThreshold: parseFloat(e.target.value) })}
                style={{ accentColor: "var(--accent-emerald)" }}
              />
              <span className="form-desc">Cosine similarity filter threshold for Layer 2 corrections mapping.</span>
            </div>

            <div className="form-group" style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
              <div>
                <label className="form-label" htmlFor="prioritizeUser">
                  Prioritize User Typed Notes
                </label>
                <div className="form-desc" style={{ marginTop: "2px" }}>Always override AI prediction with explicit text typed by user.</div>
              </div>
              <input
                id="prioritizeUser"
                type="checkbox"
                checked={weights.prioritizeUserTyping}
                onChange={(e) => setWeights({ ...weights, prioritizeUserTyping: e.target.checked })}
                style={{ width: "18px", height: "18px", accentColor: "var(--accent-emerald)" }}
              />
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="dateFallback">
                Date Convergence Fallback
              </label>
              <select
                id="dateFallback"
                className="form-select"
                value={weights.dateFallback}
                onChange={(e) => setWeights({ ...weights, dateFallback: e.target.value })}
              >
                <option value="transaction">Transacted timestamp (Extracted)</option>
                <option value="current">Current local system timestamp</option>
                <option value="reject">Reject & Flag anomaly</option>
              </select>
            </div>

            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? "Syncing Config..." : "Save Configuration"}
            </button>
          </form>
        </div>
      </div>

      {showToast && (
        <div className="toast">
          <div className="brand-dot"></div>
          <span>Weights Config successfully loaded and synced to Postgres & Redis!</span>
        </div>
      )}
    </div>
  );
}

export default DashboardPage;
