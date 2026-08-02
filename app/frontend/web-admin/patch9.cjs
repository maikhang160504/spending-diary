const fs = require('fs');
const { execSync } = require('child_process');

try {
  execSync('git checkout -- src/pages/DashboardPage.jsx');
} catch (e) {
  console.log("Git checkout failed", e);
}

const monetContent = fs.readFileSync('src/pages/MonetizationPage.jsx', 'utf-8');
let dashboardContent = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf-8');

// 1. Extract format helpers
let formatters = monetContent.substring(
  monetContent.indexOf('function formatVND'),
  monetContent.indexOf('async function fetchAPI')
).trim();

// 2. Extract components
let components = monetContent.substring(
  monetContent.indexOf('function RevenueChart({ data }) {'),
  monetContent.indexOf('export default function MonetizationPage() {')
).replace(/\/\/ ─── .*$/gm, '').trim();

components = components.replace(/  const \[hovered, setHovered\] = useState\(null\);\r?\n\r?\n  return \(/, '  return (');
components = components.replace(/function RevenueChart\(\{ data \}\) \{\r?\n  if \(\!data \|\| data\.length === 0\) \{/, 'function RevenueChart({ data }) {\n  const [hovered, setHovered] = useState(null);\n\n  if (!data || data.length === 0) {');

// 3. Fix imports
let newDash = dashboardContent;
newDash = newDash.replace(
  /  getOcrTrainHistory\r?\n\} from "\.\.\/services\/api";/,
  '  getOcrTrainHistory,\n  getMonetizationStats,\n  getMonetizationHistory,\n  getMonetizationOrders,\n  toggleUserPremium\n} from "../services/api";'
);

// Inject helpers and components
newDash = newDash.replace(
  'function DashboardPage() {',
  `${formatters}\n\n${components}\n\nfunction DashboardPage() {`
);

// Inject states
newDash = newDash.replace(
  '  const [weights, setWeights] = useState({',
  '  const [monetStats, setMonetStats] = useState(null);\n' +
  '  const [monetHistory, setMonetHistory] = useState([]);\n' +
  '  const [monetOrders, setMonetOrders] = useState([]);\n' +
  '  const [monetToggling, setMonetToggling] = useState({});\n' +
  '  const [weights, setWeights] = useState({'
);

// Inject toggle premium handler
const toggleHandler = `  const handleTogglePremium = async (userId, currentPremium) => {
    setMonetToggling((p) => ({ ...p, [userId]: true }));
    try {
      await toggleUserPremium(userId, !currentPremium);
      // Refresh orders
      const o = await getMonetizationOrders(100);
      setMonetOrders(Array.isArray(o) ? o : []);
    } catch (err) {
      alert("Lỗi đổi Premium: " + err.message);
    } finally {
      setMonetToggling((p) => ({ ...p, [userId]: false }));
    }
  };`;

// Inject API calls
const pStart = newDash.indexOf('    Promise.all([');
const pEnd = newDash.indexOf('        setAnalytics(analyticsData);');
if (pStart !== -1 && pEnd !== -1) {
  const newPromiseStr = `    Promise.all([
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
        setMonetStats(mStats);
        setMonetHistory(Array.isArray(mHistory) ? mHistory : []);
        setMonetOrders(Array.isArray(mOrders) ? mOrders : []);
        `;
  newDash = newDash.substring(0, pStart) + newPromiseStr + newDash.substring(pEnd);
}

// Inject toggle handler after useEffect
newDash = newDash.replace(
  '  const handleSaveWeights = () => {',
  `${toggleHandler}\n\n  const handleSaveWeights = () => {`
);

// Now, insert the Monetization stats and charts directly into the layout without tabs
// Let's add them right after the <div className="page-header">...</div>
const rStart = newDash.indexOf('      </div>\r\n\r\n      {error && (');
if (rStart !== -1) {
  const businessJSX = `      </div>

      <div className="dashboard-grid" style={{ marginBottom: "30px", display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "24px" }}>
        {[
          { label: "Tổng doanh thu", value: formatVND(monetStats?.totalRevenue), color: "var(--accent-emerald)" },
          { label: "Doanh thu tháng này", value: formatVND(monetStats?.monthlyRevenue), color: "var(--accent-blue)" },
          { label: "Tổng số đơn", value: monetStats?.totalOrders || "—", color: "var(--accent-purple)" },
          { label: "Tỷ lệ chuyển đổi", value: monetStats?.conversionRate ? monetStats.conversionRate.toFixed(2) + "%" : "—", color: "var(--accent-amber)" },
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

        <div className="dashboard-card" style={{ padding: "0", overflow: "hidden" }}>
          <div style={{ padding: "24px", borderBottom: "1px solid var(--border-color)" }}>
            <h3 style={{ fontSize: "16px", margin: 0 }}>Giao dịch gần nhất</h3>
          </div>
          <div style={{ overflowY: "auto", maxHeight: "400px" }}>
            <table style={{ width: "100%", borderCollapse: "collapse", textAlign: "left" }}>
              <thead>
                <tr style={{ borderBottom: "1px solid var(--border-color)", background: "var(--bg-obsidian-950)" }}>
                  <th style={{ padding: "16px 24px", fontSize: "12px", textTransform: "uppercase", color: "var(--text-muted)" }}>Giao dịch</th>
                  <th style={{ padding: "16px 24px", fontSize: "12px", textTransform: "uppercase", color: "var(--text-muted)" }}>Trạng thái</th>
                </tr>
              </thead>
              <tbody>
                {(Array.isArray(monetOrders) ? monetOrders : []).slice(0, 10).map((order) => (
                  <tr key={order._id} style={{ borderBottom: "1px solid var(--border-color)" }}>
                    <td style={{ padding: "16px 24px" }}>
                      <div style={{ fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)", marginBottom: 4 }}>
                        {formatVND(order.amount)}
                      </div>
                      <div style={{ fontSize: "12px", color: "var(--text-secondary)" }}>
                        {order.user?.fullName || "Ẩn danh"}
                      </div>
                    </td>
                    <td style={{ padding: "16px 24px" }}><OrderStatusBadge status={order.status} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
            {(!monetOrders || monetOrders.length === 0) && <div style={{ padding: "40px", textAlign: "center", color: "var(--text-muted)" }}>Chưa có giao dịch</div>}
          </div>
        </div>
      </div>\n\n      {error && (`;
  
  newDash = newDash.substring(0, rStart) + businessJSX + newDash.substring(rStart + 23);
}

fs.writeFileSync('src/pages/DashboardPage.jsx', newDash);
console.log('Build v5 without tabs completed');
