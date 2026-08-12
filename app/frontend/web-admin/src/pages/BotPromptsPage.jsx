import { useState, useEffect } from "react";
import { getBotPrompts, saveBotPrompts, getSystemSettings, saveSystemSettings, testSystemPrompt } from "../services/api";

const PERSONA_LABELS = {
  dui_de: "Dui dẻ / Vui vẻ",
  dan_doi: "Dận dỗi / Hay khóc",
  kho_tinh: "Khó tính / Kỷ luật",
  ngot_ngao: "Ngọt ngào / Chữa lành"
};

const PERSONA_ICONS = {
  dui_de: "😎🎉",
  dan_doi: "🥺😭",
  kho_tinh: "🔥😠",
  ngot_ngao: "💖🥰"
};

const MOCK_PREVIEWS = {
  dui_de: "Ăn sáng vỉa hè hết 45k hả sen? Bữa sáng thịnh soạn hết nước chấm luôn, quẩy thôi! ☕️🔥",
  dan_doi: "Lại ăn sườn nướng 55k? Ét ô ét cứu con tim, nhức nhức cái đầu quá bạn ơi! 😢",
  kho_tinh: "Trời đất, ăn gì mà hết 55k một bữa vậy?! Bạn có biết 55k là bằng mấy ngày tiền đi chợ của người ta không?",
  ngot_ngao: "Thương bạn lắm nè, đói thì phải ăn ngon một bữa thôi, đừng tiếc nha, cưng xỉu luôn á! 🥰"
};

