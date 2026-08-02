const fs = require('fs');

const dash = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf8');
const mon = fs.readFileSync('src/pages/MonetizationPage.jsx', 'utf8');

// 1. Extract Monetization components
const formatVNDMatch = mon.match(/function formatVND\([\s\S]*?\n\}/);
const formatVND = formatVNDMatch ? formatVNDMatch[0] : '';

const revChartMatch = mon.match(/function RevenueChart\(\{[\s\S]*?\n\}/);
const revChart = revChartMatch ? revChartMatch[0] : '';

const orderBadgeMatch = mon.match(/function OrderStatusBadge\(\{[\s\S]*?\n\}/);
const orderBadge = orderBadgeMatch ? orderBadgeMatch[0] : '';

if (!formatVND) console.error("MISSING formatVND!");
if (!revChart) console.error("MISSING revChart!");
if (!orderBadge) console.error("MISSING orderBadge!");

// 2. Dashboard components are already in the file. We just need to modify the main component: DashboardPage
let main = dash.match(/function DashboardPage\(\) \{[\s\S]*/)[0];

// Extract state and data fetching from Monetization
const stateMatch = mon.match(/const \[monetization, setMonetization\] = useState[\s\S]*?const \[premiumLoading, setPremiumLoading\] = useState\(false\);/);
const monStates = stateMatch ? stateMatch[0] : `  const [monetization, setMonetization] = useState({ total_premium_revenue: 0, active_subscribers: 0, growth_rate: 0, today_revenue: 0 });
  const [revHistory, setRevHistory] = useState([]);
  const [orders, setOrders] = useState([]);
  const [premiumLoading, setPremiumLoading] = useState(false);`;

const fetchMonMatch = mon.match(/const fetchMonetizationData = async \(\) => \{[\s\S]*?  \};\n/);
const fetchMon = fetchMonMatch ? fetchMonMatch[0] : `  const fetchMonetizationData = async () => {
    try {
      setPremiumLoading(true);
      const [statsRes, historyRes, ordersRes] = await Promise.all([
        getMonetizationStats(),
        getMonetizationHistory(30),
        getMonetizationOrders(1, 10)
      ]);
      if (statsRes.success) setMonetization(statsRes.data);
      if (historyRes.success) setRevHistory(historyRes.data);
      if (ordersRes.success) setOrders(ordersRes.data.orders);
    } catch (err) {
      console.error("Failed to load monetization data:", err);
    } finally {
      setPremiumLoading(false);
    }
  };
`;

// Inject states into main
main = main.replace('const [error, setError] = useState(null);', 'const [error, setError] = useState(null);\n  ' + monStates);

// Inject fetchMonetizationData
main = main.replace('const fetchData = async () => {', fetchMon + '\n\n  const fetchData = async () => {');

// Add fetchMonetizationData() call inside fetchData
main = main.replace('const [analytics, readiness, trainHis, settings, benchmarkRes, llmHis, ocrHis] = await Promise.all([', 'fetchMonetizationData();\n      const [analytics, readiness, trainHis, settings, benchmarkRes, llmHis, ocrHis] = await Promise.all([');

// Extract the Business section JSX from Monetization
const businessJsxMatch = mon.match(/(<div className=\"dashboard-header\">[\s\S]*?)<\/div>\n\n  \);\n\}/);
let businessJsx = businessJsxMatch ? businessJsxMatch[1] : '';

// The businessJsx starts with dashboard-header. Let's just keep the cards and charts.
businessJsx = businessJsx.replace(/<div className=\"dashboard-header\">[\s\S]*?<\/div>/, '');

// The old dashboard JSX is inside the return statement of main.
const dashboardHeaderMatch = main.match(/(<div className=\"dashboard-header\">[\s\S]*?<\/div>)/);
const dashboardHeader = dashboardHeaderMatch ? dashboardHeaderMatch[1] : '';

// Get the rest of the old dashboard JSX
const restJsxMatch = main.match(/<div className=\"dashboard-header\">[\s\S]*?<\/div>([\s\S]*?)<\/div>\n  \);\n\}/);
const restJsx = restJsxMatch ? restJsxMatch[1] : '';

// Build the new return statement
const newReturn = `  return (
    <div className="dashboard-container">
      ${dashboardHeader}
      
      <div className="dashboard-content" style={{ display: 'flex', flexDirection: 'column', gap: '30px' }}>
        
        {/* === KINH DOANH & DOANH THU === */}
        <section className="dashboard-section business-section">
          <div className="section-header" style={{ marginBottom: '16px', paddingBottom: '8px', borderBottom: '1px solid var(--border-color)' }}>
            <h2 style={{ fontSize: '20px', color: 'var(--text-primary)', margin: 0, display: 'flex', alignItems: 'center', gap: '10px' }}>
              Kinh doanh & Doanh thu
            </h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '14px', marginTop: '4px', margin: 0 }}>
              Theo dõi doanh thu, tăng trưởng người dùng và trạng thái thanh toán gói Premium.
            </p>
          </div>
          
          ${businessJsx}
        </section>

        {/* === TRÍ TUỆ NHÂN TẠO === */}
        <section className="dashboard-section ai-section">
          <div className="section-header" style={{ marginBottom: '16px', paddingBottom: '8px', borderBottom: '1px solid var(--border-color)' }}>
            <h2 style={{ fontSize: '20px', color: 'var(--text-primary)', margin: 0, display: 'flex', alignItems: 'center', gap: '10px' }}>
              Trí tuệ Nhân tạo (AI Core)
            </h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '14px', marginTop: '4px', margin: 0 }}>
              Giám sát chất lượng mô hình, tiến trình thu thập mẫu và cấu hình thuật toán Fusion.
            </p>
          </div>
          
          ${restJsx}
        </section>

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
}`;

// Replace the return block in main
main = main.replace(/return \([\s\S]*?\);\n\}/, newReturn + '\n}');

// Build the final file string
let topImports = dash.match(/import [\s\S]*?from \"\.\.\/services\/api\";/)[0];
// Ensure Monetization imports are there
if (!topImports.includes('getMonetizationStats')) {
    topImports = topImports.replace('getOcrTrainHistory', 'getOcrTrainHistory,\n  getMonetizationStats,\n  getMonetizationHistory,\n  getMonetizationOrders,\n  toggleUserPremium');
}

const finalCode = topImports + '\n\n' + formatVND + '\n\n' + revChart + '\n\n' + orderBadge + '\n\n' + dash.match(/function ProgressBar[\s\S]*?(?=function DashboardPage)/)[0] + '\n\n' + main;

fs.writeFileSync('src/pages/DashboardPage.jsx', finalCode, 'utf8');
console.log('Merged successfully!');
