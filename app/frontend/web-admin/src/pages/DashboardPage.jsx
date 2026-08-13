import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { 
  getAdminAnalytics, 
  getRetrainReadiness, 
  getAdminAnalyticsHistory,
  getNluTrainHistory,
  getSystemSettings,
  saveSystemSettings,
  getNluBenchmarkResults,
  triggerNluBenchmark,
  getLlmTrainHistory,
  getOcrTrainHistory,
  getMonetizationStats,
  getMonetizationHistory,
  getMonetizationOrders,
  toggleUserPremium
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

function buildSmoothSvgPath(coords) {
  if (!coords || coords.length === 0) return "";
  if (coords.length === 1) return `M ${coords[0].x},${coords[0].y}`;
  let d = `M ${coords[0].x},${coords[0].y}`;
  for (let i = 0; i < coords.length - 1; i++) {
    const p0 = coords[i === 0 ? 0 : i - 1];
    const p1 = coords[i];
    const p2 = coords[i + 1];
    const p3 = coords[i + 2 <= coords.length - 1 ? i + 2 : i + 1];

    const cp1x = p1.x + (p2.x - p0.x) / 6;
    const cp1y = p1.y + (p2.y - p0.y) / 6;
    const cp2x = p2.x - (p3.x - p1.x) / 6;
    const cp2y = p2.y - (p3.y - p1.y) / 6;

    d += ` C ${cp1x.toFixed(1)},${cp1y.toFixed(1)} ${cp2x.toFixed(1)},${cp2y.toFixed(1)} ${p2.x.toFixed(1)},${p2.y.toFixed(1)}`;
  }
  return d;
}

function ModelSubChart({ title, modelKey, historyData }) {
  const [selectedMetric, setSelectedMetric] = useState(modelKey === "ocr" ? "f1_score" : "accuracy");
  const [hoveredIndex, setHoveredIndex] = useState(null);

  const metricLabels = modelKey === "ocr" ? {
    f1_score: "Overall F1",
    precision: "Precision",
    recall: "Recall",
    address_f1: "Address F1",
    seller_f1: "Seller F1",
    total_cost_f1: "Total Cost F1"
  } : {
    accuracy: "Accuracy",
    precision: "Precision",
    recall: "Recall",
    f1_score: "F1-Score",
    test_set: "Test Set"
  };

  const getMetricValue = (run, key, metric) => {
    if (key === "ocr") {
      // Special parsing for LayoutLMv3 OCR
      if (["f1_score", "precision", "recall"].includes(metric)) {
        const altMetric = metric === "f1_score" ? "f1" : metric;
        if (run.metrics && run.metrics[altMetric] !== undefined) return run.metrics[altMetric];
        if (run.metrics && run.metrics[metric] !== undefined) return run.metrics[metric];
      }
      if (metric.endsWith("_f1")) {
        // e.g. address_f1 -> ADDRESS
        const label = metric.split("_f1")[0].toUpperCase();
        if (run.metrics && run.metrics.classification_report) {
          const regex = new RegExp(`\\b${label}\\s+[0-9.]+\\s+[0-9.]+\\s+([0-9.]+)`);
          const match = run.metrics.classification_report.match(regex);
          if (match && match[1]) {
            return parseFloat(match[1]) * 100;
          }
        }
        return 0;
      }
    }

    if (run.metrics && run.metrics[metric] !== undefined && !run.metrics[key]) {
      return run.metrics[metric] <= 1 ? run.metrics[metric] * 100 : run.metrics[metric];
    }
    if (!run.metrics || !run.metrics[key]) {
      if (metric === "test_set") return 150;
      return 0;
    }
    const val = run.metrics[key][metric];
    if (val !== undefined) return val <= 1 ? val * 100 : val;

    if (metric === "f1_score") {
      const f1 = run.metrics[key].weighted_f1 || run.metrics[key].f1 || run.metrics[key].ents_f || 0;
      return f1 <= 1 ? f1 * 100 : f1;
    }
    return 0;
  };

  const runs = historyData.filter(r => r.status === "success");

  if (runs.length === 0) {
    return (
      <div className="pro-max-chart-panel" style={{ padding: "34px", textAlign: "center" }}>
        <h3 className="pro-max-chart-title" style={{ justifyContent: "center" }}>{title}</h3>
        <p style={{ color: "var(--text-muted)", fontSize: "13px", marginTop: "8px" }}>Chưa có dữ liệu huấn luyện.</p>
      </div>
    );
  }

  const values = runs.map(r => getMetricValue(r, modelKey, selectedMetric));
  const isCount = selectedMetric === "test_set";
  
  const minVal = isCount ? 0 : Math.max(0, Math.min(50, ...values) - 5);
  const maxVal = isCount ? Math.max(...values) + 30 : 100;
  const range = maxVal - minVal;

  const getX = (index) => 36 + (index * (232 / Math.max(1, runs.length - 1)));
  const getY = (val) => 120 - ((val - minVal) / (range || 1)) * 88;

  const chartColor = modelKey === "ocr" ? "var(--accent-blue)" 
                  : modelKey === "intent" ? "var(--accent-emerald)" 
                  : modelKey === "category" ? "#a855f7" 
                  : "var(--accent-blue)";


  const encoderColor = "#c084fc";

  const tfidfRuns = modelKey === "ocr" ? runs : runs.filter(r => !r.train_type || r.train_type === "tfidf");
  const encoderRuns = modelKey === "ocr" ? [] : runs.filter(r => r.train_type === "encoder");

  const renderSmoothSeries = (lineRuns, color, idSuffix) => {
    if (lineRuns.length === 0) return null;
    const coords = lineRuns.map(r => {
      const globalIdx = runs.findIndex(x => x === r);
      return { x: getX(globalIdx), y: getY(getMetricValue(r, modelKey, selectedMetric)) };
    });

    const smoothLinePath = buildSmoothSvgPath(coords);
    const fillPath = coords.length > 1
      ? `${smoothLinePath} L ${coords[coords.length - 1].x},125 L ${coords[0].x},125 Z`
      : "";

    return (
      <g key={idSuffix}>
        <defs>
          <linearGradient id={`grad-${modelKey}-${idSuffix}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.32" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        {fillPath && <path d={fillPath} fill={`url(#grad-${modelKey}-${idSuffix})`} />}
        <path d={smoothLinePath} fill="none" stroke={color} strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round" />
        {lineRuns.map((r) => {
          const globalIdx = runs.findIndex(x => x === r);
          const v = getMetricValue(r, modelKey, selectedMetric);
          const isHovered = hoveredIndex === globalIdx;
          return (
            <g
              key={globalIdx}
              style={{ cursor: "pointer" }}
              onMouseEnter={() => setHoveredIndex(globalIdx)}
            >
              {isHovered && (
                <line
                  x1={getX(globalIdx)}
                  y1="25"
                  x2={getX(globalIdx)}
                  y2="125"
                  stroke={color}
                  strokeWidth="1"
                  strokeDasharray="3 3"
                  opacity="0.7"
                />
              )}
              <circle
                cx={getX(globalIdx)}
                cy={getY(v)}
                r={isHovered ? "6" : "4"}
                fill="var(--bg-obsidian-950)"
                stroke={color}
                strokeWidth={isHovered ? "3" : "2.2"}
                style={{ transition: "all 0.18s ease" }}
              />
              <text
                x={getX(globalIdx)}
                y={getY(v) - 10}
                textAnchor="middle"
                fill={isHovered ? "var(--text-primary)" : "var(--text-secondary)"}
                fontSize={isHovered ? "10px" : "9px"}
                fontWeight="700"
                fontFamily="var(--font-mono)"
              >
                {v}{isCount ? "" : "%"}
              </text>
            </g>
          );
        })}
      </g>
    );
  };

  const latestVal = runs.length > 0 ? getMetricValue(runs[runs.length - 1], modelKey, selectedMetric) : 0;
  const firstVal = runs.length > 1 ? getMetricValue(runs[0], modelKey, selectedMetric) : latestVal;
  const delta = (latestVal - firstVal).toFixed(1);

  return (
    <div className="pro-max-chart-panel" onMouseLeave={() => setHoveredIndex(null)}>
      <div className="pro-max-chart-head">
        <div>
          <h3 className="pro-max-chart-title">
            <span style={{ width: "8px", height: "8px", borderRadius: "50%", background: chartColor, display: "inline-block" }}></span>
            {title}
          </h3>
          {modelKey !== "ocr" && (
            <div style={{ display: "flex", gap: "10px", marginTop: "4px", fontSize: "11px", color: "var(--text-secondary)", fontWeight: "500" }}>
              <span style={{ display: "flex", alignItems: "center", gap: "4px" }}>
                <span style={{ width: "6px", height: "6px", borderRadius: "50%", background: chartColor }}></span> TF-IDF
              </span>
              <span style={{ display: "flex", alignItems: "center", gap: "4px" }}>
                <span style={{ width: "6px", height: "6px", borderRadius: "50%", background: encoderColor }}></span> PhoBERT Encoder
              </span>
            </div>
          )}
          <div className="pro-max-chart-subtitle" style={{ marginTop: "8px" }}>
            <span>Mới nhất: <strong style={{ color: chartColor, fontFamily: "var(--font-mono)" }}>{latestVal}{isCount ? "" : "%"}</strong></span>
            {runs.length > 1 && !isCount && (
              <span className="pro-max-stat-pill" style={{
                background: delta >= 0 ? "rgba(16, 185, 129, 0.12)" : "rgba(239, 68, 68, 0.12)",
                color: delta >= 0 ? "var(--accent-emerald)" : "var(--accent-rose)"
              }}>
                {delta >= 0 ? `+${delta}%` : `${delta}%`}
              </span>
            )}
          </div>
        </div>

        <div className="pro-max-pill-tabs">
          {Object.entries(metricLabels).map(([key, label]) => (
            <button
              key={key}
              type="button"
              className={`pro-max-pill-tab ${selectedMetric === key ? "active" : ""}`}
              onClick={() => setSelectedMetric(key)}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      <div style={{ height: "145px", position: "relative" }}>
        {hoveredIndex !== null && runs[hoveredIndex] && (
          <div className="pro-max-tooltip">
            <div style={{ fontSize: "11px", color: "var(--text-secondary)", marginBottom: "3px" }}>
              Run #{runs[hoveredIndex].run_index || (hoveredIndex + 1)} {modelKey !== "ocr" && (
                <span style={{ color: runs[hoveredIndex].train_type === "encoder" ? encoderColor : chartColor, marginLeft: "4px", fontWeight: "600" }}>
                  ({runs[hoveredIndex].train_type === "encoder" ? "PhoBERT" : "TF-IDF"})
                </span>
              )}
            </div>
            <div style={{ fontSize: "14px", fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)" }}>
              {metricLabels[selectedMetric]}: {getMetricValue(runs[hoveredIndex], modelKey, selectedMetric)}{isCount ? "" : "%"}
            </div>
          </div>
        )}

        <svg viewBox="0 0 300 135" style={{ width: "100%", height: "100%", overflow: "visible" }} preserveAspectRatio="none">
          <line x1="30" y1="35" x2="280" y2="35" stroke="var(--border-color)" strokeWidth="0.5" strokeDasharray="3 3" />
          <line x1="30" y1="80" x2="280" y2="80" stroke="var(--border-color)" strokeWidth="0.5" strokeDasharray="3 3" />
          <line x1="30" y1="125" x2="280" y2="125" stroke="var(--border-color)" strokeWidth="0.8" />

          {renderSmoothSeries(tfidfRuns, chartColor, "tfidf")}
          {renderSmoothSeries(encoderRuns, encoderColor, "encoder")}
        </svg>
      </div>

      <div style={{ display: "flex", justifyContent: "space-between", fontSize: "10px", color: "var(--text-muted)", fontFamily: "var(--font-mono)", marginTop: "12px", borderTop: "1px solid var(--border-color)", paddingTop: "10px" }}>
        {runs.map((r, i) => (
          <span
            key={i}
            style={{
              color: hoveredIndex === i ? "var(--text-primary)" : "var(--text-muted)",
              fontWeight: hoveredIndex === i ? "700" : "400",
              cursor: "pointer",
              transition: "color 0.2s ease"
            }}
            onMouseEnter={() => setHoveredIndex(i)}
          >
            Run #{r.run_index || (i + 1)}
          </span>
        ))}
      </div>
    </div>
  );
}

function NluBenchmarkChart({ data }) {
  if (!data) return <p style={{ color: "var(--text-muted)", textAlign: "center", padding: "24px" }}>Chưa có dữ liệu benchmark.</p>;
  
  const backends = [
    { key: "tfidf", label: "TF-IDF + SVM (Local CPU)", color: "var(--accent-blue)", speed: "< 2 ms", tag: "Siêu nhanh" },
    { key: "phobert", label: "PhoBERT Encoder (Modal GPU)", color: "var(--accent-emerald)", speed: "~ 45 ms", tag: "Cân bằng" },
    { key: "qwen25_lora", label: "Qwen 2.5-14B LoRA (GPU 4-bit)", color: "#a855f7", speed: "~ 1480 ms", tag: "Suy luận sâu" }
  ];
  
  return (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "24px", marginTop: "16px" }}>
      {/* Accuracy Comparison Card */}
      <div className="pro-max-benchmark-card">
        <div>
          <h4 style={{ fontSize: "15px", fontWeight: "700", color: "var(--text-primary)" }}>So sánh Độ chính xác Ý định & Hạng mục (%)</h4>
          <p style={{ fontSize: "12px", color: "var(--text-secondary)", marginTop: "4px" }}>Hiệu năng phân loại trên tập test benchmark chuẩn.</p>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: "18px" }}>
          {backends.map(b => {
            const acc = data[b.key]?.intent_accuracy || 0.0;
            const catAcc = data[b.key]?.category_accuracy || 0.0;
            return (
              <div key={b.key} className="pro-max-bar-row">
                <div className="pro-max-bar-header">
                  <span style={{ color: "var(--text-primary)", fontWeight: "600" }}>{b.label}</span>
                  <span style={{ fontFamily: "var(--font-mono)", fontSize: "12px", fontWeight: "700", color: b.color }}>
                    Intent: {acc}% | Category: {catAcc}%
                  </span>
                </div>
                <div className="pro-max-bar-track">
                  <div className="pro-max-bar-fill" style={{ width: `${acc * 0.58}%`, background: b.color }}></div>
                  <div className="pro-max-bar-fill" style={{ width: `${catAcc * 0.42}%`, background: b.color, opacity: 0.55 }}></div>
                </div>
              </div>
            );
          })}
        </div>

        <div style={{ display: "flex", gap: "16px", fontSize: "11px", color: "var(--text-muted)", borderTop: "1px solid var(--border-color)", paddingTop: "12px" }}>
          <span style={{ display: "flex", alignItems: "center", gap: "6px" }}>
            <span style={{ width: "10px", height: "10px", borderRadius: "3px", background: "currentColor" }}></span>
            Ý định (Intent Accuracy)
          </span>
          <span style={{ display: "flex", alignItems: "center", gap: "6px", opacity: 0.65 }}>
            <span style={{ width: "10px", height: "10px", borderRadius: "3px", background: "currentColor" }}></span>
            Hạng mục (Category Accuracy)
          </span>
        </div>
      </div>

      {/* Latency Comparison Card */}
      <div className="pro-max-benchmark-card">
        <div>
          <h4 style={{ fontSize: "15px", fontWeight: "700", color: "var(--text-primary)" }}>Phổ Thời gian phản hồi (Latency - ms)</h4>
          <p style={{ fontSize: "12px", color: "var(--text-secondary)", marginTop: "4px" }}>Tốc độ xử lý trung bình mỗi request theo kiến trúc.</p>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: "18px" }}>
          {backends.map(b => {
            const lat = data[b.key]?.avg_latency_ms || 0.0;
            const logWidth = lat > 1000 ? 94 : lat > 100 ? 58 : lat > 10 ? 32 : 12;
            return (
              <div key={b.key} className="pro-max-bar-row">
                <div className="pro-max-bar-header">
                  <span style={{ color: "var(--text-primary)", fontWeight: "600", display: "flex", alignItems: "center", gap: "8px" }}>
                    {b.label}
                    <span className="pro-max-stat-pill" style={{ background: "rgba(255,255,255,0.06)", color: b.color, fontSize: "10px" }}>{b.tag}</span>
                  </span>
                  <span style={{ fontFamily: "var(--font-mono)", fontSize: "11px", color: "var(--text-muted)", display: "flex", flexDirection: "column", alignItems: "flex-end", gap: "3px", textAlign: "right" }}>
                    <span style={{ fontSize: "12px", fontWeight: "700", color: b.color }}>
                      Tổng: {lat || b.speed} ms
                    </span>
                    {lat > 0 && (
                      <span style={{ fontSize: "10px", opacity: 0.85 }}>
                        Ý định: {data[b.key]?.intent_latency_ms || 0}ms | Hạng mục: {data[b.key]?.category_latency_ms || 0}ms
                      </span>
                    )}
                  </span>
                </div>
                <div className="pro-max-bar-track">
                  <div className="pro-max-bar-fill" style={{ width: `${logWidth}%`, background: b.color }}></div>
                </div>
              </div>
            );
          })}
        </div>

        <p style={{ fontSize: "11px", color: "var(--text-muted)", fontStyle: "italic", borderTop: "1px solid var(--border-color)", paddingTop: "12px" }}>
          💡 TF-IDF phản hồi tức thì (&lt;2ms), PhoBERT đạt cân bằng tốt (~45ms), Qwen2.5-14B-Instruct thực hiện suy luận sinh ngữ cảnh sâu.
        </p>
      </div>
    </div>
  );
}

