const fs = require('fs');

try {
  let content = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf-8');

  // Fix 1: Conversion Rate -> Premium Users
  content = content.replace(
    '{ label: "Tỷ lệ chuyển đổi", value: monetStats?.conversionRate ? monetStats.conversionRate.toFixed(2) + "%" : "—", color: "var(--accent-amber)" },',
    '{ label: "Người dùng Premium", value: monetStats?.premiumUserCount || "0", color: "var(--accent-amber)" },'
  );

  // Fix 2: Order keys
  content = content.replace(
    '                  <tr key={order._id} style={{ borderBottom: "1px solid var(--border-color)" }}>\r\n                    <td style={{ padding: "16px 24px" }}>\r\n                      <div style={{ fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)", marginBottom: 4 }}>\r\n                        {formatVND(order.amount)}\r\n                      </div>\r\n                      <div style={{ fontSize: "12px", color: "var(--text-secondary)" }}>\r\n                        {order.user?.fullName || "Ẩn danh"}\r\n                      </div>',
    '                  <tr key={order.id || Math.random()} style={{ borderBottom: "1px solid var(--border-color)" }}>\n                    <td style={{ padding: "16px 24px" }}>\n                      <div style={{ fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)", marginBottom: 4 }}>\n                        {formatVND(order.amount)}\n                      </div>\n                      <div style={{ fontSize: "12px", color: "var(--text-secondary)" }}>\n                        {order.username || order.email || "Ẩn danh"}\n                      </div>'
  );
  
  // Try CRLF vs LF matching for Fix 2
  if (content.indexOf('{order.username || order.email || "Ẩn danh"}') === -1) {
    content = content.replace(
      '                  <tr key={order._id} style={{ borderBottom: "1px solid var(--border-color)" }}>\n                    <td style={{ padding: "16px 24px" }}>\n                      <div style={{ fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)", marginBottom: 4 }}>\n                        {formatVND(order.amount)}\n                      </div>\n                      <div style={{ fontSize: "12px", color: "var(--text-secondary)" }}>\n                        {order.user?.fullName || "Ẩn danh"}\n                      </div>',
      '                  <tr key={order.id || Math.random()} style={{ borderBottom: "1px solid var(--border-color)" }}>\n                    <td style={{ padding: "16px 24px" }}>\n                      <div style={{ fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)", marginBottom: 4 }}>\n                        {formatVND(order.amount)}\n                      </div>\n                      <div style={{ fontSize: "12px", color: "var(--text-secondary)" }}>\n                        {order.username || order.email || "Ẩn danh"}\n                      </div>'
    );
  }

  // Fix 3: Fix "Tổng doanh thu premium" card name
  content = content.replace(
    '          <span className="metric-label" style={{ display: "block", fontSize: "13px", color: "var(--text-secondary)", marginBottom: "8px", paddingLeft: "16px" }}>Tổng doanh thu premium</span>',
    '          <span className="metric-label" style={{ display: "block", fontSize: "13px", color: "var(--text-secondary)", marginBottom: "8px", paddingLeft: "16px" }}>Tổng giá trị dòng tiền (Chi tiêu user)</span>'
  );

  fs.writeFileSync('src/pages/DashboardPage.jsx', content);
  console.log('Fixed cards!');
} catch (e) {
  console.error(e);
}
