import { useCallback, useEffect, useRef, useState } from "react";

const API = import.meta.env.VITE_API_BASE_URL || "http://localhost:4000";

function formatVND(amount) {
  return new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND" }).format(amount || 0);
}

function formatDate(value) {
  if (!value) return "—";
  return new Date(value).toLocaleString("vi-VN", {
    day: "2-digit", month: "2-digit", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

async function fetchAPI(path) {
  const res = await fetch(`${API}${path}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const json = await res.json();
  return json.data ?? json;
}

async function toggleUserPremium(userId, isPremium) {
  const res = await fetch(`${API}/api/admin/users/${userId}/premium`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ isPremium }),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

// ─── Mini Line Chart (SVG) ────────────────────────────────────────────────
function RevenueChart({ data }) {
  if (!data || data.length === 0) {
    return <div style={{ height: 160, display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-muted)", fontSize: 13 }}>Chưa có dữ liệu</div>;
  }

  const W = 700, H = 180, PAD = { t: 20, r: 20, b: 32, l: 60 };
  const maxVal = Math.max(...data.map((d) => d.revenue), 1);
  const chartW = W - PAD.l - PAD.r;
  const chartH = H - PAD.t - PAD.b;
  const step = chartW / (data.length - 1 || 1);

  const pts = data.map((d, i) => ({
    x: PAD.l + i * step,
    y: PAD.t + chartH - (d.revenue / maxVal) * chartH,
    ...d,
  }));

  const pathD = pts.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" ");
  const areaD = `${pathD} L ${pts[pts.length - 1].x.toFixed(1)} ${(PAD.t + chartH).toFixed(1)} L ${PAD.l} ${(PAD.t + chartH).toFixed(1)} Z`;

  const [hovered, setHovered] = useState(null);

  return (
    <div style={{ position: "relative", overflowX: "auto" }} onMouseLeave={() => setHovered(null)}>
      <svg viewBox={`0 0 ${W} ${H}`} style={{ width: "100%", height: "100%" }} preserveAspectRatio="none">
        <defs>
          <linearGradient id="rev-grad-pro" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--accent-emerald)" stopOpacity="0.32" />
            <stop offset="100%" stopColor="var(--accent-emerald)" stopOpacity="0" />
          </linearGradient>
        </defs>

        {/* Grid lines */}
        {[0, 0.25, 0.5, 0.75, 1].map((t) => {
          const y = PAD.t + chartH * (1 - t);
          return (
            <g key={t}>
              <line x1={PAD.l} y1={y} x2={W - PAD.r} y2={y} stroke="var(--border-color)" strokeWidth={0.5} strokeDasharray="3 3" />
              <text x={PAD.l - 12} y={y + 4} textAnchor="end" fontSize={10} fill="var(--text-secondary)" fontFamily="var(--font-mono)">
                {formatVND(maxVal * t).replace("₫", "").trim()}
              </text>
            </g>
          );
        })}

        {/* Area + Line */}
        <path d={areaD} fill="url(#rev-grad-pro)" />
        <path d={pathD} fill="none" stroke="var(--accent-emerald)" strokeWidth={2.8} strokeLinecap="round" strokeLinejoin="round" />

        {/* Dots */}
        {pts.map((p, i) => {
          const isHovered = hovered === i;
          return (
            <g key={i} onMouseEnter={() => setHovered(i)} style={{ cursor: "pointer" }}>
              {isHovered && (
                <line x1={p.x} y1={PAD.t} x2={p.x} y2={PAD.t + chartH} stroke="var(--accent-emerald)" strokeWidth="1" strokeDasharray="3 3" opacity="0.7" />
              )}
              <circle
                cx={p.x} cy={p.y} r={isHovered ? "6" : "3.5"}
                fill="var(--bg-obsidian-950)"
                stroke="var(--accent-emerald)"
                strokeWidth={isHovered ? "3" : "2"}
                style={{ transition: "all 0.15s ease" }}
              />
            </g>
          );
        })}

        {/* X-axis labels (every 5th) */}
        {pts.map((p, i) => {
          if (data.length > 10 && i % 5 !== 0 && i !== data.length - 1) return null;
          return (
            <text key={i} x={p.x} y={H - 10} textAnchor="middle" fontSize={10} fill="var(--text-secondary)" fontFamily="var(--font-mono)">
              {p.date}
            </text>
          );
        })}
      </svg>

      {/* Tooltip */}
      {hovered !== null && pts[hovered] && (
        <div className="pro-max-tooltip" style={{
          position: "absolute",
          top: pts[hovered].y - 60,
          left: Math.min(pts[hovered].x, W - 140) + "px",
        }}>
          <div style={{ fontSize: "11px", color: "var(--text-secondary)", marginBottom: "3px" }}>
            {pts[hovered].date}
          </div>
          <div style={{ fontSize: "14px", fontWeight: "700", color: "var(--accent-emerald)", fontFamily: "var(--font-mono)" }}>
            {formatVND(pts[hovered].revenue)}
          </div>
          <div style={{ fontSize: "11px", color: "var(--text-muted)", marginTop: "2px" }}>
            {pts[hovered].orders} đơn hoàn thành
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Status Badge ─────────────────────────────────────────────────────────
function OrderStatusBadge({ status }) {
  const map = {
    completed: { label: "Hoàn thành", color: "var(--accent-emerald)", bg: "rgba(16,185,129,0.12)" },
    pending:   { label: "Chờ TT",     color: "var(--accent-amber)", bg: "rgba(245,158,11,0.12)" },
    cancelled: { label: "Đã hủy",     color: "var(--text-muted)", bg: "rgba(107,114,128,0.12)" },
  };
  const s = map[status] || { label: status, color: "var(--text-muted)", bg: "rgba(107,114,128,0.12)" };
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", padding: "4px 10px", borderRadius: "12px",
      fontSize: "11px", fontWeight: "600", color: s.color, background: s.bg, letterSpacing: "0.2px"
    }}>
      {status === 'completed' && <span style={{ width: 6, height: 6, borderRadius: '50%', background: s.color, marginRight: 6 }}></span>}
      {status === 'pending' && <span style={{ width: 6, height: 6, borderRadius: '50%', background: s.color, marginRight: 6, animation: "pulse 1.5s infinite" }}></span>}
      {s.label}
    </span>
  );
}

// ─── Main Page ────────────────────────────────────────────────────────────
export default function MonetizationPage() {
  const [stats, setStats]       = useState(null);
  const [history, setHistory]   = useState([]);
  const [orders, setOrders]     = useState([]);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState("");
  const [toggling, setToggling] = useState({});
  const refreshTimer = useRef(null);

  const loadAll = useCallback(async () => {
    try {
      const [s, h, o] = await Promise.all([
        fetchAPI("/api/admin/monetization/stats"),
        fetchAPI("/api/admin/monetization/history?days=30"),
        fetchAPI("/api/admin/monetization/orders?limit=100"),
      ]);
      setStats(s);
      setHistory(Array.isArray(h) ? h : []);
      setOrders(Array.isArray(o) ? o : []);
      setError("");
    } catch (err) {
      setError(err.message || "Không thể tải dữ liệu");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAll();
    refreshTimer.current = setInterval(loadAll, 30_000);
    return () => clearInterval(refreshTimer.current);
  }, [loadAll]);

  const handleTogglePremium = async (userId, currentPremium) => {
    setToggling((p) => ({ ...p, [userId]: true }));
    try {
      await toggleUserPremium(userId, !currentPremium);
      // Update local orders list
      setOrders((prev) =>
        prev.map((o) => o.userId === userId ? { ...o, isPremium: !currentPremium } : o)
      );
      await loadAll(); // Refresh stats
    } catch (err) {
      alert("Lỗi: " + err.message);
    } finally {
      setToggling((p) => ({ ...p, [userId]: false }));
    }
  };

  if (loading && !stats) {
    return (
      <div style={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "80vh", color: "var(--text-secondary)" }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "12px" }}>
          <div className="brand-dot" style={{ width: "16px", height: "16px", animation: "pulse 1.5s infinite" }}></div>
          <p style={{ fontSize: "14px", fontWeight: "500" }}>Loading monetization data...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="page-container" style={{ padding: "30px 40px" }}>
      {/* Header */}
      <div className="page-header" style={{ marginBottom: "30px", display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
        <div>
          <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px", display: "flex", alignItems: "center", gap: "12px" }}>
            Monetization
            <span className="badge badge-success" style={{ padding: "4px 10px", fontSize: "12px", background: "rgba(16, 185, 129, 0.12)", color: "var(--accent-emerald)", borderRadius: "12px", fontWeight: "600", letterSpacing: "normal" }}>Live</span>
          </h1>
          <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "8px" }}>
            Theo dõi dòng tiền Premium, phân tích doanh thu và quản lý khách hàng VIP.
          </p>
        </div>
        <button
          onClick={loadAll}
          disabled={loading}
          className="btn btn-sm"
          style={{
            background: "rgba(255, 255, 255, 0.05)",
            color: "var(--text-primary)",
            border: "1px solid var(--border-color)",
            padding: "8px 16px",
            borderRadius: "8px",
            fontWeight: "500",
            cursor: loading ? "not-allowed" : "pointer",
            fontSize: "13px",
            transition: "all 0.2s"
          }}
          onMouseEnter={(e) => !loading && (e.currentTarget.style.background = "rgba(255, 255, 255, 0.1)")}
          onMouseLeave={(e) => !loading && (e.currentTarget.style.background = "rgba(255, 255, 255, 0.05)")}
        >
          {loading ? "Đang đồng bộ..." : "Đồng bộ dữ liệu"}
        </button>
      </div>

      {error && (
        <div className="toast" style={{ borderColor: "var(--accent-rose)", position: "relative", marginBottom: "20px" }}>
          <span>Error: {error}</span>
        </div>
      )}

      {/* ── Stats Cards ── */}
      <div className="metrics-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))", gap: "20px", marginBottom: "30px" }}>
        {[
          { label: "Tổng doanh thu", value: formatVND(stats?.totalRevenue), color: "var(--accent-emerald)" },
          { label: "Doanh thu tháng này", value: formatVND(stats?.monthlyRevenue), color: "var(--accent-blue)" },
          { label: "Số đơn hoàn thành", value: stats?.totalOrders ?? "—", color: "var(--accent-amber)" },
          { label: "User Premium", value: stats?.premiumUserCount ?? "—", color: "#a855f7" },
        ].map((card, idx) => (
          <div key={card.label} className="metric-card" style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px", position: "relative" }}>
            <span className="metric-indicator" style={{ position: "absolute", top: "24px", left: "24px", width: "8px", height: "8px", borderRadius: "50%", background: card.color, boxShadow: `0 0 10px ${card.color}` }}></span>
            <span className="metric-label" style={{ display: "block", fontSize: "13px", color: "var(--text-secondary)", marginBottom: "8px", paddingLeft: "16px" }}>{card.label}</span>
            <span className="metric-value" style={{ display: "block", fontSize: "28px", fontWeight: "700", color: "var(--text-primary)" }}>
              {loading && !stats ? "..." : card.value}
            </span>
          </div>
        ))}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr", gap: "30px", marginBottom: "30px" }}>
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
            <RevenueChart data={history} />
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
                100 giao dịch SePay gần nhất ({orders.length} bản ghi).
              </p>
            </div>
            <span style={{ fontSize: "12px", color: "var(--text-muted)", display: "flex", alignItems: "center", gap: "6px" }}>
              <span style={{ width: "6px", height: "6px", borderRadius: "50%", background: "var(--accent-emerald)", animation: "pulse 2s infinite" }}></span>
              Tự động làm mới
            </span>
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
                {orders.length === 0 && !loading && (
                  <tr>
                    <td colSpan={7} style={{ padding: "40px 24px", textAlign: "center", color: "var(--text-muted)", fontSize: "13px" }}>
                      Chưa có giao dịch nào
                    </td>
                  </tr>
                )}
                {orders.map((order) => (
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
                        disabled={toggling[order.userId]}
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
                        onMouseEnter={(e) => {
                          if (!order.isPremium) {
                            e.currentTarget.style.borderColor = "rgba(168, 85, 247, 0.5)";
                            e.currentTarget.style.color = "#a855f7";
                          }
                        }}
                        onMouseLeave={(e) => {
                          if (!order.isPremium) {
                            e.currentTarget.style.borderColor = "var(--border-color)";
                            e.currentTarget.style.color = "var(--text-primary)";
                          }
                        }}
                      >
                        {toggling[order.userId] ? "..." : order.isPremium ? "Hạ quyền" : "Cấp Premium"}
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
  );
}

