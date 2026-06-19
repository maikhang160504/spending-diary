import { useEffect, useState } from "react";
import { Link, NavLink, Outlet } from "react-router-dom";
import { fetchBillKaggleJobs } from "../services/api";

const navItems = [
  { path: "/", label: "Fusion & AI Quality" },
  { path: "/bill-retrain", label: "Bill OCR Retrain" },
  { path: "/nlu-ops", label: "NLU & Retraining" },
  { path: "/user-inspector", label: "User Cache Inspector" },
  { path: "/bot-prompts", label: "Bot Prompt Scenarios" },
];

const TERMINAL_JOB_STATUSES = new Set(["completed", "failed"]);

function useActiveKaggleRetrainJob() {
  const [activeJob, setActiveJob] = useState(null);

  useEffect(() => {
    let cancelled = false;

    const poll = async () => {
      try {
        const jobs = await fetchBillKaggleJobs(12);
        if (cancelled) return;
        const running = jobs.find((j) => j.status && !TERMINAL_JOB_STATUSES.has(j.status));
        setActiveJob(running || null);
      } catch {
        if (!cancelled) setActiveJob(null);
      }
    };

    poll();
    const timer = setInterval(poll, 10000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, []);

  return activeJob;
}

function Layout() {
  const activeKaggleJob = useActiveKaggleRetrainJob();
  const jobShortId = (activeKaggleJob?.id || activeKaggleJob?.job_id || "").slice(0, 8);
  const jobStatus = activeKaggleJob?.status?.replace(/_/g, " ") || "running";

  return (
    <div className="app-shell">
      <header className="topbar">
        <Link to="/" className="brand">
          <span className="brand-dot"></span>
          SpendAI Cockpit
        </Link>
        <div className="system-status">
          {activeKaggleJob && (
            <Link to="/bill-retrain" className="retrain-running-badge" title={`Kaggle job ${jobShortId} — ${jobStatus}`}>
              <span className="retrain-running-dot" />
              <span>Retrain đang chạy</span>
              <code>{jobShortId}</code>
            </Link>
          )}
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
              <span className="nav-item-label">{item.label}</span>
              {item.path === "/bill-retrain" && activeKaggleJob && (
                <span className="nav-retrain-badge" title={`Kaggle ${jobStatus}`}>
                  GPU
                </span>
              )}
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
