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

def run_retraining(nlu_dir: Path):
    global TRAINING_ACTIVE
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
            text=True
        )
        
        # Force reload in memory
        get_nlu_service().reload()
    except Exception as e:
        print(f"[NLU training] Error: {e}", flush=True)
    finally:
        TRAINING_ACTIVE = False


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


@router.post("/train", summary="Huấn luyện lại toàn bộ mô hình (Chạy ngầm)")
def train(background_tasks: BackgroundTasks):
    global TRAINING_ACTIVE
    if TRAINING_ACTIVE:
        return {"status": "error", "message": "Training is already in progress."}
    
    TRAINING_ACTIVE = True
    settings = get_settings()
    nlu_dir = Path(settings.expense_ocr_nlu_dir).resolve()
    
    background_tasks.add_task(run_retraining, nlu_dir)
    return {"status": "started", "message": "NLU model retraining triggered in background."}


@router.get("/train/status", summary="Lấy trạng thái huấn luyện")
def train_status():
    return {"training_active": TRAINING_ACTIVE}
