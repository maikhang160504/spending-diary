import { useCallback, useEffect, useRef, useState, useMemo } from "react";
import BillLabelCanvas from "../components/BillLabelCanvas";
import BillHelpModal, { BillHelpTrigger } from "../components/BillHelpModal";
import {
  approveBillSample,
  billSampleImageUrl,
  deleteBillSample,
  exportBillVerified,
  fetchBillOcrStatus,
  fetchBillSamples,
  rePrelabelBillSample,
  runBillGoldenEval,
  reloadAiModels,
  uploadBillSample,
  saveBillSample,
  triggerBillModal,
} from "../services/api";

const ENTITIES = ["OTHER", "SELLER", "ADDRESS", "TIMESTAMP", "TOTAL_COST"];

const STATUS_LABELS = {
  pending: "pending",
  approved: "approved",
  exported_archived: "exported",
};

function sampleStatusLabel(status) {
  return STATUS_LABELS[status] || status;
}

function BillToast({ toast, onDismiss }) {
  if (!toast) return null;
  return (
    <div className={`toast bill-floating-toast toast-${toast.type || "success"}`} role="status">
      <span>{toast.message}</span>
      {toast.action && (
        <button type="button" className="btn btn-sm btn-secondary" onClick={toast.action.onClick}>
          {toast.action.label}
        </button>
      )}
      <button type="button" className="btn btn-sm btn-ghost" onClick={onDismiss} aria-label="Đóng">
        ×
      </button>
    </div>
  );
}

function shortenOcrError(msg) {
  if (!msg) return "";
  if (msg.includes("vgg_transformer.pth")) {
    return "Thiếu file VietOCR weights — đặt tại OCR/models/vietocr/vgg_transformer.pth (pretrained) và bấm Tải lại model OCR.";
  }
  return msg.length > 180 ? `${msg.slice(0, 177)}…` : msg;
}

function formatPrelabelMessage(prelabel) {
  const n = (prelabel?.boxes || []).length;
  const kie = prelabel?.kie_backend || "heuristic";
  const engine = prelabel?.auto_label_engine || prelabel?.backend || "hybrid";
  if (prelabel?.error && n === 0) {
    return shortenOcrError(prelabel.error);
  }
  if (n === 0) {
    return "Auto-label trả về 0 box — kiểm tra OCR online rồi bấm Gán nhãn auto lại.";
  }
  const kieLabel = kie === "layoutlmv3" ? "LayoutLMv3 KIE" : `heuristic (${kie})`;
  return `Gán nhãn auto: ${n} boxes · entity: ${kieLabel} · ${engine}`;
}

