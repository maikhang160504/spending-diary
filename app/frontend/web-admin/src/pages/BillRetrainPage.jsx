import { useCallback, useEffect, useRef, useState } from "react";
import BillLabelCanvas from "../components/BillLabelCanvas";
import BillHelpModal, { BillHelpTrigger } from "../components/BillHelpModal";
import {
  approveBillSample,
  billSampleImageUrl,
  deleteBillSample,
  exportBillVerified,
  fetchBillKaggleJob,
  fetchBillKaggleJobs,
  fetchBillOcrStatus,
  fetchBillSamples,
  rePrelabelBillSample,
  runBillGoldenEval,
  fetchBillKagglePlan,
  triggerBillKaggle,
  reloadAiModels,
  prelabelBill,
  syncBillKaggle,
  saveBillSample,
} from "../services/api";

const ENTITIES = ["OTHER", "SELLER", "ADDRESS", "TIMESTAMP", "TOTAL_COST"];

const KAGGLE_STEPS = [
  { key: "queued", label: "Khởi tạo job" },
  { key: "versioning_dataset", label: "Upload dataset Kaggle" },
  { key: "syncing_pick_code", label: "Sync pick-train-code" },
  { key: "pushing_kernel", label: "Push kernel retrain" },
  { key: "running_on_kaggle", label: "Train trên Kaggle (GPU)" },
  { key: "syncing", label: "Đồng bộ output Kaggle" },
  { key: "deploying", label: "Tải output & deploy weights" },
  { key: "deploying_from_cloud", label: "Deploy từ cloud fallback" },
  { key: "completed", label: "Hoàn thành" },
];

const STEP_ORDER = KAGGLE_STEPS.map((s) => s.key);

const STATUS_LABELS = {
  pending: "pending",
  approved: "approved",
  exported_archived: "exported",
};

function sampleStatusLabel(status) {
  return STATUS_LABELS[status] || status;
}

function KaggleProgressPanel({ job }) {
  if (!job) return null;
  const status = job.status || "queued";
  const isFailed = status === "failed";
  const isDone = status === "completed";
  const curIdx = STEP_ORDER.indexOf(status);
  const visibleSteps = KAGGLE_STEPS.filter(
    (step) => {
      if (step.key === "deploying_from_cloud") {
        return status === "deploying_from_cloud" || STEP_ORDER.indexOf(step.key) <= curIdx;
      }
      if (step.key === "syncing") {
        return status === "syncing" || status === "syncing_pick_code" || STEP_ORDER.indexOf(step.key) <= curIdx;
      }
      return true;
    }
  );
  const activeStep = visibleSteps.find((s) => s.key === status) || visibleSteps[Math.max(0, curIdx)];
  const stepNum = Math.max(1, curIdx >= 0 ? curIdx + 1 : 1);
  const stepTotal = Math.max(1, visibleSteps.length - 1);
  const progressPct =
    isDone ? 100 : curIdx >= 0 ? Math.min(100, Math.round((curIdx / (STEP_ORDER.length - 2)) * 100)) : 0;

  return (
    <section className="bill-surface bill-kaggle-progress" id="kaggle-progress-panel">
      <div className="bill-kaggle-progress-head">
        <div>
          <p className="bill-surface-eyebrow">Kaggle retrain</p>
          <h2 className="bill-surface-title">Tiến độ train</h2>
        </div>
        <span className={`bill-status-chip ${status}`}>{status.replace(/_/g, " ")}</span>
      </div>
      <p className="bill-kaggle-meta">
        Job <code>{(job.id || job.job_id || "").slice(0, 8)}</code>
        {job.job_type && <> · {job.job_type}</>}
        {job.kernel && <> · {job.kernel}</>}
      </p>
      {!isDone && !isFailed && (
        <p className="bill-kaggle-step-label">
          Bước {stepNum}/{stepTotal} — {activeStep?.label || status.replace(/_/g, " ")}
          <span className="bill-kaggle-pct">{progressPct}%</span>
        </p>
      )}
      <div className="kaggle-track" aria-label="Tiến độ retrain">
        {KAGGLE_STEPS.map((step) => {
          const state = kaggleStepState(status, step.key);
          if (step.key === "deploying_from_cloud" && status !== "deploying_from_cloud" && state === "pending") {
            return null;
          }
          if (step.key === "syncing" && status !== "syncing" && state === "pending") {
            return null;
          }
          return (
            <div key={step.key} className={`kaggle-track-step kaggle-track-step-${state}`} title={step.label}>
              <span className="kaggle-track-dot" />
              <span className="kaggle-track-label">{step.label}</span>
            </div>
          );
        })}
      </div>
      {!isDone && !isFailed && curIdx >= 0 && (
        <div className="bill-progress-bar" aria-hidden="true">
          <div className="bill-progress-fill" style={{ width: `${progressPct}%` }} />
        </div>
      )}
      {isDone && (
        <p className="bill-inline-toast success">
          Retrain hoàn thành — weights deploy, ai-service reload OCR.
          {job.f1_score && job.f1_score !== "N/A" && <> · F1 {job.f1_score}</>}
        </p>
      )}
      {isFailed && (
        <p className="bill-inline-toast error">
          Retrain thất bại — kiểm tra log Kaggle.
          {job.error && <span className="bill-kaggle-err"> {String(job.error).slice(0, 160)}</span>}
        </p>
      )}
    </section>
  );
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
  const kieLabel = kie === "pick" ? "PICK KIE" : `heuristic (${kie})`;
  return `Gán nhãn auto: ${n} boxes · entity: ${kieLabel} · ${engine}`;
}