function LlmLossChart({ runData }) {
  const [hoveredStep, setHoveredStep] = useState(null);

  if (!runData || !runData.loss_curve || runData.loss_curve.length === 0) return null;

  const points = runData.loss_curve;
  const losses = points.map(p => p.loss);
  const minLoss = Math.max(0, Math.min(...losses) - 0.08);
  const maxLoss = Math.max(...losses) + 0.15;
  const lossRange = maxLoss - minLoss;

  const getX = (index) => 38 + (index * (425 / Math.max(1, points.length - 1)));
  const getY = (val) => 120 - ((val - minLoss) / (lossRange || 1)) * 90;

  const coords = points.map((p, i) => ({ x: getX(i), y: getY(p.loss) }));
  const smoothCurve = buildSmoothSvgPath(coords);
  const fillPath = coords.length > 1
    ? `${smoothCurve} L ${coords[coords.length - 1].x},125 L ${coords[0].x},125 Z`
    : "";

  const milestoneIndices = [
    0,
    Math.floor((points.length - 1) / 2),
    points.length - 1
  ].filter((v, i, a) => a.indexOf(v) === i);

  return (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "24px", alignItems: "center" }}>
      <div className="pro-max-chart-panel" style={{ height: "210px", padding: "16px" }}>
        {hoveredStep !== null && points[hoveredStep] && (
          <div className="pro-max-tooltip">
            <div style={{ fontSize: "11px", color: "var(--text-secondary)" }}>Step {points[hoveredStep].step}</div>
            <div style={{ fontSize: "13px", fontWeight: "700", color: "#c084fc", fontFamily: "var(--font-mono)" }}>
              Loss: {points[hoveredStep].loss.toFixed(4)}
            </div>
          </div>
        )}

        <svg viewBox="0 0 500 145" style={{ width: "100%", height: "100%", overflow: "visible" }} preserveAspectRatio="none" onMouseLeave={() => setHoveredStep(null)}>
          <defs>
            <linearGradient id="grad-loss-pro" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#a855f7" stopOpacity="0.38" />
              <stop offset="100%" stopColor="#a855f7" stopOpacity="0" />
            </linearGradient>
          </defs>
          <line x1="30" y1="30" x2="475" y2="30" stroke="var(--border-color)" strokeWidth="0.5" strokeDasharray="3 3" />
          <line x1="30" y1="75" x2="475" y2="75" stroke="var(--border-color)" strokeWidth="0.5" strokeDasharray="3 3" />
          <line x1="30" y1="120" x2="475" y2="120" stroke="var(--border-color)" strokeWidth="0.8" />

          {fillPath && <path d={fillPath} fill="url(#grad-loss-pro)" />}
          <path d={smoothCurve} fill="none" stroke="#a855f7" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round" />

          {points.map((p, i) => {
            const x = getX(i);
            const y = getY(p.loss);
            const isHovered = hoveredStep === i;
            return (
              <circle
                key={i}
                cx={x}
                cy={y}
                r={isHovered ? "6" : "3.5"}
                fill="var(--bg-obsidian-950)"
                stroke="#a855f7"
                strokeWidth={isHovered ? "3" : "2"}
                style={{ cursor: "pointer", transition: "all 0.15s ease" }}
                onMouseEnter={() => setHoveredStep(i)}
              />
            );
          })}

          {milestoneIndices.map((idx, i) => {
            const p = points[idx];
            if (!p) return null;
            const x = getX(idx);
            const y = getY(p.loss);
            return (
              <g key={`milestone-${i}`} pointerEvents="none">
                <line x1={x} y1={y} x2={x} y2="120" stroke="#a855f7" strokeWidth="0.6" strokeDasharray="2 2" opacity="0.7" />
                <text x={x} y={y - 12} textAnchor="middle" fill="var(--text-primary)" fontSize="10px" fontWeight="700" fontFamily="var(--font-mono)">
                  {p.loss.toFixed(3)}
                </text>
                <text x={x} y="135" textAnchor="middle" fill="var(--text-muted)" fontSize="9px" fontFamily="var(--font-mono)">
                  Step {p.step}
                </text>
              </g>
            );
          })}
        </svg>
      </div>

      <div className="pro-max-benchmark-card">
        <div>
          <h4 style={{ fontSize: "15px", fontWeight: "700", color: "var(--text-primary)" }}>Thông số Huấn luyện LLM (Run #{runData.run_index})</h4>
          <p style={{ fontSize: "12px", color: "var(--text-secondary)", marginTop: "4px" }}>Cấu hình huấn luyện LoRA Fine-tune trên máy chủ GPU.</p>
        </div>

        <ul style={{ fontSize: "13px", color: "var(--text-secondary)", listStyle: "none", padding: 0, margin: 0, display: "flex", flexDirection: "column", gap: "10px" }}>
          <li style={{ display: "flex", justifyContent: "space-between" }}>
            <span>🚀 Base Model</span>
            <code style={{ fontFamily: "var(--font-mono)", color: "var(--text-primary)" }}>{runData.model_id}</code>
          </li>
          <li style={{ display: "flex", justifyContent: "space-between" }}>
            <span>🎯 Adapter Target</span>
            <code style={{ fontFamily: "var(--font-mono)", color: "#c084fc" }}>{runData.lora_target}</code>
          </li>
          <li style={{ display: "flex", justifyContent: "space-between" }}>
            <span>📅 Thời gian</span>
            <span>{new Date(runData.trained_at).toLocaleString()}</span>
          </li>
          <li style={{ display: "flex", justifyContent: "space-between" }}>
            <span>📉 Loss hội tụ</span>
            <span style={{ fontFamily: "var(--font-mono)" }}>
              từ <strong style={{ color: "var(--accent-rose)" }}>{points[0].loss.toFixed(4)}</strong> xuống <strong style={{ color: "var(--accent-emerald)" }}>{points[points.length - 1].loss.toFixed(4)}</strong>
            </span>
          </li>
          <li style={{ display: "flex", justifyContent: "space-between" }}>
            <span>⏰ Thời lượng</span>
            <span style={{ fontFamily: "var(--font-mono)" }}>{runData.duration_sec ? `${runData.duration_sec.toLocaleString()} giây` : "Đang tính..."}</span>
          </li>
        </ul>
      </div>
    </div>
  );
}

