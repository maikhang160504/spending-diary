"""NLU endpoints."""
from __future__ import annotations

from fastapi import APIRouter, BackgroundTasks, HTTPException

from app.schemas.nlu import NLURequest, NLUResponse
from app.services.nlu_service import get_nlu_service
from app.core.config import get_settings
import json
import sys
import subprocess
from pathlib import Path

router = APIRouter(prefix="/nlu", tags=["nlu"])

TRAINING_ACTIVE = False

import datetime
import time


def _count_csv_rows(csv_path: Path) -> int:
    """Count non-empty rows in a CSV file (excluding header)."""
    if not csv_path.exists():
        return 0
    try:
        with open(csv_path, "r", encoding="utf-8") as f:
            return max(0, sum(1 for line in f if line.strip()) - 1)
    except Exception:
        return 0


def append_nlu_history(nlu_dir: Path, status: str, duration_sec: float, error_msg: str | None = None):
    """Append a training run record using **real** metrics from retrain_all_metrics.json."""
    history_file = nlu_dir / "text_nlu" / "models" / "nlu_training_history.json"
    metrics_file = nlu_dir / "text_nlu" / "models" / "retrain_all_metrics.json"

    # Count training rows from each dataset
    datasets_dir = nlu_dir / "text_nlu" / "datasets"
    training_rows = {
        "intent_record": _count_csv_rows(datasets_dir / "intent_record.csv"),
        "intent_action": _count_csv_rows(datasets_dir / "intent_action.csv"),
        "intent_chitchat": _count_csv_rows(datasets_dir / "intent_chitchat.csv"),
    }
    total_rows = sum(training_rows.values())

    # Load existing history
    history = []
    if history_file.exists():
        try:
            with open(history_file, "r", encoding="utf-8") as f:
                history = json.load(f)
        except Exception:
            pass

    run_idx = len(history) + 1

    # Read REAL metrics from retrain_all_metrics.json (produced by retrain_all.py)
    metrics = None
    f1_score = None
    if status == "success" and metrics_file.exists():
        try:
            with open(metrics_file, "r", encoding="utf-8") as f:
                metrics = json.load(f)
            # Use category weighted_f1 as the headline F1 (largest model)
            cat = metrics.get("category", {})
            f1_score = f"{cat.get('weighted_f1', cat.get('accuracy', 0))}".rstrip("0").rstrip(".")
        except Exception as e:
            print(f"[NLU history] Failed to read metrics file: {e}", flush=True)

    record = {
        "run_index": run_idx,
        "trained_at": datetime.datetime.utcnow().isoformat() + "Z",
        "duration_sec": round(duration_sec, 2),
        "status": status,
        "training_rows": total_rows,
        "training_rows_detail": training_rows,
        "error": error_msg,
        "f1_score": f1_score,
        "metrics": metrics,
    }
    history.append(record)
    history = history[-100:]

    try:
        history_file.parent.mkdir(parents=True, exist_ok=True)
        with open(history_file, "w", encoding="utf-8") as f:
            json.dump(history, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"Failed to write NLU history: {e}", flush=True)


def run_retraining(nlu_dir: Path):
    global TRAINING_ACTIVE
    start_time = time.time()
    error_msg = None
    status = "failed"
    try:
        # Find python path in NLU project venv (Windows: .venv/Scripts/python.exe, Unix: .venv/bin/python)
        venv_python = nlu_dir / ".venv" / "Scripts" / "python.exe"
        if not venv_python.exists():
            venv_python = nlu_dir / ".venv" / "Scripts" / "python"
        if not venv_python.exists():
            venv_python = nlu_dir / ".venv" / "bin" / "python"
        
        python_exec = str(venv_python) if venv_python.exists() else sys.executable
        script_path = nlu_dir / "text_nlu" / "train" / "retrain_all.py"
        
        # Set environment variable to make it train fast or normal
        # We can set max steps to a smaller value if we want quick validation, or just normal.
        # Spacy train can take a minute. Let's run it.
        subprocess.run(
            [python_exec, str(script_path)],
            cwd=str(nlu_dir),
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace"
        )
        
        # Force reload in memory
        get_nlu_service().reload()
        status = "success"
    except Exception as e:
        error_msg = str(e)
        print(f"[NLU training] Error: {e}", flush=True)
    finally:
        TRAINING_ACTIVE = False
        duration = time.time() - start_time
        append_nlu_history(nlu_dir, status, duration, error_msg)


@router.post(
    "/infer",
    response_model=NLUResponse,
    summary="Phân tích câu chi tiêu / hành động (text → intent + amount + category)",
)
def infer(payload: NLURequest) -> NLUResponse:
    """Run the Vietnamese expense NLU pipeline on free text.

    - Trả về `intent` ∈ {Record, Action, Chitchat}
    - Khi `intent == Record`: kèm `amount`, `category`, `record_type`.
    - `backend = "real"` nếu pipeline gốc tải được, ngược lại `backend = "mock"`.
    """
    return get_nlu_service().infer(payload)


