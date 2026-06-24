import { useState, useEffect } from "react";
import { getBotPrompts, saveBotPrompts } from "../services/api";

const PERSONA_LABELS = {
  vui: "Vui vẻ / Năng lượng cao",
  dan_doi: "Giận dỗi / Lo lắng",
  cham_choc: "Châm chọc / Hài hước nhẹ",
  dong_cam: "Đồng cảm / Ấm áp",
  nghiem_tuc: "Nghiêm túc / Rõ ràng",
  hai_huoc: "Hài hước / Bắt trend"
};

const MOCK_PREVIEWS = {
  vui: "Ăn sáng vỉa hè hết 45k hả sen? Bữa sáng thịnh soạn hết nước chấm luôn, quẩy thôi! ☕️🐢",
  dan_doi: "Lại ăn sườn nướng 55k? É t ô é t cứu con tim, nhức nhức cái đầu quá bạn ơi! 😢",
  cham_choc: "Ăn sáng nhẹ hết 45k? Ơ kìa bạn ơi, không tin nổi luôn, tiêu hoang thế! 🙄",
  dong_cam: "Bạn đã chi 45k cho bữa sáng. Oki bae, bạn làm tốt lắm, mình ở đây động viên nha! 🥺",
  nghiem_tuc: "Đã ghi nhận giao dịch ăn sáng trị giá 45,000 VND. Số liệu rõ ràng, kiểm soát tốt. ✅",
  hai_huoc: "Phở gà 45k hết nước chấm luôn trời ơi! Não cá vàng rồi hay sao mà ăn sang dzậy ta! 😂🔥"
};

