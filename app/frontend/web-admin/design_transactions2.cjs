const fs = require('fs');

try {
  let content = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf-8');

  // 1. Remove the 3rd metric card
  const metricCardRegex = /<div className="metric-card"[^>]*>\s*<span className="metric-indicator indicator-amber"[\s\S]*?<\/div>/;
  content = content.replace(metricCardRegex, '');

  // 2. Rewrite the Giao dịch gần nhất section
  const modernList = `          <div className="app-nav-track" style={{ overflowY: "auto", maxHeight: "400px", padding: "16px 20px", display: "flex", flexDirection: "column", gap: "12px" }}>
            {(Array.isArray(monetOrders) ? monetOrders : []).slice(0, 10).map((order, index) => (
              <div key={order.id || ("order-" + index)} style={{
                display: "flex", alignItems: "center", justifyContent: "space-between",
                background: "var(--bg-obsidian-950)", padding: "16px 20px",
                border: "1px solid var(--border-color)", borderRadius: "16px",
                boxShadow: "0 4px 12px rgba(0,0,0,0.1)",
                transition: "all 0.2s ease"
              }} className="transaction-item">
                <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
                  <div style={{
                    width: "42px", height: "42px", borderRadius: "12px",
                    background: order.status === "completed" ? "rgba(16, 185, 129, 0.1)" : "rgba(245, 158, 11, 0.1)",
                    color: order.status === "completed" ? "var(--accent-emerald)" : "var(--accent-amber)",
                    display: "flex", alignItems: "center", justifyContent: "center"
                  }}>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <rect x="2" y="5" width="20" height="14" rx="2" />
                      <line x1="2" y1="10" x2="22" y2="10" />
                    </svg>
                  </div>
                  <div>
                    <div style={{ fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)", fontSize: "15px", marginBottom: "4px" }}>
                      {formatVND(order.amount)}
                    </div>
                    <div style={{ fontSize: "12px", color: "var(--text-secondary)" }}>
                      {order.username || order.email || "Ẩn danh"}
                    </div>
                  </div>
                </div>
                <div>
                  <OrderStatusBadge status={order.status} />
                </div>
              </div>
            ))}
            {(!monetOrders || monetOrders.length === 0) && (
              <div style={{ padding: "40px 20px", textAlign: "center", color: "var(--text-muted)", display: "flex", flexDirection: "column", alignItems: "center", gap: "12px" }}>
                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: 0.5 }}>
                  <circle cx="12" cy="12" r="10" />
                  <line x1="12" y1="8" x2="12" y2="12" />
                  <line x1="12" y1="16" x2="12.01" y2="16" />
                </svg>
                <span>Chưa có giao dịch nào được ghi nhận</span>
              </div>
            )}
          </div>`;
    
  const originalSectionRegex = /<div style={{ overflowY: "auto", maxHeight: "400px" }}>[\s\S]*?Chưa có giao dịch<\/div>}[\s]*<\/div>/;
  content = content.replace(originalSectionRegex, modernList);

  // Adding the custom hover CSS class by injecting a quick <style> tag at the top of the file
  if (!content.includes('.transaction-item:hover')) {
    const importIdx = content.lastIndexOf('import ');
    const endOfImports = content.indexOf(';', importIdx) + 1;
    const styleInjection = `\n\nconst injectedStyles = \`
      .transaction-item:hover {
        background: rgba(255,255,255,0.03) !important;
        border-color: rgba(255,255,255,0.1) !important;
        transform: translateY(-1px);
      }
      .app-nav-track::-webkit-scrollbar {
        display: none;
      }
    \`;
    if (typeof document !== 'undefined') {
      const style = document.createElement('style');
      style.textContent = injectedStyles;
      document.head.appendChild(style);
    }\n`;
    content = content.substring(0, endOfImports) + styleInjection + content.substring(endOfImports);
  }

  fs.writeFileSync('src/pages/DashboardPage.jsx', content);
  console.log('Designed transactions section 2!');
} catch (e) {
  console.error(e);
}
