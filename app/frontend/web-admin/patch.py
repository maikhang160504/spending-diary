import sys

with open('src/pages/UserManagementPage.jsx', 'r', encoding='utf-8') as f:
    lines = f.readlines()

out = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # 1. State declarations
    if 'const [page, setPage] = useState(1);' in line:
        out.append(line)
        out.append("  const [activeTab, setActiveTab] = useState('users');\n")
        out.append("  const [appeals, setAppeals] = useState([]);\n")
        out.append("  const [loadingAppeals, setLoadingAppeals] = useState(false);\n")
    
    # 2. Add functions right after `useEffect(() => { loadUsers(); }, [loadUsers]);`
    elif 'useEffect(() => {\n' in line and i+1 < len(lines) and 'loadUsers();\n' in lines[i+1]:
        out.append(line)
        out.append(lines[i+1])
        out.append(lines[i+2]) # '  }, [loadUsers]);\n'
        
        appeals_func = """
  const loadAppeals = useCallback(async () => {
    setLoadingAppeals(true);
    try {
      const res = await fetch(`${API}/api/admin/appeals`, {
        headers: { "Authorization": `Bearer ${localStorage.getItem("admin_token")}` }
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
    if (!window.confirm(`Xác nhận ${status === 'approved' ? 'chấp nhận' : 'từ chối'} khiếu nại này?`)) return;
    try {
      const res = await fetch(`${API}/api/admin/appeals/${id}/resolve`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${localStorage.getItem("admin_token")}`
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
"""
        out.append(appeals_func)
        i += 2
    
    # 3. Add Tabs after header
    elif '      <div className="bill-stat-strip"' in line:
        tabs_html = """
      <div style={{ display: 'flex', gap: '20px', marginBottom: '24px', borderBottom: '1px solid var(--border-color)' }}>
        <button 
          onClick={() => setActiveTab('users')}
          style={{ background: 'none', border: 'none', padding: '12px 16px', fontSize: '15px', fontWeight: '600', cursor: 'pointer', color: activeTab === 'users' ? 'var(--text-primary)' : 'var(--text-muted)', borderBottom: activeTab === 'users' ? '2px solid var(--accent-blue)' : '2px solid transparent' }}
        >
          Người Dùng
        </button>
        <button 
          onClick={() => setActiveTab('appeals')}
          style={{ background: 'none', border: 'none', padding: '12px 16px', fontSize: '15px', fontWeight: '600', cursor: 'pointer', color: activeTab === 'appeals' ? 'var(--text-primary)' : 'var(--text-muted)', borderBottom: activeTab === 'appeals' ? '2px solid var(--accent-blue)' : '2px solid transparent' }}
        >
          Khiếu Nại
        </button>
      </div>

      {activeTab === 'users' ? (
        <>
"""
        out.append(tabs_html)
        out.append(line)
        
    # 4. Wrap the end of User Management tab and add Appeals tab
    elif '{banModal.isOpen && (' in line:
        end_tab = """
        </>
      ) : (
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
"""
        out.append(end_tab)
        out.append(line)
        
    else:
        out.append(line)
    
    i += 1

with open('src/pages/UserManagementPage.jsx', 'w', encoding='utf-8') as f:
    f.writelines(out)

print("Patch applied successfully.")
