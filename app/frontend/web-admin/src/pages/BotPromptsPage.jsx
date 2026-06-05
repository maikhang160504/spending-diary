import { useState, useEffect } from "react";
import { getBotPrompts, saveBotPrompts } from "../services/api";

const PERSONA_LABELS = {
  vui: "Vui vẻ / Năng lượng cao",
  dan_doi: "Dận dỗi / Lo lắng",
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
      <div style={{ padding: "40px", textAlign: "center", color: "var(--text-secondary)" }}>
        <p>Loading bot prompt metadata...</p>
      </div>
    );
  }

  return (
    <div className="page-container">
      <div className="page-header">
        <h1 className="page-title">Bot Prompt Scenarios</h1>
        <p className="page-desc">Modify System Prompts for Chat AI personas and calibrate trigger thresholds for alerts.</p>
      </div>

      <div className="dashboard-grid">
        {/* Left: System Prompt Editor */}
        <div className="panel">
          <div className="panel-header">
            <h2 className="panel-title">System Prompt Manager</h2>
            <select
              className="form-select"
              style={{ width: "200px", padding: "6px 12px", fontSize: "13px" }}
              value={persona}
              onChange={handlePersonaChange}
            >
              {Object.keys(PERSONA_LABELS).map(key => (
                <option key={key} value={key}>Vibe: {PERSONA_LABELS[key]}</option>
              ))}
            </select>
          </div>

          <form onSubmit={handleSavePrompt} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
            <div className="form-group">
              <label className="form-label">System Instruction Prompt</label>
              <textarea
                className="form-textarea monospaced"
                value={customPrompt}
                onChange={(e) => setCustomPrompt(e.target.value)}
                style={{ fontSize: "13px", lineHeight: "1.6" }}
              />
            </div>

            {/* AI Response Preview */}
            <div className="form-group">
              <label className="form-label">Mock Response Preview (For "ăn sáng 45k")</label>
              <div
                style={{
                  background: "var(--bg-obsidian-950)",
                  border: "1px solid var(--border-color)",
                  borderRadius: "8px",
                  padding: "16px",
                  position: "relative"
                }}
              >
                <div style={{ display: "flex", gap: "10px", alignItems: "center", marginBottom: "8px" }}>
                  <div className="brand-dot"></div>
                  <strong style={{ fontSize: "13px", color: "var(--text-primary)" }}>Mimo Bot (Preview)</strong>
                  <span className="badge badge-success" style={{ fontSize: "9px", padding: "1px 6px" }}>{persona}</span>
                </div>
                <p style={{ fontStyle: "italic", fontSize: "14px", color: "var(--text-primary)", paddingLeft: "16px", borderLeft: "2px solid var(--accent-emerald)" }}>
                  "{MOCK_PREVIEWS[persona] || 'Generating...'}"
                </p>
              </div>
            </div>

            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? "Deploying Prompts..." : "Deploy System Prompt"}
            </button>
          </form>
        </div>

        {/* Right: Alert Threshold Sliders */}
        <div className="panel">
          <div className="panel-header">
            <h2 className="panel-title">Story Alert Thresholds</h2>
          </div>

          <form onSubmit={(e) => { e.preventDefault(); triggerToast("Alert thresholds calibration saved!"); }} style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
            <div className="form-group">
              <label className="form-label">
                Budget Excess Warning Threshold ({thresholds.budgetAlert}%)
              </label>
              <input
                type="range"
                min="10"
                max="80"
                step="5"
                value={thresholds.budgetAlert}
                onChange={(e) => setThresholds({ ...thresholds, budgetAlert: parseInt(e.target.value) })}
                style={{ accentColor: "var(--accent-emerald)" }}
              />
              <span className="form-desc">Trigger story alarm when category spending exceeds budget allocation by this ratio.</span>
            </div>

            <div className="form-group">
              <label className="form-label">
                Category Surge Detection Threshold ({thresholds.categorySurge}%)
              </label>
              <input
                type="range"
                min="5"
                max="50"
                step="5"
                value={thresholds.categorySurge}
                onChange={(e) => setThresholds({ ...thresholds, categorySurge: parseInt(e.target.value) })}
                style={{ accentColor: "var(--accent-emerald)" }}
              />
              <span className="form-desc">Trigger advice block if category spending surges week-over-week.</span>
            </div>

            <div className="form-group">
              <label className="form-label">
                Anomaly Transaction Count Alert ({thresholds.dailyVol} tx/day)
              </label>
              <input
                type="range"
                min="2"
                max="15"
                step="1"
                value={thresholds.dailyVol}
                onChange={(e) => setThresholds({ ...thresholds, dailyVol: parseInt(e.target.value) })}
                style={{ accentColor: "var(--accent-emerald)" }}
              />
              <span className="form-desc">Warn user if transaction submissions exceed normal velocity.</span>
            </div>

            <button type="submit" className="btn btn-secondary" style={{ borderStyle: "dashed" }}>
              Save Alert Calibration
            </button>
          </form>
        </div>
      </div>

      {showToast && (
        <div className="toast">
          <div className="brand-dot"></div>
          <span>{toastMessage}</span>
        </div>
      )}
    </div>
  );
}

export default BotPromptsPage;