function kaggleStepState(jobStatus, stepKey) {
  if (jobStatus === "failed") {
    const failedIdx = STEP_ORDER.indexOf(stepKey);
    const currentIdx = STEP_ORDER.findIndex((k) => k === jobStatus);
    if (stepKey === "completed") return "pending";
    if (failedIdx <= currentIdx && stepKey !== "completed") return failedIdx === currentIdx ? "failed" : "done";
    return "pending";
  }
  if (jobStatus === "completed") return stepKey === "completed" ? "done" : "done";
  const curIdx = STEP_ORDER.indexOf(jobStatus);
  const stepIdx = STEP_ORDER.indexOf(stepKey);
  if (stepIdx < 0) return "pending";
  if (stepIdx < curIdx) return "done";
  if (stepIdx === curIdx) return "active";
  return "pending";
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
  const [kagglePlan, setKagglePlan] = useState(null);
  const [kaggleJobs, setKaggleJobs] = useState([]);
  const [activeJob, setActiveJob] = useState(null);
  const [triggerKaggleOnExport, setTriggerKaggleOnExport] = useState(false);
  const [exportJobType, setExportJobType] = useState("pick_retrain");
  const [archiveImagesOnExport, setArchiveImagesOnExport] = useState(true);
  const [drawMode, setDrawMode] = useState(false);
  const [helpOpen, setHelpOpen] = useState(false);
  const [toast, setToast] = useState(null);
  const [activeCategory, setActiveCategory] = useState("Others");
  const handledJobsRef = useRef(new Set());
  const toastTimerRef = useRef(null);

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
    setBusy(true, "Đang tải lại model OCR...");
    setMessage("");
    try {
      const r = await reloadAiModels("ocr");
      await refreshOcrStatus();
      setMessageIsError(!r.ok);
      setMessage(
        r.ok
          ? `Đã tải lại OCR — KIE: ${r.kie_backend || "unknown"}${r.kie_backend === "pick" ? " (PICK active)" : ""}`
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
    refreshOcrStatus();
    
    const storedJobId = localStorage.getItem("active_kaggle_job_id");
    if (storedJobId) {
      fetchBillKaggleJob(storedJobId)
        .then((job) => {
          if (job && job.status && !["completed", "failed"].includes(job.status)) {
            setActiveJob(job);
          } else {
            localStorage.removeItem("active_kaggle_job_id");
          }
        })
        .catch(() => {});
    }
  }, [loadSamples, refreshOcrStatus]);

  useEffect(() => {
    const jobId = activeJob?.id || activeJob?.job_id;
    if (!jobId) return undefined;
    if (activeJob.status === "completed" || activeJob.status === "failed") {
      localStorage.removeItem("active_kaggle_job_id");
      return undefined;
    }
    const t = setInterval(async () => {
      try {
        const job = await fetchBillKaggleJob(jobId);
        setActiveJob(job);
        if (job.status === "completed" || job.status === "failed") {
          localStorage.removeItem("active_kaggle_job_id");
          clearInterval(t);
          fetchBillKaggleJobs().then(setKaggleJobs).catch(() => {});
        }
      } catch {
        localStorage.removeItem("active_kaggle_job_id");
        clearInterval(t);
      }
    }, 5000);
    return () => clearInterval(t);
  }, [activeJob?.id, activeJob?.job_id, activeJob?.status]);

  useEffect(() => {
    const job = activeJob;
    if (!job || job.status !== "completed") return;
    const id = job.id || job.job_id;
    if (!id || handledJobsRef.current.has(id)) return;
    handledJobsRef.current.add(id);

    const finish = async () => {
      let reloadMsg = "";
      if (job.needs_model_reload !== false) {
        try {
          const r = await reloadAiModels("ocr");
          await refreshOcrStatus();
          reloadMsg = r.ok ? " OCR đã reload." : " (reload OCR thất bại — bấm Tải lại model OCR).";
        } catch {
          reloadMsg = " (reload OCR thất bại — bấm Tải lại model OCR).";
        }
      }
      setMessageIsError(false);
      setMessage(`Kaggle ${job.job_type || "retrain"} hoàn thành — weights đã deploy.${reloadMsg}`);
      showToast(
        "success",
        `Kaggle retrain hoàn thành (${(job.id || job.job_id || "").slice(0, 8)})${reloadMsg}`,
        { label: "Xem job", onClick: scrollToKagglePanel }
      );
    };
    finish();
  }, [activeJob, refreshOcrStatus, showToast, scrollToKagglePanel]);

  useEffect(() => {
    const job = activeJob;
    if (!job || job.status !== "failed") return;
    const id = job.id || job.job_id;
    if (!id || handledJobsRef.current.has(`failed:${id}`)) return;
    handledJobsRef.current.add(`failed:${id}`);
    showToast(
      "error",
      `Kaggle retrain thất bại (${id.slice(0, 8)})${job.error ? `: ${String(job.error).slice(0, 80)}` : ""}`,
      { label: "Xem job", onClick: scrollToKagglePanel }
    );
  }, [activeJob, showToast, scrollToKagglePanel]);

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
    setBusy(true, "Đang upload và gán nhãn auto (PaddleOCR + VietOCR + PICK)...");
    setMessage("");
    setMessageIsError(false);
    try {
      const { sample, prelabel } = await prelabelBill(file);
      applyPrelabelResult(sample, prelabel);
      await loadSamples();
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message || "Upload / gán nhãn auto thất bại");
    } finally {
      setBusy(false);
      e.target.value = "";
    }
  };

  const onAutoLabel = async () => {
    if (!active) return;
    if (boxes.length > 0 && !window.confirm(`Gán nhãn auto sẽ ghi đè ${boxes.length} box hiện tại. Tiếp tục?`)) {
      return;
    }
    setBusy(true, "Đang gán nhãn auto (PaddleOCR + VietOCR + PICK)...");
    setMessage("");
    setMessageIsError(false);
    try {
      const { sample, prelabel } = await rePrelabelBillSample(active.id);
      applyPrelabelResult(sample, prelabel);
      await loadSamples();
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message || "Gán nhãn auto thất bại");
    } finally {
      setBusy(false);
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
    setActiveCategory(s.metadata?.category || s.autoLabels?.category || "Others");
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
      setMessage("Đã duyệt — nhãn dùng cho export PICK KIE");
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message);
    } finally {
      setBusy(false);
    }
  };

  const onExport = async () => {
    setBusy(true, "Đang export nhãn đã duyệt...");
    try {
      const r = await exportBillVerified(
        triggerKaggleOnExport,
        exportJobType,
        undefined,
        archiveImagesOnExport
      );
      const username = r.kaggle_username || "mainhatkhangb2205881";
      let msg = `Đã thêm ${r.exported} hóa đơn vào dataset Kaggle (${username}/webadmin-verified-receipts).`;
      if (r.archivedImages > 0) msg += ` Đã archive ${r.archivedImages} ảnh local.`;
      if (r.kaggle_job?.job_id) {
        setActiveJob(r.kaggle_job);
        localStorage.setItem("active_kaggle_job_id", r.kaggle_job.id || r.kaggle_job.job_id);
        msg += ` Bắt đầu train job ${r.kaggle_job.job_id.slice(0, 8)} trên Kaggle.`;
      }
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
      fetchBillKaggleJobs().then(setKaggleJobs).catch(() => {});
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message);
    } finally {
      setBusy(false);
    }
  };

  const onKaggleTrigger = async (jobType) => {
    setBusy(true, `Đang khởi chạy Kaggle ${jobType}...`);
    try {
      const job = await triggerBillKaggle(jobType);
      setActiveJob(job);
      if (job.ok && job.job_id) {
        localStorage.setItem("active_kaggle_job_id", job.job_id);
      }
      setMessage(
        job.ok
          ? `Kaggle ${jobType} đã queue — job ${job.job_id?.slice(0, 8)}`
          : job.error || "Trigger failed"
      );
      fetchBillKaggleJobs().then(setKaggleJobs).catch(() => {});
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message);
    } finally {
      setBusy(false);
    }
  };

  const onGolden = async () => {
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

  const onKagglePlan = async () => {
    setBusy(true, "Đang kiểm tra Kaggle plan...");
    try {
      const plan = await fetchBillKagglePlan("pick_retrain");
      setKagglePlan(plan);
      setMessageIsError(!plan.kaggle_configured);
      setMessage(plan.kaggle_configured ? "Kaggle CLI sẵn sàng" : "Kaggle CLI chưa sẵn sàng");
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message);
    } finally {
      setBusy(false);
    }
  };

  const onSyncKaggle = async () => {
    if (!window.confirm("Đồng bộ weights từ kernel Kaggle đã COMPLETE? (Dùng khi server tắt giữa chừng retrain)")) {
      return;
    }
    setBusy(true, "Đang tải output Kaggle và deploy weights...");
    setMessage("");
    setMessageIsError(false);
    try {
      const res = await syncBillKaggle(false, exportJobType);
      if (!res.ok) {
        throw new Error(res.error || "Sync Kaggle thất bại");
      }
      if (res.job_id) {
        const jobs = await fetchBillKaggleJobs();
        setKaggleJobs(jobs);
        const synced = jobs.find((j) => (j.id || j.job_id) === res.job_id) || {
          id: res.job_id,
          job_id: res.job_id,
          status: "completed",
          f1_score: res.f1_score,
          source: "manual_sync",
        };
        setActiveJob(synced);
      }
      let reloadMsg = "";
      try {
        const r = await reloadAiModels("ocr");
        reloadMsg = r.ok ? " OCR đã reload." : " (reload OCR thất bại — bấm Tải lại model OCR).";
      } catch {
        reloadMsg = " (reload OCR thất bại — bấm Tải lại model OCR).";
      }
      setMessageIsError(false);
      setMessage(`${res.message || "Sync Kaggle OK"}${res.f1_score ? ` · F1 ${res.f1_score}` : ""}${reloadMsg}`);
      refreshOcrStatus();
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message || "Sync Kaggle thất bại");
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
            Upload, gán nhãn auto, duyệt và export cho PICK KIE trên Kaggle.
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
          <span className="bill-toolbar-label">Label</span>
          <div className="bill-toolbar-actions">
            <label className="btn btn-primary">
              Upload ảnh
              <input type="file" accept="image/*" hidden onChange={onUpload} disabled={loading} />
            </label>
            <button type="button" className="btn btn-primary" onClick={onAutoLabel} disabled={!active || loading || isArchivedSample}>
              Gán nhãn auto
            </button>
            <button type="button" className="btn btn-secondary" onClick={onSaveDraft} disabled={!active || loading || isArchivedSample}>
              Lưu nháp
            </button>
            <button
              type="button"
              className={`btn btn-secondary ${drawMode ? "active" : ""}`}
              onClick={() => setDrawMode((v) => !v)}
              disabled={!active || loading || isArchivedSample || !imageUrl}
              title="Kéo trên ảnh để vẽ bbox OTHER mới"
            >
              {drawMode ? "Hủy vẽ" : "Thêm bbox"}
            </button>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={onDeleteSelectedBox}
              disabled={!active || selectedIdx == null || loading}
              title="Xóa bbox đang chọn (Delete)"
            >
              Xóa nhãn
            </button>
            <button type="button" className="btn btn-secondary" onClick={onApprove} disabled={!active || loading || isArchivedSample}>
              Duyệt
            </button>
            <button type="button" className="btn btn-ghost danger" onClick={() => onDelete()} disabled={!active || loading}>
              Xóa
            </button>
          </div>
        </div>

        <div className="bill-toolbar-divider" aria-hidden="true" />

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
            <label className="bill-toggle">
              <input type="checkbox" checked={triggerKaggleOnExport} onChange={(e) => setTriggerKaggleOnExport(e.target.checked)} />
              <span>Auto Kaggle</span>
            </label>
            <select className="bill-select" value={exportJobType} onChange={(e) => setExportJobType(e.target.value)}>
              <option value="pick_retrain">PICK retrain</option>
            </select>
          </div>
        </div>

        <div className="bill-toolbar-divider" aria-hidden="true" />

        <div className="bill-toolbar-group">
          <span className="bill-toolbar-label">Kaggle</span>
          <div className="bill-toolbar-actions">
            <button type="button" className="btn btn-secondary" onClick={() => onKaggleTrigger("pick_retrain")} disabled={loading}>
              PICK retrain
            </button>
            <button type="button" className="btn btn-ghost" onClick={onGolden} disabled={loading}>
              Golden
            </button>
            <button type="button" className="btn btn-ghost" onClick={onKagglePlan} disabled={loading}>
              Plan
            </button>
            <button type="button" className="btn btn-ghost" onClick={onSyncKaggle} disabled={loading} title="Tải output kernel COMPLETE và deploy weights (khi server tắt giữa chừng)">
              Sync Kaggle
            </button>
          </div>
        </div>
      </div>

      {activeJob && <KaggleProgressPanel job={activeJob} />}

      <div className="grid-2 bill-retrain-grid">
        <section className="bill-surface bill-queue-panel">
          <div className="bill-surface-head">
            <div>
              <p className="bill-surface-eyebrow">Samples</p>
              <h2 className="bill-surface-title">Hàng đợi</h2>
            </div>
            <span className="bill-count-badge">{samples.length}</span>
          </div>
          {samples.length === 0 && (
            <div className="bill-empty-state">
              <p>Chưa có sample</p>
              <span className="muted">Upload ảnh hóa đơn để bắt đầu pipeline retrain.</span>
            </div>
          )}
          <ul className="sample-list">
            {samples.filter((s) => s.status !== "exported_archived").map((s) => (
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
                </button>
                <button type="button" className="btn-icon danger" title="Xóa khỏi hàng đợi" onClick={() => onDelete(s.id)} disabled={loading}>
                  ×
                </button>
              </li>
            ))}
          </ul>
        </section>

        <section className="bill-surface bill-canvas-panel">
          <div className="bill-surface-head">
            <div>
              <p className="bill-surface-eyebrow">Preview</p>
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
                  Đã export — ảnh gốc đã archive local. Nhãn vẫn xem được trong bảng bên dưới.
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
              {boxes.length > 0 && (
                <table className="data-table bill-label-table">
                  <thead>
                    <tr>
                      <th>Text</th>
                      <th>Entity</th>
                      <th>Bbox</th>
                    </tr>
                  </thead>
                  <tbody>
                    {boxes.map((b, idx) => (
                      <tr
                        key={idx}
                        className={selectedIdx === idx ? "row-active" : ""}
                        onClick={() => setSelectedIdx(idx)}
                      >
                        <td>
                          <input
                            value={b.text || ""}
                            onChange={(e) => updateBox(idx, "text", e.target.value)}
                            onClick={(e) => e.stopPropagation()}
                          />
                        </td>
                        <td>
                          <select
                            value={b.entity || "OTHER"}
                            onChange={(e) => updateBox(idx, "entity", e.target.value)}
                            onClick={(e) => e.stopPropagation()}
                          >
                            {ENTITIES.map((ent) => (
                              <option key={ent} value={ent}>{ent}</option>
                            ))}
                          </select>
                        </td>
                        <td className="mono">{b.x1},{b.y1},{b.x2},{b.y2}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </>
          )}
        </section>
      </div>

      <section className="bill-surface bill-jobs-panel">
        <div className="bill-surface-head">
          <div>
            <p className="bill-surface-eyebrow">History</p>
            <h2 className="bill-surface-title">Kaggle jobs</h2>
          </div>
          {kaggleJobs.length === 0 && (
            <button
              type="button"
              className="btn btn-secondary"
              style={{ padding: "6px 12px", fontSize: "12px", height: "auto" }}
              onClick={() => fetchBillKaggleJobs().then(setKaggleJobs).catch(() => {})}
            >
              Tải lịch sử
            </button>
          )}
        </div>
        {kaggleJobs.length > 0 ? (
          <ul className="kaggle-job-list">
            {kaggleJobs.slice(0, 8).map((j) => (
              <li key={j.id || j.job_id}>
                <button type="button" className="kaggle-job-btn" onClick={() => {
                  setActiveJob(j);
                  if (j && j.status && !["completed", "failed"].includes(j.status)) {
                    localStorage.setItem("active_kaggle_job_id", j.id || j.job_id);
                  } else {
                    localStorage.removeItem("active_kaggle_job_id");
                  }
                }}>
                  <code>{(j.id || j.job_id || "").slice(0, 8)}</code>
                  <span className={`job-status ${j.status}`}>{j.status}</span>
                  <span className="muted">{j.job_type}</span>
                  {j.f1_score && j.f1_score !== "N/A" && <span className="muted">F1 {j.f1_score}</span>}
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <p className="muted" style={{ padding: "12px 0 0 0", fontSize: "13px" }}>Bấm nút Tải lịch sử bên trên để truy xuất danh sách job từ Kaggle.</p>
        )}
      </section>

      {golden && <pre className="code-block">{JSON.stringify(golden, null, 2)}</pre>}
      {kagglePlan && <pre className="code-block">{JSON.stringify(kagglePlan, null, 2)}</pre>}
    </div>
  );
}
