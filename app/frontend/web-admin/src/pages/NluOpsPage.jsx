import { useState, useEffect } from "react";
import {
  getNluOverrides,
  addNluOverride,
  deleteNluOverride,
  cleanupInvalidNluOverrides,
  getNluAggregations,
  curateNluAggregations,
  triggerNluTrain,
  getNluTrainStatus,
  getNluModelMeta,
  getNluTrainHistory,
  importNluCsv,
  reloadAiModels,
  getNluInferenceBackend,
  setNluInferenceBackend,
  triggerLlmFinetune,
} from "../services/api";

const NLU_METRIC_SOURCES = {
  nlu_record: { key: "category" },
  nlu_chitchat: { key: "intent" },
  fusion: { key: "record_type" },
  nlu_action: { key: "action_type" },
  nlu_action_slots: { key: "action_slots", slots: true },
  ner: { key: "ner", ner: true },
};

function normalizePct(val) {
  if (val === undefined || val === null) return null;
  const n = Number(val);
  if (Number.isNaN(n)) return null;
  return n <= 1 ? n * 100 : n;
}

function getMetricValue(modelKey, metricKey, metricsObj) {
  const src = NLU_METRIC_SOURCES[modelKey];
  if (!src || !metricsObj) return null;
  const block = metricsObj[src.key];
  if (!block) return null;
  if (src.slots) {
    const block = metricsObj[src.key];
    const summary = block?.summary;
    if (!summary) return null;
    if (metricKey === "accuracy") return normalizePct(summary.avg_accuracy);
    if (metricKey === "f1_score") return normalizePct(summary.avg_weighted_f1);
    return null;
  }
  if (src.ner) {
    const map = { accuracy: "score", precision: "ents_p", recall: "ents_r", f1_score: "ents_f" };
    return normalizePct(block[map[metricKey]]);
  }
  const map = {
    accuracy: "accuracy",
    precision: "weighted_precision",
    recall: "weighted_recall",
    f1_score: "weighted_f1",
  };
  return normalizePct(block[map[metricKey]]);
}

const COMPARISON_ROWS = {
  tfidf: [
    { key: "nlu_record", label: "Category Model (category)", desc: "Phân loại danh mục chi tiêu tự động — TF-IDF" },
    { key: "nlu_chitchat", label: "Intent Model (intent-model)", desc: "Nhận diện ý định giao dịch / Trò chuyện — TF-IDF" },
    { key: "fusion", label: "Record Type Model (recordtype)", desc: "Phân loại Thu nhập / Chi tiêu — TF-IDF" },
    { key: "nlu_action", label: "Action Model (actiontype)", desc: "Nhận diện hành động thao tác ví — TF-IDF" },
    { key: "nlu_action_slots", label: "Action Slots (verb, category, time…)", desc: "Dự đoán slot chi tiết theo action_type (TF-IDF per field)" },
    { key: "ner", label: "Named Entity Recognition (spaCy NER)", desc: "Nhận diện thực thể tên riêng, số tiền, ngày tháng" },
  ],
  encoder: [
    { key: "nlu_record", label: "Category (PhoBERT encoder)", desc: "Phân loại danh mục chi tiêu — embedding PhoBERT" },
    { key: "nlu_chitchat", label: "Intent (PhoBERT encoder)", desc: "Record / Action / Chitchat — embedding PhoBERT" },
    { key: "fusion", label: "Record Type (PhoBERT encoder)", desc: "Thu nhập / Chi tiêu — embedding PhoBERT" },
    { key: "nlu_action", label: "Action Type (PhoBERT encoder)", desc: "SET_LIMIT, ADD_GOAL, … — embedding PhoBERT" },
  ],
};

function historyTrainType(entry) {
  return entry?.train_type || "tfidf";
}

function filterHistoryByType(history, type) {
  return (history || []).filter((r) => historyTrainType(r) === type && r.status === "success");
}


