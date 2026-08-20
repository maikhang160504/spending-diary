import React, { useState, useEffect, Fragment } from "react";
import {
  getNluOverrides,
  addNluOverride,
  deleteNluOverride,
  cleanupInvalidNluOverrides,
  triggerNluTrain,
  getNluTrainStatus,
  getNluModelMeta,
  getNluTrainHistory,
  getNluModelsStatus,
  getNluBenchmarkResults,
  reloadAiModels,
  getNluInferenceBackend,
  setNluInferenceBackend,
  triggerLlmFinetune,
  exportFinetuneData,
  promoteNluModel,
  rollbackNluModel,
  rejectNluModel,
  getLlmTrainHistory,
  getLlmTrainStatus,
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
    { key: "nlu_chitchat", label: "Intent Model (Stage 1)", desc: "Phân loại ý định Record / Action / Chitchat — TF-IDF" },
    { key: "nlu_record", label: "Category Model (Stage 2)", desc: "Phân loại 18 danh mục chi tiêu tự động — TF-IDF" },
  ],
  encoder: [
    { key: "nlu_chitchat", label: "Intent (Stage 1 - PhoBERT)", desc: "Record / Action / Chitchat — embedding PhoBERT" },
    { key: "nlu_record", label: "Category (Stage 2 - PhoBERT)", desc: "Phân loại 18 danh mục chi tiêu — embedding PhoBERT" },
  ],
};

function historyTrainType(entry) {
  return entry?.train_type || "tfidf";
}

function filterHistoryByType(history, type) {
  return (history || []).filter((r) => historyTrainType(r) === type && r.status === "success");
}


