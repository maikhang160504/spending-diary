const fs = require('fs');

let content = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf-8');

// 1. Add formatDate
content = content.replace(
  'function formatVND(amount) {\n  return new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND" }).format(amount || 0);\n}',
  'function formatVND(amount) {\n  return new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND" }).format(amount || 0);\n}\n\nfunction formatDate(value) {\n  if (!value) return "—";\n  return new Date(value).toLocaleString("vi-VN", {\n    day: "2-digit", month: "2-digit", year: "numeric",\n    hour: "2-digit", minute: "2-digit",\n  });\n}'
);

// 2. Add States
content = content.replace(
  'function DashboardPage() {\n  const [analytics, setAnalytics] = useState({',
  'function DashboardPage() {\n  const [activeTab, setActiveTab] = useState("business");\n  const [monetStats, setMonetStats] = useState(null);\n  const [monetHistory, setMonetHistory] = useState([]);\n  const [monetOrders, setMonetOrders] = useState([]);\n  const [monetToggling, setMonetToggling] = useState({});\n\n  const [analytics, setAnalytics] = useState({'
);

// 3. Update useEffect
content = content.replace(
  '      getNluBenchmarkResults().catch(() => null),\n      getSystemSettings().catch(() => null)\n    ])\n      .then(([analyticsData, readinessData, trainHistoryData, ocrHistoryData, llmHistoryData, benchmarkData, settingsData]) => {\n        setAnalytics(analyticsData);',
  '      getNluBenchmarkResults().catch(() => null),\n      getSystemSettings().catch(() => null),\n      getMonetizationStats().catch(() => null),\n      getMonetizationHistory(30).catch(() => []),\n      getMonetizationOrders(100).catch(() => [])\n    ])\n      .then(([analyticsData, readinessData, trainHistoryData, ocrHistoryData, llmHistoryData, benchmarkData, settingsData, mStats, mHistory, mOrders]) => {\n        setMonetStats(mStats);\n        setMonetHistory(mHistory || []);\n        setMonetOrders(mOrders || []);\n        setAnalytics(analyticsData);'
);

// 4. Add handleTogglePremium
content = content.replace(
  '  const handleSave = (e) => {',
  '  const handleTogglePremium = async (userId, currentPremium) => {\n    setMonetToggling((p) => ({ ...p, [userId]: true }));\n    try {\n      await toggleUserPremium(userId, !currentPremium);\n      setMonetOrders((prev) =>\n        prev.map((o) => (o.userId === userId ? { ...o, isPremium: !currentPremium } : o))\n      );\n      const newStats = await getMonetizationStats();\n      setMonetStats(newStats);\n    } catch (err) {\n      alert("Lỗi: " + err.message);\n    } finally {\n      setMonetToggling((p) => ({ ...p, [userId]: false }));\n    }\n  };\n\n  const handleSave = (e) => {'
);

// 5. Replace Header and Tabs
const oldHeader = `    <div className="page-container" style={{ padding: "30px 40px" }}>
      <div className="page-header" style={{ marginBottom: "30px" }}>
        <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px" }}>Fusion & AI Quality</h1>
        <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "4px" }}>
          Bảng giám sát chi tiết độ chính xác của các mô hình và cấu hình tham số AI Fusion.
        </p>
      </div>`;

