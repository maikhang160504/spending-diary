const fs = require('fs');

try {
  let content = fs.readFileSync('src/pages/DashboardPage.jsx', 'utf-8');

  // 1. Remove the 3rd metric card
  const metricCardRegex = /<div className="metric-card"[^>]*>\s*<span className="metric-indicator indicator-amber"[\s\S]*?<\/div>/;
  content = content.replace(metricCardRegex, '');

  // 2. Rewrite the Giao dịch gần nhất section
  const tableStart = content.indexOf('<table style={{ width: "100%"');
  const tableEnd = content.indexOf('</table>') + '</table>'.length;
  
  if (tableStart !== -1 && tableEnd !== -1) {
    const modernList = `
            <div className="app-nav-track" style={{ display: "flex", flexDirection: "column", gap: "12px", padding: "16px 24px", overflowY: "auto", maxHeight: "400px" }}>
              {(Array.isArray(monetOrders) ? monetOrders : []).slice(0, 10).map((order, index) => (
                <div key={order.id || ("order-" + index)} style={{ 
                  display: "flex", 
                  alignItems: "center", 
                  justifyContent: "space-between",
                  padding: "16px 20px", 
                  background: "var(--bg-obsidian-950)",
                  border: "1px solid var(--border-color)",
                  borderRadius: "16px",
                  transition: "all 0.2s ease"
                }} className="transaction-item">
                  <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
                    <div style={{ 
                      width: "40px", height: "40px", borderRadius: "12px", 
                      background: order.status === 'completed' ? "rgba(16, 185, 129, 0.1)" : "rgba(245, 158, 11, 0.1)",
                      display: "flex", alignItems: "center", justifyContent: "center",
                      color: order.status === 'completed' ? "var(--accent-emerald)" : "var(--accent-amber)"
                    }}>
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        {order.status === 'completed' ? (
                          <path d="M20 6L9 17l-5-5" />
                        ) : (
                          <circle cx="12" cy="12" r="10" />
                        )}
                      </svg>
                    </div>
                    <div>
                      <div style={{ fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)", fontSize: "15px", marginBottom: "4px" }}>
                        {formatVND(order.amount)}
                      </div>
                      <div style={{ fontSize: "12px", color: "var(--text-secondary)", fontWeight: "500" }}>
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
                <div style={{ padding: "40px 0", textAlign: "center", color: "var(--text-muted)", display: "flex", flexDirection: "column", alignItems: "center", gap: "12px" }}>
                  <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" opacity="0.5">
                    <rect x="2" y="4" width="20" height="16" rx="2" />
                    <path d="M12 12v.01" />
                  </svg>
                  <span>Chưa có giao dịch nào được ghi nhận</span>
                </div>
              )}
            </div>`;
    
    // We also need to remove the "overflowY: auto" wrapper div from the original if we put it inside modernList
    // Or just replace the table and the "Chưa có giao dịch" div.
    
    // Let's refine the replacement to replace everything inside the `<div style={{ overflowY: "auto", maxHeight: "400px" }}>`
    const listWrapperStart = content.indexOf('<div style={{ overflowY: "auto", maxHeight: "400px" }}>');
    const endOfSection = content.indexOf('</div>', listWrapperStart + 100);
    // Actually it's better to just replace the table and the fallback message string precisely.
    const fallbackMessageRegex = /{!\(.*Chưa có giao dịch<\/div>}/;
    
    // Safer:
    const originalSectionRegex = /<div style={{ overflowY: "auto", maxHeight: "400px" }}>[\s\S]*?Chưa có giao dịch(?: nào được ghi nhận)?<\/div>}/;
    
    if (originalSectionRegex.test(content)) {
      content = content.replace(originalSectionRegex, modernList);
    } else {
      // Fallback
      content = content.substring(0, listWrapperStart) + modernList + content.substring(content.indexOf('</div>', content.indexOf('Chưa có giao dịch')) + 6);
    }
  }

  // Adding the custom hover CSS class by injecting a quick <style> tag at the top of the file
  if (!content.includes('.transaction-item:hover')) {
    const importIdx = content.lastIndexOf('import ');
    const endOfImports = content.indexOf(';', importIdx) + 1;
    const styleInjection = \`\n\nconst injectedStyles = \\\`
      .transaction-item:hover {
        background: rgba(255,255,255,0.03) !important;
        border-color: rgba(255,255,255,0.1) !important;
        transform: translateY(-1px);
      }
      .app-nav-track::-webkit-scrollbar {
        display: none;
      }
    \\\`;
    if (typeof document !== 'undefined') {
      const style = document.createElement('style');
      style.textContent = injectedStyles;
      document.head.appendChild(style);
    }\n\`;
    content = content.substring(0, endOfImports) + styleInjection + content.substring(endOfImports);
  }

  fs.writeFileSync('src/pages/DashboardPage.jsx', content);
  console.log('Designed transactions section!');
} catch (e) {
  console.error(e);
}