function PrelabelQueuePanel({ jobs }) {
  if (!jobs?.length) return null;
  const activeCount = jobs.filter((j) => j.phase !== "done" && j.phase !== "failed").length;
  return (
    <div className="bill-ocr-queue-float" role="status" aria-live="polite">
      <section className="bill-surface bill-activity-panel">
        <div className="bill-surface-head">
          <div>
            <h2 className="bill-surface-title">Tiến trình OCR</h2>
          </div>
          {activeCount > 0 && <span className="bill-count-badge">{activeCount}</span>}
        </div>
        <ul className="bill-prelabel-queue">
          {jobs.map((job) => (
            <li key={job.id} className={`bill-prelabel-job ${job.phase}`}>
              <div className="bill-prelabel-job-head">
                <span className="bill-prelabel-job-label">{job.label}</span>
                <span className={`bill-status-chip ${job.phase}`}>{job.phaseLabel || job.phase}</span>
              </div>
              {job.phase !== "done" && job.phase !== "failed" && (
                <div className="bill-progress-bar" aria-hidden="true">
                  <div className="bill-progress-fill" style={{ width: `${Math.min(100, job.progress || 0)}%` }} />
                </div>
              )}
              {job.error && <p className="bill-kaggle-err">{job.error}</p>}
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

export default function BillRetrainPage() {
  const [samples, setSamples] = useState([]);
  const [active, setActive] = useState(null);
  const [boxes, setBoxes] = useState([]);
  const [selectedIdx, setSelectedIdx] = useState(null);
  const [loading, setLoading] = useState(false);
  const [loadingMessage, setLoadingMessage] = useState("");
  const [message, setMessage] = useState("");
  const [messageIsError, setMessageIsError] = useState(false);
  const [ocrStatus, setOcrStatus] = useState(null);
  const [golden, setGolden] = useState(null);
  const [archiveImagesOnExport, setArchiveImagesOnExport] = useState(true);
  const [drawMode, setDrawMode] = useState(false);
  const [helpOpen, setHelpOpen] = useState(false);
  const [toast, setToast] = useState(null);
  const [activeCategory, setActiveCategory] = useState("Others");
  const [prelabelJobs, setPrelabelJobs] = useState([]);
  const [page, setPage] = useState(1);
  const [filterStatus, setFilterStatus] = useState("all");
  
  const handledJobsRef = useRef(new Set());
  const toastTimerRef = useRef(null);
  const prelabelTimersRef = useRef({});

  const upsertPrelabelJob = useCallback((id, patch) => {
    setPrelabelJobs((prev) => prev.map((j) => (j.id === id ? { ...j, ...patch } : j)));
  }, []);

  const filteredSamples = useMemo(() => {
    return samples.filter(s => {
      if (s.status === "exported_archived") return false;
      if (filterStatus !== "all" && s.status !== filterStatus) return false;
      return true;
    });
  }, [samples, filterStatus]);

  const totalPages = Math.max(1, Math.ceil(filteredSamples.length / 10));
  const paginatedSamples = useMemo(() => {
    return filteredSamples.slice((page - 1) * 10, page * 10);
  }, [filteredSamples, page]);

  useEffect(() => {
    if (page > totalPages) setPage(1);
  }, [totalPages, page]);

  const startPrelabelProgress = useCallback((jobId) => {
    if (prelabelTimersRef.current[jobId]) clearInterval(prelabelTimersRef.current[jobId]);
    prelabelTimersRef.current[jobId] = setInterval(() => {
      setPrelabelJobs((prev) =>
        prev.map((j) => {
          if (j.id !== jobId || j.phase === "done" || j.phase === "failed") return j;
          const cap = j.phase === "upload" ? 28 : 92;
          const next = Math.min(cap, (j.progress || 0) + (j.phase === "upload" ? 4 : 1.5));
          return { ...j, progress: next };
        })
      );
    }, 800);
  }, []);

  const stopPrelabelProgress = useCallback((jobId) => {
    if (prelabelTimersRef.current[jobId]) {
      clearInterval(prelabelTimersRef.current[jobId]);
      delete prelabelTimersRef.current[jobId];
    }
  }, []);

  const enqueuePrelabelJob = useCallback((label) => {
    const id = `pl-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    setPrelabelJobs((prev) => [
      { id, label, phase: "upload", phaseLabel: "Upload", progress: 8 },
      ...prev,
    ]);
    startPrelabelProgress(id);
    return id;
  }, [startPrelabelProgress]);

  const finishPrelabelJob = useCallback((jobId, ok, error) => {
    stopPrelabelProgress(jobId);
    upsertPrelabelJob(jobId, {
      phase: ok ? "done" : "failed",
      phaseLabel: ok ? "Xong" : "Lỗi",
      progress: ok ? 100 : undefined,
      error: error || null,
    });
    setTimeout(() => {
      setPrelabelJobs((prev) => prev.filter((j) => j.id !== jobId));
    }, ok ? 2500 : 8000);
  }, [stopPrelabelProgress, upsertPrelabelJob]);

  const showToast = useCallback((type, message, action) => {
    if (toastTimerRef.current) clearTimeout(toastTimerRef.current);
    setToast({ type, message, action });
    toastTimerRef.current = setTimeout(() => setToast(null), 9000);
  }, []);

  const dismissToast = useCallback(() => {
    if (toastTimerRef.current) clearTimeout(toastTimerRef.current);
    setToast(null);
  }, []);

  const scrollToKagglePanel = useCallback(() => {
    document.getElementById("kaggle-progress-panel")?.scrollIntoView({ behavior: "smooth", block: "start" });
    dismissToast();
  }, [dismissToast]);

  const loadSamples = useCallback(async () => {
    const rows = await fetchBillSamples();
    setSamples(rows);
  }, []);

  const refreshOcrStatus = useCallback(async () => {
    try {
      const st = await fetchBillOcrStatus();
      setOcrStatus(st);
      return st;
    } catch {
      setOcrStatus({ ocr_loaded: false, error: "Không kết nối được ai-service" });
      return null;
    }
  }, []);

  const setBusy = (busy, msg = "") => {
    setLoading(busy);
    setLoadingMessage(msg);
  };

  const onReloadModels = async () => {
    if (!window.confirm("Bạn có chắc chắn muốn tải lại nóng toàn bộ model OCR (Paddle + VietOCR + LayoutLMv3) không?")) return;
    setBusy(true, "Đang tải lại model OCR...");
    setMessage("");
    try {
      const r = await reloadAiModels("ocr");
      await refreshOcrStatus();
      setMessageIsError(!r.ok);
      setMessage(
        r.ok
          ? `Đã tải lại OCR — KIE: ${r.kie_backend || "unknown"}${r.kie_backend === "layoutlmv3" ? " (LayoutLMv3 active)" : ""}`
          : r.ocr_error || "Reload OCR thất bại — kiểm tra ai-service port 8000."
      );
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message || "Reload thất bại");
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    loadSamples().catch((e) => {
      setMessageIsError(true);
      setMessage(e.message);
    });
    refreshOcrStatus().then((st) => {
      if (st && !st.ocr_loaded) {
        reloadAiModels("ocr").catch(() => { });
      }
    });
  }, [loadSamples, refreshOcrStatus]);

  const applyPrelabelResult = (sample, prelabel) => {
    setActive(sample);
    setBoxes(prelabel.boxes || sample.adminLabels || []);
    setSelectedIdx(null);
    setMessageIsError(Boolean(prelabel.error && !(prelabel.boxes || []).length));
    setMessage(formatPrelabelMessage(prelabel));
    refreshOcrStatus();
  };

  const onUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const jobId = enqueuePrelabelJob(file.name);
    setMessage("");
    setMessageIsError(false);
    try {
      upsertPrelabelJob(jobId, { phase: "upload", phaseLabel: "Upload ảnh", progress: 12 });
      const { sample } = await uploadBillSample(file);
      const label = ocrStatus?.kie_backend === "layoutlmv3" ? "OCR + LayoutLMv3" : "OCR + KIE";
      upsertPrelabelJob(jobId, { phase: "ocr", phaseLabel: label, progress: 35, sampleId: sample.id });
      setActive(sample);
      await loadSamples();
      const { sample: updated, prelabel } = await rePrelabelBillSample(sample.id);
      applyPrelabelResult(updated, prelabel);
      await loadSamples();
      finishPrelabelJob(jobId, true);
    } catch (err) {
      finishPrelabelJob(jobId, false, err.message || "Upload / gán nhãn auto thất bại");
      setMessageIsError(true);
      setMessage(err.message || "Upload / gán nhãn auto thất bại");
    } finally {
      e.target.value = "";
    }
  };

  const onAutoLabel = async () => {
    if (!active) return;
    if (boxes.length > 0 && !window.confirm(`Gán nhãn auto sẽ ghi đè ${boxes.length} box hiện tại. Tiếp tục?`)) {
      return;
    }
    const jobId = enqueuePrelabelJob(`${active.id.slice(0, 8)} · re-OCR`);
    setMessage("");
    setMessageIsError(false);
    try {
      const label = ocrStatus?.kie_backend === "layoutlmv3" ? "OCR + LayoutLMv3" : "OCR + KIE";
      upsertPrelabelJob(jobId, { phase: "ocr", phaseLabel: label, progress: 20 });
      const { sample, prelabel } = await rePrelabelBillSample(active.id);
      applyPrelabelResult(sample, prelabel);
      await loadSamples();
      finishPrelabelJob(jobId, true);
    } catch (err) {
      finishPrelabelJob(jobId, false, err.message || "Gán nhãn auto thất bại");
      setMessageIsError(true);
      setMessage(err.message || "Gán nhãn auto thất bại");
    }
  };

  const onDelete = async (id) => {
    const targetId = id || active?.id;
    if (!targetId) return;
    if (!window.confirm("Xóa sample này khỏi hàng đợi retrain?")) return;
    setBusy(true, "Đang xóa...");
    try {
      await deleteBillSample(targetId);
      if (active?.id === targetId) {
        setActive(null);
        setBoxes([]);
        setSelectedIdx(null);
      }
      await loadSamples();
      setMessageIsError(false);
      setMessage("Đã xóa sample khỏi hàng đợi");
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message);
    } finally {
      setBusy(false);
    }
  };

  const onSelectSample = (s) => {
    setDrawMode(false);
    setActive(s);
    setBoxes(s.adminLabels || s.autoLabels?.boxes || []);
    const cat = s.metadata?.category || s.autoLabels?.category || "Others";
    setActiveCategory(cat === "Other" ? "Others" : cat);
    setSelectedIdx(null);
    if (!s.metadata?.prelabelError) {
      setMessage("");
      setMessageIsError(false);
    }
  };

  const updateBox = (idx, field, value) => {
    setBoxes((prev) => prev.map((b, i) => (i === idx ? { ...b, [field]: value } : b)));
  };

  const onDeleteSelectedBox = useCallback(() => {
    if (selectedIdx == null) return;
    setBoxes((prev) => prev.filter((_, i) => i !== selectedIdx));
    setSelectedIdx(null);
    setMessageIsError(false);
    setMessage("Đã xóa nhãn (bbox) — bấm Lưu nháp để lưu");
  }, [selectedIdx]);

  useEffect(() => {
    const onKey = (e) => {
      if (e.key !== "Delete" && e.key !== "Backspace") return;
      if (selectedIdx == null || !active) return;
      const tag = e.target?.tagName?.toLowerCase();
      if (tag === "input" || tag === "textarea" || tag === "select") return;
      e.preventDefault();
      onDeleteSelectedBox();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [selectedIdx, active, onDeleteSelectedBox]);

  const onSaveDraft = async () => {
    if (!active) return;
    setBusy(true, "Đang lưu nháp...");
    try {
      await saveBillSample(active.id, boxes, "pending", activeCategory);
      await loadSamples();
      setMessageIsError(false);
      setMessage("Đã lưu nháp");
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message);
    } finally {
      setBusy(false);
    }
  };

  const onApprove = async () => {
    if (!active) return;
    if (!boxes.length) {
      setMessageIsError(true);
      setMessage("Chưa có nhãn — bấm Gán nhãn auto trước khi duyệt.");
      return;
    }
    setBusy(true, "Đang duyệt nhãn...");
    try {
      await approveBillSample(active.id, boxes, activeCategory);
      await loadSamples();
      setMessageIsError(false);
      setMessage("Đã duyệt — nhãn dùng cho export LayoutLMv3");
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message);
    } finally {
      setBusy(false);
    }
  };

  const onExport = async () => {
    if (!window.confirm("Bạn có chắc chắn muốn xuất toàn bộ mẫu hóa đơn đã duyệt sang thư mục hệ thống để retrain không?")) return;
    setBusy(true, "Đang export nhãn đã duyệt...");
    try {
      const r = await exportBillVerified(
        false,
        "layoutlmv3",
        undefined,
        archiveImagesOnExport
      );
      let msg = `Đã export ${r.exported} hóa đơn sang thư mục hệ thống retrain.`;
      if (r.archivedImages > 0) msg += ` Đã archive ${r.archivedImages} ảnh local.`;
      setMessageIsError(false);
      setMessage(msg);
      const rows = await fetchBillSamples();
      setSamples(rows);
      if (active?.id) {
        const refreshed = rows.find((s) => s.id === active.id);
        if (refreshed && refreshed.status !== "exported_archived") {
          setActive(refreshed);
        } else {
          setActive(null);
          setBoxes([]);
          setSelectedIdx(null);
        }
      }
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message);
    } finally {
      setBusy(false);
    }
  };

  const onModalTrigger = async () => {
    if (!window.confirm("Bạn có chắc chắn muốn khởi chạy huấn luyện mô hình LayoutLMv3 trên đám mây Modal (sử dụng GPU) không?\n\nTác vụ này sẽ chạy nền và có thể tốn tài nguyên đám mây.")) return;
    setBusy(true, "Đang khởi chạy training LayoutLMv3 trên Modal Cloud...");
    try {
      const res = await triggerBillModal(30, 0.00002);
      setMessageIsError(!res.ok);
      setMessage(
        res.ok
          ? `Modal training đã khởi động thành công — Job: ${res.job_id || "running"}`
          : res.error || "Không thể khởi chạy training trên Modal"
      );
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message || "Trigger Modal training thất bại");
    } finally {
      setBusy(false);
    }
  };

  const onGolden = async () => {
    if (!window.confirm("Bạn có chắc chắn muốn chạy đánh giá chất lượng (Golden Test) trên tập dữ liệu kiểm thử chuẩn không?")) return;
    setBusy(true, "Đang chạy Golden Test...");
    try {
      const r = await runBillGoldenEval();
      setGolden(r);
      setMessageIsError(false);
      setMessage(`Golden: amount ${(r.amount_acc * 100).toFixed(1)}%, category ${(r.category_acc * 100).toFixed(1)}%`);
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message);
    } finally {
      setBusy(false);
    }
  };



  const imageUrl =
    active?.imageUrl && !active?.imageArchived
      ? (active.imageUrl.startsWith("http") ? active.imageUrl : billSampleImageUrl(active.id))
      : null;
  const isArchivedSample = Boolean(active?.imageArchived || active?.status === "exported_archived");
  const ocrReady = Boolean(ocrStatus?.ocr_loaded);
  const showStalePrelabel =
    active?.metadata?.prelabelError &&
    !messageIsError &&
    !message &&
    !(active.adminLabels?.length || active.autoLabels?.boxes?.length);

  const approvedCount = samples.filter((s) => s.status === "approved").length;
  const pendingCount = samples.filter((s) => s.status === "pending").length;
  const exportedCount = samples.filter((s) => s.status === "exported_archived").length;

  return (
    <div className="page bill-retrain-page">
      <BillHelpModal open={helpOpen} onClose={() => setHelpOpen(false)} />
      <BillToast toast={toast} onDismiss={dismissToast} />
      <PrelabelQueuePanel jobs={prelabelJobs} />

      {loading && (
        <div className="bill-loading-overlay" role="status" aria-live="polite">
          <div className="bill-loading-shimmer">
            <span /><span /><span />
          </div>
          <p>{loadingMessage || "Đang xử lý..."}</p>
        </div>
      )}

      <header className="bill-page-hero">
        <div className="bill-page-hero-main">
          <p className="bill-page-eyebrow">Pipeline retrain</p>
          <h1 className="page-title">Bill OCR Retrain</h1>
          <p className="page-desc">
            Upload, gán nhãn auto, duyệt và huấn luyện mô hình LayoutLMv3.
          </p>
          <div className="bill-stat-strip">
            <div className="bill-stat">
              <span className="bill-stat-value">{pendingCount + approvedCount}</span>
              <span className="bill-stat-label">Hàng đợi</span>
            </div>
            <div className="bill-stat">
              <span className="bill-stat-value">{approvedCount}</span>
              <span className="bill-stat-label">Đã duyệt</span>
            </div>
            <div className="bill-stat">
              <span className="bill-stat-value">{pendingCount}</span>
              <span className="bill-stat-label">Chờ duyệt</span>
            </div>
            {exportedCount > 0 && (
              <div className="bill-stat">
                <span className="bill-stat-value">{exportedCount}</span>
                <span className="bill-stat-label">Đã export</span>
              </div>
            )}
          </div>
        </div>
        <div className="bill-page-hero-actions">
          <BillHelpTrigger onClick={() => setHelpOpen(true)} />
          <div className={`bill-ocr-pill ${ocrReady ? "online" : "offline"}`}>
            <span className={`bill-ocr-dot ${ocrReady ? "pulse" : ""}`} />
            OCR {ocrReady ? "Online" : "Lazy load"}
          </div>
          <button type="button" className="btn btn-secondary btn-reload-models" onClick={onReloadModels} disabled={loading}>
            Tải lại model
          </button>
        </div>
      </header>

      {!ocrReady && (
        <div className="bill-inline-toast warn">
          <strong>OCR chưa load.</strong>
          {ocrStatus?.hint || "Model load lần đầu khi Gán nhãn auto hoặc bấm Tải lại model."}
          <button type="button" className="btn btn-sm btn-secondary" onClick={onReloadModels} disabled={loading}>
            Tải ngay
          </button>
        </div>
      )}

      {(message || showStalePrelabel) && (
        <div className={`bill-inline-toast ${messageIsError || showStalePrelabel ? "error" : "success"}`}>
          {message || shortenOcrError(active.metadata.prelabelError)}
        </div>
      )}

      <div className="bill-toolbar">
        <div className="bill-toolbar-group">
          <span className="bill-toolbar-label">Category</span>
          <div className="bill-toolbar-actions">
            <select
              className="bill-select"
              value={activeCategory}
              onChange={(e) => setActiveCategory(e.target.value)}
              disabled={!active || isArchivedSample}
            >
              {["Food", "Essentials", "Social", "Transport", "Shopping", "Housing", "Health", "Beauty", "Education", "Entertainment", "Investment", "Others"].map((cat) => (
                <option key={cat} value={cat}>{cat}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="bill-toolbar-divider" aria-hidden="true" />

        <div className="bill-toolbar-group">
          <span className="bill-toolbar-label">Export</span>
          <div className="bill-toolbar-actions">
            <button type="button" className="btn btn-secondary" onClick={onExport} disabled={loading}>
              Export approved
            </button>
            <label className="bill-toggle">
              <input type="checkbox" checked={archiveImagesOnExport} onChange={(e) => setArchiveImagesOnExport(e.target.checked)} />
              <span>Xóa ảnh local sau export</span>
            </label>
          </div>
        </div>

        <div className="bill-toolbar-divider" aria-hidden="true" />

        <div className="bill-toolbar-group">
          <span className="bill-toolbar-label">Modal Cloud</span>
          <div className="bill-toolbar-actions">
            <button type="button" className="btn btn-secondary" onClick={onModalTrigger} disabled={loading}>
              Train LayoutLMv3
            </button>
          </div>
        </div>
      </div>

      <div className="grid-3 bill-retrain-grid">
        <section className="bill-surface bill-queue-panel">
          <div className="bill-surface-head" style={{ marginBottom: 12 }}>
            <div>
              <h2 className="bill-surface-title">Hàng đợi</h2>
            </div>
            <span className="bill-count-badge">{filteredSamples.length}</span>
          </div>

          <div className="bill-queue-controls" style={{ display: 'flex', gap: 10, marginBottom: 16 }}>
            <select 
              className="bill-select" 
              value={filterStatus} 
              onChange={e => { setFilterStatus(e.target.value); setPage(1); }}
              style={{ flex: 1 }}
            >
              <option value="all">Tất cả trạng thái</option>
              <option value="pending">Pending</option>
              <option value="approved">Approved</option>
            </select>
          </div>

          {filteredSamples.length === 0 && (
            <div className="bill-empty-state">
              <p>Chưa có sample</p>
              <span className="muted">Không tìm thấy hóa đơn nào phù hợp.</span>
            </div>
          )}
          
          <ul className="sample-list" style={{ maxHeight: 'none', overflow: 'visible' }}>
            {paginatedSamples.map((s) => {
              const hasLabels = s.adminLabels?.length > 0 || s.autoLabels?.boxes?.length > 0;
              return (
              <li key={s.id} className="sample-list-row">
                <button
                  type="button"
                  className={`sample-card ${active?.id === s.id ? "active" : ""} ${s.status === "approved" ? "approved" : ""} ${s.status === "exported_archived" ? "exported" : ""}`}
                  onClick={() => onSelectSample(s)}
                >
                  <code>{s.id.slice(0, 8)}</code>
                  <span className={`sample-status ${s.status}`}>{sampleStatusLabel(s.status)}</span>
                  {s.imageArchived && <span className="sample-meta archived-tag">ảnh archived</span>}
                  {s.metadata?.category && <span className="sample-meta">{s.metadata.category}</span>}
                  {!hasLabels && (
                    <span className="sample-meta unlabeled-tag" title="Chưa có nhãn (bbox)">Chưa có nhãn</span>
                  )}
                </button>
                <button type="button" className="btn-icon danger" title="Xóa khỏi hàng đợi" onClick={() => onDelete(s.id)} disabled={loading}>
                  ×
                </button>
              </li>
            )})}
          </ul>

          {totalPages > 1 && (
            <div className="bill-pagination" style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 16, marginTop: 16 }}>
              <button 
                type="button" 
                className="btn btn-secondary" 
                disabled={page <= 1} 
                onClick={() => setPage(p => Math.max(1, p - 1))}
              >
                Trước
              </button>
              <span className="muted" style={{ fontSize: 13 }}>Trang {page} / {totalPages}</span>
              <button 
                type="button" 
                className="btn btn-secondary" 
                disabled={page >= totalPages} 
                onClick={() => setPage(p => Math.min(totalPages, p + 1))}
              >
                Sau
              </button>
            </div>
          )}
        </section>

        <section className="bill-surface bill-canvas-panel">
          <div className="bill-surface-head">
            <div>
              <h2 className="bill-surface-title">Canvas nhãn</h2>
            </div>
            {active && boxes.length > 0 && (
              <span className="bill-edit-tag">{boxes.length} box · kéo thả để chỉnh</span>
            )}
          </div>
          {!active && (
            <div className="bill-empty-state">
              <p>Chưa chọn sample</p>
              <span className="muted">Upload ảnh hoặc chọn từ hàng đợi bên trái.</span>
            </div>
          )}
          {active && (
            <>
              {isArchivedSample && (
                <p className="bill-inline-toast warn bill-archived-notice">
                  Đã export — ảnh gốc đã archive local. Chọn nhãn bên dưới (hoặc trên ảnh nếu còn preview) để xem chi tiết.
                </p>
              )}
              <BillLabelCanvas
                imageUrl={imageUrl}
                boxes={boxes}
                selectedIdx={selectedIdx}
                onSelectBox={setSelectedIdx}
                onBoxesChange={isArchivedSample ? undefined : setBoxes}
                drawMode={drawMode && !isArchivedSample}
                onDrawComplete={() => {
                  setDrawMode(false);
                  setMessageIsError(false);
                  setMessage("Đã thêm bbox OTHER — chỉnh text/entity rồi Lưu nháp");
                }}
              />
              {!imageUrl && isArchivedSample && (
                <p className="muted bill-empty-boxes">Không còn ảnh preview (đã xóa khỏi disk sau export).</p>
              )}
              {boxes.length === 0 && (
                <p className="muted bill-empty-boxes">Chưa có bbox — bấm Gán nhãn auto hoặc thêm sau khi có nhãn.</p>
              )}
            </>
          )}
        </section>

        <section className="bill-surface bill-box-panel">
          <div className="bill-surface-head" style={{ marginBottom: 12 }}>
            <div>
              <h2 className="bill-surface-title">Công cụ gán nhãn</h2>
            </div>
          </div>
          <div className="bill-box-tools" style={{ display: "flex", flexWrap: "wrap", gap: 8, paddingBottom: 16, borderBottom: "1px solid var(--border-color)", marginBottom: 16 }}>
            <label className="btn btn-primary btn-sm">
              Upload ảnh
              <input type="file" accept="image/*" hidden onChange={onUpload} />
            </label>
            <button type="button" className="btn btn-primary btn-sm" onClick={onAutoLabel} disabled={!active || isArchivedSample}>
              Gán nhãn auto
            </button>
            <button type="button" className="btn btn-secondary btn-sm" onClick={onSaveDraft} disabled={!active || loading || isArchivedSample}>
              Lưu nháp
            </button>
            <button
              type="button"
              className={`btn btn-secondary btn-sm ${drawMode ? "active" : ""}`}
              onClick={() => setDrawMode((v) => !v)}
              disabled={!active || loading || isArchivedSample || !imageUrl}
              title="Kéo trên ảnh để vẽ bbox OTHER mới"
            >
              {drawMode ? "Hủy vẽ" : "Thêm bbox"}
            </button>
            <button
              type="button"
              className="btn btn-secondary btn-sm"
              onClick={onDeleteSelectedBox}
              disabled={!active || selectedIdx == null || loading}
              title="Xóa bbox đang chọn (Delete)"
            >
              Xóa nhãn
            </button>
            <button type="button" className="btn btn-secondary btn-sm" onClick={onApprove} disabled={!active || loading || isArchivedSample}>
              Duyệt
            </button>
            <button type="button" className="btn btn-ghost danger btn-sm" onClick={() => onDelete()} disabled={!active || loading}>
              Xóa
            </button>
          </div>

          <div className="bill-surface-head">
            <div>
              <h2 className="bill-surface-title">Chỉnh sửa nhãn</h2>
            </div>
          </div>
          {!active && (
            <div className="bill-empty-state">
              <p>Chưa chọn sample</p>
              <span className="muted">Hãy chọn sample để chỉnh sửa nhãn.</span>
            </div>
          )}
          {active && boxes.length === 0 && (
            <div className="bill-empty-state">
              <span className="muted">Chưa có bbox nào. Bấm Gán nhãn auto hoặc vẽ thêm.</span>
            </div>
          )}
          {active && boxes.length > 0 && (
            <div className="bill-box-detail-panel" style={{ marginTop: 0 }}>
              {!imageUrl && (
                <div className="bill-box-picker">
                  <label htmlFor="bill-box-select">Chọn nhãn</label>
                  <select
                    id="bill-box-select"
                    className="bill-select"
                    value={selectedIdx ?? ""}
                    onChange={(e) => {
                      const v = e.target.value;
                      setSelectedIdx(v === "" ? null : Number(v));
                    }}
                  >
                    <option value="">— Chọn —</option>
                    {boxes.map((b, idx) => (
                      <option key={idx} value={idx}>
                        #{idx + 1} — {(b.text || "").slice(0, 48) || b.entity || "OTHER"}
                      </option>
                    ))}
                  </select>
                </div>
              )}
              {selectedIdx != null && boxes[selectedIdx] ? (
                <div className="bill-box-detail">
                  <div className="bill-box-detail-head">
                    <span className="bill-box-detail-title">
                      Nhãn #{selectedIdx + 1} / {boxes.length}
                    </span>
                    <span className="bill-box-detail-entity">{boxes[selectedIdx].entity || "OTHER"}</span>
                  </div>
                  <div className="bill-box-detail-fields">
                    <label className="bill-box-field">
                      <span>Text</span>
                      <input
                        value={boxes[selectedIdx].text || ""}
                        onChange={(e) => updateBox(selectedIdx, "text", e.target.value)}
                        placeholder="Nội dung OCR / nhãn"
                      />
                    </label>
                    <label className="bill-box-field">
                      <span>Entity</span>
                      <select
                        value={boxes[selectedIdx].entity || "OTHER"}
                        onChange={(e) => updateBox(selectedIdx, "entity", e.target.value)}
                      >
                        {ENTITIES.map((ent) => (
                          <option key={ent} value={ent}>{ent}</option>
                        ))}
                      </select>
                    </label>
                    <div className="bill-box-field bill-box-field-bbox">
                      <span>Bbox</span>
                      <code className="mono">
                        {boxes[selectedIdx].x1},{boxes[selectedIdx].y1},{boxes[selectedIdx].x2},{boxes[selectedIdx].y2}
                      </code>
                    </div>
                  </div>
                </div>
              ) : imageUrl ? (
                <p className="muted canvas-hint bill-box-detail-hint">
                  Chọn một bbox trên ảnh để xem và chỉnh sửa nhãn ({boxes.length} nhãn).
                </p>
              ) : null}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
