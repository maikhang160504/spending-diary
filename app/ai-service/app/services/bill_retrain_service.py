"""Bill OCR retrain: pre-label, export PICK, Kaggle plan, golden eval."""
from __future__ import annotations

import importlib
import os
import sys
import tempfile
import threading
from pathlib import Path
from typing import Any

from app.adapters import expense_ocr_nlu as adapter
from app.core.config import get_settings
from app.core.logging import get_logger


logger = get_logger(__name__)
_LOCK = threading.Lock()


def _ocr_paths() -> Path:
    settings = get_settings()
    root = Path(settings.expense_ocr_nlu_dir).resolve()
    for sub in (root, root / "OCR" / "src"):
        if str(sub) not in sys.path:
            sys.path.insert(0, str(sub))
    return root


def _verified_dir() -> Path:
    settings = get_settings()
    return Path(
        settings.verified_ocr_labels_dir
        or Path(settings.expense_ocr_nlu_dir) / "OCR" / "verified_ocr_labels"
    )


def ensure_ocr_loaded_for_prelabel() -> tuple[bool, str | None]:
    """Bill retrain always attempts real OCR (ignores USE_REAL_OCR gate on OCRService)."""
    if adapter.is_ocr_loaded():
        return True, None
    if not adapter.load_real_ocr_safe():
        err = adapter.get_ocr_error() or "Real OCR pipeline not loaded"
        hint = (
            "Set USE_REAL_OCR=true in ai-service/.env, verify OCR_WEIGHTS_PATH, "
            "then restart ai-service."
        )
        return False, f"{err}. {hint}"
    return True, None


def prelabel_image(image_bytes: bytes, filename: str | None = None) -> dict[str, Any]:
    """Auto-label from hybrid pipeline for WebAdmin review."""
    ok, err = ensure_ocr_loaded_for_prelabel()
    if not ok:
        return {
            "boxes": [],
            "kie_fields": {},
            "amount": None,
            "category": "Others",
            "kie_backend": "mock",
            "error": err,
            "ocr_loaded": False,
        }
    pipeline = adapter._OCR_PIPELINE
    suffix = Path(filename or "bill.jpg").suffix or ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(image_bytes)
        tmp_path = tmp.name
    try:
        image_rgb = pipeline._read_rgb(tmp_path)
        payload = pipeline.prelabel_for_admin(image_rgb)
        payload["backend"] = payload.get("auto_label_engine", "real-hybrid")
        payload["ocr_loaded"] = True
        kie_mod = importlib.import_module("receipt_ocr.pick_kie")
        pick_path = getattr(pipeline, "pick_kie_model", None)
        payload["pick_kie_status"] = kie_mod.pick_kie_weights_status(pick_path)
        if payload.get("kie_backend") != "pick":
            payload.setdefault("warnings", []).append(
                "Auto-label đang dùng heuristic — deploy model_best.pth (PICK) rồi bấm Tải lại model OCR."
            )
        return payload
    finally:
        Path(tmp_path).unlink(missing_ok=True)


def export_verified(samples: list[dict[str, Any]]) -> dict[str, Any]:
    _ocr_paths()
    builder = importlib.import_module("receipt_ocr.kaggle_dataset_builder")
    out_dir = _verified_dir()
    out_dir.mkdir(parents=True, exist_ok=True)
    return builder.build_training_pack(samples, out_dir)


def kaggle_retrain_plan(job_type: str) -> dict[str, Any]:
    _ocr_paths()
    kaggle_mod = importlib.import_module("receipt_ocr.kaggle_runner")
    return kaggle_mod.build_retrain_plan(job_type, _verified_dir())


def kaggle_username() -> str | None:
    _ocr_paths()
    kaggle_mod = importlib.import_module("receipt_ocr.kaggle_runner")
    return kaggle_mod.kaggle_username()


def trigger_kaggle_retrain(
    job_type: str,
    webhook_url: str | None = None,
    cloud_fallback_url: str | None = None,
    auto_after_export: bool = False,
) -> dict[str, Any]:
    _ocr_paths()
    kaggle_mod = importlib.import_module("receipt_ocr.kaggle_runner")
    verified = _verified_dir()
    if not verified.exists() or not any(verified.iterdir()):
        return {"ok": False, "error": "No verified labels exported yet"}
    wh = webhook_url or os.environ.get("BILL_RETRAIN_WEBHOOK_URL")
    cloud = cloud_fallback_url or os.environ.get("BILL_RETRAIN_ARTIFACT_URL")
    job = kaggle_mod.trigger_retrain_async(job_type, verified, wh, cloud)
    job["auto_after_export"] = auto_after_export
    return {"ok": True, **job}


def get_kaggle_job(job_id: str) -> dict[str, Any] | None:
    _ocr_paths()
    kaggle_mod = importlib.import_module("receipt_ocr.kaggle_runner")
    return kaggle_mod.get_job(job_id)


def list_kaggle_jobs(limit: int = 20) -> list[dict[str, Any]]:
    _ocr_paths()
    kaggle_mod = importlib.import_module("receipt_ocr.kaggle_runner")
    return kaggle_mod.list_jobs(limit)


def deploy_artifact(source: str, job_type: str, batch_id: str | None = None) -> dict[str, Any]:
    _ocr_paths()
    deploy_mod = importlib.import_module("receipt_ocr.artifact_deploy")
    return deploy_mod.deploy_from_source(source, job_type, batch_id)


def sync_kaggle_kernel(
    job_type: str = "pick_retrain",
    *,
    skip_download: bool = False,
    download_dir: str | None = None,
) -> dict[str, Any]:
    _ocr_paths()
    kaggle_mod = importlib.import_module("receipt_ocr.kaggle_runner")
    return kaggle_mod.sync_completed_kaggle_kernel(
        job_type,
        download_dir=download_dir,
        skip_download=skip_download,
    )


def kaggle_webhook(payload: dict[str, Any]) -> dict[str, Any]:
    """Record external webhook (e.g. manual Kaggle completion notify)."""
    _ocr_paths()
    kaggle_mod = importlib.import_module("receipt_ocr.kaggle_runner")
    job_id = payload.get("job_id")
    if job_id:
        kaggle_mod.update_job_from_webhook(job_id, payload)
    logger.info("Bill retrain webhook: %s", payload)
    return {"ok": True, "received": payload}


def run_golden_eval() -> dict[str, Any]:
    _ocr_paths()
    golden_mod = importlib.import_module("receipt_ocr.golden_eval")
    nlu_mod = importlib.import_module("receipt_ocr.receipt_nlu")
    kie_mod = importlib.import_module("receipt_ocr.pick_kie")
    import pandas as pd

    fixtures_path = Path(get_settings().expense_ocr_nlu_dir) / "OCR" / "tests" / "golden" / "fixtures.jsonl"
    fixtures = golden_mod.load_golden_fixtures(fixtures_path)
    results = []
    for fx in fixtures:
        lines = pd.DataFrame([{"line_text": ln, "bbox": [0, 0, 1, 1]} for ln in fx["lines"]])
        boxes = pd.DataFrame(fx["boxes"])
        kie = kie_mod.extract_kie_fields(fx["boxes"])
        pred = nlu_mod.extract_receipt_summary(lines, df_boxes=boxes, kie_fields=kie, split_mode=False)
        metrics = golden_mod.eval_summary_against_golden(pred, fx["expected"])
        results.append({"fixture_id": fx["fixture_id"], "metrics": metrics, "predicted": pred})
    return golden_mod.run_golden_eval(results)
