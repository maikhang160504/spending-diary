import { Link, NavLink, Outlet } from "react-router-dom";

const navItems = [
  { path: "/", label: "Fusion & AI Quality" },
  { path: "/nlu-ops", label: "NLU & Retraining" },
  { path: "/user-inspector", label: "User Cache Inspector" },
  { path: "/bot-prompts", label: "Bot Prompt Scenarios" }
];

function Layout() {
  return (
    <div className="app-shell">
      <header className="topbar">
        <Link to="/" className="brand">
          <span className="brand-dot"></span>
          SpendAI Cockpit
        </Link>
        <div className="system-status">
          <div className="status-indicator">
            <span className="status-dot"></span>
            <span>NLU Core: Online</span>
          </div>
          <div className="status-indicator" style={{ borderStyle: "dashed" }}>
            <span style={{ color: "var(--accent-blue)" }}>Model: v2.4-global</span>
          </div>
        </div>
      </header>
      <div className="content-wrap">
        <aside className="sidebar">
          <div className="sidebar-title">Operations</div>
          {navItems.map((item) => (
            <NavLink key={item.path} to={item.path} end className="nav-item">
              {item.label}
            </NavLink>
          ))}
        </aside>
        <main className="main-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

export default Layout;