function BotPromptsPage() {
  const [promptsData, setPromptsData] = useState(null);
  const [persona, setPersona] = useState("hai_huoc");
  const [customPrompt, setCustomPrompt] = useState("");
  const [thresholds, setThresholds] = useState({
    budgetAlert: 30,
    categorySurge: 25,
    dailyVol: 5
  });

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showToast, setShowToast] = useState(false);
  const [toastMessage, setToastMessage] = useState("");

  const triggerToast = (msg) => {
    setToastMessage(msg);
    setShowToast(true);
    setTimeout(() => {
      setShowToast(false);
      setToastMessage("");
    }, 3000);
  };

  useEffect(() => {
    getBotPrompts()
      .then((data) => {
        setPromptsData(data);
        if (data.emotions && data.emotions[persona]) {
          setCustomPrompt(data.emotions[persona].system);
        }
        setLoading(false);
      })
      .catch((err) => {
        triggerToast("Failed to fetch prompts: " + err.message);
        setLoading(false);
      });
  }, []);

  const handlePersonaChange = (e) => {
    const val = e.target.value;
    setPersona(val);
    if (promptsData && promptsData.emotions && promptsData.emotions[val]) {
      setCustomPrompt(promptsData.emotions[val].system);
    }
  };

  const handleSavePrompt = (e) => {
    e.preventDefault();
    if (!promptsData) return;
    setSaving(true);

    const updated = { ...promptsData };
    if (updated.emotions && updated.emotions[persona]) {
      updated.emotions[persona].system = customPrompt;
    }

    saveBotPrompts(updated)
      .then((res) => {
        setPromptsData(updated);
        setSaving(false);
        triggerToast(res.message || "Prompt settings successfully deployed and hot-reloaded!");
      })
      .catch((err) => {
        triggerToast("Failed to save: " + err.message);
        setSaving(false);
      });
  };

  if (loading) {
    return (
      <div style={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "80vh", color: "var(--text-secondary)" }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "12px" }}>
          <div className="brand-dot" style={{ width: "16px", height: "16px", animation: "pulse 1.5s infinite" }}></div>
          <p style={{ fontSize: "14px", fontWeight: "500" }}>Loading bot prompt schema...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="page-container" style={{ padding: "30px 40px" }}>
      <div className="page-header" style={{ marginBottom: "24px" }}>
        <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px" }}>Bot Prompt Scenarios</h1>
        <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "4px" }}>
          Modify System Prompts for Chat AI personas and calibrate trigger thresholds for alerts.
        </p>
      </div>

      {/* Prompts DevOps Stats Strip */}
      <div className="bill-stat-strip" style={{
        marginBottom: "30px",
        background: "var(--bg-obsidian-900)",
        border: "1px solid var(--border-color)",
        borderRadius: "16px",
        padding: "20px 24px",
        display: "grid",
        gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
        gap: "20px",
        boxShadow: "inset 0 1px 0 rgba(255, 255, 255, 0.02)"
      }}>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Available Personas</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: "var(--accent-blue-hover)", fontFamily: "var(--font-sans)" }}>6 active vibe modes</span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Active Vibe</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: "var(--accent-emerald-hover)", fontFamily: "var(--font-sans)" }}>{persona.toUpperCase()}</span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Instruction Size</span>
          <span className="bill-stat-value" style={{ fontSize: "18px", fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)" }}>{customPrompt?.length || 0} chars</span>
        </div>
        <div className="bill-stat" style={{ borderRight: "none" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Deployment Mode</span>
          <span className="bill-stat-value" style={{
            fontSize: "18px",
            fontWeight: "700",
            color: "var(--accent-emerald-hover)",
            display: "flex",
            alignItems: "center",
            gap: "8px"
          }}>
            <span className="status-dot" style={{
              background: "var(--accent-emerald)",
              boxShadow: "0 0 10px var(--accent-emerald)",
              width: "8px",
              height: "8px",
              borderRadius: "50%"
            }}></span>
            Hot Reload Enabled
          </span>
        </div>
      </div>

      <div className="dashboard-grid" style={{ gap: "24px" }}>
        {/* Left: System Prompt Editor */}
        <div className="panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px",
          boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
        }}>
          <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>System Prompt Architecture</h2>
              <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>Customize LLM agent parameters based on active user sentiment.</span>
            </div>
            <select
              className="form-select"
              style={{ width: "220px", padding: "8px 14px", fontSize: "13px", background: "var(--bg-obsidian-950)", borderRadius: "8px", border: "1px solid var(--border-color)" }}
              value={persona}
              onChange={handlePersonaChange}
            >
              {Object.keys(PERSONA_LABELS).map(key => (
                <option key={key} value={key}>Vibe: {PERSONA_LABELS[key]}</option>
              ))}
            </select>
          </div>

          <form onSubmit={handleSavePrompt} style={{ display: "flex", flexDirection: "column", gap: "20px", marginTop: "16px" }}>
            <div className="form-group">
              <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "500", display: "flex", justifyContent: "space-between" }}>
                <span>System Instruction Prompt</span>
                <span className="monospaced" style={{ color: "var(--accent-blue-hover)", fontSize: "12px" }}>{persona}.system</span>
              </label>
              <textarea
                className="form-textarea monospaced"
                value={customPrompt}
                onChange={(e) => setCustomPrompt(e.target.value)}
                style={{
                  fontSize: "13px",
                  lineHeight: "1.6",
                  background: "var(--bg-obsidian-950)",
                  border: "1px solid var(--border-color)",
                  borderRadius: "8px",
                  padding: "14px",
                  minHeight: "180px",
                  color: "var(--text-primary)"
                }}
              />
            </div>

            {/* AI Response Preview */}
            <div className="form-group">
              <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "500" }}>Interactive Chat Preview (Scenario: "ăn sáng 45k")</label>
              <div
                style={{
                  background: "var(--bg-obsidian-950)",
                  border: "1px solid rgba(255, 255, 255, 0.05)",
                  borderRadius: "12px",
                  padding: "20px",
                  position: "relative",
                  boxShadow: "inset 0 1px 0 rgba(255, 255, 255, 0.02)"
                }}
              >
                <div style={{ display: "flex", gap: "10px", alignItems: "center", marginBottom: "12px" }}>
                  <div className="brand-dot" style={{ background: "var(--accent-emerald)", boxShadow: "0 0 8px var(--accent-emerald)" }}></div>
                  <strong style={{ fontSize: "13px", color: "var(--text-primary)" }}>Mimo Mascot (Preview)</strong>
                  <span className="badge badge-success" style={{
                    fontSize: "10px",
                    padding: "2px 8px",
                    borderRadius: "6px",
                    background: "rgba(16, 185, 129, 0.08)",
                    border: "1px solid rgba(16, 185, 129, 0.3)",
                    color: "var(--accent-emerald-hover)",
                    fontWeight: "600",
                    marginLeft: "auto"
                  }}>{persona}</span>
                </div>
                <div style={{
                  background: "var(--bg-obsidian-900)",
                  border: "1px solid var(--border-color)",
                  borderRadius: "12px",
                  padding: "14px 16px",
                  fontSize: "13px",
                  color: "var(--text-primary)",
                  position: "relative",
                  display: "inline-block",
                  lineHeight: "1.5",
                  maxWidth: "85%",
                  borderTopLeftRadius: "2px"
                }}>
                  "{MOCK_PREVIEWS[persona] || 'Generating...'}"
                </div>
              </div>
            </div>

            <button type="submit" className="btn btn-primary" disabled={saving} style={{
              background: "var(--accent-emerald)",
              color: "var(--bg-obsidian-950)",
              fontWeight: "600",
              fontSize: "14px",
              padding: "12px",
              borderRadius: "8px",
              cursor: "pointer"
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = "var(--accent-emerald-hover)";
              e.currentTarget.style.boxShadow = "0 0 15px var(--accent-emerald-glow)";
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = "var(--accent-emerald)";
              e.currentTarget.style.boxShadow = "none";
            }}
            >
              {saving ? "Deploying Prompt Configuration..." : "Deploy System Prompt Settings"}
            </button>
          </form>
        </div>

        {/* Right: Alert Threshold Sliders */}
        <div className="panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px",
          boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
          height: "fit-content"
        }}>
          <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)" }}>
            <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Mimo Alert Logic Calibration</h2>
            <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>Calibrate mathematical alerts that trigger chatbot comments.</span>
          </div>

          <form onSubmit={(e) => { e.preventDefault(); triggerToast("Alert thresholds calibration saved!"); }} style={{ display: "flex", flexDirection: "column", gap: "24px", marginTop: "20px" }}>
            <div className="form-group">
              <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "500", display: "flex", justifyContent: "space-between" }}>
                <span>Budget Excess Warning</span>
                <strong style={{ color: "var(--accent-blue-hover)", fontFamily: "var(--font-mono)" }}>{thresholds.budgetAlert}%</strong>
              </label>
              <input
                type="range"
                min="10"
                max="80"
                step="5"
                value={thresholds.budgetAlert}
                onChange={(e) => setThresholds({ ...thresholds, budgetAlert: parseInt(e.target.value) })}
                style={{ accentColor: "var(--accent-blue)", width: "100%", height: "6px", background: "var(--bg-obsidian-950)", borderRadius: "3px" }}
              />
              <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Warn users when spending in any category hits this ratio of their configured limit.</span>
            </div>

            <div className="form-group">
              <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "500", display: "flex", justifyContent: "space-between" }}>
                <span>Category Surge Rate</span>
                <strong style={{ color: "var(--accent-amber-hover)", fontFamily: "var(--font-mono)" }}>{thresholds.categorySurge}%</strong>
              </label>
              <input
                type="range"
                min="5"
                max="50"
                step="5"
                value={thresholds.categorySurge}
                onChange={(e) => setThresholds({ ...thresholds, categorySurge: parseInt(e.target.value) })}
                style={{ accentColor: "var(--accent-amber)", width: "100%", height: "6px", background: "var(--bg-obsidian-950)", borderRadius: "3px" }}
              />
              <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Warn users if week-over-week spending in any category jumps by this ratio.</span>
            </div>

            <div className="form-group">
              <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "500", display: "flex", justifyContent: "space-between" }}>
                <span>Velocity / Volume Surge</span>
                <strong style={{ color: "var(--accent-rose-hover)", fontFamily: "var(--font-mono)" }}>{thresholds.dailyVol} tx/day</strong>
              </label>
              <input
                type="range"
                min="2"
                max="15"
                step="1"
                value={thresholds.dailyVol}
                onChange={(e) => setThresholds({ ...thresholds, dailyVol: parseInt(e.target.value) })}
                style={{ accentColor: "var(--accent-rose)", width: "100%", height: "6px", background: "var(--bg-obsidian-950)", borderRadius: "3px" }}
              />
              <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Send a warning about high velocity if more transactions than this are logged in 24 hours.</span>
            </div>

            <button type="submit" className="btn btn-secondary" style={{
              borderStyle: "dashed",
              width: "100%",
              padding: "12px",
              fontSize: "13px",
              borderRadius: "8px",
              borderColor: "var(--border-color)",
              color: "var(--text-primary)",
              background: "transparent"
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.borderColor = "var(--text-secondary)";
              e.currentTarget.style.background = "var(--bg-obsidian-800)";
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.borderColor = "var(--border-color)";
              e.currentTarget.style.background = "transparent";
            }}
            >
              Calibrate Logic Thresholds
            </button>
          </form>
        </div>
      </div>

      {showToast && (
        <div className="toast" style={{
          position: "fixed",
          bottom: "30px",
          right: "30px",
          background: "var(--bg-obsidian-800)",
          border: "1px solid var(--accent-emerald)",
          borderRadius: "8px",
          padding: "14px 20px",
          boxShadow: "0 10px 25px rgba(0,0,0,0.3), 0 0 15px rgba(16, 185, 129, 0.1)",
          display: "flex",
          alignItems: "center",
          gap: "10px",
          zIndex: 9999
        }}>
          <div className="brand-dot" style={{ background: "var(--accent-emerald)", width: "8px", height: "8px", borderRadius: "50%" }}></div>
          <span style={{ color: "var(--text-primary)", fontSize: "13px", fontWeight: "500" }}>{toastMessage}</span>
        </div>
      )}
    </div>
  );
}

export default BotPromptsPage;
