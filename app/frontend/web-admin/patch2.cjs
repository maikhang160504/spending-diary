const fs = require('fs');
let code = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf8');

const tabHeader = `      <div className="page-header" style={{ marginBottom: "30px", display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
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
        
        <div className="pro-max-pill-tabs" style={{ background: "var(--bg-obsidian-900)", padding: "4px", borderRadius: "12px", border: "1px solid var(--border-color)" }}>
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
      </div>

      {error && (`;

code = code.replace(
  `      <div className="page-header" style={{ marginBottom: "30px" }}>
        <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px" }}>Fusion & AI Quality</h1>
        <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "4px" }}>
          Bảng giám sát chi tiết độ chính xác của các mô hình và cấu hình tham số AI Fusion.
        </p>
      </div>

      {error && (`,
  tabHeader
);

const splitPoint = `{readiness && (`;

const splitArray = code.split(splitPoint);
const part1 = splitArray[0];
const part2 = splitPoint + splitArray[1];

// We need to wrap part2 inside `{activeTab === "ai_core" && (<> ... </>)}`
// Except the very end where we have:
//       {showToast && (
//         <div className="toast" style={{
// ...
//         </div>
//       )}
//     </div>
//   );
// }

const aiCoreContent = part2.substring(0, part2.indexOf(`      {showToast && (`));
const footer = part2.substring(part2.indexOf(`      {showToast && (`));

const businessTabContent = `
      {activeTab === "business" && (
        <div style={{ display: "flex", flexDirection: "column", gap: "30px" }}>
          {/* ── Stats Cards ── */}
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
            {/* ── Revenue Chart ── */}
            <div className="panel pro-max-chart-panel" style={{
              background: "var(--bg-obsidian-900)",
              border: "1px solid var(--border-color)",
              borderRadius: "16px",
              padding: "24px"
            }}>
              <div className="panel-header" style={{ marginBottom: "20px" }}>
                <h2 className="panel-title" style={{ fontSize: "18px", fontWeight: "600", color: "var(--text-primary)" }}>Biến động Doanh thu</h2>
                <p className="form-desc" style={{ fontSize: "13px", color: "var(--text-secondary)", marginTop: "4px" }}>
                  Theo dõi hiệu suất dòng tiền vào từ các giao dịch Premium trong 30 ngày qua.
                </p>
              </div>
              <div style={{ height: "220px", marginTop: "16px" }}>
                <RevenueChart data={monetHistory} />
              </div>
            </div>

            {/* ── Orders Table ── */}
            <div className="panel" style={{
              background: "var(--bg-obsidian-900)",
              border: "1px solid var(--border-color)",
              borderRadius: "16px",
              overflow: "hidden"
            }}>
              <div className="panel-header" style={{ padding: "24px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <h2 className="panel-title" style={{ fontSize: "18px", fontWeight: "600", color: "var(--text-primary)" }}>Lịch sử Giao dịch</h2>
                  <p className="form-desc" style={{ fontSize: "13px", color: "var(--text-secondary)", marginTop: "4px" }}>
                    100 giao dịch SePay gần nhất ({monetOrders.length} bản ghi).
                  </p>
                </div>
              </div>

              <div style={{ overflowX: "auto" }}>
                <table style={{ width: "100%", borderCollapse: "collapse", fontSize: "13px" }}>
                  <thead style={{ background: "rgba(0,0,0,0.2)" }}>
                    <tr>
                      {["Thời gian", "Mã đơn", "Khách hàng", "Số tiền", "Nội dung CK", "Trạng thái", "Action"].map((h) => (
                        <th key={h} style={{ padding: "14px 24px", textAlign: "left", fontSize: "11px", fontWeight: "600", color: "var(--text-muted)", textTransform: "uppercase", letterSpacing: "0.5px" }}>
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {monetOrders.length === 0 && !loading && (
                      <tr>
                        <td colSpan={7} style={{ padding: "40px 24px", textAlign: "center", color: "var(--text-muted)", fontSize: "13px" }}>
                          Chưa có giao dịch nào
                        </td>
                      </tr>
                    )}
                    {monetOrders.map((order) => (
                      <tr
                        key={order.id}
                        style={{ borderBottom: "1px solid var(--border-color)", transition: "background 0.15s" }}
                        onMouseEnter={(e) => e.currentTarget.style.background = "rgba(255,255,255,0.02)"}
                        onMouseLeave={(e) => e.currentTarget.style.background = "transparent"}
                      >
                        <td style={{ padding: "16px 24px", color: "var(--text-secondary)", whiteSpace: "nowrap", fontFamily: "var(--font-mono)", fontSize: "12px" }}>
                          {formatDate(order.createdAt)}
                        </td>
                        <td style={{ padding: "16px 24px" }}>
                          <span style={{ fontFamily: "var(--font-mono)", fontSize: "12px", color: "var(--text-primary)", fontWeight: "500" }}>
                            {order.code}
                          </span>
                        </td>
                        <td style={{ padding: "16px 24px" }}>
                          <div style={{ fontWeight: "600", color: "var(--text-primary)", fontSize: "13px" }}>{order.username}</div>
                          <div style={{ color: "var(--text-muted)", fontSize: "12px", marginTop: "2px" }}>{order.email}</div>
                        </td>
                        <td style={{ padding: "16px 24px", fontWeight: "700", color: "var(--text-primary)", whiteSpace: "nowrap", fontFamily: "var(--font-mono)" }}>
                          {formatVND(order.amount)}
                        </td>
                        <td style={{ padding: "16px 24px", color: "var(--text-secondary)", fontSize: "12px", maxWidth: "220px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                          {order.transferContent || "—"}
                        </td>
                        <td style={{ padding: "16px 24px" }}>
                          <OrderStatusBadge status={order.status} />
                        </td>
                        <td style={{ padding: "16px 24px" }}>
                          <button
                            type="button"
                            disabled={monetToggling[order.userId]}
                            onClick={() => handleTogglePremium(order.userId, order.isPremium)}
                            style={{
                              padding: "6px 12px", borderRadius: "6px", fontSize: "12px", fontWeight: "600", cursor: "pointer",
                              border: "1px solid",
                              borderColor: order.isPremium ? "rgba(168, 85, 247, 0.3)" : "var(--border-color)",
                              background:  order.isPremium ? "rgba(168, 85, 247, 0.1)" : "transparent",
                              color:       order.isPremium ? "#a855f7" : "var(--text-primary)",
                              transition:  "all 0.2s ease",
                              whiteSpace:  "nowrap",
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

const finalCode = part1 + businessTabContent + `\n      {activeTab === "ai_core" && (\n        <div style={{ display: "flex", flexDirection: "column" }}>\n` + aiCoreContent + `\n        </div>\n      )}\n` + footer;

fs.writeFileSync('src/pages/DashboardPage.jsx', finalCode);
console.log('Patched UI tabs');
