import { useCallback, useEffect, useRef, useState, useMemo } from "react";
import BillLabelCanvas from "../components/BillLabelCanvas";
import BillHelpModal, { BillHelpTrigger } from "../components/BillHelpModal";
import {
  approveBillSample,
  approveAllBillSamples,
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
  getBillModelCandidate,
  promoteBillModel,
  rejectBillModel,
  rollbackBillModel,
  syncBillModelWorkspace,
  getBillTrainStatus,
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

function formatDuration(sec) {
  if (!sec || isNaN(sec)) return "-";
  const m = Math.floor(sec / 60);
  const h = Math.floor(m / 60);
  const remainingM = m % 60;
  if (h > 0) return `${h}h ${remainingM.toString().padStart(2, "0")}m`;
  return `${m}m`;
}

function calcMetricDiff(newVal, oldVal) {
  if (newVal === undefined || newVal === null) return null;
  const numNew = Number(newVal);
  if (isNaN(numNew)) return null;
  if (oldVal === undefined || oldVal === null) {
    return {
      formattedNew: `${numNew.toFixed(2)}%`,
      formattedOld: "-",
      diff: null,
    };
  }
  const numOld = Number(oldVal);
  if (isNaN(numOld)) {
    return {
      formattedNew: `${numNew.toFixed(2)}%`,
      formattedOld: "-",
      diff: null,
    };
  }
  const diff = numNew - numOld;
  return {
    formattedNew: `${numNew.toFixed(2)}%`,
    formattedOld: `${numOld.toFixed(2)}%`,
    diff: diff,
    diffSign: diff > 0 ? `+${diff.toFixed(2)}%` : diff < 0 ? `${diff.toFixed(2)}%` : "0.00%",
    isPositive: diff > 0,
    isNegative: diff < 0,
    arrow: diff > 0 ? "▲" : diff < 0 ? "▼" : "•",
  };
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
  const [modalTrainStatus, setModalTrainStatus] = useState({ isTraining: false });
  const [activeCategory, setActiveCategory] = useState("Others");
  const [prelabelJobs, setPrelabelJobs] = useState([]);
  const [page, setPage] = useState(1);
  const [filterStatus, setFilterStatus] = useState("all");
  const [modelStaging, setModelStaging] = useState({ current: null, candidate: null });

  const handledJobsRef = useRef(new Set());
  const toastTimerRef = useRef(null);
  const prelabelTimersRef = useRef({});
  const isTriggeringRef = useRef(0);

  const upsertPrelabelJob = useCallback((id, patch) => {
    setPrelabelJobs((prev) => prev.map((j) => (j.id === id ? { ...j, ...patch } : j)));
  }, []);

  useEffect(() => {
    const fetchTrainStatus = async () => {
      try {
        const res = await getBillTrainStatus();
        if (Date.now() < isTriggeringRef.current && !res?.isTraining) {
          // Container is still in cold start, retain optimistic training state
          return;
        }
        if (res?.isTraining) {
          isTriggeringRef.current = 0;
        }
        setModalTrainStatus(res || { isTraining: false });
        if (!res?.isTraining) {
          const candidateData = await getBillModelCandidate();
          setModelStaging(candidateData);
        }
      } catch (err) {
        console.error("Lỗi lấy trạng thái train:", err);
      }
    };

    fetchTrainStatus();
    const interval = setInterval(() => {
      fetchTrainStatus();
    }, 3000);

    return () => clearInterval(interval);
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
    const fetchCandidate = async () => {
      try {
        const data = await getBillModelCandidate();
        setModelStaging(data);
      } catch (err) {
        console.error(err);
      }
    }
    fetchCandidate();
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
    const files = Array.from(e.target.files || []);
    if (!files.length) return;
    setMessage("");
    setMessageIsError(false);
    
    for (const file of files) {
      const jobId = enqueuePrelabelJob(file.name);
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
      }
    }
    e.target.value = "";
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

  const handleApproveAll = async () => {
    const pw = window.prompt("Nhập mật khẩu quản trị để duyệt tất cả hóa đơn pending:", "");
    if (!pw) return;
    setBusy(true, "Đang duyệt tất cả...");
    try {
      const res = await approveAllBillSamples(pw);
      showToast("success", `Đã duyệt thành công ${res.count} hóa đơn.`);
      await loadSamples();
    } catch (err) {
      showToast("error", "Lỗi duyệt tất cả: " + err.message);
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
    if (modelStaging?.candidate) {
      setMessageIsError(true);
      setMessage("Đang có mô hình Candidate chờ duyệt áp dụng. Vui lòng Triển khai ngay hoặc Từ chối trước khi bắt đầu đợt huấn luyện mới.");
      return;
    }
    const pw = window.prompt("Bạn có chắc chắn muốn khởi chạy huấn luyện mô hình LayoutLMv3 trên đám mây Modal (sử dụng GPU) không?\n\nTác vụ này sẽ chạy nền và có thể tốn tài nguyên đám mây.\n\nNhập mật khẩu quản trị hệ thống (PASSWORD_RETRAIN) để xác nhận:");
    if (!pw) return;
    setBusy(true, "Đang khởi chạy training LayoutLMv3 trên Modal Cloud...");
    try {
      const res = await triggerBillModal(30, 0.00002, pw);
      setMessageIsError(!res.ok);
      setMessage(
        res.ok
          ? `Modal training đã khởi động thành công — Job: ${res.job_id || "running"}`
          : res.error || "Không thể khởi chạy training trên Modal"
      );
      if (res.ok) {
        isTriggeringRef.current = Date.now() + 15000;
        setModalTrainStatus({
          isTraining: true,
          stage: "starting",
          progress_percent: 1,
          message: "Đang khởi động Modal GPU container...",
        });
      }
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

  const onPromoteModel = async () => {
    const pw = window.prompt("Bạn có chắc chắn muốn triển khai (promote) candidate model thành model_best (production) không?\n\nThao tác này sẽ thay thế model hiện tại.\n\nNhập mật khẩu quản trị hệ thống (PASSWORD_RETRAIN) để xác nhận:");
    if (!pw) return;
    setBusy(true, "Đang triển khai model lên Production...");
    try {
      const res = await promoteBillModel(pw);
      setMessageIsError(!res.ok);
      const msg = res.message || (res.ok ? "Đã triển khai model thành công." : (res.error || "Lỗi khi triển khai model"));
      setMessage(msg);
      showToast(res.ok ? "success" : "error", msg);
      window.alert(msg);
      // Refresh
      const data = await getBillModelCandidate();
      setModelStaging(data);
    } catch (err) {
      setMessageIsError(true);
      const errMsg = err.message || "Lỗi khi triển khai model";
      setMessage(errMsg);
      showToast("error", errMsg);
      window.alert(errMsg);
    } finally {
      setBusy(false);
    }
  };

  const onRejectModel = async () => {
    const pw = window.prompt("Bạn có chắc chắn muốn TỪ CHỐI (reject) candidate model không?\n\nThao tác này sẽ xóa candidate hiện tại.\n\nNhập mật khẩu quản trị hệ thống (PASSWORD_RETRAIN) để xác nhận:");
    if (!pw) return;
    setBusy(true, "Đang từ chối và xóa mô hình candidate...");
    try {
      const res = await rejectBillModel(pw);
      setMessageIsError(!res.ok);
      const msg = res.message || (res.ok ? "Đã từ chối mô hình candidate thành công." : (res.error || "Lỗi khi từ chối model"));
      setMessage(msg);
      showToast(res.ok ? "success" : "error", msg);
      window.alert(msg);
      // Refresh
      const data = await getBillModelCandidate();
      setModelStaging(data);
    } catch (err) {
      setMessageIsError(true);
      const errMsg = err.message || "Lỗi khi từ chối model";
      setMessage(errMsg);
      showToast("error", errMsg);
      window.alert(errMsg);
    } finally {
      setBusy(false);
    }
  };

  const onRollbackModel = async () => {
    const pw = window.prompt("Bạn có chắc chắn muốn khôi phục (rollback) lại model trước đó không?\n\nThao tác này sẽ ghi đè model production hiện tại bằng bản lưu trước đó.\n\nNhập mật khẩu quản trị hệ thống (PASSWORD_RETRAIN) để xác nhận:");
    if (!pw) return;
    setBusy(true, "Đang khôi phục model phiên bản trước...");
    try {
      const res = await rollbackBillModel(pw);
      setMessageIsError(!res.ok);
      const msg = res.message || (res.ok ? "Đã khôi phục model thành công." : (res.error || "Lỗi khi khôi phục model"));
      setMessage(msg);
      showToast(res.ok ? "success" : "error", msg);
      window.alert(msg);
      const data = await getBillModelCandidate();
      setModelStaging(data);
    } catch (err) {
      setMessageIsError(true);
      const errMsg = err.message || "Lỗi khi khôi phục model";
      setMessage(errMsg);
      showToast("error", errMsg);
      window.alert(errMsg);
    } finally {
      setBusy(false);
    }
  };

  const onSyncWorkspace = async () => {
    const pw = window.prompt("Bạn có chắc chắn muốn đồng bộ model mới nhất từ đám mây (Modal) về máy tính (Workspace) không?\n\nQuá trình này có thể tốn vài phút để tải file 500MB.\n\nNhập mật khẩu quản trị hệ thống (PASSWORD_RETRAIN) để xác nhận:");
    if (!pw) return;
    setBusy(true, "Đang tải model từ Cloud về máy. Vui lòng không đóng trang...");
    try {
      const res = await syncBillModelWorkspace(pw);
      setMessageIsError(!res.ok);
      setMessage(res.message || "Đã đồng bộ model về workspace thành công.");
    } catch (err) {
      setMessageIsError(true);
      setMessage(err.message || "Lỗi khi đồng bộ model");
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
            {!modalTrainStatus?.isTraining && (
              <button 
                type="button" 
                className="btn btn-secondary" 
                onClick={onModalTrigger} 
                disabled={loading || Boolean(modelStaging?.candidate)}
                title={modelStaging?.candidate ? "Đang có mô hình Candidate chờ duyệt. Vui lòng Triển khai ngay hoặc Từ chối trước khi train mới." : "Khởi chạy training trên Modal GPU"}
                style={modelStaging?.candidate ? { opacity: 0.5, cursor: 'not-allowed' } : {}}
              >
                Train LayoutLMv3
              </button>
            )}
            {modalTrainStatus?.isTraining && (
              <div style={{ marginLeft: 16, display: 'flex', flexDirection: 'column', minWidth: 240 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', marginBottom: 6, color: 'var(--accent-amber-hover)' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <span className="status-dot pulse" style={{ background: "var(--accent-amber)", boxShadow: "0 0 8px var(--accent-amber)", width: "6px", height: "6px", borderRadius: "50%" }}></span>
                    {modalTrainStatus.message || "Đang huấn luyện LayoutLMv3..."}
                  </span>
                  <span style={{ fontWeight: 600 }}>{modalTrainStatus.progress_percent || 0}%</span>
                </div>
                <div style={{ width: "100%", height: "4px", background: "var(--bg-obsidian-800)", borderRadius: "2px", overflow: "hidden" }}>
                  <div style={{ width: `${modalTrainStatus.progress_percent || 0}%`, height: '100%', background: 'var(--accent-emerald)', transition: 'width 0.5s ease' }}></div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* SECTION: Quản lý & Đối chiếu Mô hình LayoutLMv3 */}
      {(() => {
        const currentMetrics = modelStaging.current?.metrics;
        const candidateMetrics = modelStaging.candidate?.metrics;
        const f1Diff = calcMetricDiff(candidateMetrics?.f1, currentMetrics?.f1);
        const precisionDiff = calcMetricDiff(candidateMetrics?.precision, currentMetrics?.precision);
        const recallDiff = calcMetricDiff(candidateMetrics?.recall, currentMetrics?.recall);

        return (
          <div className="bill-surface" style={{ marginBottom: 24, padding: "20px 24px", background: "var(--bg-obsidian-900)", border: "1px solid var(--border-color)", borderRadius: 16 }}>
            <div className="bill-surface-head" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12, paddingBottom: 16, borderBottom: "1px solid var(--border-color)" }}>
              <div>
                <h2 className="bill-surface-title" style={{ fontSize: 16, fontWeight: 700, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span>🧠</span> Quản lý Mô hình LayoutLMv3 (Staging & Đối chiếu)
                </h2>
                <span style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 2, display: 'block' }}>
                  Kiểm tra và so sánh trực quan chỉ số chất lượng giữa mô hình Production và mô hình Candidate mới huấn luyện trước khi duyệt áp dụng.
                </span>
              </div>
              <button 
                type="button" 
                className="btn btn-secondary btn-sm"
                onClick={async () => {
                  try {
                    const data = await getBillModelCandidate();
                    setModelStaging(data);
                  } catch (e) {
                    console.error(e);
                  }
                }}
                disabled={loading}
                style={{ fontSize: 12, display: 'flex', alignItems: 'center', gap: 6, borderRadius: 8 }}
              >
                ↻ Làm mới trạng thái
              </button>
            </div>

            {modelStaging?.candidate && (
              <div style={{
                background: "rgba(168, 85, 247, 0.1)",
                border: "1px solid rgba(168, 85, 247, 0.4)",
                borderRadius: "10px",
                padding: "12px 18px",
                marginTop: "16px",
                display: "flex",
                alignItems: "center",
                gap: "10px",
                color: "#e9d5ff",
                fontSize: "13px",
                fontWeight: "500",
                boxShadow: "0 0 15px rgba(168, 85, 247, 0.1)"
              }}>
                <span style={{ fontSize: "18px" }}>⚠️</span>
                <span>
                  <strong>Đang có mô hình Candidate chờ duyệt áp dụng.</strong> Tính năng huấn luyện mới tạm thời bị khóa. Vui lòng <strong>Triển khai ngay</strong> hoặc <strong>Từ chối</strong> trước khi bắt đầu đợt huấn luyện tiếp theo.
                </span>
              </div>
            )}

            <div className="grid-2" style={{ gap: 20, marginTop: 20 }}>
              {/* PRODUCTION MODEL CARD */}
              <div style={{
                display: 'flex',
                flexDirection: 'column',
                padding: 20,
                border: '1px solid var(--border-color)',
                borderRadius: 14,
                background: 'var(--bg-obsidian-950)',
                position: 'relative'
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                      <span style={{ fontSize: 18 }}>🛡️</span>
                      <h3 style={{ fontSize: 15, fontWeight: 700, color: 'var(--text-primary)', margin: 0 }}>Mô hình Hiện tại (Production)</h3>
                    </div>
                    <span style={{ fontSize: 11, color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
                      {modelStaging.current ? `Phiên bản: Run #${modelStaging.current.run_index || 1}` : "Chưa có bản log"}
                    </span>
                  </div>
                  <span style={{
                    background: 'var(--accent-emerald-glow)',
                    color: 'var(--accent-emerald-hover)',
                    border: '1px solid rgba(16, 185, 129, 0.3)',
                    padding: '4px 10px',
                    borderRadius: 6,
                    fontSize: 11,
                    fontWeight: 700,
                    letterSpacing: '0.04em'
                  }}>
                    ● ĐANG HOẠT ĐỘNG
                  </span>
                </div>

                <div style={{ flex: 1 }}>
                  {modelStaging.current ? (
                    <div>
                      <div style={{ display: 'flex', gap: 16, fontSize: 12, color: 'var(--text-secondary)', marginBottom: 16, padding: '10px 12px', background: 'var(--bg-obsidian-900)', borderRadius: 8, border: '1px solid var(--border-color)', flexWrap: 'wrap' }}>
                        <span>📅 <strong>Huấn luyện:</strong> {new Date(modelStaging.current.trained_at).toLocaleString('vi-VN')}</span>
                        <span>⏱️ <strong>Thời lượng:</strong> {formatDuration(modelStaging.current.duration_sec)}</span>
                      </div>

                      {/* 3 Metric Tiles */}
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginBottom: 16 }}>
                        <div style={{ padding: '12px 10px', background: 'rgba(16, 185, 129, 0.05)', border: '1px solid rgba(16, 185, 129, 0.2)', borderRadius: 10, textAlign: 'center' }}>
                          <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--accent-emerald-hover)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>F1-Score</div>
                          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--text-primary)', fontFamily: 'var(--font-mono)' }}>
                            {currentMetrics?.f1 != null ? `${Number(currentMetrics.f1).toFixed(2)}%` : "-"}
                          </div>
                          <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 2 }}>Độ đo tổng thể</div>
                        </div>

                        <div style={{ padding: '12px 10px', background: 'var(--bg-obsidian-900)', border: '1px solid var(--border-color)', borderRadius: 10, textAlign: 'center' }}>
                          <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>Precision</div>
                          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--text-primary)', fontFamily: 'var(--font-mono)' }}>
                            {currentMetrics?.precision != null ? `${Number(currentMetrics.precision).toFixed(2)}%` : "-"}
                          </div>
                          <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 2 }}>Độ chuẩn xác</div>
                        </div>

                        <div style={{ padding: '12px 10px', background: 'var(--bg-obsidian-900)', border: '1px solid var(--border-color)', borderRadius: 10, textAlign: 'center' }}>
                          <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>Recall</div>
                          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--text-primary)', fontFamily: 'var(--font-mono)' }}>
                            {currentMetrics?.recall != null ? `${Number(currentMetrics.recall).toFixed(2)}%` : "-"}
                          </div>
                          <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 2 }}>Độ bao phủ</div>
                        </div>
                      </div>
                    </div>
                  ) : (
                    <div style={{ padding: 24, textAlign: 'center', color: 'var(--text-muted)', fontSize: 13 }}>
                      Chưa có thông tin mô hình production được ghi nhận trong lịch sử.
                    </div>
                  )}
                </div>

                <div style={{ display: 'flex', gap: 10, borderTop: '1px solid var(--border-color)', paddingTop: 14, marginTop: 'auto' }}>
                  <button type="button" className="btn btn-secondary btn-sm" onClick={onSyncWorkspace} disabled={loading} title="Tải model mới nhất từ Cloud về thư mục máy tính" style={{ flex: 1, justifyContent: 'center', borderRadius: 8 }}>
                    ⬇ Đồng bộ về máy
                  </button>
                  <button type="button" className="btn btn-secondary btn-sm" onClick={onRollbackModel} disabled={loading} title="Khôi phục lại model trước đó" style={{ flex: 1, justifyContent: 'center', borderRadius: 8 }}>
                    ↺ Khôi phục bản cũ
                  </button>
                </div>
              </div>

              {/* CANDIDATE MODEL CARD (WITH DIFF EVALUATION) */}
              <div style={{
                display: 'flex',
                flexDirection: 'column',
                padding: 20,
                border: modelStaging.candidate ? '1px solid #a855f7' : '1px dashed var(--border-color)',
                borderRadius: 14,
                background: modelStaging.candidate ? 'rgba(168, 85, 247, 0.03)' : 'var(--bg-obsidian-950)',
                boxShadow: modelStaging.candidate ? '0 0 20px rgba(168, 85, 247, 0.12)' : 'none',
                position: 'relative'
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                      <span style={{ fontSize: 18 }}>✨</span>
                      <h3 style={{ fontSize: 15, fontWeight: 700, color: modelStaging.candidate ? '#c084fc' : 'var(--text-primary)', margin: 0 }}>Candidate Model (Mới huấn luyện)</h3>
                    </div>
                    <span style={{ fontSize: 11, color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
                      {modelStaging.candidate ? `Phiên bản: Run #${modelStaging.candidate.run_index}` : "Chưa có ứng viên chờ duyệt"}
                    </span>
                  </div>
                  {modelStaging.candidate ? (
                    <span style={{
                      background: 'rgba(168, 85, 247, 0.15)',
                      color: '#c084fc',
                      border: '1px solid rgba(168, 85, 247, 0.3)',
                      padding: '4px 10px',
                      borderRadius: 6,
                      fontSize: 11,
                      fontWeight: 700,
                      letterSpacing: '0.04em'
                    }}>
                      ⚡ CHỜ DUYỆT ÁP DỤNG
                    </span>
                  ) : (
                    <span style={{
                      background: 'rgba(255, 255, 255, 0.04)',
                      color: 'var(--text-muted)',
                      border: '1px solid var(--border-color)',
                      padding: '4px 10px',
                      borderRadius: 6,
                      fontSize: 11,
                      fontWeight: 600
                    }}>
                      TRỐNG
                    </span>
                  )}
                </div>

                <div style={{ flex: 1 }}>
                  {modelStaging.candidate ? (
                    <div>
                      <div style={{ display: 'flex', gap: 16, fontSize: 12, color: 'var(--text-secondary)', marginBottom: 16, padding: '10px 12px', background: 'var(--bg-obsidian-900)', borderRadius: 8, border: '1px solid var(--border-color)', flexWrap: 'wrap' }}>
                        <span>📅 <strong>Huấn luyện:</strong> {new Date(modelStaging.candidate.trained_at).toLocaleString('vi-VN')}</span>
                        <span>⏱️ <strong>Thời lượng:</strong> {formatDuration(modelStaging.candidate.duration_sec)}</span>
                      </div>

                      {/* 3 Metric Tiles with Delta Badges */}
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginBottom: 14 }}>
                        {/* F1 Tile */}
                        <div style={{ padding: '12px 10px', background: 'rgba(168, 85, 247, 0.06)', border: '1px solid rgba(168, 85, 247, 0.25)', borderRadius: 10, textAlign: 'center' }}>
                          <div style={{ fontSize: 10, fontWeight: 700, color: '#c084fc', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>F1-Score</div>
                          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--text-primary)', fontFamily: 'var(--font-mono)' }}>
                            {f1Diff?.formattedNew || "-"}
                          </div>
                          <div style={{ marginTop: 4 }}>
                            {f1Diff?.diff !== null && f1Diff?.diff !== undefined ? (
                              <span style={{
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: 2,
                                fontSize: 11,
                                fontWeight: 700,
                                color: f1Diff.isPositive ? 'var(--accent-emerald-hover)' : f1Diff.isNegative ? 'var(--accent-rose)' : 'var(--text-muted)',
                                background: f1Diff.isPositive ? 'var(--accent-emerald-glow)' : f1Diff.isNegative ? 'var(--accent-rose-glow)' : 'rgba(255,255,255,0.05)',
                                padding: '1px 6px',
                                borderRadius: 4
                              }}>
                                {f1Diff.arrow} {f1Diff.diffSign}
                              </span>
                            ) : (
                              <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>Mới</span>
                            )}
                          </div>
                          <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 4 }}>
                            Cũ: {f1Diff?.formattedOld || "-"}
                          </div>
                        </div>

                        {/* Precision Tile */}
                        <div style={{ padding: '12px 10px', background: 'var(--bg-obsidian-900)', border: '1px solid var(--border-color)', borderRadius: 10, textAlign: 'center' }}>
                          <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>Precision</div>
                          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--text-primary)', fontFamily: 'var(--font-mono)' }}>
                            {precisionDiff?.formattedNew || "-"}
                          </div>
                          <div style={{ marginTop: 4 }}>
                            {precisionDiff?.diff !== null && precisionDiff?.diff !== undefined ? (
                              <span style={{
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: 2,
                                fontSize: 11,
                                fontWeight: 700,
                                color: precisionDiff.isPositive ? 'var(--accent-emerald-hover)' : precisionDiff.isNegative ? 'var(--accent-rose)' : 'var(--text-muted)',
                                background: precisionDiff.isPositive ? 'var(--accent-emerald-glow)' : precisionDiff.isNegative ? 'var(--accent-rose-glow)' : 'rgba(255,255,255,0.05)',
                                padding: '1px 6px',
                                borderRadius: 4
                              }}>
                                {precisionDiff.arrow} {precisionDiff.diffSign}
                              </span>
                            ) : (
                              <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>Mới</span>
                            )}
                          </div>
                          <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 4 }}>
                            Cũ: {precisionDiff?.formattedOld || "-"}
                          </div>
                        </div>

                        {/* Recall Tile */}
                        <div style={{ padding: '12px 10px', background: 'var(--bg-obsidian-900)', border: '1px solid var(--border-color)', borderRadius: 10, textAlign: 'center' }}>
                          <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>Recall</div>
                          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--text-primary)', fontFamily: 'var(--font-mono)' }}>
                            {recallDiff?.formattedNew || "-"}
                          </div>
                          <div style={{ marginTop: 4 }}>
                            {recallDiff?.diff !== null && recallDiff?.diff !== undefined ? (
                              <span style={{
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: 2,
                                fontSize: 11,
                                fontWeight: 700,
                                color: recallDiff.isPositive ? 'var(--accent-emerald-hover)' : recallDiff.isNegative ? 'var(--accent-rose)' : 'var(--text-muted)',
                                background: recallDiff.isPositive ? 'var(--accent-emerald-glow)' : recallDiff.isNegative ? 'var(--accent-rose-glow)' : 'rgba(255,255,255,0.05)',
                                padding: '1px 6px',
                                borderRadius: 4
                              }}>
                                {recallDiff.arrow} {recallDiff.diffSign}
                              </span>
                            ) : (
                              <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>Mới</span>
                            )}
                          </div>
                          <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 4 }}>
                            Cũ: {recallDiff?.formattedOld || "-"}
                          </div>
                        </div>
                      </div>

                      {/* Comparative Verdict Banner */}
                      {f1Diff && f1Diff.diff > 0 ? (
                        <div style={{ background: 'rgba(16, 185, 129, 0.08)', border: '1px solid rgba(16, 185, 129, 0.25)', borderRadius: 8, padding: '10px 14px', marginBottom: 16, fontSize: 12, color: 'var(--accent-emerald-hover)', display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span style={{ fontSize: 15 }}>🚀</span>
                          <span><strong>Khuyến nghị triển khai:</strong> Mô hình mới có F1-Score tăng <strong>{f1Diff.diffSign}</strong> so với bản hiện tại, cải thiện độ chính xác bóc tách hóa đơn.</span>
                        </div>
                      ) : f1Diff && f1Diff.diff < 0 ? (
                        <div style={{ background: 'rgba(239, 68, 68, 0.08)', border: '1px solid rgba(239, 68, 68, 0.25)', borderRadius: 8, padding: '10px 14px', marginBottom: 16, fontSize: 12, color: 'var(--accent-rose-hover)', display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span style={{ fontSize: 15 }}>⚠️</span>
                          <span><strong>Cần cân nhắc:</strong> F1-Score giảm <strong>{f1Diff.diffSign}</strong> so với bản Production. Đề nghị kiểm tra kỹ chất lượng trước khi duyệt áp dụng.</span>
                        </div>
                      ) : (
                        <div style={{ background: 'rgba(2, 132, 199, 0.08)', border: '1px solid rgba(2, 132, 199, 0.25)', borderRadius: 8, padding: '10px 14px', marginBottom: 16, fontSize: 12, color: 'var(--accent-blue-hover)', display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span style={{ fontSize: 15 }}>⚖️</span>
                          <span><strong>Đánh giá:</strong> Chất lượng mô hình tương đương phiên bản Production hiện tại (chênh lệch F1: 0.00%).</span>
                        </div>
                      )}
                    </div>
                  ) : (
                    <div style={{ padding: '30px 16px', textAlign: 'center' }}>
                      <div style={{ fontSize: 32, marginBottom: 8, opacity: 0.7 }}>📦</div>
                      <p style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 6 }}>
                        Không có candidate model nào đang chờ duyệt.
                      </p>
                      <p style={{ fontSize: 12, color: 'var(--text-muted)', lineHeight: 1.5, maxWidth: 360, margin: '0 auto 16px' }}>
                        Sau khi nhấn <strong>Train LayoutLMv3</strong> và hoàn tất trên Cloud GPU, kết quả đối chiếu chỉ số F1, Precision, Recall sẽ xuất hiện tại đây.
                      </p>
                    </div>
                  )}
                </div>

                <div style={{ display: 'flex', gap: 10, borderTop: '1px solid rgba(255, 255, 255, 0.08)', paddingTop: 14, marginTop: 'auto' }}>
                  <button 
                    type="button" 
                    className="btn btn-primary btn-sm" 
                    onClick={onPromoteModel} 
                    disabled={loading || !modelStaging.candidate} 
                    style={{
                      flex: 1,
                      justifyContent: 'center',
                      borderRadius: 8,
                      fontWeight: 700,
                      background: modelStaging.candidate ? 'var(--accent-emerald)' : 'var(--bg-obsidian-800)',
                      borderColor: modelStaging.candidate ? 'var(--accent-emerald)' : 'var(--border-color)',
                      color: modelStaging.candidate ? 'var(--bg-obsidian-950)' : 'var(--text-muted)',
                      boxShadow: modelStaging.candidate ? '0 0 12px var(--accent-emerald-glow)' : 'none',
                      cursor: (loading || !modelStaging.candidate) ? 'not-allowed' : 'pointer'
                    }}
                  >
                    🚀 Triển khai ngay
                  </button>
                  <button 
                    type="button" 
                    className="btn btn-danger btn-sm" 
                    onClick={onRejectModel} 
                    disabled={loading || !modelStaging.candidate} 
                    style={{
                      flex: 1,
                      justifyContent: 'center',
                      borderRadius: 8,
                      background: modelStaging.candidate ? 'var(--accent-rose)' : 'var(--bg-obsidian-800)',
                      borderColor: modelStaging.candidate ? 'var(--accent-rose)' : 'var(--border-color)',
                      color: modelStaging.candidate ? '#fff' : 'var(--text-muted)',
                      cursor: (loading || !modelStaging.candidate) ? 'not-allowed' : 'pointer'
                    }}
                  >
                    ✕ Từ chối
                  </button>
                </div>
              </div>
            </div>
          </div>
        );
      })()}

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
              )
            })}
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
          <div className="bill-surface-head" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <h2 className="bill-surface-title" style={{ margin: 0 }}>Canvas nhãn</h2>
              {active && (
                <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, background: 'rgba(255, 255, 255, 0.04)', padding: '2px 8px', borderRadius: 8, border: '1px solid var(--border-color)' }}>
                  <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>Category:</span>
                  <select
                    className="bill-select"
                    value={activeCategory}
                    onChange={(e) => setActiveCategory(e.target.value)}
                    disabled={!active || isArchivedSample}
                    style={{ padding: '2px 6px', fontSize: 12, height: 26, borderRadius: 6, border: 'none', background: 'transparent', color: 'var(--text-primary)', fontWeight: 600, cursor: 'pointer' }}
                  >
                    {["Food", "Essentials", "Social", "Transport", "Shopping", "Housing", "Health", "Beauty", "Education", "Entertainment", "Investment", "Others"].map((cat) => (
                      <option key={cat} value={cat} style={{ background: 'var(--bg-obsidian-900)', color: 'var(--text-primary)' }}>{cat}</option>
                    ))}
                  </select>
                </div>
              )}
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
          <div className="bill-surface-head" style={{ marginBottom: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h2 className="bill-surface-title">Công cụ gán nhãn</h2>
            </div>
            <button 
              type="button" 
              className="btn btn-secondary btn-sm" 
              onClick={handleApproveAll} 
              disabled={loading || pendingCount === 0} 
              style={{ background: 'var(--accent-emerald)', color: '#fff', border: 'none', borderRadius: '6px', fontWeight: 500, padding: '4px 12px' }}
            >
              Duyệt tất cả {pendingCount > 0 ? `(${pendingCount})` : ''}
            </button>
          </div>
          <div className="bill-box-tools" style={{ display: "flex", flexWrap: "wrap", gap: 8, paddingBottom: 16, borderBottom: "1px solid var(--border-color)", marginBottom: 16, alignItems: 'center' }}>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, width: '100%', marginBottom: 4 }}>
              <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-secondary)' }}>Category:</span>
              <select
                className="bill-select"
                value={activeCategory}
                onChange={(e) => setActiveCategory(e.target.value)}
                disabled={!active || isArchivedSample}
                style={{ flex: 1, height: 32, fontSize: 12, borderRadius: 6, background: 'var(--bg-obsidian-950)', border: '1px solid var(--border-color)' }}
              >
                {["Food", "Essentials", "Social", "Transport", "Shopping", "Housing", "Health", "Beauty", "Education", "Entertainment", "Investment", "Others"].map((cat) => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
              </select>
            </div>
            <label className="btn btn-primary btn-sm">
              Upload ảnh
              <input type="file" accept="image/*" multiple hidden onChange={onUpload} />
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
