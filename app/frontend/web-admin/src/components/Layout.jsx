import { useEffect, useState } from "react";
import { Link, NavLink, Outlet } from "react-router-dom";
import { fetchBillKaggleJob, getSystemStatus } from "../services/api";

const navItems = [
  { path: "/", label: "Fusion & AI Quality" },
  { path: "/bill-retrain", label: "Bill OCR Retrain" },
  { path: "/nlu-ops", label: "NLU & Retraining" },
  { path: "/users", label: "User Management" },
  { path: "/bot-prompts", label: "Bot Prompt Scenarios" },
];

const TERMINAL_JOB_STATUSES = new Set(["completed", "failed"]);

function useActiveKaggleRetrainJob() {
  const [activeJob, setActiveJob] = useState(null);

  useEffect(() => {
    let cancelled = false;

    const poll = async () => {
      const jobId = localStorage.getItem("active_kaggle_job_id");
      if (!jobId) {
        if (activeJob !== null) {
          setActiveJob(null);
        }
        return;
      }

      try {
        const job = await fetchBillKaggleJob(jobId);
        if (cancelled) return;
        if (!job || (job.status && TERMINAL_JOB_STATUSES.has(job.status))) {
          localStorage.removeItem("active_kaggle_job_id");
          setActiveJob(null);
        } else {
          setActiveJob(job);
        }
      } catch (err) {
        if (cancelled) return;
        const msg = String(err.message || "").toLowerCase();
        if (msg.includes("not found") || msg.includes("404") || msg.includes("failed")) {
          localStorage.removeItem("active_kaggle_job_id");
          setActiveJob(null);
        } else {
          if (!cancelled) setActiveJob(null);
        }
      }
    };

    poll();
    const timer = setInterval(poll, 10000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [activeJob]);

  return activeJob;
}

function useSystemStatus() {
  const [status, setStatus] = useState({
    nluOnline: false,
    nluVersion: "Loading...",
    nluLoaded: false,
    ocrLoaded: false,
  });

  useEffect(() => {
    let cancelled = false;
    const update = async () => {
      try {
        const res = await getSystemStatus();
        if (cancelled) return;
        setStatus(res);
      } catch {
        if (!cancelled) {
          setStatus({
            nluOnline: false,
            nluVersion: "v1.1-offline",
            nluLoaded: false,
            ocrLoaded: false,
          });
        }
      }
    };
    update();
    const timer = setInterval(update, 10000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, []);

  return status;
}

function Layout() {
  const activeKaggleJob = useActiveKaggleRetrainJob();
  const systemStatus = useSystemStatus();

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
            <span className="status-dot" style={{ backgroundColor: systemStatus.nluOnline ? "var(--accent-emerald)" : "var(--accent-rose)" }}></span>
            <span>NLU Core: {systemStatus.nluOnline ? "Online" : "Offline"}</span>
          </div>

          <div className="status-indicator" style={{ borderStyle: "dashed", borderColor: "rgba(2, 132, 199, 0.3)" }}>
            <span style={{ color: "var(--accent-blue-hover)" }}>Model: {systemStatus.nluVersion}</span>
            <span className="status-badge" style={{
              marginLeft: "6px",
              fontSize: "10px",
              padding: "2px 6px",
              borderRadius: "4px",
              background: systemStatus.nluLoaded ? "rgba(16, 185, 129, 0.15)" : "rgba(245, 158, 11, 0.15)",
              color: systemStatus.nluLoaded ? "var(--accent-emerald-hover)" : "var(--accent-amber-hover)",
              fontWeight: "600"
            }}>
              {systemStatus.nluLoaded ? "Loaded" : "Lazy Load"}
            </span>
          </div>

          <div className="status-indicator" style={{ borderStyle: "dashed", borderColor: "rgba(16, 185, 129, 0.3)" }}>
            <span style={{ color: "var(--text-secondary)" }}>OCR Engine</span>
            <span className="status-badge" style={{
              marginLeft: "6px",
              fontSize: "10px",
              padding: "2px 6px",
              borderRadius: "4px",
              background: systemStatus.ocrLoaded ? "rgba(16, 185, 129, 0.15)" : "rgba(245, 158, 11, 0.15)",
              color: systemStatus.ocrLoaded ? "var(--accent-emerald-hover)" : "var(--accent-amber-hover)",
              fontWeight: "600"
            }}>
              {systemStatus.ocrLoaded ? "Loaded" : "Lazy Load"}
            </span>
          </div>
        </div>
      </header>
      <nav className="app-nav" aria-label="Operations">
        <span className="app-nav-label">Operations</span>
        <div className="app-nav-track">
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
        </div>
      </nav>
      <main className="main-content">
        <Outlet />
      </main>
    </div>
  );
}

export default Layout;