function NluOpsPage() {
  const [activeTab, setActiveTab] = useState("layer1");
  const [toastMessage, setToastMessage] = useState("");
  const [loading, setLoading] = useState(false);

  // Layer 1 state
  const [layer1Rules, setLayer1Rules] = useState([]);
  const [searchExact, setSearchExact] = useState("");
  const [newKeyword, setNewKeyword] = useState("");
  const [newCategory, setNewCategory] = useState("Food");
  const [newUserId, setNewUserId] = useState("");

  // Layer 2 state
  const [aggregations, setAggregations] = useState([]);
  const [autoRetrainAfterCurate, setAutoRetrainAfterCurate] = useState("local");

  // Model status state
  const [isTraining, setIsTraining] = useState(false);
  const [trainProgressInfo, setTrainProgressInfo] = useState(null);
  const [isLlmTraining, setIsLlmTraining] = useState(false);
  const [llmTrainParams, setLlmTrainParams] = useState({
    epochs: 3,
    lr: 0.0002,
    batchSize: 4
  });
  const [modelMeta, setModelMeta] = useState({
    version: "Loading...",
    trainedAt: "Loading...",
    f1Score: "Loading...",
    trainingRows: 0,
  });
  const [trainHistory, setTrainHistory] = useState([]);
  const [reloadingNlu, setReloadingNlu] = useState(false);
  const [inferenceBackend, setInferenceBackend] = useState("tfidf");
  const [savingBackend, setSavingBackend] = useState(false);
  const [compareTrainType, setCompareTrainType] = useState("tfidf");

  // CSV Import state
  const [csvFile, setCsvFile] = useState(null);
  const [autoRetrainCsv, setAutoRetrainCsv] = useState("local");
  const [importingCsv, setImportingCsv] = useState(false);

  const renderMetricCell = (modelKey, metricKey, trainType = compareTrainType) => {
    const filtered = filterHistoryByType(trainHistory, trainType);
    const newModel = filtered.length > 0 ? filtered[filtered.length - 1] : null;
    const oldModel = filtered.length > 1 ? filtered[filtered.length - 2] : null;

    const newVal = getMetricValue(modelKey, metricKey, newModel?.metrics);
    const oldVal = getMetricValue(modelKey, metricKey, oldModel?.metrics);
    
    if (newVal === undefined || newVal === null) {
      return <span style={{ color: "var(--text-muted)", fontSize: "13px" }}>-</span>;
    }
    
    const formattedNew = `${newVal.toFixed(1)}%`;
    if (oldVal === undefined || oldVal === null) {
      return (
        <div>
          <span style={{ color: "var(--text-primary)", fontWeight: "600", fontSize: "13px" }}>{formattedNew}</span>
        </div>
      );
    }
    
    const formattedOld = `${oldVal.toFixed(1)}%`;
    const diff = newVal - oldVal;
    const diffColor = diff > 0 ? "var(--accent-emerald-hover)" : diff < 0 ? "var(--accent-rose)" : "var(--text-muted)";
    const diffSign = diff > 0 ? `+${diff.toFixed(1)}%` : diff < 0 ? `${diff.toFixed(1)}%` : "0.0%";
    const arrow = diff > 0 ? "▲" : diff < 0 ? "▼" : "•";
    
    return (
      <div style={{ display: "flex", flexDirection: "column", gap: "2px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
          <span style={{ color: "var(--text-primary)", fontWeight: "600", fontSize: "13px" }}>{formattedNew}</span>
          <span style={{ fontSize: "11px", color: diffColor, fontWeight: "700", display: "flex", alignItems: "center", gap: "2px" }}>
            {arrow} {diffSign}
          </span>
        </div>
        <div style={{ fontSize: "11px", color: "var(--text-muted)" }}>
          Cũ: {formattedOld}
        </div>
      </div>
    );
  };

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(""), 3000);
  };

  // Fetch all NLU telemetry initially to populate stats
  const fetchAllData = () => {
    setLoading(true);
    Promise.all([
      getNluOverrides().catch(() => []),
      getNluAggregations().catch(() => []),
      getNluTrainStatus().catch(() => ({ training_active: false })),
      getNluModelMeta().catch(() => ({ version: "v1.2.0-fallback", trainedAt: "2026-06-21", f1Score: "91.2%" })),
      getNluTrainHistory().catch(() => []),
      getNluInferenceBackend().catch(() => ({ backend: "tfidf" })),
    ])
      .then(([overridesData, aggregationsData, statusData, metaData, historyData, backendData]) => {
        setLayer1Rules(overridesData);
        setAggregations(aggregationsData.map(item => ({ ...item, approved: false })));
        setIsTraining(statusData.training_active);
        setTrainProgressInfo(statusData);
        setModelMeta(metaData);
        setTrainHistory(historyData);
        setInferenceBackend(backendData?.backend || metaData?.inferenceBackend || "tfidf");
        const backend = backendData?.backend || metaData?.inferenceBackend || "tfidf";
        setCompareTrainType(backend === "encoder" ? "encoder" : "tfidf");
        setLoading(false);
      })
      .catch((err) => {
        showToast("Error loading telemetry data: " + err.message);
        setLoading(false);
      });
  };

  useEffect(() => {
    fetchAllData();
  }, []);

  // Poll training status if active
  useEffect(() => {
    let intervalId;
    if (isTraining) {
      intervalId = setInterval(() => {
        getNluTrainStatus()
          .then((data) => {
            setTrainProgressInfo(data);
            if (!data.training_active) {
              setIsTraining(false);
              showToast("Model retraining completed successfully!");
              getNluModelMeta().then(meta => setModelMeta(meta)).catch(() => {});
              getNluTrainHistory().then(history => setTrainHistory(history)).catch(() => {});
            }
          })
          .catch(() => {});
      }, 3000);
    }
    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }, [isTraining]);

  // Tab switching loads specific data just in case
  const handleTabChange = (tab) => {
    setActiveTab(tab);
    if (tab === "layer1") {
      getNluOverrides().then(data => setLayer1Rules(data)).catch(() => {});
    } else if (tab === "layer2") {
      getNluAggregations().then(data => setAggregations(data.map(item => ({ ...item, approved: false })))).catch(() => {});
    } else if (tab === "model") {
      getNluTrainStatus().then(data => setIsTraining(data.training_active)).catch(() => {});
      getNluModelMeta().then(data => setModelMeta(data)).catch(() => {});
      getNluTrainHistory().then(data => setTrainHistory(data)).catch(() => {});
    }
  };

  // Add Exact rule
  const handleAddRule = (e) => {
    e.preventDefault();
    if (!newKeyword.trim() || !newUserId.trim()) {
      showToast("Please provide target User ID and keyword phrase.");
      return;
    }
    setLoading(true);
    addNluOverride(newUserId.trim(), newKeyword.trim().toLowerCase(), newCategory)
      .then(() => {
        setNewKeyword("");
        // Keep ID to allow quick multiple additions for the same user
        getNluOverrides().then(data => {
          setLayer1Rules(data);
          setLoading(false);
        });
        showToast("Đã thêm quy tắc cá nhân hóa danh mục!");
      })
      .catch((err) => {
        showToast("Failed to add override: " + err.message);
        setLoading(false);
      });
  };

  // Delete Exact rule
  const handleDeleteRule = (userId, keyword) => {
    setLoading(true);
    deleteNluOverride(userId, keyword)
      .then(() => {
        getNluOverrides().then(data => {
          setLayer1Rules(data);
          setLoading(false);
        });
        showToast("Đã thu hồi quy tắc cá nhân hóa danh mục.");
      })
      .catch((err) => {
        showToast("Failed to delete rule: " + err.message);
        setLoading(false);
      });
  };

  const handleCleanupInvalidRules = async () => {
    setLoading(true);
    try {
      const preview = await cleanupInvalidNluOverrides(false);
      if (!preview.invalidCount) {
        showToast("Không có quy tắc cá nhân hóa danh mục nào sai cần dọn.");
        setLoading(false);
        return;
      }
      const sample = (preview.invalid || [])
        .slice(0, 3)
        .map((r) => `"${r.keyword}"`)
        .join(", ");
      const ok = window.confirm(
        `Tìm thấy ${preview.invalidCount} quy tắc cá nhân hóa danh mục sai (tên danh mục, OCR dài, v.v.).\n` +
          `Ví dụ: ${sample}\n\nXóa tất cả?`
      );
      if (!ok) {
        setLoading(false);
        return;
      }
      const result = await cleanupInvalidNluOverrides(true);
      const data = await getNluOverrides();
      setLayer1Rules(data);
      showToast(`Đã xóa ${result.removed} quy tắc cá nhân hóa danh mục không hợp lệ.`);
    } catch (err) {
      showToast("Dọn rule thất bại: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleImportCsv = (e) => {
    e.preventDefault();
    if (!csvFile) {
      showToast("Vui lòng chọn một tập tin CSV!");
      return;
    }
    setImportingCsv(true);
    const autoRetrain = autoRetrainCsv !== "none";
    importNluCsv(csvFile, autoRetrain, autoRetrainCsv)
      .then((data) => {
        showToast(`Đã import thành công ${data.addedCount} dòng mới!`);
        setCsvFile(null);
        const fileInput = document.getElementById("nlu-csv-file-input");
        if (fileInput) fileInput.value = "";
        setImportingCsv(false);
        fetchAllData();
      })
      .catch((err) => {
        showToast("Import thất bại: " + err.message);
        setImportingCsv(false);
      });
  };

  // Toggle checks in Aggregation tab
  const toggleAggregateApprove = (idx) => {
    const next = [...aggregations];
    next[idx].approved = !next[idx].approved;
    setAggregations(next);
  };

  // Curation export
  const handleExportCuration = () => {
    const selected = aggregations.filter((a) => a.approved);
    if (selected.length === 0) {
      showToast("Vui lòng tích chọn ít nhất một cụm câu để duyệt xuất.");
      return;
    }
    if (!window.confirm(`Duyệt và xuất ${selected.length} cụm câu đã sửa sang dataset huấn luyện chính?\n\nHành động này không thể hoàn tác.`)) return;
    setLoading(true);
    const autoRetrain = autoRetrainAfterCurate !== "none";
    curateNluAggregations(selected, autoRetrain, autoRetrainAfterCurate)
      .then((res) => {
        getNluAggregations().then(data => {
          setAggregations(data.map(item => ({ ...item, approved: false })));
          setLoading(false);
        });
        if (autoRetrain) {
          setIsTraining(true);
        }
        showToast(res.message || `Đã thêm ${selected.length} mẫu vào dataset huấn luyện chính!`);
      })
      .catch((err) => {
        showToast("Xuất dữ liệu thất bại: " + err.message);
        setLoading(false);
      });
  };

  // Trigger retraining in background
  const handleRetrain = (target = "local") => {
    const label = target === "encoder" ? "PhoBERT Encoder" : "TF-IDF & NLU";
    const pw = window.prompt(`Bạn có chắc chắn muốn bắt đầu huấn luyện lại mô hình ${label} không?\nQuá trình này sẽ diễn ra chạy nền.\n\nNhập mật khẩu quản trị hệ thống (PASSWORD_RETRAIN) để xác nhận:`);
    if (!pw) return;
    setLoading(true);
    triggerNluTrain(target, pw)
      .then((res) => {
        setIsTraining(true);
        showToast(res.message || `Đã bắt đầu retrain mô hình ${label} chạy nền!`);
        setLoading(false);
      })
      .catch((err) => {
        showToast("Huấn luyện thất bại: " + err.message);
        setLoading(false);
      });
  };

  const handleReloadNlu = () => {
    if (!window.confirm("Bạn có chắc chắn muốn nạp nóng lại mô hình NLU mới nhất từ đĩa không?")) return;
    setReloadingNlu(true);
    reloadAiModels("nlu")
      .then((res) => {
        setReloadingNlu(false);
        const ver = res.nlu_version ? ` (${res.nlu_version})` : "";
        showToast((res.message || "Model NLU đã được nạp nóng thành công!") + ver);
        fetchAllData();
      })
      .catch((err) => {
        setReloadingNlu(false);
        showToast("Tải lại model thất bại: " + err.message);
      });
  };

  const handleLlmFinetune = () => {
    const pw = window.prompt("Bắt đầu huấn luyện Fine-tune Qwen2.5-14B-Instruct trên GPU Modal H100?\n\nTác vụ này sẽ chạy nền trong khoảng 1 giờ và tiêu thụ tài nguyên đám mây.\n\nNhập mật khẩu quản trị hệ thống (PASSWORD_RETRAIN) để xác nhận:");
    if (!pw) return;

    setIsLlmTraining(true);
    triggerLlmFinetune(llmTrainParams.epochs, llmTrainParams.lr, llmTrainParams.batchSize, pw)
      .then((res) => {
        showToast("Đã kích hoạt fine-tune Qwen2.5-14B-Instruct trên GPU Modal H100!");
        setIsLlmTraining(false);
      })
      .catch((err) => {
        showToast("Fine-tune LLM thất bại: " + err.message);
        setIsLlmTraining(false);
      });
  };

  const handleInferenceBackendChange = (backend) => {
    if (backend === inferenceBackend) return;
    const confirmMsg = backend === "llm" 
      ? "Kích hoạt mô hình Qwen2.5-14B-Instruct làm bộ xử lý NLU mặc định?\n\nMô hình sẽ được nạp nóng vào GPU VRAM tự động."
      : `Chuyển đổi bộ xử lý NLU mặc định thành mô hình ${backend.toUpperCase()}?`;
    if (!window.confirm(confirmMsg)) return;

    const pwd = window.prompt("Yêu cầu nhập mật khẩu bảo mật hệ thống (Retrain Password):");
    if (pwd === null) return;
    if (!pwd) {
      alert("Mật khẩu không được để trống!");
      return;
    }

    setSavingBackend(true);
    setNluInferenceBackend(backend, pwd)
      .then((res) => {
        setSavingBackend(false);
        const activeBackend = res.backend || backend;
        setInferenceBackend(activeBackend);
        setCompareTrainType(activeBackend === "encoder" ? "encoder" : "tfidf");
        
        if (activeBackend === "llm") {
          window.alert("Mô hình LLM Qwen2.5-14B-Instruct đã được kích hoạt thành công làm bộ xử lý NLU mặc định!\n\nLưu ý: Mô hình sẽ bắt đầu được tải nóng vào GPU. Request đầu tiên có thể mất một chút thời gian.");
        } else {
          showToast(res.message || `Bộ xử lý NLU mặc định đã đổi thành → ${activeBackend.toUpperCase()}`);
        }
        getNluModelMeta().then(setModelMeta).catch(() => {});
      })
      .catch((err) => {
        setSavingBackend(false);
        showToast("Đổi backend thất bại: " + err.message);
      });
  };

  const filteredRules = layer1Rules.filter((r) =>
    (r.keyword || '').toLowerCase().includes(searchExact.toLowerCase()) ||
    (r.userId || '').toLowerCase().includes(searchExact.toLowerCase()) ||
    (r.email || '').toLowerCase().includes(searchExact.toLowerCase())
  );

  const getBackendLabel = (bk) => {
    if (bk === "llm") return "Qwen2.5 LLM";
    if (bk === "encoder") return "PhoBERT Encoder";
    return "TF-IDF Classic";
  };

  const getBackendBadgeColor = (bk) => {
    if (bk === "llm") return "var(--accent-emerald)";
    if (bk === "encoder") return "#a855f7"; // purple
    return "var(--accent-blue)";
  };

  return (
    <div className="page-container" style={{ padding: "35px 45px", maxWidth: "1600px", margin: "0 auto" }}>
      <div className="page-header" style={{ marginBottom: "28px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <h1 className="page-title" style={{ fontSize: "28px", fontWeight: "700", color: "var(--text-primary)", letterSpacing: "-0.5px" }}>NLU & Retraining Operations</h1>
          <p className="page-desc" style={{ color: "var(--text-secondary)", fontSize: "14px", marginTop: "4px" }}>
            Giám sát cá nhân hóa danh mục, tinh chỉnh dữ liệu đính chính, huấn luyện và kích hoạt các bộ suy luận NLU.
          </p>
        </div>
        <div style={{
          display: "flex",
          alignItems: "center",
          gap: "12px",
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          padding: "10px 18px",
          borderRadius: "12px",
          boxShadow: "var(--shadow-glow)"
        }}>
          <span style={{ fontSize: "11px", color: "var(--text-secondary)", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.05em" }}>Đang hoạt động:</span>
          <span style={{
            fontSize: "13px",
            fontWeight: "700",
            color: "var(--text-primary)",
            background: `${getBackendBadgeColor(inferenceBackend)}22`,
            border: `1px solid ${getBackendBadgeColor(inferenceBackend)}55`,
            padding: "4px 10px",
            borderRadius: "6px",
            display: "inline-flex",
            alignItems: "center",
            gap: "6px"
          }}>
            <span style={{
              width: "6px",
              height: "6px",
              borderRadius: "50%",
              background: getBackendBadgeColor(inferenceBackend),
              boxShadow: `0 0 8px ${getBackendBadgeColor(inferenceBackend)}`
            }}></span>
            {getBackendLabel(inferenceBackend)}
          </span>
        </div>
      </div>

      {/* DevOps Status Strip */}
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
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Cá nhân hóa danh mục</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: "var(--accent-blue-hover)", fontFamily: "var(--font-sans)" }}>{layer1Rules.length} rules</span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Cụm sửa đổi Layer 2</span>
          <span className="bill-stat-value" style={{ fontSize: "20px", fontWeight: "700", color: "var(--accent-amber-hover)", fontFamily: "var(--font-sans)" }}>{aggregations.length} clusters</span>
        </div>
        <div className="bill-stat" style={{ paddingRight: "20px", borderRight: "1px solid var(--border-color)" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Phiên bản Model</span>
          <span className="bill-stat-value" style={{ fontSize: "18px", fontWeight: "700", color: "var(--text-primary)", fontFamily: "var(--font-mono)", letterSpacing: "-0.5px" }}>{modelMeta.version || "Unknown"}</span>
        </div>
        <div className="bill-stat" style={{ borderRight: "none" }}>
          <span className="bill-stat-label" style={{ fontSize: "10px", color: "var(--text-muted)", letterSpacing: "0.1em", textTransform: "uppercase", fontWeight: "600", display: "block", marginBottom: "4px" }}>Trạng thái Worker</span>
          <span className="bill-stat-value" style={{
            fontSize: "18px",
            fontWeight: "700",
            color: (isTraining || isLlmTraining) ? "var(--accent-amber-hover)" : "var(--accent-emerald-hover)",
            display: "flex",
            alignItems: "center",
            gap: "8px"
          }}>
            <span className="status-dot" style={{
              background: (isTraining || isLlmTraining) ? "var(--accent-amber)" : "var(--accent-emerald)",
              boxShadow: (isTraining || isLlmTraining) ? "0 0 10px var(--accent-amber)" : "0 0 10px var(--accent-emerald)",
              animation: (isTraining || isLlmTraining) ? "pulse 1.5s infinite" : "none",
              width: "8px",
              height: "8px",
              borderRadius: "50%"
            }}></span>
            {(isTraining || isLlmTraining) 
              ? `${trainProgressInfo?.message || "Đang Retraining..."}${trainProgressInfo?.elapsed_seconds ? ` (${trainProgressInfo.elapsed_seconds}s)` : ""}`
              : "Sẵn sàng"}
          </span>
        </div>
      </div>

      <div className="tabs-header" style={{ marginBottom: "28px" }}>
        <button
          className={`tab-btn ${activeTab === "layer1" ? "active" : ""}`}
          onClick={() => handleTabChange("layer1")}
          style={{ fontSize: "14px", padding: "12px 20px" }}
        >
          Layer 1: Cá nhân hóa danh mục
        </button>
        <button
          className={`tab-btn ${activeTab === "layer2" ? "active" : ""}`}
          onClick={() => handleTabChange("layer2")}
          style={{ fontSize: "14px", padding: "12px 20px" }}
        >
          Layer 2: Thu thập đính chính
        </button>
        <button
          className={`tab-btn ${activeTab === "model" ? "active" : ""}`}
          onClick={() => handleTabChange("model")}
          style={{ fontSize: "14px", padding: "12px 20px" }}
        >
          Trọng số & Huấn luyện
        </button>
      </div>

      {loading && (
         <div style={{ display: "flex", alignItems: "center", gap: "10px", color: "var(--text-secondary)", marginBottom: "20px", fontSize: "13px" }}>
           <span className="status-dot" style={{ background: "var(--accent-blue)", boxShadow: "0 0 8px var(--accent-blue)", animation: "pulse 1.5s infinite", width: "6px", height: "6px", borderRadius: "50%" }}></span>
           <span>Đang truy vấn chỉ mục database và tệp trọng số...</span>
         </div>
      )}

      {/* TAB 1: EXACT MATCH OVERRIDES */}
      {activeTab === "layer1" && (
        <div className="dashboard-grid" style={{ gap: "24px" }}>
          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
          }}>
            <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)" }}>
              <div>
                <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Layer 1: Cá nhân hóa danh mục</h2>
                <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>
                  Định nghĩa các từ khóa hoặc cụm từ ánh xạ trực tiếp tới một danh mục theo nhu cầu cá nhân hóa của từng người dùng.
                </span>
              </div>
              <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  style={{ whiteSpace: "nowrap", fontSize: "13px" }}
                  disabled={loading}
                  onClick={handleCleanupInvalidRules}
                >
                  Dọn rule lỗi
                </button>
                <input
                  type="text"
                  className="form-input"
                  placeholder="Tìm kiếm từ khóa hoặc người dùng..."
                  style={{ width: "260px", padding: "8px 14px", fontSize: "13px", background: "var(--bg-obsidian-950)", borderRadius: "8px", border: "1px solid var(--border-color)" }}
                  value={searchExact}
                  onChange={(e) => setSearchExact(e.target.value)}
                />
              </div>
            </div>

            <div className="table-container" style={{ borderRadius: "12px", border: "1px solid var(--border-color)", overflow: "hidden", marginTop: "20px" }}>
              <table className="custom-table">
                <thead>
                  <tr style={{ background: "var(--bg-obsidian-950)" }}>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Người dùng / Account</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Từ khóa (Keyword)</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Danh mục cá nhân hóa</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Ngày tạo</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em", textAlign: "right" }}>Thao tác</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRules.map((rule, idx) => (
                    <tr key={idx} style={{ transition: "background 0.15s ease" }}>
                      <td className="monospaced" style={{ padding: "14px 18px" }}>
                        <div style={{ color: "var(--text-primary)", fontWeight: "500", fontSize: "13px" }}>{rule.username || 'Active Client'}</div>
                        <div style={{ color: "var(--text-muted)", fontSize: "11px", marginTop: "2px" }}>{rule.userId}</div>
                      </td>
                      <td style={{ padding: "14px 18px", fontSize: "13px", color: "var(--text-primary)" }}>
                        <code style={{ background: "var(--bg-obsidian-950)", padding: "4px 8px", borderRadius: "6px", border: "1px solid var(--border-color)", fontFamily: "var(--font-mono)" }}>"{rule.keyword}"</code>
                      </td>
                      <td style={{ padding: "14px 18px" }}>
                        <span className="badge badge-success" style={{
                          background: "rgba(16, 185, 129, 0.08)",
                          border: "1px solid rgba(16, 185, 129, 0.3)",
                          color: "var(--accent-emerald-hover)",
                          padding: "4px 10px",
                          borderRadius: "8px",
                          fontWeight: "600",
                          fontSize: "11px"
                        }}>
                          {rule.categoryCode}
                        </span>
                      </td>
                      <td style={{ padding: "14px 18px", fontSize: "12px", color: "var(--text-secondary)" }}>
                        {new Date(rule.date || Date.now()).toISOString().split("T")[0]}
                      </td>
                      <td style={{ padding: "14px 18px", textAlign: "right" }}>
                        <button
                          className="btn"
                          style={{
                            padding: "6px 12px",
                            fontSize: "12px",
                            color: "var(--accent-rose)",
                            background: "rgba(239, 68, 68, 0.05)",
                            border: "1px solid rgba(239, 68, 68, 0.2)",
                            borderRadius: "6px",
                            transition: "all 0.2s"
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = "rgba(239, 68, 68, 0.12)";
                            e.currentTarget.style.borderColor = "var(--accent-rose)";
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = "rgba(239, 68, 68, 0.05)";
                            e.currentTarget.style.borderColor = "rgba(239, 68, 68, 0.2)";
                          }}
                          onClick={() => handleDeleteRule(rule.userId, rule.keyword)}
                        >
                          Thu hồi
                        </button>
                      </td>
                    </tr>
                  ))}
                  {filteredRules.length === 0 && (
                    <tr>
                      <td colSpan="5" style={{ textAlign: "center", padding: "40px", color: "var(--text-muted)" }}>
                        Không có quy tắc cá nhân hóa danh mục nào phù hợp.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
            height: "fit-content"
          }}>
            <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", alignItems: "center", gap: "8px" }}>
              <div className="brand-dot" style={{ background: "var(--accent-blue)" }}></div>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Thêm quy tắc cá nhân hóa danh mục</h2>
            </div>
            <form onSubmit={handleAddRule} style={{ display: "flex", flexDirection: "column", gap: "18px", marginTop: "16px" }}>
              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)" }}>User ID người dùng (UUID)</label>
                <input
                  type="text"
                  className="form-input monospaced"
                  placeholder="Ví dụ: 8f6d7c89-a29b-..."
                  style={{ background: "var(--bg-obsidian-950)", fontSize: "13px" }}
                  value={newUserId}
                  onChange={(e) => setNewUserId(e.target.value)}
                  required
                />
                <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Luật sẽ chỉ áp dụng riêng cho phiên hội thoại của client này.</span>
              </div>

              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)" }}>Cụm từ khớp tuyệt đối (Keyword)</label>
                <input
                  type="text"
                  className="form-input"
                  placeholder="Ví dụ: uống trà sữa xingfu"
                  style={{ background: "var(--bg-obsidian-950)", fontSize: "13px" }}
                  value={newKeyword}
                  onChange={(e) => setNewKeyword(e.target.value)}
                  required
                />
                <span className="form-desc" style={{ fontSize: "11px", color: "var(--text-muted)" }}>Chuỗi chữ thường không dấu hoặc có dấu để bắt trùng khớp.</span>
              </div>

              <div className="form-group">
                <label className="form-label" style={{ color: "var(--text-primary)" }}>Danh mục gán tĩnh</label>
                <select
                  className="form-select"
                  value={newCategory}
                  onChange={(e) => setNewCategory(e.target.value)}
                  style={{ background: "var(--bg-obsidian-950)", fontSize: "13px", height: "40px" }}
                >
                  <option value="Food">Food (Ăn uống)</option>
                  <option value="Shopping">Shopping (Mua sắm)</option>
                  <option value="Transport">Transport (Di chuyển)</option>
                  <option value="Entertainment">Entertainment (Giải trí)</option>
                  <option value="Housing">Housing (Nhà ở)</option>
                  <option value="Health">Health (Sức khoẻ)</option>
                  <option value="Education">Education (Học tập)</option>
                  <option value="Travel">Travel (Du lịch)</option>
                  <option value="Others">Others (Khác)</option>
                  <option value="Salary">Salary (Lương)</option>
                  <option value="Bonus">Bonus (Thưởng/Lì xì)</option>
                  <option value="Business">Business (Kinh doanh)</option>
                  <option value="Essentials">Essentials (Thiết yếu)</option>
                  <option value="Beauty">Beauty (Làm đẹp)</option>
                  <option value="Social">Social (Xã hội)</option>
                </select>
              </div>

              <button type="submit" className="btn btn-primary" style={{
                marginTop: "8px",
                background: "var(--accent-blue)",
                color: "var(--text-primary)",
                fontWeight: "600",
                width: "100%",
                padding: "12px",
                border: "none",
                borderRadius: "8px"
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = "var(--accent-blue-hover)";
                e.currentTarget.style.boxShadow = "0 0 15px var(--accent-blue-glow)";
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = "var(--accent-blue)";
                e.currentTarget.style.boxShadow = "none";
              }}
              >
                Lưu quy tắc cá nhân hóa
              </button>
            </form>
          </div>
        </div>
      )}

      {/* TAB 2: CORRECTION AGGREGATION & CURATION */}
      {activeTab === "layer2" && (
        <div className="panel" style={{
          background: "var(--bg-obsidian-900)",
          border: "1px solid var(--border-color)",
          borderRadius: "16px",
          padding: "24px",
          boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
        }}>
          <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "16px" }}>
            <div>
              <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Cụm gom lỗi sửa của người dùng (Layer 2)</h2>
              <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>
                Các phản hồi điều chỉnh nhãn của khách hàng được tự động gom nhóm. Duyệt các dòng này để lưu vào tập huấn luyện bổ sung.
              </span>
            </div>
            
            <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: "12px" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Tự động huấn luyện lại:</span>
                  <select
                    value={autoRetrainAfterCurate}
                    onChange={(e) => setAutoRetrainAfterCurate(e.target.value)}
                    style={{
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid var(--border-color)",
                      color: "var(--text-primary)",
                      borderRadius: "6px",
                      padding: "6px 12px",
                      fontSize: "13px",
                      outline: "none",
                      cursor: "pointer"
                    }}
                  >
                    <option value="none">Không</option>
                    <option value="local">Cục bộ (CPU)</option>
                  </select>
                </div>
                <button
                  className="btn btn-primary"
                  onClick={handleExportCuration}
                  disabled={aggregations.length === 0 || !aggregations.some(a => a.approved)}
                  style={{
                    background: "var(--accent-emerald)",
                    color: "var(--bg-obsidian-950)",
                    fontWeight: "600",
                    padding: "10px 18px",
                    borderRadius: "8px",
                    opacity: (!aggregations.some(a => a.approved)) ? 0.5 : 1,
                    cursor: (!aggregations.some(a => a.approved)) ? "not-allowed" : "pointer"
                  }}
                >
                  Duyệt và xuất các câu đã chọn ({aggregations.filter(a => a.approved).length})
                </button>
              </div>
            </div>
          </div>

          <div className="table-container" style={{ borderRadius: "12px", border: "1px solid var(--border-color)", overflow: "hidden", marginTop: "20px" }}>
            <table className="custom-table">
              <thead>
                <tr style={{ background: "var(--bg-obsidian-950)" }}>
                  <th style={{ width: "50px", padding: "14px 18px" }}>
                    <input
                      type="checkbox"
                      checked={aggregations.length > 0 && aggregations.every((a) => a.approved)}
                      onChange={(e) => {
                        const checked = e.target.checked;
                        setAggregations(aggregations.map((a) => ({ ...a, approved: checked })));
                      }}
                      style={{ width: "16px", height: "16px", accentColor: "var(--accent-emerald)", cursor: "pointer" }}
                    />
                  </th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Nội dung câu nói</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Người dùng sửa thành</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Loại ví</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>AI đoán ban đầu</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Số lượt sửa (Votes)</th>
                  <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em", textAlign: "right" }}>Trạng thái</th>
                </tr>
              </thead>
              <tbody>
                {aggregations.map((agg, idx) => (
                  <tr key={idx} style={{
                    transition: "background 0.15s ease",
                    background: agg.approved ? "rgba(16, 185, 129, 0.02)" : "transparent"
                  }}>
                    <td style={{ padding: "14px 18px" }}>
                      <input
                        type="checkbox"
                        checked={agg.approved}
                        onChange={() => toggleAggregateApprove(idx)}
                        style={{ width: "16px", height: "16px", accentColor: "var(--accent-emerald)", cursor: "pointer" }}
                      />
                    </td>
                    <td className="monospaced" style={{ padding: "14px 18px", color: "var(--text-primary)" }}>
                      <code style={{ background: "var(--bg-obsidian-950)", padding: "4px 8px", borderRadius: "6px", border: "1px solid var(--border-color)", fontFamily: "var(--font-mono)" }}>"{agg.text}"</code>
                    </td>
                    <td style={{ padding: "14px 18px" }}>
                      <span className="badge badge-success" style={{
                        background: "rgba(16, 185, 129, 0.08)",
                        border: "1px solid rgba(16, 185, 129, 0.3)",
                        color: "var(--accent-emerald-hover)",
                        padding: "4px 10px",
                        borderRadius: "8px",
                        fontWeight: "600",
                        fontSize: "11px"
                      }}>
                        {agg.targetCategory}
                      </span>
                    </td>
                    <td style={{ padding: "14px 18px" }}>
                      <span className="badge" style={{
                        background: "rgba(2, 132, 199, 0.08)",
                        border: "1px solid rgba(2, 132, 199, 0.3)",
                        color: "var(--accent-blue-hover)",
                        padding: "4px 10px",
                        borderRadius: "8px",
                        fontWeight: "600",
                        fontSize: "11px",
                        textTransform: "uppercase"
                      }}>{agg.recordType || "Expense"}</span>
                    </td>
                    <td style={{ padding: "14px 18px" }}>
                      <span className="badge badge-danger" style={{
                        background: "rgba(239, 68, 68, 0.08)",
                        border: "1px solid rgba(239, 68, 68, 0.3)",
                        color: "var(--accent-rose-hover)",
                        padding: "4px 10px",
                        borderRadius: "8px",
                        fontWeight: "600",
                        fontSize: "11px"
                      }}>
                        {agg.originalCategory}
                      </span>
                    </td>
                    <td style={{ padding: "14px 18px", fontWeight: "700", fontFamily: "var(--font-mono)", fontSize: "14px", color: "var(--text-primary)" }}>
                      {agg.count.toLocaleString()}
                    </td>
                    <td style={{ padding: "14px 18px", textAlign: "right", fontSize: "13px", fontWeight: "600" }}>
                      {agg.approved ? (
                        <span style={{ color: "var(--accent-emerald)" }}>✓ Đã xếp hàng chờ</span>
                      ) : (
                        <span style={{ color: "var(--text-muted)" }}>Chờ duyệt</span>
                      )}
                    </td>
                  </tr>
                ))}
                {aggregations.length === 0 && (
                  <tr>
                    <td colSpan="7" style={{ textAlign: "center", padding: "40px", color: "var(--text-muted)" }}>
                      Không tìm thấy cụm từ đính chính nào trong chỉ mục logs.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: MODEL VERSIONING & RETRAINING */}
      {activeTab === "model" && (
        <>
          {/* Active Model Cards Selector Section */}
          <div style={{ marginBottom: "30px" }}>
            <h2 style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "16px" }}>Lựa chọn Bộ suy luận NLU vận hành</h2>
            
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "24px" }}>
              {/* Card 1: TF-IDF Classic */}
              <div style={{
                background: "var(--bg-obsidian-900)",
                border: inferenceBackend === "tfidf" ? "1px solid var(--accent-blue-hover)" : "1px solid var(--border-color)",
                borderRadius: "16px",
                padding: "24px",
                boxShadow: inferenceBackend === "tfidf" ? "0 0 15px rgba(56, 189, 248, 0.15)" : "none",
                display: "flex",
                flexDirection: "column",
                justifyContent: "space-between",
                opacity: (isTraining || isLlmTraining) ? 0.7 : 1,
                transition: "all 0.3s ease"
              }}>
                <div>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "12px" }}>
                    <span style={{ fontSize: "28px" }}>📊</span>
                    <span style={{
                      fontSize: "10px",
                      textTransform: "uppercase",
                      letterSpacing: "0.08em",
                      fontWeight: "700",
                      background: "rgba(2, 132, 199, 0.15)",
                      color: "var(--accent-blue-hover)",
                      padding: "4px 8px",
                      borderRadius: "6px"
                    }}>TF-IDF Classic</span>
                  </div>
                  <h3 style={{ fontSize: "16px", fontWeight: "700", color: "var(--text-primary)", marginBottom: "6px" }}>Phân loại TF-IDF & spaCy</h3>
                  <p style={{ fontSize: "12px", color: "var(--text-muted)", marginBottom: "12px", fontFamily: "var(--font-mono)" }}>Local CPU · ~20 MB · Trễ: &lt; 15ms</p>
                  <p style={{ fontSize: "13px", color: "var(--text-secondary)", lineHeight: "1.5" }}>
                    Bộ phân loại intent và category cổ điển dựa trên tần suất từ (TF-IDF) và spaCy NER. Hoạt động cực nhẹ, phản hồi tức thời nhưng không hiểu ngữ nghĩa phức tạp.
                  </p>
                </div>
                <div style={{ marginTop: "20px" }}>
                  {inferenceBackend === "tfidf" ? (
                    <button disabled style={{ width: "100%", padding: "10px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-color)", color: "var(--text-muted)", borderRadius: "8px", fontWeight: "600", cursor: "not-allowed" }}>
                      Đang kích hoạt
                    </button>
                  ) : (
                    <button
                      onClick={() => handleInferenceBackendChange("tfidf")}
                      disabled={savingBackend || isTraining || isLlmTraining}
                      style={{ width: "100%", padding: "10px", background: "var(--bg-obsidian-950)", border: "1px solid var(--accent-blue)", color: "var(--accent-blue-hover)", borderRadius: "8px", fontWeight: "600", cursor: "pointer", transition: "all 0.2s" }}
                      onMouseEnter={(e) => { e.currentTarget.style.background = "var(--accent-blue-glow)"; }}
                      onMouseLeave={(e) => { e.currentTarget.style.background = "var(--bg-obsidian-950)"; }}
                    >
                      Kích hoạt bộ lọc Classic
                    </button>
                  )}
                </div>
              </div>

              {/* Card 2: PhoBERT Encoder */}
              <div style={{
                background: "var(--bg-obsidian-900)",
                border: inferenceBackend === "encoder" ? "1px solid #c084fc" : "1px solid var(--border-color)",
                borderRadius: "16px",
                padding: "24px",
                boxShadow: inferenceBackend === "encoder" ? "0 0 15px rgba(192, 132, 252, 0.15)" : "none",
                display: "flex",
                flexDirection: "column",
                justifyContent: "space-between",
                opacity: (isTraining || isLlmTraining) ? 0.7 : 1,
                transition: "all 0.3s ease"
              }}>
                <div>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "12px" }}>
                    <span style={{ fontSize: "28px" }}>🧬</span>
                    <span style={{
                      fontSize: "10px",
                      textTransform: "uppercase",
                      letterSpacing: "0.08em",
                      fontWeight: "700",
                      background: "rgba(168, 85, 247, 0.15)",
                      color: "#c084fc",
                      padding: "4px 8px",
                      borderRadius: "6px"
                    }}>BERT Encoder</span>
                  </div>
                  <h3 style={{ fontSize: "16px", fontWeight: "700", color: "var(--text-primary)", marginBottom: "6px" }}>Phân loại PhoBERT Encoder</h3>
                  <p style={{ fontSize: "12px", color: "var(--text-muted)", marginBottom: "12px", fontFamily: "var(--font-mono)" }}>Local CPU/GPU · ~540 MB · Trễ: &lt; 80ms</p>
                  <p style={{ fontSize: "13px", color: "var(--text-secondary)", lineHeight: "1.5" }}>
                    Sử dụng biểu diễn ngữ nghĩa của ngôn ngữ tiếng Việt từ PhoBERT kết hợp mạng nơ-ron MLP để phân lớp. Nhận diện ý định thông minh hơn, chịu lỗi chính tả tốt.
                  </p>
                </div>
                <div style={{ marginTop: "20px" }}>
                  {inferenceBackend === "encoder" ? (
                    <button disabled style={{ width: "100%", padding: "10px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-color)", color: "var(--text-muted)", borderRadius: "8px", fontWeight: "600", cursor: "not-allowed" }}>
                      Đang kích hoạt
                    </button>
                  ) : (
                    <button
                      onClick={() => handleInferenceBackendChange("encoder")}
                      disabled={savingBackend || isTraining || isLlmTraining}
                      style={{ width: "100%", padding: "10px", background: "var(--bg-obsidian-950)", border: "1px solid #a855f7", color: "#c084fc", borderRadius: "8px", fontWeight: "600", cursor: "pointer", transition: "all 0.2s" }}
                      onMouseEnter={(e) => { e.currentTarget.style.background = "rgba(168, 85, 247, 0.1)"; }}
                      onMouseLeave={(e) => { e.currentTarget.style.background = "var(--bg-obsidian-950)"; }}
                    >
                      Kích hoạt PhoBERT
                    </button>
                  )}
                </div>
              </div>

              {/* Card 3: Qwen2.5 14B Fine-tuned */}
              <div style={{
                background: "var(--bg-obsidian-900)",
                border: inferenceBackend === "llm" ? "1px solid var(--accent-emerald-hover)" : "1px solid var(--border-color)",
                borderRadius: "16px",
                padding: "24px",
                boxShadow: inferenceBackend === "llm" ? "0 0 15px var(--accent-emerald-glow)" : "none",
                display: "flex",
                flexDirection: "column",
                justifyContent: "space-between",
                opacity: (isTraining || isLlmTraining) ? 0.7 : 1,
                transition: "all 0.3s ease"
              }}>
                <div>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "12px" }}>
                    <span style={{ fontSize: "28px" }}>🔥</span>
                    <span style={{
                      fontSize: "10px",
                      textTransform: "uppercase",
                      letterSpacing: "0.08em",
                      fontWeight: "700",
                      background: "var(--accent-emerald-glow)",
                      color: "var(--accent-emerald-hover)",
                      padding: "4px 8px",
                      borderRadius: "6px"
                    }}>LLM Agent</span>
                  </div>
                  <h3 style={{ fontSize: "16px", fontWeight: "700", color: "var(--text-primary)", marginBottom: "6px" }}>Qwen2.5-14B Fine-tuned (Mặc định)</h3>
                  <p style={{ fontSize: "12px", color: "var(--text-muted)", marginBottom: "12px", fontFamily: "var(--font-mono)" }}>Modal GPU (A10G) · ~29.5 GB · Trễ: &lt; 800ms</p>
                  <p style={{ fontSize: "13px", color: "var(--text-secondary)", lineHeight: "1.5" }}>
                    Sử dụng mô hình ngôn ngữ lớn đã fine-tune khớp hội thoại ví Mimo. Phân tích tự nhiên Gen Z slang (ét ô ét, mlem), xử lý đa luồng chi tiêu và phản hồi cực vui nhộn.
                  </p>
                </div>
                <div style={{ marginTop: "20px" }}>
                  {inferenceBackend === "llm" ? (
                    <button disabled style={{ width: "100%", padding: "10px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-color)", color: "var(--text-muted)", borderRadius: "8px", fontWeight: "600", cursor: "not-allowed" }}>
                      Đang kích hoạt làm mặc định
                    </button>
                  ) : (
                    <button
                      onClick={() => handleInferenceBackendChange("llm")}
                      disabled={savingBackend || isTraining || isLlmTraining}
                      style={{ width: "100%", padding: "10px", background: "var(--bg-obsidian-950)", border: "1px solid var(--accent-emerald)", color: "var(--accent-emerald-hover)", borderRadius: "8px", fontWeight: "600", cursor: "pointer", transition: "all 0.2s" }}
                      onMouseEnter={(e) => { e.currentTarget.style.background = "var(--accent-emerald-glow)"; }}
                      onMouseLeave={(e) => { e.currentTarget.style.background = "var(--bg-obsidian-950)"; }}
                    >
                      Kích hoạt làm Mặc định
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Trigger Train Worker Panel (Full Width) */}
          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            display: "flex",
            flexDirection: "column",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
            marginBottom: "24px"
          }}>
            <div>
              <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "16px" }}>
                <div style={{
                  width: "8px",
                  height: "8px",
                  borderRadius: "50%",
                  background: (isTraining || isLlmTraining) ? "var(--accent-amber)" : "var(--accent-emerald)",
                  boxShadow: (isTraining || isLlmTraining) ? "0 0 8px var(--accent-amber)" : "0 0 8px var(--accent-emerald)"
                }} />
                <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Bảng điều khiển huấn luyện</h2>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: "20px", marginBottom: "20px" }}>
                {/* Local CPU Retrain Card */}
                <div 
                  onClick={() => { if (!isTraining && !isLlmTraining) handleRetrain("local"); }}
                  style={{
                    border: `1px solid ${isTraining && compareTrainType === "tfidf" ? "var(--accent-emerald)" : "var(--border-color)"}`,
                    background: isTraining && compareTrainType === "tfidf" ? "rgba(16, 185, 129, 0.05)" : "var(--bg-obsidian-950)",
                    borderRadius: "12px",
                    padding: "24px 16px",
                    cursor: (isTraining || isLlmTraining) ? "not-allowed" : "pointer",
                    textAlign: "center",
                    transition: "all 0.2s"
                  }}
                >
                  <div style={{ fontSize: "32px", marginBottom: "10px" }}>💻</div>
                  <h4 style={{ fontSize: "14px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "6px" }}>Huấn luyện NLU Classic</h4>
                  <span style={{ fontSize: "12px", color: "var(--text-secondary)", display: "block" }}>Chạy nền · 1-2 phút</span>
                  <span style={{ fontSize: "11px", color: "var(--text-muted)", display: "block", marginTop: "8px", lineHeight: 1.4 }}>
                    Huấn luyện lại bộ phân loại TF-IDF cho Intent, Category, Record Type và mô hình Named Entity (NER).
                  </span>
                </div>

                {/* PhoBERT Encoder Retrain Card */}
                <div 
                  onClick={() => { if (!isTraining && !isLlmTraining) handleRetrain("encoder"); }}
                  style={{
                    border: `1px solid ${isTraining && compareTrainType === "encoder" ? "var(--accent-emerald)" : "var(--border-color)"}`,
                    background: isTraining && compareTrainType === "encoder" ? "rgba(16, 185, 129, 0.05)" : "var(--bg-obsidian-950)",
                    borderRadius: "12px",
                    padding: "24px 16px",
                    cursor: (isTraining || isLlmTraining) ? "not-allowed" : "pointer",
                    textAlign: "center",
                    transition: "all 0.2s"
                  }}
                >
                  <div style={{ fontSize: "32px", marginBottom: "10px" }}>🧬</div>
                  <h4 style={{ fontSize: "14px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "6px" }}>Huấn luyện PhoBERT</h4>
                  <span style={{ fontSize: "12px", color: "var(--text-secondary)", display: "block" }}>Chạy nền · 2-3 phút</span>
                  <span style={{ fontSize: "11px", color: "var(--text-muted)", display: "block", marginTop: "8px", lineHeight: 1.4 }}>
                    Huấn luyện lại các đầu phân loại MLP dựa trên embedding cố định của PhoBERT tiếng Việt.
                  </span>
                </div>

                {/* LLM Fine-tune Card */}
                <div 
                  style={{
                    border: `1px solid ${isLlmTraining ? "#a855f7" : "var(--border-color)"}`,
                    background: isLlmTraining ? "rgba(168, 85, 247, 0.05)" : "var(--bg-obsidian-950)",
                    borderRadius: "12px",
                    padding: "24px 16px",
                    textAlign: "center",
                    position: "relative"
                  }}
                >
                  <div style={{ fontSize: "32px", marginBottom: "10px" }}>🔥</div>
                  <h4 style={{ fontSize: "14px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "6px" }}>Fine-tune Qwen2.5-14B</h4>
                  <span style={{ fontSize: "12px", color: "var(--text-secondary)", display: "block", marginBottom: "12px" }}>GPU H100 Modal · ~1 giờ</span>
                  
                  {/* Hyperparameter Inputs */}
                  <div style={{ display: "flex", gap: "8px", justifyContent: "center", marginBottom: "16px", fontSize: "11px" }}>
                    <div style={{ display: "flex", flexDirection: "column", gap: "4px" }}>
                      <span style={{ color: "var(--text-muted)" }}>Epochs</span>
                      <input 
                        type="number" 
                        min="1" 
                        max="10"
                        step="1"
                        value={llmTrainParams.epochs}
                        onChange={(e) => {
                          const v = parseInt(e.target.value);
                          if (!isNaN(v)) setLlmTrainParams({ ...llmTrainParams, epochs: Math.min(10, Math.max(1, v)) });
                        }}
                        style={{ width: "50px", background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", color: "var(--text-primary)", borderRadius: "4px", padding: "4px", fontSize: "11px", textAlign: "center" }}
                      />
                    </div>
                    <div style={{ display: "flex", flexDirection: "column", gap: "4px" }}>
                      <span style={{ color: "var(--text-muted)" }}>LR</span>
                      <input 
                        type="number" 
                        step="0.00005"
                        min="0.00001"
                        max="1"
                        value={llmTrainParams.lr}
                        onChange={(e) => {
                          const v = parseFloat(e.target.value);
                          if (!isNaN(v) && v > 0 && v <= 1) setLlmTrainParams({ ...llmTrainParams, lr: v });
                        }}
                        style={{ width: "80px", background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", color: "var(--text-primary)", borderRadius: "4px", padding: "4px", fontSize: "11px", textAlign: "center" }}
                      />
                    </div>
                    <div style={{ display: "flex", flexDirection: "column", gap: "4px" }}>
                      <span style={{ color: "var(--text-muted)" }}>Batch Size</span>
                      <input 
                        type="number" 
                        min="1" 
                        max="16"
                        step="1"
                        value={llmTrainParams.batchSize}
                        onChange={(e) => {
                          const v = parseInt(e.target.value);
                          if (!isNaN(v)) setLlmTrainParams({ ...llmTrainParams, batchSize: Math.min(16, Math.max(1, v)) });
                        }}
                        style={{ width: "60px", background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", color: "var(--text-primary)", borderRadius: "4px", padding: "4px", fontSize: "11px", textAlign: "center" }}
                      />
                    </div>
                  </div>

                  <button 
                    onClick={handleLlmFinetune}
                    disabled={isTraining || isLlmTraining}
                    style={{
                      background: "var(--accent-emerald)",
                      color: "var(--bg-obsidian-950)",
                      border: "none",
                      borderRadius: "8px",
                      padding: "8px 16px",
                      fontSize: "12px",
                      fontWeight: "700",
                      cursor: (isTraining || isLlmTraining) ? "not-allowed" : "pointer",
                      opacity: (isTraining || isLlmTraining) ? 0.6 : 1
                    }}
                  >
                    {isLlmTraining ? "Đang Fine-tune..." : "Bắt đầu Fine-tune"}
                  </button>
                </div>
              </div>

              {isTraining && (
                <div style={{ background: "rgba(16, 185, 129, 0.05)", border: "1px solid rgba(16, 185, 129, 0.2)", borderRadius: "8px", padding: "12px", fontSize: "12px", color: "var(--accent-emerald)" }}>
                  ⚙️ Đang chạy huấn luyện NLU nền... Vui lòng không đóng trang.
                </div>
              )}
            </div>
          </div>

          <div className="dashboard-grid" style={{ gap: "24px" }}>
            {/* Model Registry Info */}
            <div className="panel" style={{
              background: "var(--bg-obsidian-900)",
              border: "1px solid var(--border-color)",
              borderRadius: "16px",
              padding: "24px",
              boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
            }}>
              <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", gap: "10px", alignItems: "center" }}>
                <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)", marginRight: "auto" }}>Chỉ mục trọng số hệ thống</h2>
                <button
                  className="btn btn-secondary"
                  style={{ padding: "6px 12px", fontSize: "12px", borderRadius: "6px", border: "1px solid var(--border-color)" }}
                  onClick={handleReloadNlu}
                  disabled={reloadingNlu || isTraining}
                >
                  {reloadingNlu ? "Đang tải..." : "Tải lại model NLU"}
                </button>
                <button
                  className="btn btn-secondary"
                  style={{ padding: "6px 12px", fontSize: "12px", borderRadius: "6px" }}
                  onClick={fetchAllData}
                >
                  Đồng bộ Registry
                </button>
              </div>
              
              <div style={{ display: "flex", flexDirection: "column", gap: "16px", marginTop: "16px" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Định danh Registry đang chạy</span>
                  <strong className="monospaced" style={{ color: "var(--accent-blue-hover)", fontSize: "13px" }}>{modelMeta.version}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Huấn luyện tại</span>
                  <strong className="monospaced" style={{ fontSize: "13px" }}>{modelMeta.trainedAt}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Bộ giải mã NLU hiện tại</span>
                  <strong className="monospaced" style={{ color: "var(--accent-emerald)", fontSize: "13px" }}>{inferenceBackend.toUpperCase()}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>F1-Score Đánh giá Chung</span>
                  <strong className="monospaced" style={{ color: "var(--accent-emerald-hover)", fontSize: "13px" }}>{modelMeta.f1Score}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", paddingBottom: "12px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Tiến trình huấn luyện nền</span>
                  <strong className="monospaced" style={{ fontSize: "13px" }}>
                    {isTraining ? (
                      <span style={{ color: "var(--accent-amber-hover)", display: "flex", alignItems: "center", gap: "6px" }}>
                        <span className="status-dot pulse" style={{ background: "var(--accent-amber)", boxShadow: "0 0 8px var(--accent-amber)", width: "6px", height: "6px", borderRadius: "50%" }}></span>
                        Đang huấn luyện NLU nền...
                      </span>
                    ) : isLlmTraining ? (
                      <span style={{ color: "var(--accent-amber-hover)", display: "flex", alignItems: "center", gap: "6px" }}>
                        <span className="status-dot pulse" style={{ background: "var(--accent-amber)", boxShadow: "0 0 8px var(--accent-amber)", width: "6px", height: "6px", borderRadius: "50%" }}></span>
                        Modal H100 Fine-tuning...
                      </span>
                    ) : (
                      <span style={{ color: "var(--accent-emerald-hover)", display: "flex", alignItems: "center", gap: "6px" }}>
                        <span className="status-dot" style={{ background: "var(--accent-emerald)", boxShadow: "0 0 8px var(--accent-emerald)", width: "6px", height: "6px", borderRadius: "50%" }}></span>
                        Trạng thái nghỉ (Idle)
                      </span>
                    )}
                  </strong>
                </div>
              </div>
            </div>

            {/* Import CSV Panel */}
            <div className="panel" style={{
              background: "var(--bg-obsidian-900)",
              border: "1px solid var(--border-color)",
              borderRadius: "16px",
              padding: "24px",
              boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
            }}>
              <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)" }}>
                <div>
                  <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Nạp tập dữ liệu huấn luyện bổ sung (Import CSV)</h2>
                  <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>
                    Tải lên tệp CSV chứa dữ liệu mẫu để tích hợp trực tiếp vào tập huấn luyện lõi.
                  </span>
                </div>
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: "20px", marginTop: "20px" }}>
                {/* Formatting Guidelines */}
                <div style={{ background: "var(--bg-obsidian-950)", padding: "18px", borderRadius: "12px", border: "1px solid var(--border-color)" }}>
                  <h3 style={{ color: "var(--text-primary)", fontSize: "13px", fontWeight: "600", marginBottom: "10px" }}>Hướng dẫn định dạng tệp CSV:</h3>
                  <p style={{ fontSize: "12px", color: "var(--text-secondary)", lineHeight: "1.6", margin: 0 }}>
                    • Mã hóa tệp bắt buộc là <strong>UTF-8</strong>.<br />
                    • Dòng tiêu đề: <code style={{ color: "var(--accent-blue-hover)", fontFamily: "var(--font-mono)" }}>text,label,type,is_money</code><br />
                    • <strong>text</strong>: Câu mô tả (Ví dụ: <code style={{ fontFamily: "var(--font-mono)" }}>"Ăn sáng hết 35k"</code>)<br />
                    • <strong>label</strong>: Tên danh mục chuẩn (Ví dụ: <code style={{ fontFamily: "var(--font-mono)" }}>Food, Shopping, ...</code>)
                  </p>
                </div>

                {/* Upload Area */}
                <form 
                  onSubmit={(e) => {
                    e.preventDefault();
                    if (!csvFile) return;
                    if (!window.confirm(`Bạn có chắc chắn muốn nạp dữ liệu từ tệp "${csvFile.name}" và cập nhật dataset huấn luyện NLU không?`)) return;
                    handleImportCsv(e);
                  }} 
                  style={{ display: "flex", flexDirection: "column", gap: "16px" }}
                >
                  <div className="form-group" style={{ margin: 0 }}>
                    <label className="form-label" style={{ color: "var(--text-primary)", marginBottom: "8px", display: "block" }}>Chọn tệp CSV dữ liệu</label>
                    <input
                      id="nlu-csv-file-input"
                      type="file"
                      accept=".csv"
                      className="form-input"
                      style={{ background: "var(--bg-obsidian-950)", padding: "8px 12px" }}
                      onChange={(e) => setCsvFile(e.target.files?.[0] || null)}
                      required
                    />
                  </div>

                  <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                      <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Tự động huấn luyện:</span>
                      <select
                        value={autoRetrainCsv}
                        onChange={(e) => setAutoRetrainCsv(e.target.value)}
                        style={{
                          background: "var(--bg-obsidian-950)",
                          border: "1px solid var(--border-color)",
                          color: "var(--text-primary)",
                          borderRadius: "6px",
                          padding: "6px 12px",
                          fontSize: "13px",
                          outline: "none",
                          cursor: "pointer"
                        }}
                      >
                        <option value="none">Không</option>
                        <option value="local">Cục bộ (CPU)</option>
                      </select>
                    </div>
                  </div>

                  <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={importingCsv || !csvFile}
                    style={{
                      background: "var(--accent-emerald)",
                      color: "var(--bg-obsidian-950)",
                      fontWeight: "600",
                      width: "100%",
                      padding: "10px",
                      borderRadius: "8px",
                      opacity: (importingCsv || !csvFile) ? 0.6 : 1,
                      cursor: (importingCsv || !csvFile) ? "not-allowed" : "pointer"
                    }}
                  >
                    {importingCsv ? "Đang nạp dữ liệu..." : "Nạp dữ liệu vào CSV hệ thống"}
                  </button>
                </form>
              </div>
            </div>
          </div>

          {/* Model Comparison Table */}
          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
            marginTop: "24px"
          }}>
            <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "16px" }}>
              <div>
                <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>So sánh chỉ số chất lượng mô hình (F1/Accuracy)</h2>
                <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>
                  Theo dõi sự thay đổi chất lượng mô hình trước và sau khi retrain riêng biệt cho từng loại.
                </span>
              </div>
              <div style={{ display: "flex", gap: "8px", flexWrap: "wrap", alignItems: "center" }}>
                {["tfidf", "encoder"].map((type) => (
                  <button
                    key={type}
                    type="button"
                    onClick={() => setCompareTrainType(type)}
                    style={{
                      padding: "6px 14px",
                      borderRadius: "8px",
                      fontSize: "12px",
                      fontWeight: "600",
                      cursor: "pointer",
                      border: compareTrainType === type
                        ? (type === "encoder" ? "1px solid var(--accent-violet)" : "1px solid var(--accent-blue-hover)")
                        : "1px solid var(--border-color)",
                      background: compareTrainType === type
                        ? (type === "encoder" ? "rgba(139, 92, 246, 0.1)" : "rgba(26, 115, 232, 0.08)")
                        : "var(--bg-obsidian-950)",
                      color: compareTrainType === type ? "var(--text-primary)" : "var(--text-secondary)",
                    }}
                  >
                    {type === "tfidf" ? "NLU Classic (TF-IDF)" : "PhoBERT Encoder"}
                  </button>
                ))}
              </div>
              {(() => {
                const filtered = filterHistoryByType(trainHistory, compareTrainType);
                if (!filtered.length) return null;
                const latest = filtered[filtered.length - 1];
                const prev = filtered.length > 1 ? filtered[filtered.length - 2] : null;
                const typeLabel = compareTrainType === "encoder" ? "Encoder" : "TF-IDF";
                return (
                  <div style={{ fontSize: "12px", color: "var(--text-secondary)", display: "flex", gap: "16px", flexWrap: "wrap", width: "100%" }}>
                    <span>
                      {typeLabel} mới nhất: <strong style={{ color: compareTrainType === "encoder" ? "#c4b5fd" : "var(--accent-blue-hover)" }}>Run #{latest.run_index}</strong>
                      {" "}({new Date(latest.trained_at).toLocaleDateString("vi-VN")})
                      {latest.source ? ` · ${latest.source}` : ""}
                      {latest.encoder_model ? ` · ${latest.encoder_model}` : ""}
                    </span>
                    {prev && (
                      <span>
                        Trước đó: <strong style={{ color: "var(--text-muted)" }}>Run #{prev.run_index}</strong>
                        {prev.source ? ` · ${prev.source}` : ""}
                      </span>
                    )}
                  </div>
                );
              })()}
            </div>

            {filterHistoryByType(trainHistory, compareTrainType).length === 0 && (
              <div style={{ marginTop: "16px", padding: "14px", borderRadius: "8px", background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", fontSize: "12px", color: "var(--text-muted)" }}>
                Chưa có dữ liệu lịch sử chạy huấn luyện thành công cho mô hình {compareTrainType === "encoder" ? "PhoBERT encoder" : "TF-IDF classic"}.
              </div>
            )}

            <div className="table-container" style={{ borderRadius: "12px", border: "1px solid var(--border-color)", overflow: "hidden", marginTop: "16px" }}>
              <table className="custom-table">
                <thead>
                  <tr style={{ background: "var(--bg-obsidian-950)" }}>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Thành phần Pipeline</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Accuracy (Độ chính xác)</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Precision</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Recall</th>
                    <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>F1-Score</th>
                  </tr>
                </thead>
                <tbody>
                  {(COMPARISON_ROWS[compareTrainType] || COMPARISON_ROWS.tfidf).map((sub) => (
                    <tr key={sub.key}>
                      <td style={{ padding: "14px 18px" }}>
                        <div style={{ color: "var(--text-primary)", fontWeight: "600", fontSize: "13px" }}>{sub.label}</div>
                        <div style={{ color: "var(--text-muted)", fontSize: "11px", marginTop: "2px" }}>{sub.desc}</div>
                      </td>
                      <td style={{ padding: "14px 18px" }}>{renderMetricCell(sub.key, "accuracy")}</td>
                      <td style={{ padding: "14px 18px" }}>{renderMetricCell(sub.key, "precision")}</td>
                      <td style={{ padding: "14px 18px" }}>{renderMetricCell(sub.key, "recall")}</td>
                      <td style={{ padding: "14px 18px" }}>{renderMetricCell(sub.key, "f1_score")}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {compareTrainType === "tfidf" && (() => {
              const filtered = filterHistoryByType(trainHistory, "tfidf");
              const latest = filtered.length ? filtered[filtered.length - 1] : null;
              const slots = latest?.metrics?.action_slots || modelMeta?.actionSlots;
              const fields = slots?.fields;
              if (!fields || typeof fields !== "object") return null;
              const summary = slots.summary || {};
              return (
                <div style={{ marginTop: "20px", padding: "16px", background: "var(--bg-obsidian-950)", borderRadius: "12px", border: "1px solid var(--border-color)" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "12px", flexWrap: "wrap", gap: "8px" }}>
                    <h3 style={{ margin: 0, fontSize: "14px", fontWeight: "600", color: "var(--text-primary)" }}>Chi tiết trích xuất Action Slots theo trường</h3>
                    <span style={{ fontSize: "11px", color: "var(--text-muted)" }}>
                      {summary.trained_fields ?? Object.keys(fields).length} fields
                      {summary.dataset_rows != null ? ` · ${summary.dataset_rows.toLocaleString()} rows CSV` : ""}
                      {summary.avg_weighted_f1 != null ? ` · avg F1 ${(summary.avg_weighted_f1 * 100).toFixed(1)}%` : ""}
                    </span>
                  </div>
                  <div className="table-container" style={{ borderRadius: "8px", border: "1px solid var(--border-color)", overflow: "hidden" }}>
                    <table className="custom-table">
                      <thead>
                        <tr style={{ background: "var(--bg-obsidian-900)" }}>
                          <th style={{ padding: "10px 14px", fontSize: "10px" }}>Tên Slot Field</th>
                          <th style={{ padding: "10px 14px", fontSize: "10px" }}>Kiểu dữ liệu</th>
                          <th style={{ padding: "10px 14px", fontSize: "10px" }}>Số mẫu train</th>
                          <th style={{ padding: "10px 14px", fontSize: "10px" }}>Accuracy</th>
                          <th style={{ padding: "10px 14px", fontSize: "10px" }}>Weighted F1</th>
                        </tr>
                      </thead>
                      <tbody>
                        {Object.entries(fields).map(([name, m]) => (
                          <tr key={name}>
                            <td style={{ padding: "10px 14px", fontFamily: "var(--font-mono)", fontSize: "12px" }}>{name}</td>
                            <td style={{ padding: "10px 14px", fontSize: "12px" }}>{m.type || "—"}</td>
                            <td style={{ padding: "10px 14px", fontSize: "12px" }}>{m.train_samples ?? "—"}</td>
                            <td style={{ padding: "10px 14px", fontSize: "12px" }}>
                              {m.accuracy != null ? `${(m.accuracy * 100).toFixed(1)}%` : "—"}
                            </td>
                            <td style={{ padding: "10px 14px", fontSize: "12px" }}>
                              {m.weighted_f1 != null ? `${(m.weighted_f1 * 100).toFixed(1)}%` : "—"}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              );
            })()}
          </div>
        </>
      )}

      {toastMessage && (
        <div className="toast" style={{
          position: "fixed",
          bottom: "30px",
          right: "30px",
          background: "var(--bg-obsidian-800)",
          border: "1px solid var(--accent-blue)",
          borderRadius: "8px",
          padding: "14px 20px",
          boxShadow: "0 10px 25px rgba(0,0,0,0.3), 0 0 15px rgba(2, 132, 199, 0.1)",
          display: "flex",
          alignItems: "center",
          gap: "10px",
          zIndex: 9999
        }}>
          <div className="brand-dot" style={{ background: "var(--accent-blue)", width: "8px", height: "8px", borderRadius: "50%" }}></div>
          <span style={{ color: "var(--text-primary)", fontSize: "13px", fontWeight: "500" }}>{toastMessage}</span>
        </div>
      )}
    </div>
  );
}

export default NluOpsPage;