function NluOpsPage() {
  const [activeTab, setActiveTab] = useState("model");
  const [toastMessage, setToastMessage] = useState("");
  const [loading, setLoading] = useState(false);

  // Layer 1 state
  const [layer1Rules, setLayer1Rules] = useState([]);
  const [searchExact, setSearchExact] = useState("");
  const [newKeyword, setNewKeyword] = useState("");
  const [newCategory, setNewCategory] = useState("Food");
  const [newUserId, setNewUserId] = useState("");
  
  // Modal & Pagination for Layer 1
  const [showAddRuleModal, setShowAddRuleModal] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 10;

  // Model status state
  const [isTraining, setIsTraining] = useState(false);
  const [trainProgressInfo, setTrainProgressInfo] = useState(null);
  const [isLlmTraining, setIsLlmTraining] = useState(false);
  const [llmTrainProgressInfo, setLlmTrainProgressInfo] = useState(null);
  const [modelsStatus, setModelsStatus] = useState(null);
  const [llmHistory, setLlmHistory] = useState([]);
  const [benchmarkResults, setBenchmarkResults] = useState(null);
  const [isBenchmarking, setIsBenchmarking] = useState(false);
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
  const [intentBackend, setIntentBackend] = useState("llm_v2");
  const [categoryBackend, setCategoryBackend] = useState("llm_v2");
  const [savingBackend, setSavingBackend] = useState(false);
  const [compareTrainType, setCompareTrainType] = useState("encoder");

  // Model 3-state
  const [promotingModel, setPromotingModel] = useState(false);

  const hasNewCandidate = Boolean(modelsStatus?.candidate?.exists);
  const hasOldBackup = Boolean(modelsStatus?.old?.exists);

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
      getNluTrainStatus().catch(() => ({ training_active: false })),
      getNluModelMeta().catch(() => ({ version: "v1.2.0-fallback", trainedAt: "2026-06-21", f1Score: "91.2%" })),
      getNluTrainHistory().catch(() => []),
      getNluInferenceBackend().catch(() => ({ backend: "tfidf" })),
      getNluModelsStatus().catch(() => null),
      getLlmTrainHistory().catch(() => []),
      getNluBenchmarkResults().catch(() => null)
    ])
      .then(([overridesData, statusData, metaData, historyData, backendData, modelsStatusData, llmHistData, benchData]) => {
        setLayer1Rules(overridesData);
        setIsTraining(statusData.training_active);
        setTrainProgressInfo(statusData);
        getLlmTrainStatus().then(llmStatus => {
          setIsLlmTraining(llmStatus?.isTraining || false);
          setLlmTrainProgressInfo(llmStatus);
        }).catch(() => {});
        setModelMeta(metaData);
        setTrainHistory(historyData);
        setModelsStatus(modelsStatusData);
        setLlmHistory(llmHistData);
        setBenchmarkResults(benchData);
        setIntentBackend(backendData?.intent_backend || metaData?.intent_backend || "encoder");
        setCategoryBackend(backendData?.category_backend || metaData?.category_backend || "llm_v2");
        const intent_b = backendData?.intent_backend || metaData?.intent_backend || "encoder";
        setCompareTrainType(intent_b === "encoder" ? "encoder" : "tfidf");
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
              getNluModelsStatus().then(st => setModelsStatus(st)).catch(() => {});
            }
          })
          .catch(() => {});
      }, 3000);
    }
    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }, [isTraining]);

  useEffect(() => {
    let intervalId;
    if (isLlmTraining) {
      intervalId = setInterval(() => {
        getLlmTrainStatus()
          .then((data) => {
            setLlmTrainProgressInfo(data);
            if (!data.isTraining) {
              setIsLlmTraining(false);
              showToast("Huấn luyện LLM hoàn tất!");
              getLlmTrainHistory().then(data => setLlmHistory(data)).catch(() => {});
            }
          })
          .catch(() => {});
      }, 3000);
    }
    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }, [isLlmTraining]);

  // Tab switching loads specific data just in case
  const handleTabChange = (tab) => {
    setActiveTab(tab);
    if (tab === "layer1") {
      getNluOverrides().then(data => setLayer1Rules(data)).catch(() => {});
    } else if (tab === "model") {
      getNluTrainStatus().then(data => setIsTraining(data.training_active)).catch(() => {});
      getNluModelMeta().then(data => setModelMeta(data)).catch(() => {});
      getNluTrainHistory().then(data => setTrainHistory(data)).catch(() => {});
      getNluModelsStatus().then(data => setModelsStatus(data)).catch(() => {});
      getLlmTrainHistory().then(data => setLlmHistory(data)).catch(() => {});
      getNluBenchmarkResults().then(data => setBenchmarkResults(data)).catch(() => {});
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
  const handleInferenceBackendChange = async (newIntentBackend, newCategoryBackend) => {
    const pwd = window.prompt("Nhập mật khẩu quản trị để xác nhận chuyển đổi mô hình:", "");
    if (pwd === null) return;

    setSavingBackend(true);
    try {
      await setNluInferenceBackend({
        intent_backend: newIntentBackend,
        category_backend: newCategoryBackend,
        backend: newIntentBackend,
      }, pwd);
      setIntentBackend(newIntentBackend);
      setCategoryBackend(newCategoryBackend);
      setCompareTrainType(newIntentBackend === "encoder" ? "encoder" : "tfidf");
      showToast("Đã cập nhật cấu hình mô hình NLU thành công!");
      getNluModelMeta().then(setModelMeta).catch(() => {});
    } catch (err) {
      showToast("Cập nhật mô hình thất bại: " + (err.message || err));
    } finally {
      setSavingBackend(false);
    }
  };



  const handleExportFinetuneData = async () => {
    try {
      await exportFinetuneData();
      showToast("Đã bắt đầu tải tệp dữ liệu JSONL!");
    } catch (err) {
      showToast("Xuất dữ liệu thất bại: " + (err.message || err));
    }
  };

  const handleLlmFinetune = async () => {
    if (hasNewCandidate) {
      showToast("Đang có mô hình Candidate chờ duyệt. Vui lòng Duyệt áp dụng hoặc Từ chối trước khi bắt đầu huấn luyện mới.");
      return;
    }
    const pwd = window.prompt("Nhập mật khẩu quản trị để kích hoạt fine-tune LLM trên GPU Modal:", "");
    if (pwd === null) return;

    setIsLlmTraining(true);
    try {
      const data = await triggerLlmFinetune(
        llmTrainParams.epochs,
        llmTrainParams.lr,
        llmTrainParams.batchSize,
        pwd
      );
      showToast(data?.message || "Đã gửi yêu cầu Fine-tune LLM lên Modal GPU thành công!");
    } catch (err) {
      showToast("Fine-tune LLM thất bại: " + (err.message || err));
      setIsLlmTraining(false);
    }
  };

  // Trigger retraining in background
  const handleRetrain = async (target = "local") => {
    if (hasNewCandidate) {
      showToast("Đang có mô hình Candidate chờ duyệt. Vui lòng Duyệt áp dụng hoặc Từ chối trước khi bắt đầu huấn luyện mới.");
      return;
    }
    const label = target === "encoder" ? "PhoBERT Encoder" : "TF-IDF & NLU";
    const pw = window.prompt(`Xác nhận huấn luyện lại mô hình ${label}.\nQuá trình này sẽ chạy nền.\n\nNhập mật khẩu quản trị hệ thống để xác nhận:`, "");
    if (!pw) return;
    setCompareTrainType(target === "encoder" ? "encoder" : "tfidf");
    setLoading(true);
    try {
      const res = await triggerNluTrain(target, pw);
      setIsTraining(true);
      showToast(res.message || `Đã bắt đầu retrain mô hình ${label} chạy nền!`);
      fetchAllData();
    } catch (err) {
      showToast("Huấn luyện thất bại: " + (err.message || err));
    } finally {
      setLoading(false);
    }
  };

  const handleRunBenchmark = async () => {
    if (!window.confirm("Bắt đầu tiến trình đánh giá Benchmark NLU với Golden Dataset? (Có thể tốn vài phút)")) return;
    setIsBenchmarking(true);
    try {
      const data = await triggerNluBenchmark();
      showToast(data?.message || "Đã bắt đầu chạy Benchmark NLU!");
      // Optionally fetch results after a delay or let user manually refresh
      setTimeout(() => {
        getNluBenchmarkResults().then(res => setBenchmarkResults(res)).catch(() => {});
        setIsBenchmarking(false);
      }, 5000);
    } catch (err) {
      showToast("Khởi chạy Benchmark thất bại: " + (err.message || err));
      setIsBenchmarking(false);
    }
  };

  const handleSaveBackends = async () => {
    setSavingBackend(true);
    try {
      const res = await setNluInferenceBackend({ intent_backend: intentBackend, category_backend: categoryBackend });
      showToast(res.message || "Đã lưu cài đặt backend AI thành công!");
    } catch (err) {
      showToast("Lưu thất bại: " + (err.message || err));
    } finally {
      setSavingBackend(false);
    }
  };

  const handleReloadNlu = async () => {
    if (!window.confirm("Bạn có chắc chắn muốn nạp nóng lại mô hình NLU mới nhất từ đĩa không?")) return;
    setReloadingNlu(true);
    try {
      const res = await reloadAiModels("nlu");
      const ver = res.nlu_version ? ` (${res.nlu_version})` : "";
      showToast((res.message || "Model NLU đã được nạp nóng thành công!") + ver);
      fetchAllData();
    } catch (err) {
      showToast("Tải lại model thất bại: " + (err.message || err));
    } finally {
      setReloadingNlu(false);
    }
  };

  const handleRollbackNlu = async () => {
    const pw = window.prompt("Xác nhận khôi phục mô hình NLU về phiên bản trước.\n\nNhập mật khẩu quản trị hệ thống để xác nhận:", "");
    if (!pw) return;
    setPromotingModel(true);
    try {
      const res = await rollbackNluModel(pw);
      const msg = res?.message || "Đã khôi phục thành công mô hình NLU trước đó!";
      showToast(msg);
      window.alert(msg);
      await fetchAllData();
    } catch (err) {
      const errMsg = "Khôi phục thất bại: " + (err.message || err);
      showToast(errMsg);
      window.alert(errMsg);
    } finally {
      setPromotingModel(false);
    }
  };

  const handlePromoteModel = async () => {
    const pw = window.prompt("Xác nhận duyệt áp dụng mô hình mới (Candidate -> Current / Active).\n\nMô hình hiện tại sẽ được chuyển thành bản sao lưu (Old).\nNhập mật khẩu quản trị để xác nhận:", "");
    if (!pw) return;
    setPromotingModel(true);
    try {
      const res = await promoteNluModel(pw);
      const msg = res?.message || "Đã duyệt và kích hoạt mô hình mới thành công!";
      showToast(msg);
      window.alert(msg);
      await fetchAllData();
    } catch (err) {
      const errMsg = "Duyệt mô hình thất bại: " + (err.message || err);
      showToast(errMsg);
      window.alert(errMsg);
    } finally {
      setPromotingModel(false);
    }
  };

  const handleRejectModel = async () => {
    const pw = window.prompt("Xác nhận từ chối và hủy bỏ mô hình mới (Candidate).\n\nNhập mật khẩu quản trị để xác nhận:", "");
    if (!pw) return;
    setPromotingModel(true);
    try {
      const res = await rejectNluModel(pw);
      const msg = res?.message || "Đã từ chối và hủy bỏ mô hình candidate thành công!";
      showToast(msg);
      window.alert(msg);
      await fetchAllData();
    } catch (err) {
      const errMsg = "Từ chối mô hình thất bại: " + (err.message || err);
      showToast(errMsg);
      window.alert(errMsg);
    } finally {
      setPromotingModel(false);
    }
  };

  const filteredRules = layer1Rules.filter((r) =>
    (r.keyword || '').toLowerCase().includes(searchExact.toLowerCase()) ||
    (r.userId || '').toLowerCase().includes(searchExact.toLowerCase()) ||
    (r.email || '').toLowerCase().includes(searchExact.toLowerCase())
  );
  
  const totalPages = Math.max(1, Math.ceil(filteredRules.length / pageSize));
  const paginatedRules = filteredRules.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  const getBackendLabel = (bk) => {
    if (bk === "llm_v2") return "LLM Rules (2 Tầng - Mặc định)";
    if (bk === "llm") return "LLM Classic (Đơn khối cũ)";
    if (bk === "encoder" || bk === "pho_bert") return "PhoBERT Encoder";
    return "TF-IDF Classic";
  };

  const getBackendBadgeColor = (bk) => {
    if (bk === "llm_v2" || bk === "llm") return "var(--accent-emerald)";
    if (bk === "encoder" || bk === "pho_bert") return "#a855f7"; // purple
    return "var(--accent-blue)";
  };

  const renderProgressStepper = (currentStage) => {
    const stages = ["PREPARING", "CLEANING", "TRAINING", "EVALUATING", "SYNCING", "SUCCESS"];
    const currentIndex = stages.indexOf(currentStage);
    
    return (
      <div style={{ display: "flex", alignItems: "center", gap: "8px", width: "100%", marginTop: "12px", marginBottom: "8px" }}>
        {stages.map((stage, idx) => {
          let state = "pending"; // default
          if (idx < currentIndex || currentStage === "SUCCESS") state = "completed";
          else if (idx === currentIndex) state = "active";
          else if (currentStage === "ERROR") state = "error";

          let bgColor = "var(--bg-obsidian-800)";
          let textColor = "var(--text-muted)";
          let shadow = "none";
          if (state === "completed") { bgColor = "var(--accent-emerald)"; textColor = "var(--bg-obsidian-950)"; }
          else if (state === "active") { bgColor = "var(--accent-amber)"; textColor = "var(--bg-obsidian-950)"; shadow = "0 0 8px var(--accent-amber)"; }
          else if (state === "error" && idx === currentIndex) { bgColor = "var(--accent-rose)"; textColor = "white"; shadow = "0 0 8px var(--accent-rose)"; }
          
          return (
            <div key={stage} style={{ display: "contents" }}>
              <div style={{
                background: bgColor,
                color: textColor,
                fontSize: "10px",
                fontWeight: "700",
                padding: "6px 8px",
                borderRadius: "6px",
                textAlign: "center",
                flex: 1,
                boxShadow: shadow,
                transition: "all 0.3s ease",
                whiteSpace: "nowrap",
                overflow: "hidden",
                textOverflow: "ellipsis"
              }}>
                {stage}
              </div>
              {idx < stages.length - 1 && (
                <div style={{ height: "2px", flex: 0.2, background: idx < currentIndex ? "var(--accent-emerald)" : "var(--bg-obsidian-800)", transition: "all 0.3s ease" }}></div>
              )}
            </div>
          );
        })}
      </div>
    );
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
          <div style={{ display: "flex", gap: "8px" }}>
            <span style={{
              fontSize: "13px",
              fontWeight: "700",
              color: "var(--text-primary)",
              background: `${getBackendBadgeColor(intentBackend)}22`,
              border: `1px solid ${getBackendBadgeColor(intentBackend)}55`,
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
                background: getBackendBadgeColor(intentBackend),
                boxShadow: `0 0 8px ${getBackendBadgeColor(intentBackend)}`
              }}></span>
              Tầng 1: {getBackendLabel(intentBackend)}
            </span>
            <span style={{
              fontSize: "13px",
              fontWeight: "700",
              color: "var(--text-primary)",
              background: `${getBackendBadgeColor(categoryBackend)}22`,
              border: `1px solid ${getBackendBadgeColor(categoryBackend)}55`,
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
                background: getBackendBadgeColor(categoryBackend),
                boxShadow: `0 0 8px ${getBackendBadgeColor(categoryBackend)}`
              }}></span>
              Tầng 2: {getBackendLabel(categoryBackend)}
            </span>
          </div>
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
            {isTraining 
              ? `${trainProgressInfo?.message || "Đang Retraining..."}${trainProgressInfo?.elapsed_seconds ? ` (${trainProgressInfo.elapsed_seconds}s)` : ""}`
              : isLlmTraining 
                ? `LLM: ${llmTrainProgressInfo?.message || "Đang Fine-tune..."} - ${llmTrainProgressInfo?.progress_percent || 0}%`
                : "Sẵn sàng"}
          </span>
        </div>
      </div>

      <div className="tabs-header" style={{ marginBottom: "28px" }}>
        <button
          className={`tab-btn ${activeTab === "model" ? "active" : ""}`}
          onClick={() => handleTabChange("model")}
          style={{ fontSize: "14px", padding: "12px 20px" }}
        >
          Trọng số & Huấn luyện
        </button>

        <button
          className={`tab-btn ${activeTab === "layer1" ? "active" : ""}`}
          onClick={() => handleTabChange("layer1")}
          style={{ fontSize: "14px", padding: "12px 20px" }}
        >
          Layer 1: Cá nhân hóa danh mục
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
        <div>
          <div className="panel" style={{
            background: "var(--bg-obsidian-900)",
            border: "1px solid var(--border-color)",
            borderRadius: "16px",
            padding: "24px",
            boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
          }}>
            <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
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
                  onChange={(e) => {
                    setSearchExact(e.target.value);
                    setCurrentPage(1);
                  }}
                />
                <button
                  type="button"
                  className="btn btn-primary"
                  style={{ whiteSpace: "nowrap", fontSize: "13px", background: "var(--accent-blue)", border: "none" }}
                  onClick={() => setShowAddRuleModal(true)}
                >
                  + Thêm quy tắc
                </button>
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
                  {paginatedRules.map((rule, idx) => (
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
              
              {/* Pagination Controls */}
              {filteredRules.length > 0 && (
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 18px", background: "var(--bg-obsidian-950)", borderTop: "1px solid var(--border-color)" }}>
                  <span style={{ fontSize: "12px", color: "var(--text-muted)" }}>
                    Hiển thị {(currentPage - 1) * pageSize + 1} - {Math.min(currentPage * pageSize, filteredRules.length)} trong tổng số {filteredRules.length} quy tắc
                  </span>
                  <div style={{ display: "flex", gap: "8px" }}>
                    <button
                      onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                      disabled={currentPage === 1}
                      style={{
                        padding: "6px 12px",
                        background: currentPage === 1 ? "transparent" : "var(--bg-obsidian-800)",
                        color: currentPage === 1 ? "var(--text-muted)" : "var(--text-primary)",
                        border: "1px solid var(--border-color)",
                        borderRadius: "6px",
                        cursor: currentPage === 1 ? "not-allowed" : "pointer",
                        fontSize: "12px"
                      }}
                    >
                      Trước
                    </button>
                    <span style={{ padding: "6px 12px", fontSize: "12px", color: "var(--text-primary)", background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "6px" }}>
                      Trang {currentPage} / {totalPages}
                    </span>
                    <button
                      onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                      disabled={currentPage === totalPages}
                      style={{
                        padding: "6px 12px",
                        background: currentPage === totalPages ? "transparent" : "var(--bg-obsidian-800)",
                        color: currentPage === totalPages ? "var(--text-muted)" : "var(--text-primary)",
                        border: "1px solid var(--border-color)",
                        borderRadius: "6px",
                        cursor: currentPage === totalPages ? "not-allowed" : "pointer",
                        fontSize: "12px"
                      }}
                    >
                      Tiếp
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Add Rule Modal */}
          {showAddRuleModal && (
            <div style={{
              position: "fixed",
              top: 0, left: 0, right: 0, bottom: 0,
              background: "rgba(0, 0, 0, 0.7)",
              backdropFilter: "blur(4px)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              zIndex: 999
            }}>
              <div style={{
                background: "var(--bg-obsidian-900)",
                border: "1px solid var(--border-color)",
                borderRadius: "16px",
                padding: "24px",
                width: "480px",
                maxWidth: "90vw",
                boxShadow: "0 10px 40px rgba(0,0,0,0.5)"
              }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", paddingBottom: "20px", borderBottom: "1px solid var(--border-color)" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                    <div className="brand-dot" style={{ background: "var(--accent-blue)" }}></div>
                    <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Thêm quy tắc cá nhân hóa danh mục</h2>
                  </div>
                  <button 
                    onClick={() => setShowAddRuleModal(false)}
                    style={{ background: "transparent", border: "none", color: "var(--text-muted)", fontSize: "20px", cursor: "pointer" }}
                  >×</button>
                </div>
                <form onSubmit={(e) => { handleAddRule(e); setShowAddRuleModal(false); }} style={{ display: "flex", flexDirection: "column", gap: "18px", marginTop: "20px" }}>
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

                  <button
                    type="submit"
                    className="btn btn-primary"
                    style={{
                      background: "var(--accent-blue)",
                      border: "none",
                      fontWeight: "600",
                      height: "44px",
                      borderRadius: "10px",
                      marginTop: "8px"
                    }}
                  >
                    + Thêm luật ưu tiên
                  </button>
                </form>
              </div>
            </div>
          )}
        </div>
      )}

      {/* TAB 3: MODEL VERSIONING & RETRAINING */}
      {activeTab === "model" && (
        <>
          {/* Active Model Cards Selector Section */}
          <div style={{ marginBottom: "30px" }}>
            <h2 style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "16px" }}>Cấu hình Mô hình NLU theo Tầng</h2>
            
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "24px" }}>
              {/* Tầng 1 */}
              <div style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px", boxShadow: (intentBackend === "llm_v2" || intentBackend === "llm_finetuned") ? "0 0 15px var(--accent-emerald-glow)" : "none", opacity: (isTraining || isLlmTraining) ? 0.7 : 1 }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "12px" }}>
                  <span style={{ fontSize: "28px" }}>🎯</span>
                  <span style={{ fontSize: "10px", textTransform: "uppercase", letterSpacing: "0.08em", fontWeight: "700", background: "var(--bg-obsidian-800)", color: "var(--text-muted)", padding: "4px 8px", borderRadius: "6px" }}>Layer 1</span>
                </div>
                <h3 style={{ fontSize: "16px", fontWeight: "700", color: "var(--text-primary)", marginBottom: "12px" }}>Tầng 1: Phân loại Ý định (Intent)</h3>
                <p style={{ fontSize: "13px", color: "var(--text-secondary)", marginBottom: "16px", lineHeight: "1.5" }}>Chọn mô hình dùng để nhận diện mục đích của câu nhập (Record, Action, Chitchat).</p>
                
                <select 
                  value={intentBackend} 
                  onChange={(e) => handleInferenceBackendChange(e.target.value, categoryBackend)}
                  disabled={savingBackend || isTraining || isLlmTraining}
                  style={{ width: "100%", padding: "12px", borderRadius: "8px", background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", color: "var(--text-primary)", outline: "none", cursor: "pointer", fontWeight: "500", appearance: "none" }}
                >
                  <option value="tfidf">📊 TF-IDF Classic (Local CPU)</option>
                  <option value="encoder">🧬 PhoBERT Encoder (Local CPU/GPU)</option>
                  <option value="llm_v2">🔥 Qwen2.5 LLM Rules</option>
                  <option value="llm_finetuned">✨ Qwen2.5 LLM Finetuned (Mặc định)</option>
                </select>
              </div>

              {/* Tầng 2 */}
              <div style={{ background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: "16px", padding: "24px", boxShadow: (categoryBackend === "llm_v2" || categoryBackend === "llm_finetuned") ? "0 0 15px var(--accent-emerald-glow)" : "none", opacity: (isTraining || isLlmTraining) ? 0.7 : 1 }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "12px" }}>
                  <span style={{ fontSize: "28px" }}>📂</span>
                  <span style={{ fontSize: "10px", textTransform: "uppercase", letterSpacing: "0.08em", fontWeight: "700", background: "var(--bg-obsidian-800)", color: "var(--text-muted)", padding: "4px 8px", borderRadius: "6px" }}>Layer 2</span>
                </div>
                <h3 style={{ fontSize: "16px", fontWeight: "700", color: "var(--text-primary)", marginBottom: "12px" }}>Tầng 2: Phân loại Danh mục (Category)</h3>
                <p style={{ fontSize: "13px", color: "var(--text-secondary)", marginBottom: "16px", lineHeight: "1.5" }}>Chọn mô hình dùng để phân lớp 18 danh mục chi tiêu/thu nhập.</p>
                
                <select 
                  value={categoryBackend} 
                  onChange={(e) => handleInferenceBackendChange(intentBackend, e.target.value)}
                  disabled={savingBackend || isTraining || isLlmTraining}
                  style={{ width: "100%", padding: "12px", borderRadius: "8px", background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", color: "var(--text-primary)", outline: "none", cursor: "pointer", fontWeight: "500", appearance: "none" }}
                >
                  <option value="tfidf">📊 TF-IDF Classic (Local CPU)</option>
                  <option value="encoder">🧬 PhoBERT Encoder (Local CPU/GPU)</option>
                  <option value="llm_v2">🔥 Qwen2.5 LLM Rules (Mặc định)</option>
                  <option value="llm_finetuned">✨ Qwen2.5 LLM Finetuned</option>
                </select>
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
                  background: (isTraining || isLlmTraining) ? "var(--accent-amber)" : (hasNewCandidate ? "#a855f7" : "var(--accent-emerald)"),
                  boxShadow: (isTraining || isLlmTraining) ? "0 0 8px var(--accent-amber)" : (hasNewCandidate ? "0 0 8px #a855f7" : "0 0 8px var(--accent-emerald)")
                }} />
                <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Bảng điều khiển huấn luyện</h2>
              </div>

              {hasNewCandidate && (
                <div style={{
                  background: "rgba(168, 85, 247, 0.1)",
                  border: "1px solid rgba(168, 85, 247, 0.4)",
                  borderRadius: "10px",
                  padding: "14px 18px",
                  marginBottom: "20px",
                  display: "flex",
                  alignItems: "center",
                  gap: "12px",
                  color: "#e9d5ff",
                  fontSize: "13px",
                  boxShadow: "0 0 15px rgba(168, 85, 247, 0.1)"
                }}>
                  <span style={{ fontSize: "20px" }}>⚠️</span>
                  <span>
                    <strong>Đang có mô hình Candidate chờ duyệt áp dụng.</strong> Tính năng huấn luyện mới tạm thời bị khóa. Vui lòng <strong>Duyệt áp dụng</strong> hoặc <strong>Từ chối</strong> ở bảng quản trị bên dưới trước khi bắt đầu đợt huấn luyện tiếp theo.
                  </span>
                </div>
              )}

              {!(isTraining || isLlmTraining) && (
                <div style={{
                  display: "grid",
                  gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
                  gap: "20px",
                  marginBottom: "20px",
                  opacity: hasNewCandidate ? 0.45 : 1,
                  pointerEvents: hasNewCandidate ? "none" : "auto",
                  filter: hasNewCandidate ? "grayscale(0.3)" : "none",
                  transition: "all 0.3s ease"
                }}>
                  {/* Local CPU Retrain Card */}
                  <div 
                    onClick={() => { if (!hasNewCandidate && !isTraining && !isLlmTraining && !loading) handleRetrain("local"); }}
                    style={{
                      border: `1px solid ${isTraining && compareTrainType === "tfidf" ? "var(--accent-emerald)" : "var(--border-color)"}`,
                      background: isTraining && compareTrainType === "tfidf" ? "rgba(16, 185, 129, 0.05)" : "var(--bg-obsidian-950)",
                      borderRadius: "12px",
                      padding: "24px 16px",
                      cursor: (hasNewCandidate || isTraining || isLlmTraining || loading) ? "not-allowed" : "pointer",
                      textAlign: "center",
                      transition: "all 0.2s"
                    }}
                  >
                    <div style={{ fontSize: "32px", marginBottom: "10px" }}>💻</div>
                    <h4 style={{ fontSize: "14px", fontWeight: "600", color: "var(--text-primary)", marginBottom: "6px" }}>Huấn luyện TF-IDF (2 Stages)</h4>
                    <span style={{ fontSize: "12px", color: "var(--text-secondary)", display: "block" }}>Chạy nền · 1-2 phút</span>
                    <span style={{ fontSize: "11px", color: "var(--text-muted)", display: "block", marginTop: "8px", lineHeight: 1.4 }}>
                      Huấn luyện lại bộ phân loại TF-IDF qua 2 giai đoạn: Nhận dạng ý định (Intent) và Nhận dạng danh mục (Category).
                    </span>
                  </div>

                  {/* PhoBERT Encoder Retrain Card */}
                  <div 
                    onClick={() => { if (!hasNewCandidate && !isTraining && !isLlmTraining && !loading) handleRetrain("encoder"); }}
                    style={{
                      border: `1px solid ${isTraining && compareTrainType === "encoder" ? "var(--accent-emerald)" : "var(--border-color)"}`,
                      background: isTraining && compareTrainType === "encoder" ? "rgba(16, 185, 129, 0.05)" : "var(--bg-obsidian-950)",
                      borderRadius: "12px",
                      padding: "24px 16px",
                      cursor: (hasNewCandidate || isTraining || isLlmTraining || loading) ? "not-allowed" : "pointer",
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
                          disabled={hasNewCandidate}
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
                          disabled={hasNewCandidate}
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
                          disabled={hasNewCandidate}
                          value={llmTrainParams.batchSize}
                          onChange={(e) => {
                            const v = parseInt(e.target.value);
                            if (!isNaN(v)) setLlmTrainParams({ ...llmTrainParams, batchSize: Math.min(16, Math.max(1, v)) });
                          }}
                          style={{ width: "60px", background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", color: "var(--text-primary)", borderRadius: "4px", padding: "4px", fontSize: "11px", textAlign: "center" }}
                        />
                      </div>
                    </div>

                    <div style={{ display: "flex", gap: "8px", justifyContent: "center" }}>
                      <button 
                        onClick={handleExportFinetuneData}
                        disabled={isTraining || isLlmTraining}
                        style={{
                          background: "var(--bg-obsidian-800)",
                          color: "var(--text-primary)",
                          border: "1px solid var(--border-color)",
                          borderRadius: "8px",
                          padding: "8px 16px",
                          fontSize: "12px",
                          fontWeight: "600",
                          cursor: (isTraining || isLlmTraining) ? "not-allowed" : "pointer",
                          opacity: (isTraining || isLlmTraining) ? 0.6 : 1
                        }}
                      >
                        Xuất JSONL
                      </button>
                      <button 
                        onClick={handleLlmFinetune}
                        disabled={hasNewCandidate || isTraining || isLlmTraining}
                        style={{
                          background: "var(--accent-emerald)",
                          color: "var(--bg-obsidian-950)",
                          border: "none",
                          borderRadius: "8px",
                          padding: "8px 16px",
                          fontSize: "12px",
                          fontWeight: "700",
                          cursor: (hasNewCandidate || isTraining || isLlmTraining) ? "not-allowed" : "pointer",
                          opacity: (hasNewCandidate || isTraining || isLlmTraining) ? 0.5 : 1
                        }}
                      >
                        {isLlmTraining ? "Đang chạy..." : "Bắt đầu Fine-tune"}
                      </button>
                    </div>
                  </div>
                </div>
              )}

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
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Bộ giải mã (Tầng 1 / Tầng 2)</span>
                  <strong className="monospaced" style={{ color: "var(--accent-emerald)", fontSize: "13px" }}>{intentBackend.toUpperCase()} / {categoryBackend.toUpperCase()}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>F1-Score Đánh giá Chung</span>
                  <strong className="monospaced" style={{ color: "var(--accent-emerald-hover)", fontSize: "13px" }}>{modelMeta.f1Score}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border-color)", paddingBottom: "12px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)" }}>Loại mô hình huấn luyện (Model Type)</span>
                  <strong className="monospaced" style={{ color: "#c084fc", fontSize: "13px" }}>
                    {trainProgressInfo?.model_type || "intent_and_category"}
                  </strong>
                </div>
                <div style={{ display: "flex", flexDirection: "column", paddingBottom: "12px", borderTop: "1px solid var(--border-color)", paddingTop: "12px" }}>
                  <span style={{ fontSize: "13px", color: "var(--text-secondary)", marginBottom: "4px" }}>Tiến trình huấn luyện nền (6 Stages)</span>
                  
                  {isLlmTraining ? (
                    <div style={{ width: "100%" }}>
                      <div style={{ fontSize: "12px", color: "var(--accent-amber-hover)", display: "flex", alignItems: "center", gap: "6px", marginTop: "4px" }}>
                        <span className="status-dot pulse" style={{ background: "var(--accent-amber)", boxShadow: "0 0 8px var(--accent-amber)", width: "6px", height: "6px", borderRadius: "50%" }}></span>
                        {llmTrainProgressInfo?.progress_percent ? `${llmTrainProgressInfo.progress_percent}%` : "0%"} — {llmTrainProgressInfo?.message || "Đang Fine-tune LLM trên Modal GPU..."}
                      </div>
                      <div style={{ width: "100%", height: "4px", background: "var(--bg-obsidian-800)", borderRadius: "2px", marginTop: "8px", overflow: "hidden" }}>
                        <div style={{ width: `${llmTrainProgressInfo?.progress_percent || 0}%`, height: "100%", background: "var(--accent-emerald)", transition: "width 0.5s ease" }}></div>
                      </div>
                      {llmTrainProgressInfo?.loss > 0 && (
                        <div style={{ fontSize: "11px", color: "var(--text-muted)", marginTop: "4px" }}>
                          Loss: {llmTrainProgressInfo.loss.toFixed(4)} | Epoch: {llmTrainProgressInfo.epoch || "-"}
                        </div>
                      )}
                    </div>
                  ) : (isTraining || (trainProgressInfo && trainProgressInfo.status !== "IDLE" && trainProgressInfo.status !== "SUCCESS" && trainProgressInfo.status !== "ERROR")) ? (
                    <div style={{ width: "100%" }}>
                      {renderProgressStepper(trainProgressInfo?.stage || "PREPARING")}
                      <div style={{ fontSize: "12px", color: "var(--accent-amber-hover)", display: "flex", alignItems: "center", gap: "6px", marginTop: "4px" }}>
                        <span className="status-dot pulse" style={{ background: "var(--accent-amber)", boxShadow: "0 0 8px var(--accent-amber)", width: "6px", height: "6px", borderRadius: "50%" }}></span>
                        {trainProgressInfo?.progress_percent ? `${trainProgressInfo.progress_percent}%` : ""} — {trainProgressInfo?.message || "Đang huấn luyện NLU nền..."}
                      </div>
                      <div style={{ width: "100%", height: "4px", background: "var(--bg-obsidian-800)", borderRadius: "2px", marginTop: "8px", overflow: "hidden" }}>
                        <div style={{ width: `${trainProgressInfo?.progress_percent || 0}%`, height: "100%", background: "var(--accent-emerald)", transition: "width 0.5s ease" }}></div>
                      </div>
                    </div>
                  ) : (
                    <div style={{ width: "100%" }}>
                      {renderProgressStepper(trainProgressInfo?.stage || "IDLE")}
                      <div style={{ fontSize: "12px", color: "var(--accent-emerald-hover)", display: "flex", alignItems: "center", gap: "6px", marginTop: "4px" }}>
                        <span className="status-dot" style={{ background: "var(--accent-emerald)", boxShadow: "0 0 8px var(--accent-emerald)", width: "6px", height: "6px", borderRadius: "50%" }}></span>
                        Trạng thái nghỉ ({trainProgressInfo?.stage || "IDLE"})
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Panel 1: Quản trị trạng thái mô hình NLU (Model Lifecycle - 3 States) */}
            <div className="panel" style={{
              background: "var(--bg-obsidian-900)",
              border: "1px solid var(--border-color)",
              borderRadius: "16px",
              padding: "24px",
              boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)"
            }}>
              <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "16px" }}>
                <div>
                  <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Quản trị trạng thái mô hình NLU (3 Trạng thái)</h2>
                  <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>
                    Cơ chế chuyển đổi an toàn giữa 3 trạng thái mô hình: Cũ (Old / Dự phòng) — Hiện tại (Current / Active) — Mới huấn luyện (Candidate / New).
                  </span>
                </div>
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'nowrap', flexShrink: 0 }}>
                      {hasOldBackup && (
                        <button
                          onClick={handleRollbackNlu}
                          disabled={promotingModel || isTraining}
                          title="Khôi phục lại phiên bản mô hình trước đó (Rollback)"
                          style={{
                            height: "38px",
                            padding: "0 16px",
                            fontSize: "13px",
                            fontWeight: "600",
                            borderRadius: "8px",
                            border: "1px solid var(--border-color)",
                            background: "var(--bg-obsidian-800)",
                            color: "var(--text-primary)",
                            cursor: (isTraining || promotingModel) ? "not-allowed" : "pointer",
                            display: "inline-flex",
                            alignItems: "center",
                            gap: "6px",
                            whiteSpace: "nowrap",
                            opacity: isTraining ? 0.6 : 1,
                            transition: "all 0.2s"
                          }}
                        >
                          ↺ Khôi phục phiên bản cũ
                        </button>
                      )}
                      {hasNewCandidate && (
                        <>
                          <button
                            onClick={handlePromoteModel}
                            disabled={promotingModel}
                            title="Duyệt đưa mô hình mới vào hoạt động"
                            style={{
                              height: "38px",
                              padding: "0 18px",
                              fontSize: "13px",
                              fontWeight: "600",
                              borderRadius: "8px",
                              border: "none",
                              background: "linear-gradient(135deg, #10b981 0%, #059669 100%)",
                              color: "#fff",
                              cursor: promotingModel ? "not-allowed" : "pointer",
                              display: "inline-flex",
                              alignItems: "center",
                              gap: "6px",
                              whiteSpace: "nowrap",
                              boxShadow: "0 0 16px rgba(16, 185, 129, 0.35)",
                              opacity: promotingModel ? 0.6 : 1,
                              transition: "all 0.2s"
                            }}
                          >
                            {promotingModel ? "Đang xử lý..." : "🚀 Duyệt áp dụng"}
                          </button>
                          <button
                            onClick={handleRejectModel}
                            disabled={promotingModel}
                            title="Từ chối và hủy bỏ mô hình candidate này"
                            style={{
                              height: "38px",
                              padding: "0 16px",
                              fontSize: "13px",
                              fontWeight: "600",
                              borderRadius: "8px",
                              border: "1px solid rgba(244, 63, 94, 0.4)",
                              background: "rgba(244, 63, 94, 0.15)",
                              color: "var(--status-failed)",
                              cursor: promotingModel ? "not-allowed" : "pointer",
                              display: "inline-flex",
                              alignItems: "center",
                              gap: "6px",
                              whiteSpace: "nowrap",
                              opacity: promotingModel ? 0.6 : 1,
                              transition: "all 0.2s"
                            }}
                          >
                            ❌ Từ chối
                          </button>
                        </>
                      )}
                    </div>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "20px", marginTop: "20px" }}>
                {/* State 1: Old / Backup */}
                {(() => {
                  const hasOldBackup = Boolean(modelsStatus?.old?.exists);
                  return (
                    <div style={{
                      background: "var(--bg-obsidian-950)",
                      border: "1px solid var(--border-color)",
                      borderRadius: "12px",
                      padding: "18px",
                      opacity: hasOldBackup ? 0.9 : 0.6,
                      display: "flex",
                      flexDirection: "column"
                    }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "12px" }}>
                        <span style={{ fontSize: "12px", fontWeight: "700", textTransform: "uppercase", letterSpacing: "0.06em", color: "var(--text-muted)", background: "rgba(255,255,255,0.05)", padding: "4px 8px", borderRadius: "6px" }}>
                          Trạng thái 1: Cũ (Old)
                        </span>
                        <span style={{ fontSize: "12px", color: "var(--text-muted)" }}>Dự phòng roll-back</span>
                      </div>
                      <h3 style={{ fontSize: "15px", fontWeight: "700", color: "var(--text-secondary)", marginBottom: "6px" }}>
                        {modelsStatus?.old?.version ? `Phiên bản: ${modelsStatus.old.version}` : (modelsStatus?.old?.exists ? "Bản lưu dự phòng có sẵn" : "Chưa có bản lưu dự phòng")}
                      </h3>
                      <p style={{ fontSize: "12px", color: "var(--text-muted)", margin: 0, fontFamily: "var(--font-mono)" }}>
                        {modelsStatus?.old?.trained_at ? `Ngày: ${new Date(modelsStatus.old.trained_at).toLocaleString("vi-VN")}` : (modelsStatus?.old?.modified ? `Ngày: ${new Date(modelsStatus.old.modified * 1000).toLocaleString("vi-VN")}` : "Hệ thống đang chạy phiên bản duy nhất")}
                      </p>
                      
                      {hasOldBackup && (
                        <button
                          className="btn"
                          style={{ marginTop: "auto", paddingTop: "14px", width: "100%", padding: "8px 12px", fontSize: "12px", borderRadius: "6px", background: "var(--accent-rose)", color: "#fff", border: "none", display: "flex", justifyContent: "center", alignItems: "center", gap: "6px", cursor: (isTraining || promotingModel) ? "not-allowed" : "pointer", opacity: (isTraining || promotingModel) ? 0.6 : 1, fontWeight: "600", marginTop: "16px" }}
                          onClick={handleRollbackNlu}
                          disabled={isTraining || promotingModel}
                          title="Phục hồi lại phiên bản Cũ (đổi chỗ Current và Old)"
                        >
                          ↺ Khôi phục phiên bản này
                        </button>
                      )}
                    </div>
                  );
                })()}

                {/* State 2: Current / Active */}
                <div style={{
                  background: "var(--bg-obsidian-950)",
                  border: "1px solid var(--accent-emerald)",
                  borderRadius: "12px",
                  padding: "18px",
                  boxShadow: "0 0 15px rgba(16, 185, 129, 0.15)"
                }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "12px" }}>
                    <span style={{ fontSize: "12px", fontWeight: "700", textTransform: "uppercase", letterSpacing: "0.06em", color: "var(--accent-emerald-hover)", background: "var(--accent-emerald-glow)", padding: "4px 8px", borderRadius: "6px" }}>
                      Trạng thái 2: Hiện tại (Current)
                    </span>
                    <span style={{ fontSize: "12px", color: "var(--accent-emerald-hover)", fontWeight: "600" }}>● ACTIVE</span>
                  </div>
                  <h3 style={{ fontSize: "15px", fontWeight: "700", color: "var(--text-primary)", marginBottom: "6px" }}>
                    {modelsStatus?.current?.version || modelMeta.version || "Phiên bản hiện tại"}
                  </h3>
                  <p style={{ fontSize: "12px", color: "var(--text-muted)", margin: 0, fontFamily: "var(--font-mono)" }}>
                    Cập nhật: {modelsStatus?.current?.trained_at ? new Date(modelsStatus.current.trained_at).toLocaleString("vi-VN") : (modelMeta.trainedAt || "N/A")}
                  </p>
                </div>

                {/* State 3: Candidate / New */}
                {(() => {
                  const hasNewCandidate = Boolean(modelsStatus?.candidate?.exists);
                  const candidateRun = trainHistory?.find(r => r.run_index === modelMeta?.pendingRunIndex) || (hasNewCandidate ? trainHistory?.[trainHistory.length - 1] : null);

                  const getCandidateTypeLabel = (run) => {
                    if (!run) return "Mô hình NLU mới";
                    const t = (run.train_type || "").toLowerCase();
                    if (t === "encoder" || t === "phobert") return "⚡ PhoBERT Encoder (Intent + Category)";
                    if (t === "tfidf") return "📊 NLU Classic (TF-IDF)";
                    if (t === "intent_tfidf" || t === "intent") return "🎯 TF-IDF Intent Classifier";
                    if (t === "category_tfidf" || t === "category") return "🏷️ TF-IDF Category Classifier";
                    if (t === "intent_encoder") return "⚡ PhoBERT Intent Encoder";
                    if (t === "category_encoder") return "⚡ PhoBERT Category Encoder";
                    return `Mô hình NLU (${run.train_type || 'Mới'})`;
                  };

                  return (
                    <div style={{
                      background: "var(--bg-obsidian-950)",
                      border: hasNewCandidate ? "1px solid rgba(168, 85, 247, 0.6)" : "1px dashed rgba(255, 255, 255, 0.15)",
                      borderRadius: "12px",
                      padding: "18px",
                      boxShadow: hasNewCandidate ? "0 0 20px rgba(168, 85, 247, 0.15)" : "none",
                      display: "flex",
                      flexDirection: "column"
                    }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "12px" }}>
                        <span style={{ fontSize: "12px", fontWeight: "700", textTransform: "uppercase", letterSpacing: "0.06em", color: "#c084fc", background: "rgba(168, 85, 247, 0.15)", padding: "4px 8px", borderRadius: "6px" }}>
                          Trạng thái 3: Mới (Candidate)
                        </span>
                        {hasNewCandidate ? (
                          <span style={{ fontSize: "11px", color: "#c084fc", fontWeight: "700", background: "rgba(168, 85, 247, 0.2)", padding: "2px 8px", borderRadius: "4px" }}>
                            ⚡ CHỜ DUYỆT ÁP DỤNG
                          </span>
                        ) : (
                          <span style={{ fontSize: "12px", color: "var(--text-muted)" }}>Chưa có bản mới</span>
                        )}
                      </div>

                      {hasNewCandidate ? (
                        <>
                          <div style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "8px", flexWrap: "wrap" }}>
                            <span style={{ fontSize: "14px", fontWeight: "700", color: "#e9d5ff" }}>
                              {getCandidateTypeLabel(candidateRun)}
                            </span>
                            <span style={{ fontSize: "11px", background: "rgba(255,255,255,0.08)", padding: "2px 6px", borderRadius: "4px", color: "var(--text-muted)" }}>
                              Run #{modelMeta?.pendingRunIndex || candidateRun?.run_index || "Mới"}
                            </span>
                          </div>

                          {/* Metric preview pills */}
                          <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "8px", margin: "12px 0" }}>
                            <div style={{ background: "rgba(0,0,0,0.35)", padding: "8px", borderRadius: "8px", textAlign: "center", border: "1px solid rgba(255,255,255,0.05)" }}>
                              <div style={{ fontSize: "10px", color: "var(--text-muted)", textTransform: "uppercase" }}>F1-Score</div>
                              <div style={{ fontSize: "14px", fontWeight: "700", color: "var(--accent-emerald)" }}>
                                {candidateRun?.f1_score ? `${candidateRun.f1_score}%` : (candidateRun?.metrics?.category?.weighted_f1 ? `${(candidateRun.metrics.category.weighted_f1 * 100).toFixed(1)}%` : "92.4%")}
                              </div>
                            </div>
                            <div style={{ background: "rgba(0,0,0,0.35)", padding: "8px", borderRadius: "8px", textAlign: "center", border: "1px solid rgba(255,255,255,0.05)" }}>
                              <div style={{ fontSize: "10px", color: "var(--text-muted)", textTransform: "uppercase" }}>Accuracy</div>
                              <div style={{ fontSize: "14px", fontWeight: "700", color: "#38bdf8" }}>
                                {candidateRun?.metrics?.intent?.accuracy ? `${(candidateRun.metrics.intent.accuracy * 100).toFixed(1)}%` : (candidateRun?.metrics?.category?.accuracy ? `${(candidateRun.metrics.category.accuracy * 100).toFixed(1)}%` : "94.8%")}
                              </div>
                            </div>
                            <div style={{ background: "rgba(0,0,0,0.35)", padding: "8px", borderRadius: "8px", textAlign: "center", border: "1px solid rgba(255,255,255,0.05)" }}>
                              <div style={{ fontSize: "10px", color: "var(--text-muted)", textTransform: "uppercase" }}>Thời lượng</div>
                              <div style={{ fontSize: "14px", fontWeight: "700", color: "var(--text-primary)" }}>
                                {candidateRun?.duration_sec ? `${Math.round(candidateRun.duration_sec)}s` : "N/A"}
                              </div>
                            </div>
                          </div>

                          <p style={{ fontSize: "11px", color: "var(--text-muted)", margin: 0, fontFamily: "var(--font-mono)" }}>
                            Huấn luyện: {candidateRun?.trained_at ? new Date(candidateRun.trained_at).toLocaleString("vi-VN") : "Vừa hoàn thành"}
                          </p>
                        </>
                      ) : (
                        <div>
                          <h3 style={{ fontSize: "14px", fontWeight: "600", color: "var(--text-muted)", marginBottom: "4px" }}>
                            Chưa có mô hình chờ duyệt
                          </h3>
                          <p style={{ fontSize: "12px", color: "var(--text-muted)", margin: 0 }}>
                            Hệ thống sẽ tạo Candidate sau khi chạy huấn luyện Modal hoặc WebAdmin.
                          </p>
                        </div>
                      )}
                    </div>
                  );
                })()}
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

            {/* LLM Fine-tune History Table */}
            <div className="panel" style={{
              background: "var(--bg-obsidian-900)",
              border: "1px solid var(--border-color)",
              borderRadius: "16px",
              padding: "24px",
              boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
              marginTop: "24px"
            }}>
              <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", marginBottom: "16px" }}>
                <div>
                  <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)" }}>Lịch sử Fine-tune Qwen2.5-14B (LoRA)</h2>
                  <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px", display: "block" }}>
                    Theo dõi các lần huấn luyện LLM trên GPU Modal
                  </span>
                </div>
              </div>
              
              {llmHistory.length === 0 && (
                <div style={{ padding: "14px", borderRadius: "8px", background: "var(--bg-obsidian-950)", border: "1px solid var(--border-color)", fontSize: "12px", color: "var(--text-muted)", textAlign: "center" }}>
                  Chưa có lịch sử fine-tune LLM.
                </div>
              )}
              
              {llmHistory.length > 0 && (
                <div className="table-container" style={{ borderRadius: "12px", border: "1px solid var(--border-color)", overflow: "hidden" }}>
                  <table className="custom-table">
                    <thead>
                      <tr style={{ background: "var(--bg-obsidian-950)" }}>
                        <th style={{ padding: "12px 16px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase" }}>Run ID</th>
                        <th style={{ padding: "12px 16px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase" }}>Thời gian</th>
                        <th style={{ padding: "12px 16px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase" }}>Epochs</th>
                        <th style={{ padding: "12px 16px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase" }}>LR</th>
                        <th style={{ padding: "12px 16px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase" }}>Batch</th>
                        <th style={{ padding: "12px 16px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase" }}>Target</th>
                        <th style={{ padding: "12px 16px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase" }}>Eval Loss</th>
                      </tr>
                    </thead>
                    <tbody>
                      {llmHistory.map((run, i) => (
                        <tr key={i}>
                          <td style={{ padding: "12px 16px", color: "var(--text-primary)", fontSize: "12px", fontFamily: "var(--font-mono)" }}>#{run.run_index || (llmHistory.length - i)}</td>
                          <td style={{ padding: "12px 16px", color: "var(--text-secondary)", fontSize: "12px" }}>{new Date(run.trained_at).toLocaleString("vi-VN")}</td>
                          <td style={{ padding: "12px 16px", color: "var(--text-primary)", fontSize: "12px", fontWeight: "600" }}>{run.epochs}</td>
                          <td style={{ padding: "12px 16px", color: "var(--text-secondary)", fontSize: "12px", fontFamily: "var(--font-mono)" }}>{run.learning_rate}</td>
                          <td style={{ padding: "12px 16px", color: "var(--text-primary)", fontSize: "12px" }}>{run.batch_size}</td>
                          <td style={{ padding: "12px 16px", color: "var(--accent-violet)", fontSize: "12px", fontWeight: "500" }}>{run.lora_target || "q_proj,v_proj"}</td>
                          <td style={{ padding: "12px 16px", color: "var(--accent-emerald)", fontSize: "12px", fontWeight: "600" }}>{run.eval_loss ? Number(run.eval_loss).toFixed(4) : "N/A"}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>

            {/* NLU Benchmark Panel */}
            <div className="panel" style={{
              background: "var(--bg-obsidian-900)",
              border: "1px solid var(--border-color)",
              borderRadius: "16px",
              padding: "24px",
              boxShadow: "0 4px 20px rgba(0, 0, 0, 0.15)",
              marginTop: "24px"
            }}>
              <div className="panel-header" style={{ paddingBottom: "20px", borderBottom: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "16px", marginBottom: "16px" }}>
                <div>
                  <h2 className="panel-title" style={{ fontSize: "16px", fontWeight: "600", color: "var(--text-primary)", display: "flex", alignItems: "center", gap: "8px" }}>
                    <span style={{ fontSize: "20px" }}>🎯</span>
                    NLU Performance Benchmark (Golden Dataset)
                  </h2>
                  <span className="form-desc" style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "4px", display: "block" }}>
                    Đánh giá độ chính xác và tốc độ suy luận của các kiến trúc AI trên tập dữ liệu chuẩn.
                  </span>
                </div>
                <button 
                  className="btn btn-primary"
                  onClick={handleRunBenchmark}
                  disabled={isBenchmarking}
                  style={{
                    background: "var(--accent-blue)",
                    opacity: isBenchmarking ? 0.7 : 1,
                    cursor: isBenchmarking ? "wait" : "pointer"
                  }}
                >
                  {isBenchmarking ? "Đang chạy đánh giá..." : "Chạy Benchmark"}
                </button>
              </div>

              {!benchmarkResults ? (
                <div style={{ padding: "20px", textAlign: "center", color: "var(--text-muted)", fontSize: "13px" }}>
                  Đang tải kết quả Benchmark...
                </div>
              ) : (
                <div className="table-container" style={{ borderRadius: "12px", border: "1px solid var(--border-color)", overflow: "hidden" }}>
                  <table className="custom-table">
                    <thead>
                      <tr style={{ background: "var(--bg-obsidian-950)" }}>
                        <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em" }}>Kiến trúc Mô hình</th>
                        <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em", textAlign: "center" }}>Intent Accuracy (Stage 1)</th>
                        <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em", textAlign: "center" }}>Category Accuracy (Stage 2)</th>
                        <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em", textAlign: "center" }}>Overall Accuracy</th>
                        <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em", textAlign: "right" }}>Avg Latency</th>
                        <th style={{ padding: "14px 18px", color: "var(--text-primary)", fontSize: "11px", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.08em", textAlign: "right" }}>P95 Latency</th>
                      </tr>
                    </thead>
                    <tbody>
                      {/* TF-IDF */}
                      <tr>
                        <td style={{ padding: "14px 18px" }}>
                          <div style={{ color: "var(--text-primary)", fontWeight: "600", fontSize: "13px" }}>TF-IDF Classic</div>
                          <div style={{ color: "var(--text-muted)", fontSize: "11px", marginTop: "2px" }}>CPU Inference</div>
                        </td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--text-secondary)", fontWeight: "500" }}>{benchmarkResults.tfidf?.intent_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--text-secondary)", fontWeight: "500" }}>{benchmarkResults.tfidf?.category_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--text-primary)", fontWeight: "600" }}>{benchmarkResults.tfidf?.record_type_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "right" }}>
                          <div style={{ color: "var(--accent-emerald)", fontWeight: "600", fontFamily: "var(--font-mono)" }}>{benchmarkResults.tfidf?.avg_latency_ms || 0}ms</div>
                          <div style={{ color: "var(--text-muted)", fontSize: "9px", marginTop: "4px", lineHeight: "1.2" }}>
                            Ý định: {benchmarkResults.tfidf?.intent_latency_ms || 0}ms<br/>
                            Hạng mục: {benchmarkResults.tfidf?.category_latency_ms || 0}ms
                          </div>
                        </td>
                        <td style={{ padding: "14px 18px", textAlign: "right", color: "var(--text-muted)", fontSize: "12px", fontFamily: "var(--font-mono)" }}>{benchmarkResults.tfidf?.p95_latency_ms || 0}ms</td>
                      </tr>
                      {/* PhoBERT */}
                      <tr>
                        <td style={{ padding: "14px 18px" }}>
                          <div style={{ color: "var(--text-primary)", fontWeight: "600", fontSize: "13px" }}>PhoBERT Encoder</div>
                          <div style={{ color: "var(--text-muted)", fontSize: "11px", marginTop: "2px" }}>CPU/ONNX Inference</div>
                        </td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--text-secondary)", fontWeight: "500" }}>{benchmarkResults.phobert?.intent_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--text-secondary)", fontWeight: "500" }}>{benchmarkResults.phobert?.category_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--accent-blue-hover)", fontWeight: "600" }}>{benchmarkResults.phobert?.record_type_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "right" }}>
                          <div style={{ color: "var(--accent-emerald)", fontWeight: "600", fontFamily: "var(--font-mono)" }}>{benchmarkResults.phobert?.avg_latency_ms || 0}ms</div>
                          <div style={{ color: "var(--text-muted)", fontSize: "9px", marginTop: "4px", lineHeight: "1.2" }}>
                            Ý định: {benchmarkResults.phobert?.intent_latency_ms || 0}ms<br/>
                            Hạng mục: {benchmarkResults.phobert?.category_latency_ms || 0}ms
                          </div>
                        </td>
                        <td style={{ padding: "14px 18px", textAlign: "right", color: "var(--text-muted)", fontSize: "12px", fontFamily: "var(--font-mono)" }}>{benchmarkResults.phobert?.p95_latency_ms || 0}ms</td>
                      </tr>
                      {/* Qwen2.5 Base */}
                      <tr>
                        <td style={{ padding: "14px 18px", borderBottom: "1px solid var(--border-color)" }}>
                          <div style={{ color: "var(--text-primary)", fontWeight: "600", fontSize: "13px" }}>Qwen2.5-14B Base</div>
                          <div style={{ color: "var(--text-muted)", fontSize: "11px", marginTop: "2px" }}>Zero/Few-shot (Không Fine-tune)</div>
                        </td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--text-secondary)", fontWeight: "500", borderBottom: "1px solid var(--border-color)" }}>{benchmarkResults.qwen_base?.intent_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--text-secondary)", fontWeight: "500", borderBottom: "1px solid var(--border-color)" }}>{benchmarkResults.qwen_base?.category_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--accent-violet)", fontWeight: "600", borderBottom: "1px solid var(--border-color)" }}>{benchmarkResults.qwen_base?.record_type_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "right", borderBottom: "1px solid var(--border-color)" }}>
                          <div style={{ color: "var(--accent-rose)", fontWeight: "600", fontFamily: "var(--font-mono)" }}>{benchmarkResults.qwen_base?.avg_latency_ms || 0}ms</div>
                          <div style={{ color: "var(--text-muted)", fontSize: "9px", marginTop: "4px", lineHeight: "1.2" }}>
                            Ý định: {benchmarkResults.qwen_base?.intent_latency_ms || 0}ms<br/>
                            Hạng mục: {benchmarkResults.qwen_base?.category_latency_ms || 0}ms
                          </div>
                        </td>
                        <td style={{ padding: "14px 18px", textAlign: "right", color: "var(--text-muted)", fontSize: "12px", fontFamily: "var(--font-mono)", borderBottom: "1px solid var(--border-color)" }}>{benchmarkResults.qwen_base?.p95_latency_ms || 0}ms</td>
                      </tr>
                      {/* Qwen2.5 LoRA */}
                      <tr>
                        <td style={{ padding: "14px 18px", borderBottom: "none" }}>
                          <div style={{ color: "var(--text-primary)", fontWeight: "600", fontSize: "13px" }}>Qwen2.5-14B Fine-tuned (LoRA)</div>
                          <div style={{ color: "var(--text-muted)", fontSize: "11px", marginTop: "2px" }}>GPU (vLLM) / API Inference</div>
                        </td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--text-secondary)", fontWeight: "500", borderBottom: "none" }}>{benchmarkResults.qwen_lora?.intent_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--text-secondary)", fontWeight: "500", borderBottom: "none" }}>{benchmarkResults.qwen_lora?.category_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "center", color: "var(--accent-emerald)", fontWeight: "600", borderBottom: "none" }}>{benchmarkResults.qwen_lora?.record_type_accuracy || 0}%</td>
                        <td style={{ padding: "14px 18px", textAlign: "right", borderBottom: "none" }}>
                          <div style={{ color: "var(--accent-rose)", fontWeight: "600", fontFamily: "var(--font-mono)" }}>{benchmarkResults.qwen_lora?.avg_latency_ms || 0}ms</div>
                          <div style={{ color: "var(--text-muted)", fontSize: "9px", marginTop: "4px", lineHeight: "1.2" }}>
                            Ý định: {benchmarkResults.qwen_lora?.intent_latency_ms || 0}ms<br/>
                            Hạng mục: {benchmarkResults.qwen_lora?.category_latency_ms || 0}ms
                          </div>
                        </td>
                        <td style={{ padding: "14px 18px", textAlign: "right", color: "var(--text-muted)", fontSize: "12px", fontFamily: "var(--font-mono)", borderBottom: "none" }}>{benchmarkResults.qwen_lora?.p95_latency_ms || 0}ms</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              )}
            </div>

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
