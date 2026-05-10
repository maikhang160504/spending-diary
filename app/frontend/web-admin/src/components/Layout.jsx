import { Link, NavLink, Outlet } from "react-router-dom";

const navItems = [
  { path: "/", label: "Dashboard" },
  { path: "/users", label: "Quan ly user" },
  { path: "/expenses", label: "Xem chi tieu" },
  { path: "/categories", label: "Quan ly danh muc" },
  { path: "/ai-logs", label: "Xem log AI" }
];

function Layout() {
  return (
    <div className="app-shell">
      <header className="topbar">
        <Link to="/" className="brand">
          SpendAI Admin
        </Link>
      </header>
      <div className="content-wrap">
        <aside className="sidebar">
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