@router.get("/prompts", summary="Lấy file cấu hình prompts.json")
def get_prompts():
    settings = get_settings()
    prompts_path = Path(settings.expense_ocr_nlu_dir) / "src" / "prompts" / "prompts.json"
    if not prompts_path.exists():
        raise HTTPException(status_code=404, detail=f"prompts.json not found at {prompts_path}")
    try:
        with open(prompts_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to read prompts: {e}")


@router.post("/prompts", summary="Lưu file cấu hình prompts.json và reload")
def save_prompts(payload: dict):
    settings = get_settings()
    prompts_path = Path(settings.expense_ocr_nlu_dir) / "src" / "prompts" / "prompts.json"
    try:
        prompts_path.parent.mkdir(parents=True, exist_ok=True)
        with open(prompts_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        
        # Force reload bundle to pick up new prompts configuration
        get_nlu_service().reload()
        return {"success": True, "message": "Prompts saved and NLU hot-reloaded."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to write prompts: {e}")


from pydantic import BaseModel, Field

class NluTrainRequest(BaseModel):
    target: str = Field(default="local", description="Target of retraining: 'local' (CPU) or 'kaggle' (GPU)")


@router.post("/train", summary="Huấn luyện lại toàn bộ mô hình (Chạy ngầm)")
def train(payload: NluTrainRequest = NluTrainRequest(), background_tasks: BackgroundTasks = None):
    global TRAINING_ACTIVE
    settings = get_settings()
    nlu_dir = Path(settings.expense_ocr_nlu_dir).resolve()

    if payload.target == "kaggle":
        from app.services import kaggle_nlu_service
        from receipt_ocr import kaggle_runner
        if not kaggle_runner.kaggle_available():
            raise HTTPException(
                status_code=400,
                detail="Kaggle API or credentials (.kaggle/kaggle.json) not configured on the server."
            )
        
        res = kaggle_nlu_service.trigger_kaggle_nlu_retrain(nlu_dir)
        if "error" in res:
            raise HTTPException(status_code=500, detail=res["error"])
        
        return {
            "status": "started",
            "target": "kaggle",
            "job_id": res.get("job_id"),
            "message": "NLU model retraining triggered on Kaggle in background."
        }

    # Local training flow
    if TRAINING_ACTIVE:
        return {"status": "error", "message": "Training is already in progress locally."}
    
    TRAINING_ACTIVE = True
    if background_tasks:
        background_tasks.add_task(run_retraining, nlu_dir)
    else:
        # Fallback if background_tasks is not injected
        import threading
        threading.Thread(target=run_retraining, args=(nlu_dir,), daemon=True).start()

    return {"status": "started", "target": "local", "message": "NLU model retraining triggered locally in background."}


@router.get("/train/kaggle/jobs", summary="Lấy danh sách các jobs train NLU trên Kaggle")
def get_kaggle_nlu_jobs(limit: int = 20):
    settings = get_settings()
    nlu_root = Path(settings.expense_ocr_nlu_dir).resolve()
    jobs_file = nlu_root / "text_nlu" / "models" / "nlu_kaggle_jobs.json"
    from app.services import kaggle_nlu_service
    return kaggle_nlu_service.list_jobs(jobs_file, limit)


@router.get("/train/kaggle/jobs/{job_id}", summary="Lấy trạng thái chi tiết của job train NLU trên Kaggle")
def get_kaggle_nlu_job(job_id: str):
    settings = get_settings()
    nlu_root = Path(settings.expense_ocr_nlu_dir).resolve()
    jobs_file = nlu_root / "text_nlu" / "models" / "nlu_kaggle_jobs.json"
    from app.services import kaggle_nlu_service
    job = kaggle_nlu_service.get_job(jobs_file, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job



@router.get("/train/status", summary="Lấy trạng thái huấn luyện")
def train_status():
    return {"training_active": TRAINING_ACTIVE}


@router.get("/internal/status", summary="Lấy thông tin mô hình NLU hiện tại")
def internal_status():
    service = get_nlu_service()
    loaded = service.try_load()
    return {
        "loaded": loaded,
        "backend": "real" if loaded else "mock"
    }


@router.get("/train/history", summary="Lấy lịch sử retrain NLU")
def train_history():
    settings = get_settings()
    nlu_dir = Path(settings.expense_ocr_nlu_dir).resolve()
    history_file = nlu_dir / "text_nlu" / "models" / "nlu_training_history.json"
    if not history_file.exists():
        return []
    try:
        with open(history_file, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to read NLU training history: {e}")