function BotPromptsPage() {
  const [promptsData, setPromptsData] = useState(null);
  const [systemSettings, setSystemSettings] = useState({
    llmTemperature: 0.7,
    llmTopK: 40,
    ocrWeight: 0.75,
    nluThreshold: 0.85,
    dateFallback: "transaction"
  });
  const [persona, setPersona] = useState("dui_de");
  const [customPrompt, setCustomPrompt] = useState("");
  const [thresholds, setThresholds] = useState({
    budgetAlert: 80,
    categorySurge: 25,
    dailyVol: 5
  });

  // Prompt tabs
  const [promptTab, setPromptTab] = useState("persona"); // "persona" | "intent" | "category"
  const [intentPrompt, setIntentPrompt] = useState("");
  const [categoryPrompt, setCategoryPrompt] = useState("");
  const [recordPrompt, setRecordPrompt] = useState("");
  const [actionSlotPrompt, setActionSlotPrompt] = useState("");

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testingPrompt, setTestingPrompt] = useState(false);
  const [testText, setTestText] = useState("chi tiêu ăn sáng hết 45k");
  const [callerContext, setCallerContext] = useState("chat");
  const [forceIntent, setForceIntent] = useState("Auto");
  const [testResult, setTestResult] = useState(null);

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
    Promise.all([
      getBotPrompts(),
      getSystemSettings()
    ])
      .then(([prompts, settings]) => {
        setPromptsData(prompts);
        if (prompts.emotions && prompts.emotions[persona]) {
          setCustomPrompt(prompts.emotions[persona].system);
        }
        // Load NLU classification prompts
        setIntentPrompt(prompts.llm_intent_classification?.system || "");
        setCategoryPrompt(prompts.llm_record_slot_extraction?.system || "");
        setRecordPrompt(prompts.llm_unified_prompt?.system || "");
        setActionSlotPrompt(prompts.llm_action_slot_extraction?.system || "");
        if (settings) {
          setSystemSettings({
            llmTemperature: settings.llmTemperature !== undefined ? settings.llmTemperature : 0.7,
            llmTopK: settings.llmTopK !== undefined ? settings.llmTopK : 40,
            ocrWeight: settings.ocrWeight !== undefined ? settings.ocrWeight : 0.75,
            nluThreshold: settings.nluThreshold !== undefined ? settings.nluThreshold : 0.85,
            dateFallback: settings.dateFallback || "transaction"
          });
          setThresholds({
            budgetAlert: settings.budgetAlert !== undefined ? settings.budgetAlert : 80,
            categorySurge: settings.categorySurge !== undefined ? settings.categorySurge : 25,
            dailyVol: settings.dailyVol !== undefined ? settings.dailyVol : 5
          });
        }
        setLoading(false);
      })
      .catch((err) => {
        triggerToast("Failed to fetch settings: " + err.message);
        setLoading(false);
      });
  }, []);

  const handlePersonaChange = (val) => {
    setPersona(val);
    if (promptsData && promptsData.emotions && promptsData.emotions[val]) {
      setCustomPrompt(promptsData.emotions[val].system);
    }
  };

  const handleSaveAllSettings = (e) => {
    e.preventDefault();
    if (!promptsData) return;
    setSaving(true);

    const updatedPrompts = { ...promptsData };
    if (updatedPrompts.emotions && updatedPrompts.emotions[persona]) {
      updatedPrompts.emotions[persona].system = customPrompt;
    }
    // Save NLU classification prompts
    if (updatedPrompts.llm_intent_classification) {
      updatedPrompts.llm_intent_classification.system = intentPrompt;
    }
    if (updatedPrompts.llm_record_slot_extraction) {
      updatedPrompts.llm_record_slot_extraction.system = categoryPrompt;
    }
    if (updatedPrompts.llm_unified_prompt) {
      updatedPrompts.llm_unified_prompt.system = recordPrompt;
    }
    if (updatedPrompts.llm_action_slot_extraction) {
      updatedPrompts.llm_action_slot_extraction.system = actionSlotPrompt;
    }

    Promise.all([
      saveBotPrompts(updatedPrompts),
      saveSystemSettings({
        ...systemSettings,
        ...thresholds
      })
    ])
      .then(() => {
        setPromptsData(updatedPrompts);
        setSaving(false);
        triggerToast("Cấu hình prompt & tham số LLM đã lưu và áp dụng thành công!");
      })
      .catch((err) => {
        triggerToast("Lưu cấu hình thất bại: " + err.message);
        setSaving(false);
      });
  };

  const handleTestPrompt = async (e) => {
    e.preventDefault();
    if (!testText.trim()) {
      triggerToast("Vui lòng nhập câu text để test");
      return;
    }
    setTestingPrompt(true);
    try {
      const res = await testSystemPrompt({
        text: testText,
        override_prompt: customPrompt,
        persona: persona,
        temperature: systemSettings.llmTemperature,
        top_k: systemSettings.llmTopK,
        caller_context: callerContext,
        force_intent: forceIntent,
      });

      setTestResult(res);
      triggerToast("Test thành công!");
    } catch (err) {
      triggerToast("Test thất bại: " + err.message);
    } finally {
      setTestingPrompt(false);
    }
  };

  if (loading) {
    return (
      <div style={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "80vh", color: "var(--text-secondary)" }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "12px" }}>
          <div className="brand-dot" style={{ width: "16px", height: "16px", animation: "pulse 1.5s infinite", background: "var(--accent-blue)" }}></div>
          <p style={{ fontSize: "14px", fontWeight: "500" }}>Loading bot prompt schema & configs...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="page-container" style={{ padding: "30px 40px" }}>
      <div className="page-header" style={{ marginBottom: "24px" }}>
        <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px" }}>Bot Prompt & LLM Calibrator</h1>
        <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "4px" }}>
          Hiệu chỉnh tham số mô hình LLM, System Prompts theo cảm xúc, và ngưỡng cảnh báo chi tiêu thông minh.
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
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>HuggingFace Model</span>
          <span className="bill-stat-value" style={{ fontSize: "16px", fontWeight: "700", color: "var(--accent-blue-hover)", fontFamily: "var(--font-mono)" }}>qwen-vismimo (14B)</span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Vibe Mode</span>
          <span className="bill-stat-value" style={{ fontSize: "16px", fontWeight: "700", color: "var(--accent-emerald-hover)", fontFamily: "var(--font-sans)" }}>
            {PERSONA_ICONS[persona]} {persona.toUpperCase()}
          </span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>LLM Sample Temp</span>
          <span className="bill-stat-value" style={{ fontSize: "18px", fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)" }}>{systemSettings.llmTemperature}</span>
        </div>
        <div className="bill-stat" style={{ borderRight: "none" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Modal GPU Node</span>
          <span className="bill-stat-value" style={{
            fontSize: "16px",
            fontWeight: "700",
            color: "var(--accent-emerald-hover)",
            display: "flex",
            alignItems: "center",
            gap: "8px"
          }}>
            <span className="status-dot pulse" style={{
              background: "var(--accent-emerald)",
              boxShadow: "0 0 10px var(--accent-emerald)",
              width: "8px",
              height: "8px",
              borderRadius: "50%"
            }}></span>
            A10G Quantized (4-bit)
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
          boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
          display: "flex",
          flexDirection: "column",
          gap: "20px"
        }}>
          <div className="panel-header" style={{ paddingBottom: "16px", borderBottom: "1px solid var(--border-color)" }}>
            <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "4px" }}>System Prompt Settings</h2>
            <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)" }}>Thiết lập phản hồi và tính cách tương tác của chatbot.</span>
          </div>

          {/* Main prompt tabs */}
          <div style={{ display: "flex", gap: "8px", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px", flexWrap: "wrap" }}>
            {[
              { key: "persona", label: "🎭 Tính cách bot", desc: "Giọng điệu cảm xúc" },
              { key: "intent", label: "🎯 Phân loại intent", desc: "Record / Action / Chitchat" },
              { key: "category", label: "🏷️ Trích xuất Category", desc: "Danh mục & giao dịch" },
              { key: "action", label: "⚡ Trích xuất Action", desc: "Slots & lệnh hành động" },
            ].map(tab => (
              <button
                key={tab.key}
                type="button"
                onClick={() => setPromptTab(tab.key)}
                style={{
                  background: promptTab === tab.key ? "rgba(2, 132, 199, 0.15)" : "var(--bg-obsidian-950)",
                  border: `1px solid ${promptTab === tab.key ? "var(--accent-blue)" : "var(--border-color)"}`,
                  color: promptTab === tab.key ? "var(--accent-blue-hover)" : "var(--text-secondary)",
                  borderRadius: "8px",
                  padding: "8px 14px",
                  fontSize: "12px",
                  fontWeight: "600",
                  cursor: "pointer",
                  transition: "all 0.2s",
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "flex-start",
                  gap: "2px",
                }}
              >
                <span>{tab.label}</span>
                <span style={{ fontSize: "10px", fontWeight: "400", opacity: 0.7 }}>{tab.desc}</span>
              </button>
            ))}
          </div>
          {/* Tab: Persona sub-selector (sub-tabs for persona tone) */}
          {promptTab === "persona" && (
            <div style={{ display: "flex", flexWrap: "wrap", gap: "8px", marginTop: "4px" }}>
              {Object.keys(PERSONA_LABELS).map((key) => (
                <button
                  key={key}
                  type="button"
                  onClick={() => handlePersonaChange(key)}
                  style={{
                    background: persona === key ? "rgba(2, 132, 199, 0.15)" : "var(--bg-obsidian-950)",
                    border: `1px solid ${persona === key ? "var(--accent-blue)" : "var(--border-color)"}`,
                    color: persona === key ? "var(--accent-blue-hover)" : "var(--text-secondary)",
                    borderRadius: "8px",
                    padding: "8px 14px",
                    fontSize: "12px",
                    fontWeight: "600",
                    cursor: "pointer",
                    transition: "all 0.2s"
                  }}
                >
                  {PERSONA_ICONS[key]} {PERSONA_LABELS[key].split(" / ")[0]}
                </button>
              ))}
            </div>
          )}

          <form onSubmit={handleSaveAllSettings} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
            {/* Persona prompt editor */}
            {promptTab === "persona" && (
              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "600", display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
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
                    minHeight: "160px",
                    color: "var(--text-primary)"
                  }}
                />
              </div>
            )}

            {/* Intent classification prompt editor */}
            {promptTab === "intent" && (
              <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
                <div style={{ background: "rgba(2,132,199,0.05)", border: "1px solid rgba(2,132,199,0.2)", borderRadius: "8px", padding: "12px", fontSize: "12px", color: "var(--accent-blue-hover)" }}>
                  🎯 Prompt phân loại ý định (Tầng 1 NLU): quyết định câu nói thuộc nhóm Record / Action / Chitchat. Được gọi khi không có rule cứng override.
                </div>
                <div className="form-group">
                  <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "600", display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                    <span>Intent Classification Prompt</span>
                    <span className="monospaced" style={{ color: "var(--accent-blue-hover)", fontSize: "12px" }}>llm_intent_classification.system</span>
                  </label>
                  <textarea
                    className="form-textarea monospaced"
                    value={intentPrompt}
                    onChange={(e) => setIntentPrompt(e.target.value)}
                    style={{
                      fontSize: "12px",
                      lineHeight: "1.6",
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid var(--border-color)",
                      borderRadius: "8px",
                      padding: "14px",
                      minHeight: "220px",
                      color: "var(--text-primary)",
                      fontFamily: "var(--font-mono)"
                    }}
                  />
                  <span style={{ fontSize: "11px", color: "var(--text-muted)", marginTop: "6px", display: "block" }}>
                    Prompt phải trả về JSON: {`{"intent": "Record|Action|Chitchat", "confidence": 0.0-1.0}`}. Không thay đổi format output.
                  </span>
                </div>
              </div>
            )}

            {/* Category & Record extraction prompt editor */}
            {promptTab === "category" && (
              <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
                <div style={{ background: "rgba(16,185,129,0.05)", border: "1px solid rgba(16,185,129,0.2)", borderRadius: "8px", padding: "12px", fontSize: "12px", color: "var(--accent-emerald-hover)" }}>
                  🏷️ Prompt trích xuất danh mục chi tiêu (Tầng 2 NLU - Record): quyết định label, amount, type từ câu ghi chép giao dịch.
                </div>
                <div className="form-group">
                  <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "600", display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                    <span>Record Slot Extraction Prompt</span>
                    <span className="monospaced" style={{ color: "var(--accent-emerald-hover)", fontSize: "12px" }}>llm_record_slot_extraction.system</span>
                  </label>
                  <textarea
                    className="form-textarea monospaced"
                    value={categoryPrompt}
                    onChange={(e) => setCategoryPrompt(e.target.value)}
                    style={{
                      fontSize: "12px",
                      lineHeight: "1.6",
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid var(--border-color)",
                      borderRadius: "8px",
                      padding: "14px",
                      minHeight: "220px",
                      color: "var(--text-primary)",
                      fontFamily: "var(--font-mono)"
                    }}
                  />
                  <span style={{ fontSize: "11px", color: "var(--text-muted)", marginTop: "6px", display: "block" }}>
                    Danh mục hợp lệ: Food / Transport / Shopping / Entertainment / Health / Education / Beauty / Housing / Social / Business / Bonus / Charity / Essentials / Debt / Investment / Savings / Salary / Others.
                  </span>
                </div>
                <div className="form-group">
                  <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "600", display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                    <span>Unified LLM Prompt (Tổng hợp NLU + NLG)</span>
                    <span className="monospaced" style={{ color: "var(--text-muted)", fontSize: "12px" }}>llm_unified_prompt.system</span>
                  </label>
                  <textarea
                    className="form-textarea monospaced"
                    value={recordPrompt}
                    onChange={(e) => setRecordPrompt(e.target.value)}
                    style={{
                      fontSize: "12px",
                      lineHeight: "1.6",
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid rgba(255,255,255,0.08)",
                      borderRadius: "8px",
                      padding: "14px",
                      minHeight: "180px",
                      color: "var(--text-primary)",
                      fontFamily: "var(--font-mono)"
                    }}
                  />
                  <span style={{ fontSize: "11px", color: "var(--text-muted)", marginTop: "6px", display: "block" }}>
                    Prompt tổng hợp xử lý NLU và tạo câu trả lời NLG cuối cùng (khi dùng chế độ full LLM pipeline).
                  </span>
                </div>
              </div>
            )}

            {/* Action slot prompt editor */}
            {promptTab === "action" && (
              <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
                <div style={{ background: "rgba(251,191,36,0.05)", border: "1px solid rgba(251,191,36,0.2)", borderRadius: "8px", padding: "12px", fontSize: "12px", color: "var(--accent-amber-hover)" }}>
                  ⚡ Prompt trích xuất action slots (Tầng 2 NLU - Action): xác định action_type và slots từ lệnh của người dùng như báo cáo, đặt hạn mức, tạo mục tiêu.
                </div>
                <div className="form-group">
                  <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "600", display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                    <span>Action Slot Extraction Prompt</span>
                    <span className="monospaced" style={{ color: "var(--accent-amber-hover)", fontSize: "12px" }}>llm_action_slot_extraction.system</span>
                  </label>
                  <textarea
                    className="form-textarea monospaced"
                    value={actionSlotPrompt}
                    onChange={(e) => setActionSlotPrompt(e.target.value)}
                    style={{
                      fontSize: "12px",
                      lineHeight: "1.6",
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid var(--border-color)",
                      borderRadius: "8px",
                      padding: "14px",
                      minHeight: "220px",
                      color: "var(--text-primary)",
                      fontFamily: "var(--font-mono)"
                    }}
                  />
                  <span style={{ fontSize: "11px", color: "var(--text-muted)", marginTop: "6px", display: "block" }}>
                    Action types hợp lệ: REPORT_GENERAL / REPORT_COMPARE / SET_LIMIT / SET_GOAL / ADD_GOAL / SET_TONE / SEARCH_RECORD / SUGGEST_BUDGET / SYSTEM_SETTING / SET_USERNAME / SET_ALERT.
                  </span>
                </div>
              </div>
            )}

            {/* AI Response Preview */}
            <div className="form-group">
              <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "600", marginBottom: "8px" }}>Interactive Chat Preview (Kiểm thử 2 tầng NLU)</label>
              
              <div style={{ display: "flex", gap: "12px", marginBottom: "12px", flexWrap: "wrap" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
                  <span style={{ fontSize: "12px", color: "var(--text-muted)", fontWeight: "500" }}>Ngữ cảnh gọi (Caller Context):</span>
                  <select
                    value={callerContext}
                    onChange={(e) => setCallerContext(e.target.value)}
                    style={{
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid var(--border-color)",
                      borderRadius: "6px",
                      padding: "4px 8px",
                      color: "var(--text-primary)",
                      fontSize: "12px"
                    }}
                  >
                    <option value="chat">chat (Mặc định)</option>
                    <option value="addstory">addstory (Ghi chép nhanh)</option>
                  </select>
                </div>

                <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
                  <span style={{ fontSize: "12px", color: "var(--text-muted)", fontWeight: "500" }}>Ép buộc ý định (Force Intent):</span>
                  <select
                    value={forceIntent}
                    onChange={(e) => setForceIntent(e.target.value)}
                    style={{
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid var(--border-color)",
                      borderRadius: "6px",
                      padding: "4px 8px",
                      color: "var(--text-primary)",
                      fontSize: "12px"
                    }}
                  >
                    <option value="Auto">Auto (Tự động phân loại)</option>
                    <option value="Record">Record (Ghi chép)</option>
                    <option value="Action">Action (Hành động)</option>
                    <option value="Chitchat">Chitchat (Trò chuyện)</option>
                  </select>
                </div>
              </div>

              <div style={{ display: "flex", gap: "10px", marginBottom: "16px" }}>
                <input
                  type="text"
                  className="form-input"
                  value={testText}
                  onChange={(e) => setTestText(e.target.value)}
                  placeholder="Nhập câu chi tiêu để test..."
                  style={{
                    flex: 1,
                    background: "var(--bg-obsidian-950)",
                    border: "1px solid var(--border-color)",
                    borderRadius: "8px",
                    padding: "10px 14px",
                    color: "var(--text-primary)"
                  }}
                />
                <button 
                  type="button" 
                  className="btn btn-secondary" 
                  onClick={handleTestPrompt} 
                  disabled={testingPrompt}
                  style={{
                    background: "rgba(26,115,232,0.1)",
                    border: "1px solid rgba(26,115,232,0.3)",
                    color: "var(--accent-blue-hover)",
                    fontWeight: "600",
                    padding: "0 16px",
                    borderRadius: "8px",
                    cursor: "pointer"
                  }}
                >
                  {testingPrompt ? "Testing..." : "Test Live Prompt"}
                </button>
              </div>

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
                  <strong style={{ fontSize: "13px", color: "var(--text-primary)" }}>Mimo Mascot (Mô phỏng phản hồi)</strong>
                  <span className="badge" style={{
                    fontSize: "10px",
                    padding: "2px 8px",
                    borderRadius: "6px",
                    background: "rgba(16, 185, 129, 0.08)",
                    border: "1px solid rgba(16, 185, 129, 0.3)",
                    color: "var(--accent-emerald-hover)",
                    fontWeight: "600",
                    marginLeft: "auto"
                  }}>{testResult?.result?.emotion || "neutral"}</span>
                </div>
                
                {testResult ? (
                  <div style={{
                    background: "var(--bg-obsidian-900)",
                    border: "1px solid var(--border-color)",
                    borderRadius: "12px",
                    padding: "14px 16px",
                    fontSize: "13px",
                    color: "var(--text-primary)",
                    lineHeight: "1.5"
                  }}>
                    <div style={{ marginBottom: "8px", color: "var(--text-muted)", display: "flex", flexWrap: "wrap", gap: "12px", borderBottom: "1px dashed var(--border-color)", paddingBottom: "8px" }}>
                      <span><strong>Intent:</strong> {testResult.result?.intent || "N/A"} ({testResult.result?.intent_confidence != null ? `${Math.round(testResult.result.intent_confidence * 100)}%` : "100%"})</span>
                      <span><strong>Rule:</strong> {testResult.result?.rule_used || "N/A"}</span>
                      <span style={{ fontSize: "11px", marginLeft: "auto" }}>{testResult.latency_ms}ms</span>
                    </div>
                    {/* Emotion / Action type row */}
                    {(testResult.result?.mimo_emotion || testResult.result?.emotion || testResult.result?.gemini_json?.mimo_emotion || testResult.result?.action_type) && (
                      <div style={{ marginBottom: "8px", fontSize: "12px", color: "var(--accent-blue)", display: "flex", gap: "16px", flexWrap: "wrap" }}>
                        {(testResult.result?.mimo_emotion || testResult.result?.emotion || testResult.result?.gemini_json?.mimo_emotion) && (
                          <span>🎭 Emotion: <strong>{testResult.result?.mimo_emotion || testResult.result?.emotion || testResult.result?.gemini_json?.mimo_emotion}</strong></span>
                        )}
                        {testResult.result?.action_type && (
                          <span>⚡ Action: <strong>{testResult.result.action_type}</strong></span>
                        )}
                      </div>
                    )}
                    {/* Response text */}
                    {(() => {
                      const text = testResult.result?.response
                        || testResult.result?.nlg_response
                        || testResult.result?.gemini_json?.response
                        || testResult.result?.note;
                      if (text) {
                        return <div style={{ fontStyle: "italic" }}>"{ text }"</div>;
                      }
                      // Fallback: hiển thị toàn bộ result dưới dạng JSON debug
                      return (
                        <div>
                          <div style={{ color: "var(--accent-amber)", marginBottom: "6px", fontSize: "12px" }}>
                            ⚠️ Không có trường response — raw result:
                          </div>
                          <pre style={{ fontSize: "11px", color: "var(--text-secondary)", whiteSpace: "pre-wrap", wordBreak: "break-all", maxHeight: "200px", overflow: "auto", background: "var(--bg-obsidian-950)", padding: "8px", borderRadius: "6px", margin: 0 }}>
                            {JSON.stringify(testResult.result, null, 2)}
                          </pre>
                        </div>
                      );
                    })()}
                    {testResult.result?.amount !== undefined && (
                      <div style={{ marginTop: "8px", fontSize: "12px", color: "var(--text-secondary)" }}>
                        Amount: {testResult.result.amount} | Category: {testResult.result.category || "General"}
                      </div>
                    )}
                  </div>
                ) : (
                  <div style={{
                    background: "var(--bg-obsidian-900)",
                    border: "1px dashed var(--border-color)",
                    borderRadius: "12px",
                    padding: "14px 16px",
                    fontSize: "13px",
                    color: "var(--text-muted)",
                    textAlign: "center"
                  }}>
                    Bấm Test Live Prompt để xem kết quả từ mô hình Qwen 2 tầng
                  </div>
                )}

              </div>
            </div>

            <button type="submit" className="btn btn-primary" disabled={saving} style={{
              background: "var(--accent-emerald)",
              color: "var(--bg-obsidian-950)",
              fontWeight: "700",
              fontSize: "14px",
              padding: "12px",
              borderRadius: "8px",
              cursor: "pointer",
              transition: "all 0.2s"
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
              {saving ? "Deploying Configuration..." : "Lưu & Áp Dụng Cấu Hình Hệ Thống"}
            </button>
          </form>
        </div>

        {/* Right Columns: LLM Parameters & Thresholds */}
        <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
          
          {/* Hugging Face Model Card widget */}
          <div className="panel" style={{
            background: "linear-gradient(135deg, rgba(26,115,232,0.08) 0%, rgba(139,92,246,0.08) 100%)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "20px 24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.1)"
          }}>
            <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
              <div style={{ fontSize: "28px" }}>🤗</div>
              <div>
                <h4 style={{ fontSize: "14px", fontWeight: "700", color: "var(--text-primary)", margin: 0 }}>Hugging Face Repository</h4>
                <p style={{ fontSize: "11px", color: "var(--text-secondary)", margin: "2px 0 0 0" }}>Active fine-tuned weights registry</p>
              </div>
            </div>
            
            <div style={{ display: "flex", flexDirection: "column", gap: "8px", marginTop: "16px", fontSize: "12px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px dashed var(--border-color)", paddingBottom: "6px" }}>
                <span style={{ color: "var(--text-muted)" }}>Merged Base Model</span>
                <strong style={{ fontFamily: "var(--font-mono)", color: "var(--text-primary)" }}>Maikhang/qwen-vismimo</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", paddingBottom: "6px" }}>
                <span style={{ color: "var(--text-muted)" }}>LoRA Adapter</span>
                <strong style={{ fontFamily: "var(--font-mono)", color: "var(--text-primary)" }}>qwen-vismimo-lora</strong>
              </div>
            </div>
          </div>

          {/* LLM Sampling Sliders */}
          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
          }}>
            <div className="panel-header" style={{ paddingBottom: "16px", borderBottom: "1px solid var(--border-color)", marginBottom: "20px" }}>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "4px" }}>LLM Sampling Parameters</h2>
              <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)" }}>Hiệu chỉnh tham số suy diễn của mô hình fine-tuned.</span>
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "500", display: "flex", justifyContent: "space-between", marginBottom: "6px" }}>
                  <span>Inference Temperature</span>
                  <strong style={{ color: "var(--accent-blue-hover)", fontFamily: "var(--font-mono)" }}>{systemSettings.llmTemperature}</strong>
                </label>
                <input
                  type="range"
                  min="0.1"
                  max="1.5"
                  step="0.05"
                  value={systemSettings.llmTemperature}
                  onChange={(e) => setSystemSettings({ ...systemSettings, llmTemperature: parseFloat(e.target.value) })}
                  style={{ accentColor: "var(--accent-blue)", width: "100%", height: "6px", background: "var(--bg-obsidian-950)", borderRadius: "3px" }}
                />
                <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Nhiệt độ cao giúp câu trả lời ngẫu nhiên & sáng tạo hơn. Thấp giúp câu trả lời nhất quán & chính xác.</span>
              </div>

              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "500", display: "flex", justifyContent: "space-between", marginBottom: "6px" }}>
                  <span>Top-K Sampling Limit</span>
                  <strong style={{ color: "var(--accent-violet-hover)", fontFamily: "var(--font-mono)" }}>{systemSettings.llmTopK}</strong>
                </label>
                <input
                  type="range"
                  min="1"
                  max="100"
                  step="1"
                  value={systemSettings.llmTopK}
                  onChange={(e) => setSystemSettings({ ...systemSettings, llmTopK: parseInt(e.target.value) })}
                  style={{ accentColor: "var(--accent-violet)", width: "100%", height: "6px", background: "var(--bg-obsidian-950)", borderRadius: "3px" }}
                />
                <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Giới hạn tập hợp các token có xác suất cao nhất được xem xét khi generate câu tiếp theo.</span>
              </div>
            </div>
          </div>

          {/* Mimo Alert Calibration */}
          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
          }}>
            <div className="panel-header" style={{ paddingBottom: "16px", borderBottom: "1px solid var(--border-color)", marginBottom: "20px" }}>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "4px" }}>Mimo Alert Logic Calibration</h2>
              <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)" }}>Ngưỡng chi tiêu kích hoạt cảnh báo thông minh của chatbot.</span>
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "500", display: "flex", justifyContent: "space-between", marginBottom: "6px" }}>
                  <span>Budget Excess Warning</span>
                  <strong style={{ color: "var(--accent-blue-hover)", fontFamily: "var(--font-mono)" }}>{thresholds.budgetAlert}%</strong>
                </label>
                <input
                  type="range"
                  min="10"
                  max="100"
                  step="5"
                  value={thresholds.budgetAlert}
                  onChange={(e) => setThresholds({ ...thresholds, budgetAlert: parseInt(e.target.value) })}
                  style={{ accentColor: "var(--accent-blue)", width: "100%", height: "6px", background: "var(--bg-obsidian-950)", borderRadius: "3px" }}
                />
                <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Cảnh báo khi chi tiêu bất kỳ danh mục nào đạt tỷ lệ này so với hạn mức của họ.</span>
              </div>

              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "500", display: "flex", justifyContent: "space-between", marginBottom: "6px" }}>
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
                <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Cảnh báo nếu chi tiêu danh mục tăng vọt theo tỷ lệ này so với tuần trước.</span>
              </div>

              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)", fontWeight: "500", display: "flex", justifyContent: "space-between", marginBottom: "6px" }}>
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
                <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Gửi thông báo nhác nhở nếu số giao dịch ghi nhận vượt ngưỡng này trong 24 giờ.</span>
              </div>
            </div>
          </div>

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