const newHeader = `    <div className="page-container" style={{ padding: "30px 40px" }}>
      <div className="page-header" style={{ marginBottom: "30px", display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
        <div>
          <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px" }}>
            {activeTab === "business" ? "Kinh doanh & Doanh thu" : "Trí tuệ Nhân tạo (AI Core)"}
          </h1>
          <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "4px" }}>
            {activeTab === "business" 
              ? "Giám sát chỉ số tài chính, lợi nhuận, biến động dòng tiền và giao dịch."
              : "Bảng giám sát chi tiết độ chính xác của các mô hình và cấu hình tham số AI Fusion."}
          </p>
        </div>
        
        <div className="pro-max-pill-tabs" style={{ background: "var(--bg-obsidian-900)", padding: "4px", borderRadius: "12px", border: "1px solid var(--border-color)", display: "flex", gap: "4px" }}>
          <button
            type="button"
            className={\`pro-max-pill-tab \${activeTab === "business" ? "active" : ""}\`}
            onClick={() => setActiveTab("business")}
            style={{ padding: "8px 16px" }}
          >
            Kinh doanh
          </button>
          <button
            type="button"
            className={\`pro-max-pill-tab \${activeTab === "ai_core" ? "active" : ""}\`}
            onClick={() => setActiveTab("ai_core")}
            style={{ padding: "8px 16px" }}
          >
            AI Core
          </button>
        </div>
      </div>`;

content = content.replace(oldHeader, newHeader);

// 6. Split at {readiness && (
const splitPoint = '{readiness && (';
const parts = content.split(splitPoint);
const part1 = parts[0];
const part2 = splitPoint + parts[1];

// 7. Find {showToast && (
const toastPoint = '      {showToast && (';
const p2Parts = part2.split(toastPoint);
const aiCoreContent = p2Parts[0];
const footer = toastPoint + p2Parts[1];

