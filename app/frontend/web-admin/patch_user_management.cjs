const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'src/pages/UserManagementPage.jsx');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Add states
content = content.replace(
  'const [page, setPage] = useState(1);',
  `const [page, setPage] = useState(1);
  const [activeTab, setActiveTab] = useState('users');
  const [appeals, setAppeals] = useState([]);
  const [loadingAppeals, setLoadingAppeals] = useState(false);`
);

// 2. Add functions
const insertFunc = `  const loadAppeals = useCallback(async () => {
    setLoadingAppeals(true);
    try {
      const res = await fetch(\`\${API}/api/admin/appeals\`, {
        headers: { "Authorization": \`Bearer \${localStorage.getItem("admin_token")}\` }
      });
      if (!res.ok) throw new Error("Failed to load appeals");
      const json = await res.json();
      setAppeals(json.data || []);
    } catch (err) {
      console.error(err);
    } finally {
      setLoadingAppeals(false);
    }
  }, []);

  useEffect(() => {
    if (activeTab === 'appeals') {
      loadAppeals();
    }
  }, [activeTab, loadAppeals]);

  const handleResolveAppeal = async (id, status) => {
    if (!window.confirm(\`Xác nhận \${status === 'approved' ? 'chấp nhận' : 'từ chối'} khiếu nại này?\`)) return;
    try {
      const res = await fetch(\`\${API}/api/admin/appeals/\${id}/resolve\`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": \`Bearer \${localStorage.getItem("admin_token")}\`
        },
        body: JSON.stringify({ status })
      });
      if (!res.ok) throw new Error("Failed to resolve appeal");
      loadAppeals();
      loadUsers();
    } catch (err) {
      alert("Lỗi xử lý khiếu nại: " + err.message);
    }
  };

  useEffect(() => {`;

content = content.replace('  useEffect(() => {', insertFunc);

// 3. Inject Tab buttons after page header
const tabsHtml = `      </div>

      {/* TABS */}
      <div style={{ display: 'flex', gap: '20px', marginBottom: '24px', borderBottom: '1px solid var(--border-color)' }}>
        <button 
          onClick={() => setActiveTab('users')}
          style={{ 
            background: 'none', border: 'none', padding: '12px 16px', fontSize: '15px', fontWeight: '600', cursor: 'pointer',
            color: activeTab === 'users' ? 'var(--text-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'users' ? '2px solid var(--accent-blue)' : '2px solid transparent'
          }}
        >
          Người Dùng
        </button>
        <button 
          onClick={() => setActiveTab('appeals')}
          style={{ 
            background: 'none', border: 'none', padding: '12px 16px', fontSize: '15px', fontWeight: '600', cursor: 'pointer',
            color: activeTab === 'appeals' ? 'var(--text-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'appeals' ? '2px solid var(--accent-blue)' : '2px solid transparent'
          }}
        >
          Khiếu Nại
        </button>
      </div>

      {activeTab === 'users' ? (
        <>
          {/* Metrics Strip */}`;

content = content.replace(
  '      </div>\n\n      {/* Metrics Strip */}',
  tabsHtml
);

// 4. Wrap the end of user management content and add Appeals UI
const appealsHtml = `
      {/* End User Management Container */}
        </>
      ) : (
        /* APPEALS TAB */
        <div className="panel" style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px" }}>
          <h2 style={{ fontSize: "20px", fontWeight: "600", marginBottom: "20px" }}>Danh sách khiếu nại</h2>
          {loadingAppeals ? (
            <p style={{ color: "var(--text-muted)" }}>Đang tải...</p>
          ) : appeals.length === 0 ? (
            <p style={{ color: "var(--text-muted)" }}>Không có khiếu nại nào.</p>
          ) : (
            <div style={{ overflowX: "auto" }}>
              <table style={{ width: "100%", borderCollapse: "collapse" }}>
                <thead>
                  <tr style={{ borderBottom: "1px solid var(--border-color)", color: "var(--text-muted)", fontSize: "12px", textTransform: "uppercase" }}>
                    <th style={{ padding: "12px", textAlign: "left" }}>Người dùng</th>
                    <th style={{ padding: "12px", textAlign: "left" }}>Email</th>
                    <th style={{ padding: "12px", textAlign: "left" }}>Lý do Bị Khóa</th>
                    <th style={{ padding: "12px", textAlign: "left" }}>Lý do Khiếu nại</th>
                    <th style={{ padding: "12px", textAlign: "left" }}>Ngày tạo</th>
                    <th style={{ padding: "12px", textAlign: "right" }}>Thao tác</th>
                  </tr>
                </thead>
                <tbody>
                  {appeals.map(a => (
                    <tr key={a.id} style={{ borderBottom: "1px solid var(--border-color)", opacity: a.status !== 'pending' ? 0.6 : 1 }}>
                      <td style={{ padding: "12px" }}>{a.username}</td>
                      <td style={{ padding: "12px", color: "var(--text-muted)" }}>{a.email}</td>
                      <td style={{ padding: "12px", color: "var(--accent-rose)", maxWidth: "150px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }} title={a.ban_reason}>{a.ban_reason}</td>
                      <td style={{ padding: "12px", maxWidth: "250px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }} title={a.reason}>{a.reason}</td>
                      <td style={{ padding: "12px" }}>{new Date(a.created_at).toLocaleString('vi-VN')}</td>
                      <td style={{ padding: "12px", textAlign: "right" }}>
                        {a.status === 'pending' ? (
                          <div style={{ display: "flex", gap: "8px", justifyContent: "flex-end" }}>
                            <button onClick={() => handleResolveAppeal(a.id, 'approved')} style={{ background: "var(--accent-emerald-hover)", color: "#fff", border: "none", padding: "6px 12px", borderRadius: "4px", cursor: "pointer", fontSize: "13px" }}>Duyệt</button>
                            <button onClick={() => handleResolveAppeal(a.id, 'rejected')} style={{ background: "var(--accent-rose)", color: "#fff", border: "none", padding: "6px 12px", borderRadius: "4px", cursor: "pointer", fontSize: "13px" }}>Từ chối</button>
                          </div>
                        ) : (
                          <span style={{ fontSize: "13px", fontWeight: "600", color: a.status === 'approved' ? 'var(--accent-emerald-hover)' : 'var(--accent-rose)' }}>
                            {a.status === 'approved' ? 'Đã duyệt' : 'Đã từ chối'}
                          </span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Modals go here */}
`;

// Find where "return (" ends for the main content
// Let's replace the last closing tags
content = content.replace(
  '      </div>\n\n      {/* Modal Ban User */}',
  appealsHtml + '\n\n      {/* Modal Ban User */}'
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Successfully patched UserManagementPage.jsx');
