import { useCallback, useEffect, useMemo, useState } from "react";
import UserCacheInspector from "../components/UserCacheInspector";
import { getAdminUsers, getUserInspector } from "../services/api";

const API = import.meta.env.VITE_API_BASE_URL || "http://localhost:4000";

const PAGE_SIZE = 10;

const AUTH_LABELS = {
  Google: "Google Sign-In",
  Email: "Email / Mật khẩu",
  Unknown: "Chưa xác định",
};

const AUTH_FILTER_OPTIONS = ["all", "Google", "Email", "Unknown"];
const AGE_FILTER_OPTIONS = ["all", "__unset__", "18-22 tuổi", "23-30 tuổi", "31-40 tuổi", "41-50 tuổi", "Trên 50"];
const JOB_FILTER_OPTIONS = ["all", "__unset__", "Sinh viên", "Văn phòng", "Freelancer", "Kinh doanh", "Khác"];

function authLabel(provider) {
  return AUTH_LABELS[provider] || provider || "Chưa xác định";
}

function mergeFilterOptions(base, users, field) {
  const seen = new Set(base);
  users.forEach((u) => {
    const v = u[field];
    if (v) seen.add(v);
  });
  return Array.from(seen);
}

function matchesProfileFilter(value, filterValue) {
  if (filterValue === "all") return true;
  if (filterValue === "__unset__") return !value;
  return value === filterValue;
}

function initials(name, email) {
  const src = (name || email || "?").trim();
  return src.slice(0, 2).toUpperCase();
}

function avatarHue(id) {
  let hash = 0;
  for (let i = 0; i < (id || "").length; i += 1) {
    hash = (hash * 31 + id.charCodeAt(i)) % 360;
  }
  return hash;
}

function formatDate(value) {
  if (!value) return "—";
  return new Date(value).toLocaleDateString("vi-VN", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  });
}

function buildPageWindow(current, total) {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
  const pages = new Set([1, total, current, current - 1, current + 1]);
  return Array.from(pages)
    .filter((p) => p >= 1 && p <= total)
    .sort((a, b) => a - b);
}