const businessContent = `
      {activeTab === "business" && (
        <div style={{ display: "flex", flexDirection: "column", gap: "30px", marginBottom: "30px" }}>
          <div className="metrics-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))", gap: "20px" }}>
            {[
              { label: "Tổng doanh thu", value: formatVND(monetStats?.totalRevenue), color: "var(--accent-emerald)" },
              { label: "Doanh thu tháng này", value: formatVND(monetStats?.monthlyRevenue), color: "var(--accent-blue)" },
              { label: "Số đơn hoàn thành", value: monetStats?.totalOrders ?? "—", color: "var(--accent-amber)" },
              { label: "User Premium", value: monetStats?.premiumUserCount ?? "—", color: "#a855f7" },
            ].map((card, idx) => (
              <div key={card.label} className="metric-card" style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px", position: "relative" }}>
                <span className="metric-indicator" style={{ position: "absolute", top: "24px", left: "24px", width: "8px", height: "8px", borderRadius: "50%", background: card.color, boxShadow: \`0 0 10px \${card.color}\` }}></span>
                <span className="metric-label" style={{ display: "block", fontSize: "13px", color: "var(--text-secondary)", marginBottom: "8px", paddingLeft: "16px" }}>{card.label}</span>
                <span className="metric-value" style={{ display: "block", fontSize: "28px", fontWeight: "700", color: "var(--text-primary)" }}>
                  {(!monetStats && loading) ? "..." : card.value}
                </span>
              </div>
            ))}
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr", gap: "30px" }}>
            <div className="panel pro-max-chart-panel" style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px" }}>
              <div className="panel-header" style={{ marginBottom: "20px" }}>
                <h2 className="panel-title" style={{ fontSize: "18px", fontWeight: "600", color: "var(--text-primary)" }}>Biến động Doanh thu</h2>
                <p className="form-desc" style={{ fontSize: "13px", color: "var(--text-secondary)", marginTop: "4px" }}>Theo dõi hiệu suất dòng tiền vào từ các giao dịch Premium trong 30 ngày qua.</p>
              </div>
              <div style={{ height: "220px", marginTop: "16px" }}>
                <RevenueChart data={monetHistory} />
              </div>
            </div>

            <div className="panel" style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", overflow: "hidden" }}>
              <div className="panel-header" style={{ padding: "24px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <h2 className="panel-title" style={{ fontSize: "18px", fontWeight: "600", color: "var(--text-primary)" }}>Lịch sử Giao dịch</h2>
                  <p className="form-desc" style={{ fontSize: "13px", color: "var(--text-secondary)", marginTop: "4px" }}>100 giao dịch SePay gần nhất ({monetOrders.length} bản ghi).</p>
                </div>
              </div>

              <div style={{ overflowX: "auto" }}>
                <table style={{ width: "100%", borderCollapse: "collapse", fontSize: "13px" }}>
                  <thead style={{ background: "rgba(0,0,0,0.2)" }}>
                    <tr>
                      {["Thời gian", "Mã đơn", "Khách hàng", "Số tiền", "Nội dung CK", "Trạng thái", "Action"].map((h) => (
                        <th key={h} style={{ padding: "14px 24px", textAlign: "left", fontSize: "11px", fontWeight: "600", color: "var(--text-muted)", textTransform: "uppercase", letterSpacing: "0.5px" }}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {monetOrders.length === 0 && !loading && (
                      <tr><td colSpan={7} style={{ padding: "40px 24px", textAlign: "center", color: "var(--text-muted)", fontSize: "13px" }}>Chưa có giao dịch nào</td></tr>
                    )}
                    {monetOrders.map((order) => (
                      <tr key={order.id} style={{ borderBottom: "1px solid var(--border-color)", transition: "background 0.15s" }} onMouseEnter={(e) => e.currentTarget.style.background = "rgba(255,255,255,0.02)"} onMouseLeave={(e) => e.currentTarget.style.background = "transparent"}>
                        <td style={{ padding: "16px 24px", color: "var(--text-secondary)", whiteSpace: "nowrap", fontFamily: "var(--font-mono)", fontSize: "12px" }}>{formatDate(order.createdAt)}</td>
                        <td style={{ padding: "16px 24px" }}><span style={{ fontFamily: "var(--font-mono)", fontSize: "12px", color: "var(--text-primary)", fontWeight: "500" }}>{order.code}</span></td>
                        <td style={{ padding: "16px 24px" }}>
                          <div style={{ fontWeight: "600", color: "var(--text-primary)", fontSize: "13px" }}>{order.username}</div>
                          <div style={{ color: "var(--text-muted)", fontSize: "12px", marginTop: "2px" }}>{order.email}</div>
                        </td>
                        <td style={{ padding: "16px 24px", fontWeight: "700", color: "var(--text-primary)", whiteSpace: "nowrap", fontFamily: "var(--font-mono)" }}>{formatVND(order.amount)}</td>
                        <td style={{ padding: "16px 24px", color: "var(--text-secondary)", fontSize: "12px", maxWidth: "220px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{order.transferContent || "—"}</td>
                        <td style={{ padding: "16px 24px" }}><OrderStatusBadge status={order.status} /></td>
                        <td style={{ padding: "16px 24px" }}>
                          <button
                            type="button"
                            disabled={monetToggling[order.userId]}
                            onClick={() => handleTogglePremium(order.userId, order.isPremium)}
                            style={{
                              padding: "6px 12px", borderRadius: "6px", fontSize: "12px", fontWeight: "600", cursor: "pointer",
                              border: "1px solid", borderColor: order.isPremium ? "rgba(168, 85, 247, 0.3)" : "var(--border-color)",
                              background:  order.isPremium ? "rgba(168, 85, 247, 0.1)" : "transparent",
                              color:       order.isPremium ? "#a855f7" : "var(--text-primary)", transition:  "all 0.2s ease", whiteSpace:  "nowrap",
                            }}
                          >
                            {monetToggling[order.userId] ? "..." : order.isPremium ? "Hạ quyền" : "Cấp Premium"}
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      )}
`;

const aiCoreStart = `      {activeTab === "ai_core" && (\n        <div style={{ display: "flex", flexDirection: "column" }}>\n`;
const aiCoreEnd = `        </div>\n      )}\n\n`;

const finalContent = part1 + businessContent + aiCoreStart + aiCoreContent + aiCoreEnd + footer;

fs.writeFileSync('src/pages/DashboardPage.jsx', finalContent);
console.log('Script completed successfully');
