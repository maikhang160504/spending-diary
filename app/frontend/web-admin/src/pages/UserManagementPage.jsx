import { useCallback, useEffect, useMemo, useState } from "react";
import UserCacheInspector from "../components/UserCacheInspector";
import { getAdminUsers, getUserInspector } from "../services/api";

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

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  const ageOptions = useMemo(() => mergeFilterOptions(AGE_FILTER_OPTIONS, users, "ageGroup"), [users]);
  const jobOptions = useMemo(() => mergeFilterOptions(JOB_FILTER_OPTIONS, users, "jobType"), [users]);

  const filteredUsers = useMemo(() => {
    const q = search.trim().toLowerCase();
    return users.filter((u) => {
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
    const active = users.filter((u) => u.isActive).length;
    const google = users.filter((u) => u.authProvider === "Google").length;
    const email = users.filter((u) => u.authProvider === "Email").length;
    return { total: users.length, active, google, email };
  }, [users]);

  const onSelectUser = (userId) => {
    setSelectedId(userId);
    loadInspector(userId);
  };

  return (
    <div className="page-container user-mgmt-page">
      <header className="user-mgmt-hero">
        <div className="user-mgmt-hero-copy">
          <h1 className="user-mgmt-title">User Management</h1>
          <p className="user-mgmt-desc">
            Quản lý tài khoản, hồ sơ onboarding và cache NLU — lọc theo nhóm, duyệt có phân trang.
          </p>
        </div>
        <div className="user-mgmt-hero-actions">
          <button type="button" className="btn btn-secondary" onClick={loadUsers} disabled={listLoading}>
            {listLoading ? "Đang tải..." : "Làm mới"}
          </button>
        </div>
      </header>

      <div className="user-mgmt-metrics">
        <div className="user-mgmt-metric">
          <span className="user-mgmt-metric-label">Tổng tài khoản</span>
          <strong className="user-mgmt-metric-value">{stats.total}</strong>
        </div>
        <div className="user-mgmt-metric">
          <span className="user-mgmt-metric-label">Đang hoạt động</span>
          <strong className="user-mgmt-metric-value ok">{stats.active}</strong>
        </div>
        <div className="user-mgmt-metric">
          <span className="user-mgmt-metric-label">Google</span>
          <strong className="user-mgmt-metric-value">{stats.google}</strong>
        </div>
        <div className="user-mgmt-metric">
          <span className="user-mgmt-metric-label">Email</span>
          <strong className="user-mgmt-metric-value">{stats.email}</strong>
        </div>
        <div className="user-mgmt-metric">
          <span className="user-mgmt-metric-label">Kết quả lọc</span>
          <strong className="user-mgmt-metric-value">{filteredUsers.length}</strong>
        </div>
      </div>

      {listError && <div className="user-mgmt-error">{listError}</div>}

      <div className="user-mgmt-layout">
        <section className="user-mgmt-directory">
          <div className="user-mgmt-toolbar">
            <label className="user-mgmt-search">
              <span>Tìm kiếm</span>
              <input
                type="search"
                className="form-input"
                placeholder="Tên, email, UUID, nhóm tuổi..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </label>
            <div className="user-mgmt-filters">
              <label className="user-mgmt-filter">
                <span>Đăng nhập</span>
                <select className="bill-select" value={filterAuth} onChange={(e) => setFilterAuth(e.target.value)}>
                  <option value="all">Tất cả</option>
                  {AUTH_FILTER_OPTIONS.filter((v) => v !== "all").map((v) => (
                    <option key={v} value={v}>{authLabel(v)}</option>
                  ))}
                </select>
              </label>
              <label className="user-mgmt-filter">
                <span>Nhóm tuổi</span>
                <select className="bill-select" value={filterAge} onChange={(e) => setFilterAge(e.target.value)}>
                  <option value="all">Tất cả</option>
                  {ageOptions.filter((v) => v !== "all").map((v) => (
                    <option key={v} value={v}>{v === "__unset__" ? "Chưa khai báo" : v}</option>
                  ))}
                </select>
              </label>
              <label className="user-mgmt-filter">
                <span>Nghề nghiệp</span>
                <select className="bill-select" value={filterJob} onChange={(e) => setFilterJob(e.target.value)}>
                  <option value="all">Tất cả</option>
                  {jobOptions.filter((v) => v !== "all").map((v) => (
                    <option key={v} value={v}>{v === "__unset__" ? "Chưa khai báo" : v}</option>
                  ))}
                </select>
              </label>
              {hasActiveFilters && (
                <button type="button" className="btn btn-ghost user-mgmt-clear-filters" onClick={clearFilters}>
                  Xóa lọc
                </button>
              )}
            </div>
          </div>

          <div className="user-mgmt-table-wrap">
            {listLoading ? (
              <div className="user-mgmt-table-skeleton" aria-hidden="true">
                {Array.from({ length: 6 }).map((_, i) => (
                  <div key={i} className="user-inspector-skeleton user-inspector-skeleton-wide" />
                ))}
              </div>
            ) : filteredUsers.length === 0 ? (
              <div className="user-mgmt-empty">
                <p>Không có người dùng phù hợp</p>
                <span>Thử bỏ bộ lọc hoặc làm mới danh sách.</span>
                {hasActiveFilters && (
                  <button type="button" className="btn btn-ghost" onClick={clearFilters}>
                    Xóa lọc
                  </button>
                )}
              </div>
            ) : (
              <table className="user-mgmt-table">
                <thead>
                  <tr>
                    <th scope="col">Người dùng</th>
                    <th scope="col">Đăng nhập</th>
                    <th scope="col">Hồ sơ</th>
                    <th scope="col">Trạng thái</th>
                    <th scope="col">Ngày tạo</th>
                  </tr>
                </thead>
                <tbody>
                  {paginatedUsers.map((user) => {
                    const hue = avatarHue(user.id);
                    const isSelected = selectedId === user.id;
                    return (
                      <tr
                        key={user.id}
                        className={isSelected ? "selected" : ""}
                        tabIndex={0}
                        onClick={() => onSelectUser(user.id)}
                        onKeyDown={(e) => {
                          if (e.key === "Enter" || e.key === " ") {
                            e.preventDefault();
                            onSelectUser(user.id);
                          }
                        }}
                      >
                        <td>
                          <div className="user-mgmt-row-user">
                            <span
                              className="user-mgmt-avatar"
                              style={{
                                "--avatar-hue": hue,
                                background: `hsla(${hue}, 42%, 46%, 0.14)`,
                                borderColor: `hsla(${hue}, 52%, 58%, 0.32)`,
                                color: `hsl(${hue}, 68%, 72%)`,
                              }}
                              aria-hidden="true"
                            >
                              {initials(user.username, user.email)}
                            </span>
                            <span className="user-mgmt-row-copy">
                              <strong>{user.username || "Chưa đặt tên"}</strong>
                              <span>{user.email}</span>
                            </span>
                          </div>
                        </td>
                        <td>
                          <span className={`user-auth-badge ${user.authProvider?.toLowerCase() || "unknown"}`}>
                            {authLabel(user.authProvider)}
                          </span>
                        </td>
                        <td>
                          <span className="user-mgmt-profile-chip">{user.ageGroup || "—"}</span>
                          <span className="user-mgmt-profile-chip muted">{user.jobType || "—"}</span>
                        </td>
                        <td>
                          <span className={`user-status-pill compact ${user.isActive ? "ok" : "off"}`}>
                            {user.isActive ? "Active" : "Inactive"}
                          </span>
                        </td>
                        <td className="user-mgmt-date">{formatDate(user.createdAt)}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </div>

          {!listLoading && filteredUsers.length > 0 && (
            <footer className="user-mgmt-pagination">
              <p className="user-mgmt-range">
                Hiển thị <strong>{rangeStart}–{rangeEnd}</strong> / {filteredUsers.length} người dùng
              </p>
              <div className="user-mgmt-page-controls">
                <button
                  type="button"
                  className="user-mgmt-page-btn"
                  disabled={page <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                >
                  Trước
                </button>
                <div className="user-mgmt-page-list">
                  {pageWindow.map((p, idx) => {
                    const prev = pageWindow[idx - 1];
                    const gap = prev != null && p - prev > 1;
                    return (
                      <span key={p} className="user-mgmt-page-item">
                        {gap && <span className="user-mgmt-page-ellipsis" aria-hidden="true">…</span>}
                        <button
                          type="button"
                          className={`user-mgmt-page-btn ${p === page ? "active" : ""}`}
                          aria-current={p === page ? "page" : undefined}
                          onClick={() => setPage(p)}
                        >
                          {p}
                        </button>
                      </span>
                    );
                  })}
                </div>
                <button
                  type="button"
                  className="user-mgmt-page-btn"
                  disabled={page >= totalPages}
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                >
                  Sau
                </button>
              </div>
            </footer>
          )}
        </section>

        <aside className="user-mgmt-detail">
          <div className="user-mgmt-detail-head">
            <h2 className="user-mgmt-detail-title">Chi tiết người dùng</h2>
          </div>

          {!selectedUser && (
            <div className="user-mgmt-detail-empty">
              <p>Chưa chọn người dùng</p>
              <span>Chọn một dòng trong bảng để xem hồ sơ và cache inspector.</span>
            </div>
          )}

          {selectedUser && (
            <>
              <div className="user-profile-card">
                <div className="user-profile-head">
                  <span
                    className="user-mgmt-avatar large"
                    style={{
                      "--avatar-hue": avatarHue(selectedUser.id),
                      background: `hsla(${avatarHue(selectedUser.id)}, 42%, 46%, 0.14)`,
                      borderColor: `hsla(${avatarHue(selectedUser.id)}, 52%, 58%, 0.32)`,
                      color: `hsl(${avatarHue(selectedUser.id)}, 68%, 72%)`,
                    }}
                  >
                    {initials(selectedUser.username, selectedUser.email)}
                  </span>
                  <div>
                    <h3 className="user-profile-name">{selectedUser.username || "Chưa đặt tên"}</h3>
                    <p className="user-profile-email">{selectedUser.email}</p>
                  </div>
                  <span className={`user-status-pill ${selectedUser.isActive ? "ok" : "off"}`}>
                    {selectedUser.isActive ? "Active" : "Inactive"}
                  </span>
                </div>

                <dl className="user-profile-grid">
                  <div>
                    <dt>Nhóm tuổi</dt>
                    <dd>{selectedUser.ageGroup || inspector?.ageGroup || "Chưa khai báo"}</dd>
                  </div>
                  <div>
                    <dt>Nhóm việc làm</dt>
                    <dd>{selectedUser.jobType || inspector?.jobType || "Chưa khai báo"}</dd>
                  </div>
                  <div>
                    <dt>Đăng nhập bằng</dt>
                    <dd>
                      <span className={`user-auth-badge ${selectedUser.authProvider?.toLowerCase() || "unknown"}`}>
                        {authLabel(selectedUser.authProvider || inspector?.authProvider)}
                      </span>
                    </dd>
                  </div>
                  <div>
                    <dt>Vai trò</dt>
                    <dd>{selectedUser.role || "user"}</dd>
                  </div>
                  <div>
                    <dt>Ngày tạo</dt>
                    <dd>{formatDate(selectedUser.createdAt || inspector?.createdAt)}</dd>
                  </div>
                  <div>
                    <dt>User ID</dt>
                    <dd><code className="mono">{selectedUser.id}</code></dd>
                  </div>
                </dl>
              </div>

              <div className="user-profile-actions" style={{ marginTop: "16px", padding: "16px", background: "white", borderRadius: "12px", border: "1px solid #f1f5f9" }}>
                <h4 style={{ fontWeight: "600", fontSize: "14px", marginBottom: "12px", color: "#1e293b" }}>Xuất dữ liệu chi tiêu (Excel/CSV)</h4>
                <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
                  <a
                    href={`${import.meta.env.VITE_API_BASE_URL || "http://localhost:4000"}/api/admin/transactions/export?userId=${selectedUser.id}&period=day`}
                    download
                    className="user-mgmt-page-btn"
                    style={{ textDecoration: "none", fontSize: "12px", padding: "6px 12px", textAlign: "center" }}
                  >
                    📅 Hôm nay
                  </a>
                  <a
                    href={`${import.meta.env.VITE_API_BASE_URL || "http://localhost:4000"}/api/admin/transactions/export?userId=${selectedUser.id}&period=week`}
                    download
                    className="user-mgmt-page-btn"
                    style={{ textDecoration: "none", fontSize: "12px", padding: "6px 12px", textAlign: "center" }}
                  >
                    🗓️ Tuần này
                  </a>
                  <a
                    href={`${import.meta.env.VITE_API_BASE_URL || "http://localhost:4000"}/api/admin/transactions/export?userId=${selectedUser.id}&period=month`}
                    download
                    className="user-mgmt-page-btn"
                    style={{ textDecoration: "none", fontSize: "12px", padding: "6px 12px", textAlign: "center" }}
                  >
                    📊 Tháng này
                  </a>
                  <a
                    href={`${import.meta.env.VITE_API_BASE_URL || "http://localhost:4000"}/api/admin/transactions/export?userId=${selectedUser.id}&period=all`}
                    download
                    className="user-mgmt-page-btn primary"
                    style={{ textDecoration: "none", fontSize: "12px", padding: "6px 12px", textAlign: "center", background: "#0d9488", color: "white" }}
                  >
                    📥 Tất cả
                  </a>
                </div>
              </div>

              {inspectorError && <div className="user-mgmt-error">{inspectorError}</div>}

              <div className="user-inspector-wrap">
                <UserCacheInspector
                  userId={selectedId}
                  data={inspector}
                  loading={inspectorLoading}
                  onRefresh={() => loadInspector(selectedId)}
                />
              </div>
            </>
          )}
        </aside>
      </div>
    </div>
  );
}

export default UserManagementPage;