function formatVND(amount) {
  return new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND" }).format(amount || 0);
}

function formatDate(value) {
  if (!value) return "—";
  return new Date(value).toLocaleString("vi-VN", {
    day: "2-digit", month: "2-digit", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

function RevenueChart({ data }) {
  const [hovered, setHovered] = useState(null);

  if (!data || data.length === 0) {
    return <div style={{ height: 160, display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-muted)", fontSize: 13 }}>Chưa có dữ liệu</div>;
  }

  const W = 700, H = 180, PAD = { t: 20, r: 20, b: 32, l: 60 };
  const maxVal = Math.max(...data.map((d) => d.revenue), 1);
  const chartW = W - PAD.l - PAD.r;
  const chartH = H - PAD.t - PAD.b;
  const step = chartW / (data.length - 1 || 1);

  const pts = data.map((d, i) => ({
    x: PAD.l + i * step,
    y: PAD.t + chartH - (d.revenue / maxVal) * chartH,
    ...d,
  }));

  const pathD = pts.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" ");
  const areaD = `${pathD} L ${pts[pts.length - 1].x.toFixed(1)} ${(PAD.t + chartH).toFixed(1)} L ${PAD.l} ${(PAD.t + chartH).toFixed(1)} Z`;

  return (
    <div style={{ position: "relative", overflowX: "auto" }} onMouseLeave={() => setHovered(null)}>
      <svg viewBox={`0 0 ${W} ${H}`} style={{ width: "100%", height: "100%" }} preserveAspectRatio="none">
        <defs>
          <linearGradient id="rev-grad-pro" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--accent-emerald)" stopOpacity="0.32" />
            <stop offset="100%" stopColor="var(--accent-emerald)" stopOpacity="0" />
          </linearGradient>
        </defs>

        {/* Grid lines */}
        {[0, 0.25, 0.5, 0.75, 1].map((t) => {
          const y = PAD.t + chartH * (1 - t);
          return (
            <g key={t}>
              <line x1={PAD.l} y1={y} x2={W - PAD.r} y2={y} stroke="var(--border-color)" strokeWidth={0.5} strokeDasharray="3 3" />
              <text x={PAD.l - 12} y={y + 4} textAnchor="end" fontSize={10} fill="var(--text-secondary)" fontFamily="var(--font-mono)">
                {formatVND(maxVal * t).replace("₫", "").trim()}
              </text>
            </g>
          );
        })}

        {/* Area + Line */}
        <path d={areaD} fill="url(#rev-grad-pro)" />
        <path d={pathD} fill="none" stroke="var(--accent-emerald)" strokeWidth={2.8} strokeLinecap="round" strokeLinejoin="round" />

        {/* Dots */}
        {pts.map((p, i) => {
          const isHovered = hovered === i;
          return (
            <g key={i} onMouseEnter={() => setHovered(i)} style={{ cursor: "pointer" }}>
              {isHovered && (
                <line x1={p.x} y1={PAD.t} x2={p.x} y2={PAD.t + chartH} stroke="var(--accent-emerald)" strokeWidth="1" strokeDasharray="3 3" opacity="0.7" />
              )}
              <circle
                cx={p.x} cy={p.y} r={isHovered ? "6" : "3.5"}
                fill="var(--bg-obsidian-950)"
                stroke="var(--accent-emerald)"
                strokeWidth={isHovered ? "3" : "2"}
                style={{ transition: "all 0.15s ease" }}
              />
            </g>
          );
        })}

        {/* X-axis labels (every 5th) */}
        {pts.map((p, i) => {
          if (data.length > 10 && i % 5 !== 0 && i !== data.length - 1) return null;
          return (
            <text key={i} x={p.x} y={H - 10} textAnchor="middle" fontSize={10} fill="var(--text-secondary)" fontFamily="var(--font-mono)">
              {p.date}
            </text>
          );
        })}
      </svg>

      {/* Tooltip */}
      {hovered !== null && pts[hovered] && (
        <div className="pro-max-tooltip" style={{
          position: "absolute",
          top: pts[hovered].y - 60,
          left: Math.min(pts[hovered].x, W - 140) + "px",
        }}>
          <div style={{ fontSize: "11px", color: "var(--text-secondary)", marginBottom: "3px" }}>
            {pts[hovered].date}
          </div>
          <div style={{ fontSize: "14px", fontWeight: "700", color: "var(--accent-emerald)", fontFamily: "var(--font-mono)" }}>
            {formatVND(pts[hovered].revenue)}
          </div>
          <div style={{ fontSize: "11px", color: "var(--text-muted)", marginTop: "2px" }}>
            {pts[hovered].orders} đơn hoàn thành
          </div>
        </div>
      )}
    </div>
  );
}


function OrderStatusBadge({ status }) {
  const map = {
    completed: { label: "Hoàn thành", color: "var(--accent-emerald)", bg: "rgba(16,185,129,0.12)" },
    pending:   { label: "Chờ TT",     color: "var(--accent-amber)", bg: "rgba(245,158,11,0.12)" },
    cancelled: { label: "Đã hủy",     color: "var(--text-muted)", bg: "rgba(107,114,128,0.12)" },
  };
  const s = map[status] || { label: status, color: "var(--text-muted)", bg: "rgba(107,114,128,0.12)" };
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", padding: "4px 10px", borderRadius: "12px",
      fontSize: "11px", fontWeight: "600", color: s.color, background: s.bg, letterSpacing: "0.2px"
    }}>
      {status === 'completed' && <span style={{ width: 6, height: 6, borderRadius: '50%', background: s.color, marginRight: 6 }}></span>}
      {status === 'pending' && <span style={{ width: 6, height: 6, borderRadius: '50%', background: s.color, marginRight: 6, animation: "pulse 1.5s infinite" }}></span>}
      {s.label}
    </span>
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
  const [ocrHistory, setOcrHistory] = useState([]);
  const [llmHistory, setLlmHistory] = useState([]);
  const [benchmarkResults, setBenchmarkResults] = useState(null);
  const [runningBenchmark, setRunningBenchmark] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [monetStats, setMonetStats] = useState(null);
  const [monetHistory, setMonetHistory] = useState([]);
  const [monetOrders, setMonetOrders] = useState([]);
  const [monetToggling, setMonetToggling] = useState({});
  const [weights, setWeights] = useState({
    ocrWeight: 0.75,
    nluThreshold: 0.85,
    dateFallback: "transaction",
  });
  const [saving, setSaving] = useState(false);
  const [showToast, setShowToast] = useState(false);

  useEffect(() => {
    Promise.all([
      getAdminAnalytics().catch(()=>null),
      getRetrainReadiness().catch(()=>null),
      getNluTrainHistory().catch(()=>[]),
      getOcrTrainHistory().catch(()=>[]),
      getLlmTrainHistory().catch(()=>[]),
      getNluBenchmarkResults().catch(()=>null),
      getSystemSettings().catch(()=>null),
      getMonetizationStats().catch(()=>null),
      getMonetizationHistory(30).catch(()=>[]),
      getMonetizationOrders(100).catch(()=>[])
    ])
      .then(([analyticsData, readinessData, trainHistoryData, ocrHistoryData, llmHistoryData, benchmarkData, settingsData, mStats, mHistory, mOrders]) => {
        setMonetStats(mStats?.data || mStats);
        const historyData = mHistory?.data || mHistory;
        const ordersData = mOrders?.data || mOrders;
        setMonetHistory(Array.isArray(historyData) ? historyData : []);
        setMonetOrders(Array.isArray(ordersData) ? ordersData : []);
                setAnalytics(analyticsData);
        setReadiness(readinessData);
        setTrainHistory(trainHistoryData || []);
        setOcrHistory(ocrHistoryData || []);
        setLlmHistory(llmHistoryData || []);
        setBenchmarkResults(benchmarkData);
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

  const handleRunBenchmark = () => {
    setRunningBenchmark(true);
    triggerNluBenchmark()
      .then(() => {
        alert("Đã kích hoạt đánh giá Benchmark NLU trên GPU Modal. Kết quả sẽ tự động cập nhật sau ít phút.");
        const timer = setInterval(() => {
          getNluBenchmarkResults()
            .then(data => {
              if (data && Object.keys(data).length > 0) {
                setBenchmarkResults(data);
                setRunningBenchmark(false);
                clearInterval(timer);
              }
            })
            .catch(() => {});
        }, 15000);
      })
      .catch((err) => {
        alert("Lỗi chạy benchmark: " + err.message);
        setRunningBenchmark(false);
      });
  };

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

      <div className="dashboard-grid" style={{ marginBottom: "30px", display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "24px" }}>
        {[
          { label: "Tổng doanh thu", value: formatVND(monetStats?.totalRevenue), color: "var(--accent-emerald)" },
          { label: "Doanh thu tháng này", value: formatVND(monetStats?.monthlyRevenue), color: "var(--accent-blue)" },
          { label: "Tổng số đơn", value: monetStats?.totalOrders || "—", color: "var(--accent-purple)" },
          { label: "Người dùng Premium", value: monetStats?.premiumUserCount || "0", color: "var(--accent-amber)" },
        ].map((s, idx) => (
          <div key={idx} className="dashboard-card" style={{ padding: "24px" }}>
            <div style={{ fontSize: "14px", color: "var(--text-secondary)", marginBottom: "12px", display: "flex", alignItems: "center", gap: "8px" }}>
              <div style={{ width: 8, height: 8, borderRadius: "50%", background: s.color }} /> {s.label}
            </div>
            <div style={{ fontSize: "32px", fontWeight: "800", fontFamily: "var(--font-mono)", color: "var(--text-primary)" }}>{s.value}</div>
          </div>
        ))}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "2fr 1fr", gap: "24px", marginBottom: "30px" }}>
        <div className="dashboard-card" style={{ padding: "24px" }}>
          <h3 style={{ fontSize: "16px", marginBottom: "20px", color: "var(--text-primary)" }}>Biểu đồ Doanh thu (30 ngày)</h3>
          <RevenueChart data={monetHistory} />
        </div>

        <div className="dashboard-card" style={{ padding: "0", overflow: "hidden", display: "flex", flexDirection: "column" }}>
          <div style={{ padding: "24px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center", background: "rgba(255, 255, 255, 0.01)" }}>
            <h3 style={{ fontSize: "16px", margin: 0, color: "var(--text-primary)", display: "flex", alignItems: "center", gap: "8px", fontWeight: "600" }}>
              Giao dịch gần nhất
              <span style={{ display: "inline-block", width: "6px", height: "6px", borderRadius: "50%", background: "var(--accent-emerald)", animation: "pulse 2s infinite" }}></span>
            </h3>
          </div>
          <div style={{ overflowY: "auto", maxHeight: "400px", padding: "8px 0" }}>
            <div style={{ display: "flex", flexDirection: "column" }}>
              {(Array.isArray(monetOrders) ? monetOrders : []).slice(0, 10).map((order, index) => {
                const isCompleted = order.status === 'completed';
                const isPending = order.status === 'pending';
                const isCancelled = order.status === 'cancelled';
                const name = order.username || order.email || "Ẩn danh";
                const initial = name.charAt(0).toUpperCase();
                
                return (
                  <div key={order.id || ("order-" + index)} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "16px 24px", borderBottom: "1px solid rgba(255, 255, 255, 0.03)", transition: "all 0.2s ease", cursor: "default" }} onMouseEnter={(e) => e.currentTarget.style.background = "rgba(255, 255, 255, 0.02)"} onMouseLeave={(e) => e.currentTarget.style.background = "transparent"}>
                    <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
                      <div style={{
                        width: "40px", height: "40px", borderRadius: "50%",
                        background: isCompleted ? "linear-gradient(135deg, rgba(16,185,129,0.2) 0%, rgba(16,185,129,0.05) 100%)" : isPending ? "linear-gradient(135deg, rgba(245,158,11,0.2) 0%, rgba(245,158,11,0.05) 100%)" : "rgba(107,114,128,0.1)",
                        border: `1px solid ${isCompleted ? "rgba(16,185,129,0.3)" : isPending ? "rgba(245,158,11,0.3)" : "rgba(107,114,128,0.2)"}`,
                        display: "flex", alignItems: "center", justifyContent: "center",
                        color: isCompleted ? "var(--accent-emerald)" : isPending ? "var(--accent-amber)" : "var(--text-muted)",
                        fontSize: "16px", fontWeight: "700", fontFamily: "var(--font-sans)"
                      }}>
                        {initial}
                      </div>
                      <div>
                        <div style={{ fontWeight: "600", color: isCancelled ? "var(--text-muted)" : "var(--text-primary)", fontSize: "14px", marginBottom: "4px" }}>
                          {name}
                        </div>
                        <div style={{ fontSize: "12px", color: "var(--text-secondary)", display: "flex", alignItems: "center", gap: "6px" }}>
                          {order.createdAt ? new Date(order.createdAt).toLocaleString("vi-VN", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "2-digit" }) : "Vừa xong"}
                          {order.code && (
                            <>
                              <span style={{ width: "3px", height: "3px", borderRadius: "50%", background: "var(--text-muted)", display: "inline-block" }}></span>
                              <span style={{ fontFamily: "var(--font-mono)", fontSize: "11px", color: "var(--text-muted)" }}>#{order.code}</span>
                            </>
                          )}
                        </div>
                      </div>
                    </div>
                    <div style={{ textAlign: "right" }}>
                      <div style={{ 
                        fontWeight: "700", 
                        color: isCompleted ? "var(--text-primary)" : "var(--text-secondary)", 
                        fontFamily: "var(--font-mono)", 
                        fontSize: "15px", 
                        marginBottom: "6px",
                        textDecoration: isCancelled ? "line-through" : "none",
                        opacity: isCancelled ? 0.6 : 1
                      }}>
                        {isCompleted ? "+" : ""}{formatVND(order.amount)}
                      </div>
                      <OrderStatusBadge status={order.status} />
                    </div>
                  </div>
                );
              })}
            </div>
            {(!monetOrders || monetOrders.length === 0) && (
              <div style={{ padding: "60px 20px", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
                <div style={{ width: "48px", height: "48px", borderRadius: "50%", background: "var(--bg-obsidian-800)", display: "flex", alignItems: "center", justifyContent: "center", marginBottom: "16px", color: "var(--text-muted)" }}>
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>
                </div>
                <div style={{ color: "var(--text-secondary)", fontSize: "14px", fontWeight: "500" }}>Chưa có giao dịch nào</div>
                <div style={{ color: "var(--text-muted)", fontSize: "12px", marginTop: "4px" }}>Giao dịch mới sẽ hiển thị tại đây</div>
              </div>
            )}
          </div>
        </div>
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
            Ngưỡng kích hoạt: NLU ≥ 10,000 giao dịch trong CSDL · OCR ≥ 1,000 ảnh hóa đơn đã quét.
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
              actionLabel="Đến trang quản lý NLU"
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
              actionLabel="Đến trang quản lý OCR"
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
          <span className="metric-value" style={{ display: "block", fontSize: "32px", fontWeight: "700", color: "var(--text-primary)" }}>{analytics.totalExpenses ? analytics.totalExpenses.toLocaleString() : "0"}</span>
          <span className="metric-desc" style={{ display: "block", fontSize: "12px", color: "var(--text-muted)", marginTop: "4px" }}>Giao dịch xử lý qua giọng nói/ảnh hóa đơn</span>
        </div>
        <div className="metric-card" style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px", position: "relative" }}>
          <span className="metric-indicator indicator-amber" style={{ position: "absolute", top: "24px", left: "24px", width: "8px", height: "8px", borderRadius: "50%", background: "var(--accent-amber)", boxShadow: "0 0 10px var(--accent-amber)" }}></span>
          <span className="metric-label" style={{ display: "block", fontSize: "13px", color: "var(--text-secondary)", marginBottom: "8px", paddingLeft: "16px" }}>Tổng số người dùng</span>
          <span className="metric-value" style={{ display: "block", fontSize: "32px", fontWeight: "700", color: "var(--text-primary)" }}>{analytics.totalUsers ? analytics.totalUsers.toLocaleString() : "0"}</span>
          <span className="metric-desc" style={{ display: "block", fontSize: "12px", color: "var(--text-muted)", marginTop: "4px" }}>Số lượng người dùng đã đăng ký</span>
        </div>
      </div>

      {/* NLU Benchmark Panel */}
      <div className="panel" style={{
        background: "var(--bg-obsidian-900)",
        border: "1px solid var(--border-color)",
        borderRadius: "16px",
        padding: "24px",
        marginBottom: "30px"
      }}>
        <div className="panel-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px" }}>
          <div>
            <h2 className="panel-title" style={{ fontSize: "18px", fontWeight: "600", color: "var(--text-primary)" }}>So sánh hiệu năng NLU (benchmark)</h2>
            <p className="form-desc" style={{ fontSize: "13px", color: "var(--text-secondary)", marginTop: "4px" }}>
              So sánh chéo hiệu năng của 3 kiến trúc mô hình NLU phục vụ chương thực nghiệm của luận văn.
            </p>
          </div>
          <button
            onClick={handleRunBenchmark}
            disabled={runningBenchmark}
            className="btn btn-sm"
            style={{
              background: "rgba(16, 185, 129, 0.12)",
              color: "var(--accent-emerald)",
              border: "1px solid rgba(16, 185, 129, 0.25)",
              padding: "6px 14px",
              borderRadius: "8px",
              fontWeight: "600",
              cursor: "pointer",
              fontSize: "12px"
            }}
          >
            {runningBenchmark ? "Đang chạy đánh giá..." : "Chạy đánh giá benchmark"}
          </button>
        </div>
        <NluBenchmarkChart data={benchmarkResults} />
      </div>

      {/* Qwen Fine-tuning History Panel */}
      {llmHistory && llmHistory.length > 0 && (
        <div className="panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px",
          marginBottom: "30px"
        }}>
          <div className="panel-header" style={{ marginBottom: "20px" }}>
            <h2 className="panel-title" style={{ fontSize: "18px", fontWeight: "600", color: "var(--text-primary)" }}>Độ hội tụ huấn luyện fine-tune LLM</h2>
            <p className="form-desc" style={{ fontSize: "13px", color: "var(--text-secondary)", marginTop: "4px" }}>
              Biểu đồ độ dốc loss qua các step huấn luyện LoRA trên Nvidia H100 GPU.
            </p>
          </div>
          <LlmLossChart runData={llmHistory[0]} />
        </div>
      )}

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
              <h2 className="panel-title" style={{ fontSize: "18px", fontWeight: "600", color: "var(--text-primary)" }}>Chi tiết đo lường hiệu năng (telemetry runs)</h2>
              <p className="form-desc" style={{ fontSize: "13px", color: "var(--text-secondary)", marginTop: "4px" }}>
                Chi tiết các metric đánh giá chất lượng qua các lần chạy huấn luyện.
              </p>
            </div>
            <span className="badge badge-success" style={{ padding: "4px 10px", fontSize: "12px", background: "rgba(16, 185, 129, 0.12)", color: "var(--accent-emerald)", borderRadius: "12px", fontWeight: "600" }}>Mục tiêu: &gt;90%</span>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "20px" }}>
            <ModelSubChart title="Độ chính xác OCR / KIE" modelKey="ocr" historyData={ocrHistory} />
            <ModelSubChart title="Độ chính xác ý định (tầng 1)" modelKey="intent" historyData={trainHistory} />
            <ModelSubChart title="Độ chính xác danh mục (tầng 2)" modelKey="category" historyData={trainHistory} />
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
          <span style={{ color: "var(--text-primary)", fontSize: "13px", fontWeight: "500" }}>Cấu hình trọng số đã được đồng bộ lên PostgreSQL!</span>
        </div>
      )}
    </div>
  );
}

export default DashboardPage;
