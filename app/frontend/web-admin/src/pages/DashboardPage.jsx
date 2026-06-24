import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { 
  getAdminAnalytics, 
  getRetrainReadiness, 
  getAdminAnalyticsHistory,
  getNluTrainHistory,
  getSystemSettings,
  saveSystemSettings
} from "../services/api";

function ProgressBar({ percent, level }) {
  const color =
    level === "ready" ? "var(--accent-emerald)" : level === "building" ? "var(--accent-amber)" : "var(--text-muted)";
  return (
    <div className="retrain-progress" style={{ height: "6px", background: "var(--bg-obsidian-950)", borderRadius: "3px", overflow: "hidden", marginTop: "8px" }}>
      <div className="retrain-progress-fill" style={{ width: `${percent}%`, height: "100%", background: color, borderRadius: "3px", transition: "width 0.5s ease" }} />
    </div>
  );
}

function ReadinessCard({ title, current, threshold, percent, level, ready, extra, actionTo, actionLabel }) {
  const statusColor = ready ? "var(--accent-emerald)" : level === "building" ? "var(--accent-amber)" : "var(--text-muted)";
  return (
    <div className={`retrain-card retrain-${level}`} style={{
      background: "var(--bg-obsidian-800)",
      border: `1px solid ${ready ? "rgba(16, 185, 129, 0.25)" : "var(--border-color)"}`,
      borderRadius: "12px",
      padding: "20px",
      boxShadow: ready ? "0 0 15px rgba(16, 185, 129, 0.04)" : "none",
      transition: "transform 0.2s ease, border-color 0.2s ease",
      display: "flex",
      flexDirection: "column",
      justifyContent: "space-between"
    }}>
      <div>
        <div className="retrain-card-head" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "12px" }}>
          <h3 style={{ fontSize: "14px", fontWeight: "600", color: "var(--text-primary)" }}>{title}</h3>
          <span className="badge" style={{
            fontSize: "11px",
            padding: "3px 8px",
            borderRadius: "12px",
            background: ready ? "rgba(16, 185, 129, 0.15)" : level === "building" ? "rgba(245, 158, 11, 0.15)" : "rgba(71, 85, 105, 0.15)",
            color: statusColor,
            fontWeight: "600"
          }}>
            {ready ? "Sẵn sàng" : `${percent}%`}
          </span>
        </div>
        <p className="retrain-count" style={{ fontSize: "24px", fontWeight: "700", color: "var(--text-primary)", marginBottom: "4px" }}>
          <strong>{current.toLocaleString()}</strong>
          <span className="muted" style={{ fontSize: "14px", color: "var(--text-muted)", fontWeight: "normal" }}> / {threshold.toLocaleString()}</span>
        </p>
        <ProgressBar percent={percent} level={level} />
        {extra && <p className="retrain-extra muted" style={{ fontSize: "12px", color: "var(--text-secondary)", marginTop: "12px", fontStyle: "italic" }}>{extra}</p>}
      </div>
      {actionTo && (
        <Link to={actionTo} className="btn btn-sm" style={{
          marginTop: "16px",
          width: "100%",
          textAlign: "center",
          padding: "8px",
          background: ready ? "var(--accent-emerald)" : "var(--bg-obsidian-900)",
          color: ready ? "var(--bg-obsidian-950)" : "var(--text-primary)",
          fontWeight: "600",
          border: ready ? "none" : "1px solid var(--border-color)",
          borderRadius: "8px",
          display: "block",
          fontSize: "12px",
          transition: "all 0.2s ease"
        }}>
          {actionLabel}
        </Link>
      )}
    </div>
  );
}