function UserManagementPage() {
  const [users, setUsers] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [inspector, setInspector] = useState(null);
  const [listLoading, setListLoading] = useState(true);
  const [inspectorLoading, setInspectorLoading] = useState(false);
  const [listError, setListError] = useState("");
  const [inspectorError, setInspectorError] = useState("");
  const [search, setSearch] = useState("");
  const [filterAuth, setFilterAuth] = useState("all");
  const [filterAge, setFilterAge] = useState("all");
  const [filterJob, setFilterJob] = useState("all");
  const [page, setPage] = useState(1);
  const [activeTab, setActiveTab] = useState('users');
  const [appeals, setAppeals] = useState([]);
  const [loadingAppeals, setLoadingAppeals] = useState(false);

  const pendingAppealsCount = useMemo(() => {
    return appeals.filter(a => a.status === 'pending').length;
  }, [appeals]);

  const loadUsers = useCallback(() => {
    setListLoading(true);
    setListError("");
    return getAdminUsers()
      .then((rows) => {
        setUsers(rows);
        return rows;
      })
      .catch((err) => {
        setListError(err.message || "Không tải được danh sách người dùng");
        setUsers([]);
      })
      .finally(() => setListLoading(false));
  }, []);

  const loadInspector = useCallback((userId) => {
    if (!userId) {
      setInspector(null);
      return;
    }
    setInspectorLoading(true);
    setInspectorError("");
    getUserInspector(userId)
      .then(setInspector)
      .catch((err) => {
        setInspectorError(err.message || "Không tải được cache inspector");
        setInspector(null);
      })
      .finally(() => setInspectorLoading(false));
  }, []);

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
    loadUsers();
    loadAppeals();
  }, [loadUsers, loadAppeals]);

  useEffect(() => {
    if (activeTab === 'appeals') {
      loadAppeals();
    }
  }, [activeTab, loadAppeals]);

  const handleResolveAppeal = async (id, status) => {
    let adminNote = "";
    if (status === 'rejected') {
      const input = window.prompt("Nhập lý do từ chối khiếu nại (sẽ gửi email thông báo trực tiếp cho người dùng):", "Thông tin khiếu nại chưa đủ cơ sở để mở khóa tài khoản.");
      if (input === null) return;
      adminNote = input.trim();
    } else {
      if (!window.confirm("Xác nhận chấp thuận khiếu nại và mở khóa tài khoản này? Hệ thống sẽ gửi email thông báo cho người dùng.")) return;
    }

    try {
      const res = await fetch(`${API}/api/admin/appeals/${id}/resolve`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${localStorage.getItem("admin_token")}`
        },
        body: JSON.stringify({ status, adminNote })
      });
      if (!res.ok) throw new Error("Failed to resolve appeal");
      alert(status === 'approved' ? "Đã duyệt mở khóa tài khoản và gửi email thông báo thành công!" : "Đã từ chối khiếu nại và gửi email thông báo thành công!");
      loadAppeals();
      loadUsers();
    } catch (err) {
      alert("Lỗi xử lý khiếu nại: " + err.message);
    }
  };

  const ageOptions = useMemo(() => mergeFilterOptions(AGE_FILTER_OPTIONS, users, "ageGroup"), [users]);
  const jobOptions = useMemo(() => mergeFilterOptions(JOB_FILTER_OPTIONS, users, "jobType"), [users]);

  const filteredUsers = useMemo(() => {
    const q = search.trim().toLowerCase();
    return users.filter((u) => {
      if (u.role === "admin") return false;
      if (filterAuth !== "all" && u.authProvider !== filterAuth) return false;
      if (!matchesProfileFilter(u.ageGroup, filterAge)) return false;
      if (!matchesProfileFilter(u.jobType, filterJob)) return false;
      if (!q) return true;
      const hay = [u.username, u.email, u.id, u.ageGroup, u.jobType, u.authProvider]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return hay.includes(q);
    });
  }, [users, search, filterAuth, filterAge, filterJob]);

  const totalPages = Math.max(1, Math.ceil(filteredUsers.length / PAGE_SIZE));

  useEffect(() => {
    setPage(1);
  }, [search, filterAuth, filterAge, filterJob]);

  useEffect(() => {
    if (page > totalPages) setPage(totalPages);
  }, [page, totalPages]);

  const paginatedUsers = useMemo(() => {
    const start = (page - 1) * PAGE_SIZE;
    return filteredUsers.slice(start, start + PAGE_SIZE);
  }, [filteredUsers, page]);

  const pageWindow = useMemo(() => buildPageWindow(page, totalPages), [page, totalPages]);

  const rangeStart = filteredUsers.length === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const rangeEnd = Math.min(page * PAGE_SIZE, filteredUsers.length);

  const hasActiveFilters = filterAuth !== "all" || filterAge !== "all" || filterJob !== "all" || search.trim();

  const clearFilters = () => {
    setSearch("");
    setFilterAuth("all");
    setFilterAge("all");
    setFilterJob("all");
  };

  const selectedUser = users.find((u) => u.id === selectedId) || null;

  const stats = useMemo(() => {
    const list = users.filter((u) => u.role !== "admin");
    const active = list.filter((u) => u.isActive).length;
    const google = list.filter((u) => u.authProvider === "Google").length;
    const email = list.filter((u) => u.authProvider === "Email").length;
    const premium = list.filter((u) => u.isPremium).length;
    return { total: list.length, active, google, email, premium };
  }, [users]);

  const [toggling, setToggling] = useState({});
  const [banModal, setBanModal] = useState({ isOpen: false, userId: null, currentStatus: null });
  const [banReasonOption, setBanReasonOption] = useState("Spam hoặc lạm dụng hệ thống");
  const [banReasonCustom, setBanReasonCustom] = useState("");

  const PREDEFINED_REASONS = [
    "Spam hoặc lạm dụng hệ thống",
    "Vi phạm tiêu chuẩn cộng đồng",
    "Tạo giao dịch ảo/gian lận",
    "Sử dụng ngôn từ không phù hợp",
    "Tài khoản có dấu hiệu bị hack",
    "other"
  ];

  const handleTogglePremium = async (e, userId, currentPremium) => {
    e.stopPropagation();
    setToggling((p) => ({ ...p, [userId]: true }));
    try {
      const res = await fetch(`${API}/api/admin/users/${userId}/premium`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": `Bearer ${localStorage.getItem("admin_token")}` },
        body: JSON.stringify({ isPremium: !currentPremium }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setUsers((prev) =>
        prev.map((u) => u.id === userId ? { ...u, isPremium: !currentPremium } : u)
      );
    } catch (err) {
      alert("Lỗi: " + err.message);
    } finally {
      setToggling((p) => ({ ...p, [userId]: false }));
    }
  };

  const handleToggleBan = async (e, userId, currentStatus) => {
    e.stopPropagation();
    const isBanned = currentStatus === 'banned';
    
    if (!isBanned) {
      setBanModal({ isOpen: true, userId, currentStatus });
      return;
    }
    
    if (isBanned && !window.confirm("Bạn có chắc muốn mở khóa tài khoản này?")) {
      return;
    }
    
    executeBanToggle(userId, 'active', null);
  };

  const submitBan = () => {
    const reason = banReasonOption === 'other' ? banReasonCustom : banReasonOption;
    if (!reason.trim()) {
      alert("Phải nhập lý do khóa.");
      return;
    }
    setBanModal({ isOpen: false, userId: null, currentStatus: null });
    executeBanToggle(banModal.userId, 'banned', reason);
  };

  const executeBanToggle = async (userId, newStatus, reason) => {
    setToggling((p) => ({ ...p, [userId]: true }));
    try {
      const res = await fetch(`${API}/api/admin/users/${userId}/status`, {
        method: "PUT",
        headers: { "Content-Type": "application/json", "Authorization": `Bearer ${localStorage.getItem("admin_token")}` },
        body: JSON.stringify({ status: newStatus, banReason: reason }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setUsers((prev) =>
        prev.map((u) => u.id === userId ? { ...u, status: data.user.status, banReason: newStatus === 'active' ? null : reason } : u)
      );
    } catch (err) {
      alert("Lỗi: " + err.message);
    } finally {
      setToggling((p) => ({ ...p, [userId]: false }));
    }
  };

  const onSelectUser = (userId) => {
    setSelectedId(userId);
    loadInspector(userId);
  };

  return (
    <div className="page-container" style={{ padding: "30px 40px", maxWidth: "1600px", margin: "0 auto" }}>
      {/* Header */}
      <div className="page-header" style={{ marginBottom: "24px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px" }}>User Management</h1>
          <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "4px" }}>
            Quản lý tài khoản, hồ sơ onboarding và cache NLU — lọc theo nhóm, phân trang.
          </p>
        </div>
        <button type="button" className="btn" onClick={loadUsers} disabled={listLoading} style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          color: "var(--text-primary)",
          padding: "8px 16px",
          borderRadius: "8px",
          fontWeight: "600",
          fontSize: "13px",
          cursor: "pointer",
          display: "flex",
          alignItems: "center",
          gap: "8px",
          transition: "all 0.2s"
        }}>
          {listLoading ? (
            <>
              <span className="brand-dot" style={{ width: "8px", height: "8px", animation: "pulse 1.5s infinite", background: "var(--accent-blue)" }}></span>
              Đang tải...
            </>
          ) : "Làm mới"}
        </button>
      </div>

      {/* Metrics Strip */}

      <div style={{ display: 'flex', gap: '20px', marginBottom: '24px', borderBottom: '1px solid var(--border-color)' }}>
        <button 
          onClick={() => setActiveTab('users')}
          style={{ background: 'none', border: 'none', padding: '12px 16px', fontSize: '15px', fontWeight: '600', cursor: 'pointer', color: activeTab === 'users' ? 'var(--text-primary)' : 'var(--text-muted)', borderBottom: activeTab === 'users' ? '2px solid var(--accent-blue)' : '2px solid transparent' }}
        >
          Người Dùng
        </button>
        <button 
          onClick={() => setActiveTab('appeals')}
          style={{
            background: 'none',
            border: 'none',
            padding: '12px 16px',
            fontSize: '15px',
            fontWeight: '600',
            cursor: 'pointer',
            color: activeTab === 'appeals' ? 'var(--text-primary)' : 'var(--text-muted)',
            borderBottom: activeTab === 'appeals' ? '2px solid var(--accent-blue)' : '2px solid transparent',
            display: 'inline-flex',
            alignItems: 'center',
            gap: '8px'
          }}
        >
          <span>Khiếu Nại</span>
          {pendingAppealsCount > 0 && (
            <span
              style={{
                display: "inline-flex",
                alignItems: "center",
                justifyContent: "center",
                background: "var(--accent-rose, #f43f5e)",
                color: "#ffffff",
                fontSize: "11px",
                fontWeight: "700",
                minWidth: "20px",
                height: "20px",
                padding: "0 6px",
                borderRadius: "10px",
                boxShadow: "0 0 6px rgba(244, 63, 94, 0.4)",
              }}
              title={`${pendingAppealsCount} khiếu nại đang chờ xử lý`}
            >
              {pendingAppealsCount}
            </span>
          )}
        </button>
      </div>

      {activeTab === 'users' ? (
        <>
      <div className="bill-stat-strip" style={{
        marginBottom: "30px",
        background: "var(--bg-obsidian-900)",
        border: "1px solid var(--border-color)",
        borderRadius: "16px",
        padding: "20px 24px",
        display: "grid",
        gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))",
        gap: "20px",
        boxShadow: "inset 0 1px 0 rgba(255, 255, 255, 0.02)"
      }}>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Tổng tài khoản</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)" }}>{stats.total}</span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Đang hoạt động</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: "var(--accent-emerald-hover)", fontFamily: "var(--font-mono)" }}>{stats.active}</span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Google / Email</span>
          <span className="bill-stat-value" style={{ fontSize: "16px", fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)" }}>{stats.google} <span style={{color:"var(--text-muted)", fontWeight:"400"}}>/</span> {stats.email}</span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>👑 Premium</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: "#a78bfa", fontFamily: "var(--font-mono)" }}>{stats.premium}</span>
        </div>
        <div className="bill-stat">
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Kết quả lọc</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)" }}>{filteredUsers.length}</span>
        </div>
      </div>

      {listError && <div className="user-mgmt-error" style={{ background: "rgba(239, 68, 68, 0.1)", color: "var(--accent-rose)", padding: "12px", borderRadius: "8px", border: "1px solid rgba(239, 68, 68, 0.2)", fontSize: "13px", marginBottom: "20px" }}>{listError}</div>}

      <div className="dashboard-grid" style={{ gap: "24px", gridTemplateColumns: selectedUser ? "2fr 1fr" : "1fr" }}>
        
        {/* Left Side: Directory */}
        <section className="panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px",
          boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
          display: "flex",
          flexDirection: "column",
          gap: "20px",
          height: "fit-content"
        }}>
          {/* Toolbar */}
          <div style={{ display: "flex", flexWrap: "wrap", gap: "16px", alignItems: "flex-end", paddingBottom: "16px", borderBottom: "1px solid var(--border-color)" }}>
            <div style={{ flex: "1 1 200px" }}>
              <label style={{ fontSize: "12px", fontWeight: "600", color: "var(--text-muted)", marginBottom: "6px", display: "block", textTransform: "uppercase", letterSpacing: "0.05em" }}>Tìm kiếm</label>
              <input
                type="search"
                placeholder="Tên, email, UUID..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                style={{
                  width: "100%",
                  background: "var(--bg-obsidian-950)",
                  border: "1px solid var(--border-color)",
                  borderRadius: "8px",
                  padding: "10px 14px",
                  color: "var(--text-primary)",
                  fontSize: "13px"
                }}
              />
            </div>
            
            <div>
              <label style={{ fontSize: "12px", fontWeight: "600", color: "var(--text-muted)", marginBottom: "6px", display: "block", textTransform: "uppercase", letterSpacing: "0.05em" }}>Đăng nhập</label>
              <select value={filterAuth} onChange={(e) => setFilterAuth(e.target.value)} style={{ background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", borderRadius: "8px", padding: "10px 14px", color: "var(--text-primary)", fontSize: "13px", height: "40px" }}>
                <option value="all">Tất cả</option>
                {AUTH_FILTER_OPTIONS.filter((v) => v !== "all").map((v) => <option key={v} value={v}>{authLabel(v)}</option>)}
              </select>
            </div>
            
            <div>
              <label style={{ fontSize: "12px", fontWeight: "600", color: "var(--text-muted)", marginBottom: "6px", display: "block", textTransform: "uppercase", letterSpacing: "0.05em" }}>Nhóm tuổi</label>
              <select value={filterAge} onChange={(e) => setFilterAge(e.target.value)} style={{ background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", borderRadius: "8px", padding: "10px 14px", color: "var(--text-primary)", fontSize: "13px", height: "40px" }}>
                <option value="all">Tất cả</option>
                {ageOptions.filter((v) => v !== "all").map((v) => <option key={v} value={v}>{v === "__unset__" ? "Chưa khai báo" : v}</option>)}
              </select>
            </div>

            <div>
              <label style={{ fontSize: "12px", fontWeight: "600", color: "var(--text-muted)", marginBottom: "6px", display: "block", textTransform: "uppercase", letterSpacing: "0.05em" }}>Nghề nghiệp</label>
              <select value={filterJob} onChange={(e) => setFilterJob(e.target.value)} style={{ background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", borderRadius: "8px", padding: "10px 14px", color: "var(--text-primary)", fontSize: "13px", height: "40px" }}>
                <option value="all">Tất cả</option>
                {jobOptions.filter((v) => v !== "all").map((v) => <option key={v} value={v}>{v === "__unset__" ? "Chưa khai báo" : v}</option>)}
              </select>
            </div>

            {hasActiveFilters && (
              <button type="button" onClick={clearFilters} style={{
                background: "transparent", border: "none", color: "var(--accent-rose-hover)", fontWeight: "600", fontSize: "13px", padding: "10px", cursor: "pointer"
              }}>
                Xóa lọc
              </button>
            )}
          </div>

          {/* User Cards Grid */}
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: "16px" }}>
            {listLoading ? (
              Array.from({ length: 6 }).map((_, i) => (
                <div key={i} style={{ height: "120px", background: "var(--bg-obsidian-950)", borderRadius: "12px", border: "1px solid var(--border-color)", animation: "pulse 1.5s infinite" }}></div>
              ))
            ) : paginatedUsers.length === 0 ? (
              <div style={{ gridColumn: "1 / -1", textAlign: "center", padding: "60px 20px", color: "var(--text-muted)" }}>
                <p style={{ fontWeight: "600", fontSize: "15px", color: "var(--text-primary)", marginBottom: "6px" }}>Không có người dùng phù hợp</p>
                <p style={{ fontSize: "13px" }}>Thử bỏ bộ lọc hoặc làm mới danh sách.</p>
              </div>
            ) : (
              paginatedUsers.map((user) => {
                const hue = avatarHue(user.id);
                const isSelected = selectedId === user.id;
                return (
                  <div
                    key={user.id}
                    onClick={() => onSelectUser(user.id)}
                    style={{
                      background: isSelected ? "rgba(26,115,232,0.05)" : "var(--bg-obsidian-950)",
                      border: `1px solid ${isSelected ? "var(--accent-blue)" : "var(--border-color)"}`,
                      borderRadius: "12px",
                      padding: "16px",
                      cursor: "pointer",
                      transition: "all 0.2s",
                      position: "relative",
                      display: "flex",
                      flexDirection: "column",
                      gap: "12px"
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
                      <div style={{
                        width: "42px", height: "42px", borderRadius: "50%",
                        background: `hsla(${hue}, 42%, 46%, 0.14)`,
                        border: `1px solid hsla(${hue}, 52%, 58%, 0.32)`,
                        color: `hsl(${hue}, 68%, 72%)`,
                        display: "flex", alignItems: "center", justifyContent: "center",
                        fontWeight: "700", fontSize: "14px", flexShrink: 0
                      }}>
                        {initials(user.username, user.email)}
                      </div>
                      <div style={{ minWidth: 0, flex: 1 }}>
                        <div style={{ fontWeight: "600", color: "var(--text-primary)", fontSize: "14px", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                          {user.username || "Chưa đặt tên"}
                        </div>
                        <div style={{ color: "var(--text-muted)", fontSize: "12px", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", marginTop: "2px" }}>
                          {user.email}
                        </div>
                      </div>
                      <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: "4px" }}>
                        <span style={{
                          fontSize: "10px", fontWeight: "700", padding: "2px 6px", borderRadius: "4px",
                          background: user.status === 'banned' ? "rgba(239,68,68,0.1)" : user.isActive ? "rgba(16,185,129,0.1)" : "rgba(100,116,139,0.1)",
                          color: user.status === 'banned' ? "var(--accent-rose)" : user.isActive ? "var(--accent-emerald-hover)" : "var(--text-muted)",
                          border: `1px solid ${user.status === 'banned' ? "rgba(239,68,68,0.2)" : user.isActive ? "rgba(16,185,129,0.2)" : "rgba(100,116,139,0.2)"}`
                        }}>
                          {user.status === 'banned' ? "BANNED" : user.isActive ? "ACTIVE" : "INACTIVE"}
                        </span>
                        {user.isPremium && (
                          <span style={{ fontSize: "12px" }} title="Premium User">👑</span>
                        )}
                      </div>
                    </div>

                    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: "auto", paddingTop: "12px", borderTop: "1px dashed rgba(255,255,255,0.05)" }}>
                      <div style={{ display: "flex", gap: "6px" }}>
                        {user.ageGroup && <span style={{ fontSize: "10px", background: "var(--bg-obsidian-800)", color: "var(--text-secondary)", padding: "2px 6px", borderRadius: "4px", border: "1px solid var(--border-color)" }}>{user.ageGroup}</span>}
                        {user.jobType && <span style={{ fontSize: "10px", background: "var(--bg-obsidian-800)", color: "var(--text-secondary)", padding: "2px 6px", borderRadius: "4px", border: "1px solid var(--border-color)" }}>{user.jobType}</span>}
                      </div>
                      <div style={{ display: "flex", gap: "8px" }}>
                        <button
                          type="button"
                          onClick={(e) => handleToggleBan(e, user.id, user.status)}
                          disabled={toggling[user.id]}
                          style={{
                            background: user.status === 'banned' ? "rgba(16,185,129,0.12)" : "rgba(239,68,68,0.12)",
                            border: `1px solid ${user.status === 'banned' ? "rgba(16,185,129,0.4)" : "rgba(239,68,68,0.4)"}`,
                            color: user.status === 'banned' ? "var(--accent-emerald)" : "var(--accent-rose)",
                            fontSize: "11px", fontWeight: "600", padding: "4px 8px", borderRadius: "6px", cursor: "pointer",
                            transition: "all 0.2s"
                          }}
                        >
                          {toggling[user.id] ? "..." : user.status === 'banned' ? "Mở Khóa" : "Khóa"}
                        </button>
                        <button
                          type="button"
                          onClick={(e) => handleTogglePremium(e, user.id, user.isPremium)}
                          disabled={toggling[user.id]}
                          style={{
                            background: user.isPremium ? "rgba(167,139,250,0.12)" : "transparent",
                            border: `1px solid ${user.isPremium ? "rgba(167,139,250,0.4)" : "rgba(255,255,255,0.1)"}`,
                            color: user.isPremium ? "#c4b5fd" : "var(--text-muted)",
                            fontSize: "11px", fontWeight: "600", padding: "4px 8px", borderRadius: "6px", cursor: "pointer",
                            transition: "all 0.2s"
                          }}
                        >
                          {toggling[user.id] ? "..." : user.isPremium ? "Hạ cấp" : "Nâng Premium"}
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Pagination */}
          {!listLoading && filteredUsers.length > 0 && (
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", paddingTop: "20px", borderTop: "1px solid var(--border-color)", marginTop: "auto" }}>
              <span style={{ fontSize: "13px", color: "var(--text-muted)" }}>
                Hiển thị <strong style={{ color: "var(--text-primary)" }}>{rangeStart}–{rangeEnd}</strong> / {filteredUsers.length}
              </span>
              <div style={{ display: "flex", gap: "6px" }}>
                <button
                  type="button"
                  disabled={page <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  style={{ background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", color: "var(--text-primary)", padding: "6px 12px", borderRadius: "6px", fontSize: "12px", fontWeight: "600", cursor: page <= 1 ? "not-allowed" : "pointer", opacity: page <= 1 ? 0.5 : 1 }}
                >
                  Trước
                </button>
                {pageWindow.map((p, idx) => {
                  const prev = pageWindow[idx - 1];
                  const gap = prev != null && p - prev > 1;
                  return (
                    <div key={p} style={{ display: "flex", gap: "6px" }}>
                      {gap && <span style={{ color: "var(--text-muted)", padding: "6px" }}>…</span>}
                      <button
                        type="button"
                        onClick={() => setPage(p)}
                        style={{
                          background: p === page ? "var(--accent-blue)" : "var(--bg-obsidian-950)",
                          border: `1px solid ${p === page ? "var(--accent-blue)" : "var(--border-color)"}`,
                          color: p === page ? "#fff" : "var(--text-primary)",
                          padding: "6px 12px", borderRadius: "6px", fontSize: "12px", fontWeight: "600", cursor: "pointer"
                        }}
                      >
                        {p}
                      </button>
                    </div>
                  );
                })}
                <button
                  type="button"
                  disabled={page >= totalPages}
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  style={{ background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", color: "var(--text-primary)", padding: "6px 12px", borderRadius: "6px", fontSize: "12px", fontWeight: "600", cursor: page >= totalPages ? "not-allowed" : "pointer", opacity: page >= totalPages ? 0.5 : 1 }}
                >
                  Sau
                </button>
              </div>
            </div>
          )}
        </section>

        {/* Right Side: Detail Panel */}
        {selectedUser && (
          <aside style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
            <div className="panel" style={{
              background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px", boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
            }}>
              <div style={{ display: "flex", alignItems: "center", gap: "16px", paddingBottom: "20px", borderBottom: "1px dashed var(--border-color)", marginBottom: "20px" }}>
                <div style={{
                  width: "56px", height: "56px", borderRadius: "12px",
                  background: `hsla(${avatarHue(selectedUser.id)}, 42%, 46%, 0.14)`,
                  border: `1px solid hsla(${avatarHue(selectedUser.id)}, 52%, 58%, 0.32)`,
                  color: `hsl(${avatarHue(selectedUser.id)}, 68%, 72%)`,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  fontWeight: "700", fontSize: "20px", flexShrink: 0
                }}>
                  {initials(selectedUser.username, selectedUser.email)}
                </div>
                <div style={{ minWidth: 0 }}>
                  <h3 style={{ fontSize: "18px", fontWeight: "700", color: "var(--text-primary)", margin: 0, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                    {selectedUser.username || "Chưa đặt tên"}
                  </h3>
                  <p style={{ fontSize: "13px", color: "var(--text-muted)", margin: "4px 0 0 0" }}>{selectedUser.email}</p>
                </div>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px" }}>
                <div>
                  <div style={{ fontSize: "11px", color: "var(--text-muted)", textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: "4px" }}>Nhóm tuổi</div>
                  <div style={{ fontSize: "14px", color: "var(--text-primary)", fontWeight: "500" }}>{selectedUser.ageGroup || inspector?.ageGroup || "—"}</div>
                </div>
                <div>
                  <div style={{ fontSize: "11px", color: "var(--text-muted)", textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: "4px" }}>Nghề nghiệp</div>
                  <div style={{ fontSize: "14px", color: "var(--text-primary)", fontWeight: "500" }}>{selectedUser.jobType || inspector?.jobType || "—"}</div>
                </div>
                <div>
                  <div style={{ fontSize: "11px", color: "var(--text-muted)", textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: "4px" }}>Đăng nhập</div>
                  <div style={{ fontSize: "14px", color: "var(--text-primary)", fontWeight: "500" }}>{authLabel(selectedUser.authProvider || inspector?.authProvider)}</div>
                </div>
                <div>
                  <div style={{ fontSize: "11px", color: "var(--text-muted)", textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: "4px" }}>Ngày tạo</div>
                  <div style={{ fontSize: "14px", color: "var(--text-primary)", fontWeight: "500" }}>{formatDate(selectedUser.createdAt || inspector?.createdAt)}</div>
                </div>
                <div style={{ gridColumn: "1 / -1" }}>
                  <div style={{ fontSize: "11px", color: "var(--text-muted)", textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: "4px" }}>User ID</div>
                  <div style={{ fontSize: "12px", color: "var(--text-primary)", fontFamily: "var(--font-mono)", background: "var(--bg-obsidian-950)", padding: "8px 12px", borderRadius: "8px", border: "1px solid var(--border-color)" }}>
                    {selectedUser.id}
                  </div>
                </div>
              </div>
            </div>

            {inspectorError && <div className="user-mgmt-error" style={{ background: "rgba(239, 68, 68, 0.1)", color: "var(--accent-rose)", padding: "12px", borderRadius: "8px", border: "1px solid rgba(239, 68, 68, 0.2)", fontSize: "13px" }}>{inspectorError}</div>}

            <div style={{ flex: 1, background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px", boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)" }}>
              <UserCacheInspector
                userId={selectedId}
                data={inspector}
                loading={inspectorLoading}
                onRefresh={() => loadInspector(selectedId)}
              />
            </div>
          </aside>
        )}
      </div>


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
                          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: "2px" }}>
                            <span style={{ fontSize: "13px", fontWeight: "600", color: a.status === 'approved' ? 'var(--accent-emerald-hover)' : 'var(--accent-rose)' }}>
                              {a.status === 'approved' ? 'Đã duyệt' : 'Đã từ chối'}
                            </span>
                            {a.admin_note && (
                              <span style={{ fontSize: "11px", color: "var(--text-muted)", maxWidth: "180px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }} title={`Lý do phản hồi: ${a.admin_note}`}>
                                {a.admin_note}
                              </span>
                            )}
                          </div>
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
      {banModal.isOpen && (
        <div style={{
          position: "fixed", top: 0, left: 0, right: 0, bottom: 0,
          background: "rgba(0,0,0,0.6)", backdropFilter: "blur(4px)",
          display: "flex", alignItems: "center", justifyContent: "center", zIndex: 9999
        }}>
          <div style={{
            background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)",
            padding: "24px", borderRadius: "16px", width: "400px", maxWidth: "90%",
            boxShadow: "0 10px 40px rgba(0,0,0,0.4)"
          }}>
            <h3 style={{ margin: "0 0 16px 0", fontSize: "18px", color: "var(--text-primary)" }}>Khóa tài khoản</h3>
            <p style={{ margin: "0 0 12px 0", fontSize: "14px", color: "var(--text-muted)" }}>Vui lòng chọn lý do khóa tài khoản người dùng này:</p>
            
            <select
              value={banReasonOption}
              onChange={(e) => setBanReasonOption(e.target.value)}
              style={{
                width: "100%", padding: "10px", borderRadius: "8px", border: "1px solid var(--border-color)",
                background: "var(--bg-obsidian)", color: "var(--text-primary)", marginBottom: "12px", outline: "none"
              }}
            >
              {PREDEFINED_REASONS.map((r, i) => (
                <option key={i} value={r} style={{ background: "var(--bg-obsidian-900)", color: "var(--text-primary)" }}>
                  {r === "other" ? "Lý do khác (Nhập thủ công)" : r}
                </option>
              ))}
            </select>

            {banReasonOption === "other" && (
              <input
                type="text"
                placeholder="Nhập lý do khóa..."
                value={banReasonCustom}
                onChange={(e) => setBanReasonCustom(e.target.value)}
                style={{
                  width: "100%", padding: "10px", borderRadius: "8px", border: "1px solid var(--border-color)",
                  background: "var(--bg-obsidian)", color: "var(--text-primary)", marginBottom: "16px", outline: "none"
                }}
              />
            )}

            <div style={{ display: "flex", justifyContent: "flex-end", gap: "12px", marginTop: "20px" }}>
              <button
                onClick={() => setBanModal({ isOpen: false, userId: null, currentStatus: null })}
                style={{
                  padding: "8px 16px", borderRadius: "8px", border: "1px solid var(--border-color)",
                  background: "transparent", color: "var(--text-muted)", cursor: "pointer"
                }}
              >
                Hủy
              </button>
              <button
                onClick={submitBan}
                style={{
                  padding: "8px 16px", borderRadius: "8px", border: "none",
                  background: "var(--accent-rose)", color: "#fff", cursor: "pointer", fontWeight: "600"
                }}
              >
                Xác nhận Khóa
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default UserManagementPage;