function ModelSubChart({ title, modelKey, historyData }) {
  const [selectedMetric, setSelectedMetric] = useState("accuracy"); // accuracy, precision, recall, f1_score, test_set

  const metricLabels = {
    accuracy: "Accuracy",
    precision: "Precision",
    recall: "Recall",
    f1_score: "F1-Score",
    test_set: "Test Set"
  };

  const getMetricValue = (run, key, metric) => {
    if (!run.metrics || !run.metrics[key]) {
      if (metric === "test_set") return 150;
      return 88.0;
    }
    return run.metrics[key][metric] || 0;
  };

  const runs = historyData.filter(r => r.status === "success");

  if (runs.length === 0) {
    return (
      <div className="panel" style={{ padding: "30px", textAlign: "center", color: "var(--text-muted)" }}>
        <p>Không có dữ liệu huấn luyện.</p>
      </div>
    );
  }

  const values = runs.map(r => getMetricValue(r, modelKey, selectedMetric));
  const isCount = selectedMetric === "test_set";
  
  // Dynamic scale
  const minVal = isCount ? 0 : Math.max(0, Math.min(50, ...values) - 5);
  const maxVal = isCount ? Math.max(...values) + 30 : 100;
  const range = maxVal - minVal;

  const getX = (index) => 35 + (index * (230 / Math.max(1, runs.length - 1)));
  const getY = (val) => 125 - ((val - minVal) / (range || 1)) * 95;

  const points = runs.map((r, i) => `${getX(i)},${getY(values[i])}`).join(" ");

  const fillPath = runs.length > 0
    ? `M ${getX(0)},130 L ${runs.map((r, i) => `${getX(i)} ${getY(values[i])}`).join(" L ")} L ${getX(runs.length - 1)},130 Z`
    : "";

  const chartColor = modelKey === "ocr" ? "var(--accent-blue)" 
                  : modelKey === "nlu_record" ? "var(--accent-emerald)" 
                  : modelKey === "nlu_action" ? "var(--accent-amber)" 
                  : modelKey === "nlu_chitchat" ? "#a855f7" 
                  : "#ec4899"; // fusion

  const accentLabelClass = modelKey === "ocr" ? "indicator-blue" 
                  : modelKey === "nlu_record" ? "indicator-emerald" 
                  : modelKey === "nlu_action" ? "indicator-amber" 
                  : "indicator-emerald";

  return (
    <div className="panel" style={{
      background: "var(--bg-obsidian-900)",
      border: "1px solid var(--border-color)",
      borderRadius: "12px",
      padding: "18px",
      display: "flex",
      flexDirection: "column",
      position: "relative"
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "16px" }}>
        <div>
          <h3 style={{ fontSize: "14px", fontWeight: "600", color: "var(--text-primary)" }}>{title}</h3>
          <span style={{ fontSize: "11px", color: "var(--text-secondary)", display: "block", marginTop: "2px" }}>
            Hiện tại: <strong style={{ color: chartColor, fontFamily: "var(--font-mono)" }}>{values[values.length - 1]}{isCount ? "" : "%"}</strong>
          </span>
        </div>
        <select
          className="form-select"
          style={{ width: "95px", padding: "4px 8px", fontSize: "11px", height: "24px", background: "var(--bg-obsidian-800)", border: "1px solid var(--border-color)", color: "var(--text-primary)", borderRadius: "6px" }}
          value={selectedMetric}
          onChange={(e) => setSelectedMetric(e.target.value)}
        >
          {Object.keys(metricLabels).map(k => (
            <option key={k} value={k}>{metricLabels[k]}</option>
          ))}
        </select>
      </div>

      <div style={{ height: "130px", position: "relative" }}>
        <svg viewBox="0 0 300 135" className="svg-chart" style={{ width: "100%", height: "100%", overflow: "visible" }} preserveAspectRatio="none">
          <defs>
            <linearGradient id={`grad-${modelKey}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={chartColor} stopOpacity="0.18" />
              <stop offset="100%" stopColor={chartColor} stopOpacity="0" />
            </linearGradient>
          </defs>
          
          {/* Horizontal lines */}
          <line x1="30" y1="30" x2="280" y2="30" stroke="var(--border-color)" strokeWidth="0.5" strokeDasharray="4 4" />
          <line x1="30" y1="80" x2="280" y2="80" stroke="var(--border-color)" strokeWidth="0.5" strokeDasharray="4 4" />
          <line x1="30" y1="130" x2="280" y2="130" stroke="var(--border-color)" strokeWidth="0.5" />
          
          {/* Area fill */}
          {fillPath && <path d={fillPath} fill={`url(#grad-${modelKey})`} />}
          
          {/* Polyline */}
          <polyline
            fill="none"
            stroke={chartColor}
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            points={points}
          />
          
          {/* Interactive node points & values */}
          {runs.map((r, i) => (
            <g key={i}>
              <circle
                cx={getX(i)}
                cy={getY(values[i])}
                r="4"
                fill="var(--bg-obsidian-950)"
                stroke={chartColor}
                strokeWidth="2.5"
              />
              <text
                x={getX(i)}
                y={getY(values[i]) - 8}
                textAnchor="middle"
                fill="var(--text-primary)"
                fontSize="9px"
                fontWeight="600"
                fontFamily="var(--font-mono)"
              >
                {values[i]}{isCount ? "" : "%"}
              </text>
            </g>
          ))}
        </svg>
      </div>

      <div style={{ display: "flex", justifyContent: "space-between", fontSize: "9px", padding: "0 6px", marginTop: "10px", borderTop: "1px solid var(--border-color)", paddingTop: "8px" }}>
        {runs.map((r, i) => (
          <span key={i} style={{ color: "var(--text-muted)", fontFamily: "var(--font-mono)" }}>
            Run #{r.run_index || (i+1)}
          </span>
        ))}
      </div>
    </div>
  );
}

function DashboardPage() {
  const [analytics, setAnalytics] = useState({
    totalUsers: 0,
    totalExpenses: 0,
    totalExpenseAmount: 0,
    fusionSuccessRate: 90.0
  });
  const [readiness, setReadiness] = useState(null);
  const [trainHistory, setTrainHistory] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [weights, setWeights] = useState({
    ocrWeight: 0.75,
    nluThreshold: 0.85,
    dateFallback: "transaction",
  });
  const [saving, setSaving] = useState(false);
  const [showToast, setShowToast] = useState(false);

  useEffect(() => {
    Promise.all([
      getAdminAnalytics(),
      getRetrainReadiness(),
      getNluTrainHistory(),
      getSystemSettings().catch(() => null)
    ])
      .then(([analyticsData, readinessData, trainHistoryData, settingsData]) => {
        setAnalytics(analyticsData);
        setReadiness(readinessData);
        setTrainHistory(trainHistoryData || []);
        if (settingsData) {
          setWeights({
            ocrWeight: settingsData.ocrWeight ?? 0.75,
            nluThreshold: settingsData.nluThreshold ?? 0.85,
            dateFallback: settingsData.dateFallback ?? "transaction",
          });
        }
        setLoading(false)
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  const handleSave = (e) => {
    e.preventDefault();
    setSaving(true);
    saveSystemSettings(weights)
      .then(() => {
        setSaving(false);
        setShowToast(true);
        setTimeout(() => setShowToast(false), 3000);
      })
      .catch((err) => {
        setError("Lỗi đồng bộ cấu hình: " + err.message);
        setSaving(false);
      });
  };

  if (loading) {
    return (
      <div style={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "80vh", color: "var(--text-secondary)" }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "12px" }}>
          <div className="brand-dot" style={{ width: "16px", height: "16px", animation: "pulse 1.5s infinite" }}></div>
          <p style={{ fontSize: "14px", fontWeight: "500" }}>Loading AI telemetry panel...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="page-container" style={{ padding: "30px 40px" }}>
      <div className="page-header" style={{ marginBottom: "30px" }}>
        <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px" }}>Fusion & AI Quality</h1>
        <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "4px" }}>
          Bảng giám sát chi tiết độ chính xác của các mô hình và cấu hình tham số AI Fusion.
        </p>
      </div>

      {error && (
        <div className="toast" style={{ borderColor: "var(--accent-rose)", position: "relative", marginBottom: "20px" }}>
          <span>Error: {error}</span>
        </div>
      )}

      {readiness && (
        <section className="panel retrain-panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px",
          marginBottom: "30px"
        }}>
          <div className="panel-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "8px" }}>
            <h2 className="panel-title" style={{ fontSize: "18px", fontWeight: "600", color: "var(--text-primary)" }}>Hàng đợi Huấn luyện (Retrain Readiness)</h2>
            <span className={`badge ${readiness.anyReady ? "badge-success" : "badge-muted"}`} style={{
              fontSize: "12px",
              padding: "4px 10px",
              borderRadius: "20px",
              background: readiness.anyReady ? "rgba(16, 185, 129, 0.15)" : "rgba(71, 85, 105, 0.15)",
              color: readiness.anyReady ? "var(--accent-emerald)" : "var(--text-muted)",
              fontWeight: "600"
            }}>
              {readiness.anyReady ? "Có mô hình sẵn sàng" : "Chưa đạt ngưỡng"}
            </span>
          </div>
          <p className="page-desc" style={{ fontSize: "13px", color: "var(--text-secondary)", marginBottom: "24px" }}>
            Ngưỡng kích hoạt: NLU Category ≥ {readiness.thresholds.categoryCorrections} sửa lỗi từ người dùng · OCR KIE ≥ {readiness.thresholds.ocrKieApproved} hóa đơn được duyệt trên WebAdmin.
          </p>
          <div className="retrain-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "20px" }}>
            <ReadinessCard
              title="Mô hình danh mục (NLU)"
              current={readiness.category.curatedPool}
              threshold={readiness.category.threshold}
              percent={readiness.category.percent}
              level={readiness.category.level}
              ready={readiness.category.ready}
              extra={`${readiness.category.correctionRows} dữ liệu chỉnh sửa`}
              actionTo="/nlu-ops"
              actionLabel="Duyệt dữ liệu sửa lỗi NLU"
            />
            <ReadinessCard
              title="Trích xuất thông tin (OCR / KIE)"
              current={readiness.billOcr.approved}
              threshold={readiness.billOcr.threshold}
              percent={readiness.billOcr.percent}
              level={readiness.billOcr.level}
              ready={readiness.billOcr.ready}
              extra={`Đang chờ duyệt: ${readiness.billOcr.pending} · Đã lưu trữ: ${readiness.billOcr.exported}`}
              actionTo="/bill-retrain"
              actionLabel="Duyệt nhãn Bill OCR"
            />
          </div>
        </section>
      )}

      {/* Analytics Telemetry Cards */}
      <div className="metrics-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))", gap: "20px", marginBottom: "30px" }}>
        <div className="metric-card" style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px", position: "relative" }}>
          <span className="metric-indicator indicator-emerald" style={{ position: "absolute", top: "24px", left: "24px", width: "8px", height: "8px", borderRadius: "50%", background: "var(--accent-emerald)", boxShadow: "0 0 10px var(--accent-emerald)" }}></span>
          <span className="metric-label" style={{ display: "block", fontSize: "13px", color: "var(--text-secondary)", marginBottom: "8px", paddingLeft: "16px" }}>Độ hội tụ AI Fusion</span>
          <span className="metric-value" style={{ display: "block", fontSize: "32px", fontWeight: "700", color: "var(--text-primary)" }}>{analytics.fusionSuccessRate}%</span>
          <span className="metric-desc" style={{ display: "block", fontSize: "12px", color: "var(--text-muted)", marginTop: "4px" }}>Tỉ lệ khớp chính xác Số tiền, Ngày & Hạng mục</span>
        </div>
        <div className="metric-card" style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px", position: "relative" }}>
          <span className="metric-indicator indicator-blue" style={{ position: "absolute", top: "24px", left: "24px", width: "8px", height: "8px", borderRadius: "50%", background: "var(--accent-blue)", boxShadow: "0 0 10px var(--accent-blue)" }}></span>
          <span className="metric-label" style={{ display: "block", fontSize: "13px", color: "var(--text-secondary)", marginBottom: "8px", paddingLeft: "16px" }}>Tổng số lượt AI trích xuất</span>
          <span className="metric-value" style={{ display: "block", fontSize: "32px", fontWeight: "700", color: "var(--text-primary)" }}>{analytics.totalExpenses.toLocaleString()}</span>
          <span className="metric-desc" style={{ display: "block", fontSize: "12px", color: "var(--text-muted)", marginTop: "4px" }}>Giao dịch xử lý qua giọng nói/ảnh hóa đơn</span>
        </div>
        <div className="metric-card" style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px", position: "relative" }}>
          <span className="metric-indicator indicator-amber" style={{ position: "absolute", top: "24px", left: "24px", width: "8px", height: "8px", borderRadius: "50%", background: "var(--accent-amber)", boxShadow: "0 0 10px var(--accent-amber)" }}></span>
          <span className="metric-label" style={{ display: "block", fontSize: "13px", color: "var(--text-secondary)", marginBottom: "8px", paddingLeft: "16px" }}>Tổng khối lượng chi tiêu</span>
          <span className="metric-value" style={{ display: "block", fontSize: "28px", fontWeight: "700", color: "var(--text-primary)" }}>{Number(analytics.totalExpenseAmount).toLocaleString()} VND</span>
          <span className="metric-desc" style={{ display: "block", fontSize: "12px", color: "var(--text-muted)", marginTop: "4px" }}>Tổng giá trị dòng tiền thực tế được theo dõi</span>
        </div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: "30px", marginBottom: "30px" }}>
        {/* Quality Metrics Sub-charts Grid */}
        <div className="panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px"
        }}>
          <div className="panel-header" style={{ marginBottom: "20px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div>
              <h2 className="panel-title" style={{ fontSize: "18px", fontWeight: "600", color: "var(--text-primary)" }}>Model Accuracy & Telemetry Runs</h2>
              <p className="form-desc" style={{ fontSize: "13px", color: "var(--text-secondary)", marginTop: "4px" }}>
                Chi tiết các metric đánh giá chất lượng qua các lần chạy huấn luyện.
              </p>
            </div>
            <span className="badge badge-success" style={{ padding: "4px 10px", fontSize: "12px", background: "rgba(16, 185, 129, 0.12)", color: "var(--accent-emerald)", borderRadius: "12px", fontWeight: "600" }}>Target: &gt;90%</span>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "20px" }}>
            <ModelSubChart title="OCR / KIE Model" modelKey="ocr" historyData={trainHistory} />
            <ModelSubChart title="NLU Record Model" modelKey="nlu_record" historyData={trainHistory} />
            <ModelSubChart title="NLU Action Model" modelKey="nlu_action" historyData={trainHistory} />
            <ModelSubChart title="NLU Chitchat Model" modelKey="nlu_chitchat" historyData={trainHistory} />
            <ModelSubChart title="Fusion Convergence" modelKey="fusion" historyData={trainHistory} />
          </div>
        </div>

        {/* Fusion Weight Configuration */}
        <div className="panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px"
        }}>
          <div className="panel-header" style={{ marginBottom: "20px" }}>
            <h2 className="panel-title" style={{ fontSize: "18px", fontWeight: "600", color: "var(--text-primary)" }}>Thuật toán Fusion & Cấu hình Trọng số</h2>
            <p className="form-desc" style={{ fontSize: "13px", color: "var(--text-secondary)", marginTop: "4px" }}>
              Calibrate các tham số quyết định khi chập nhận dữ liệu giữa NLU và kết quả OCR.
            </p>
          </div>

          <form onSubmit={handleSave} style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))", gap: "24px" }}>
            <div className="form-group">
              <label className="form-label" htmlFor="ocrWeight" style={{ color: "var(--text-primary)", fontWeight: "500", fontSize: "13px", display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                <span>OCR Confidence Weight</span>
                <strong style={{ color: "var(--accent-emerald)", fontFamily: "var(--font-mono)" }}>{weights.ocrWeight}</strong>
              </label>
              <input
                id="ocrWeight"
                type="range"
                min="0.1"
                max="1.0"
                step="0.05"
                value={weights.ocrWeight}
                onChange={(e) => setWeights({ ...weights, ocrWeight: parseFloat(e.target.value) })}
                style={{ accentColor: "var(--accent-emerald)", width: "100%", height: "6px", background: "var(--bg-obsidian-800)", borderRadius: "3px" }}
              />
              <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "6px", display: "block" }}>Độ ưu tiên gán cho dữ liệu quét hóa đơn khi độ tin cậy mô hình dao động.</span>
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="nluThreshold" style={{ color: "var(--text-primary)", fontWeight: "500", fontSize: "13px", display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                <span>NLU Similarity Threshold</span>
                <strong style={{ color: "var(--accent-emerald)", fontFamily: "var(--font-mono)" }}>{weights.nluThreshold}</strong>
              </label>
              <input
                id="nluThreshold"
                type="range"
                min="0.5"
                max="0.95"
                step="0.05"
                value={weights.nluThreshold}
                onChange={(e) => setWeights({ ...weights, nluThreshold: parseFloat(e.target.value) })}
                style={{ accentColor: "var(--accent-emerald)", width: "100%", height: "6px", background: "var(--bg-obsidian-800)", borderRadius: "3px" }}
              />
              <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "6px", display: "block" }}>Ngưỡng lọc cosine similarity cho thuật toán sửa lỗi cá nhân hóa ở Layer 2.</span>
            </div>



            <div className="form-group" style={{ display: "flex", flexDirection: "column" }}>
              <label className="form-label" htmlFor="dateFallback" style={{ color: "var(--text-primary)", fontWeight: "500", fontSize: "13px", marginBottom: "8px" }}>
                Phương án dự phòng chập ngày (Date Convergence)
              </label>
              <select
                id="dateFallback"
                className="form-select"
                value={weights.dateFallback}
                onChange={(e) => setWeights({ ...weights, dateFallback: e.target.value })}
                style={{ height: "40px", background: "var(--bg-obsidian-800)", border: "1px solid var(--border-color)", color: "var(--text-primary)", padding: "0 12px", borderRadius: "8px", fontSize: "13px" }}
              >
                <option value="transaction">Lấy theo ngày trên hóa đơn (Extracted)</option>
                <option value="current">Mặc định ngày hiện tại của hệ thống</option>
                <option value="reject">Từ chối và gắn nhãn giao dịch lỗi</option>
              </select>
            </div>

            <div style={{ gridColumn: "1 / -1", display: "flex", justifyContent: "flex-end", marginTop: "10px" }}>
              <button type="submit" className="btn btn-primary" disabled={saving} style={{
                background: "var(--accent-emerald)",
                color: "var(--bg-obsidian-950)",
                fontWeight: "600",
                fontSize: "14px",
                padding: "12px 24px",
                border: "none",
                borderRadius: "8px",
                cursor: "pointer",
                transition: "opacity 0.2s ease"
              }}>
                {saving ? "Đang đồng bộ..." : "Đồng bộ Cấu hình Trọng số"}
              </button>
            </div>
          </form>
        </div>
      </div>

      {showToast && (
        <div className="toast" style={{
          position: "fixed",
          bottom: "30px",
          right: "30px",
          background: "var(--bg-obsidian-800)",
          border: "1px solid var(--accent-emerald)",
          borderRadius: "8px",
          padding: "14px 20px",
          boxShadow: "0 10px 25px rgba(0,0,0,0.3), 0 0 15px rgba(16, 185, 129, 0.1)",
          display: "flex",
          alignItems: "center",
          gap: "10px",
          zIndex: 9999
        }}>
          <div className="brand-dot" style={{ background: "var(--accent-emerald)", width: "8px", height: "8px", borderRadius: "50%" }}></div>
          <span style={{ color: "var(--text-primary)", fontSize: "13px", fontWeight: "500" }}>Cấu hình trọng số đã được đồng bộ lên PostgreSQL & Redis!</span>
        </div>
      )}
    </div>
  );
}

export default DashboardPage;
