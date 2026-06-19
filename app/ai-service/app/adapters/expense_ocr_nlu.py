"""Adapter that wraps the original `expense-ocr-nlu` repo as a lazy-loaded backend.

We don't want the FastAPI service to crash on startup if those big artifacts
(PaddleOCR, VietOCR, PhoBERT, joblib bundles) are missing or fail to import.
Hence the adapter:

* keeps the heavy import inside `try/except`,
* exposes booleans `is_nlu_loaded()` / `is_ocr_loaded()`,
* falls back to the lightweight mock when the real pipeline cannot be loaded.
"""
from __future__ import annotations

import importlib
import sys
import tempfile
import threading
from pathlib import Path
from typing import Any

from app.core.config import get_settings
from app.core.logging import get_logger


logger = get_logger(__name__)
_LOCK = threading.Lock()

_NLU_BUNDLE: dict[str, Any] | None = None
_NLU_ERROR: str | None = None

_OCR_PIPELINE: Any = None
_OCR_ERROR: str | None = None


def _ensure_paths_on_sys_path() -> Path:
    """Add expense-ocr-nlu sub-paths to sys.path so its modules import correctly."""
    settings = get_settings()
    root = Path(settings.expense_ocr_nlu_dir).resolve()
    if not root.is_dir():
        raise FileNotFoundError(f"expense-ocr-nlu directory not found: {root}")
    candidates = [root, root / "OCR" / "src", root / "text_nlu"]
    for path in candidates:
        spath = str(path)
        if spath not in sys.path:
            sys.path.insert(0, spath)
    return root


def _load_nlu_bundle_unlocked() -> dict[str, Any]:
    """Heavy import; only call inside lock."""
    global _NLU_BUNDLE, _NLU_ERROR

    if _NLU_BUNDLE is not None:
        return _NLU_BUNDLE

    _ensure_paths_on_sys_path()

    try:
        env_module = importlib.import_module("src.config.env")
        settings_module = importlib.import_module("src.config.settings")
        models_module = importlib.import_module("src.nlu.models")
        ner_module = importlib.import_module("src.nlu.ner")
        pipeline_module = importlib.import_module("src.nlu.pipeline")
        llm_runner = importlib.import_module("src.nlg.llm_runner")
        context_meta = importlib.import_module("src.nlg.context_meta")
        json_sanitize = importlib.import_module("src.nlu.json_sanitize")
        action_executor = importlib.import_module("src.nlu.action_executor")
    except Exception as exc:  # pragma: no cover - depends on local env
        _NLU_ERROR = f"NLU import failed: {exc}"
        logger.warning(_NLU_ERROR)
        raise

    env_module.load_env_file(settings_module.ENV_PATH)

    bundle = {
        "intent": models_module.load_intent_model(),
        "category": models_module.load_category_model(),
        "action_type": models_module.load_action_type_model(),
        "record_type": models_module.load_record_type_model(),
        "sentiment": models_module.load_chitchat_sentiment_model(),
        "ner": ner_module.load_ner_model(settings_module.NER_MODEL_DIR),
        "prompts": llm_runner.load_prompts(settings_module.PROMPTS_PATH),
        "request_template": llm_runner.load_request_template(settings_module.REQUEST_TEMPLATE_PATH),
        "pipeline_module": pipeline_module,
        "llm_runner": llm_runner,
        "context_meta": context_meta,
        "json_sanitize": json_sanitize,
        "action_executor": action_executor,
    }
    _NLU_BUNDLE = bundle
    logger.info("Loaded real NLU bundle from expense-ocr-nlu.")

    # Auto-warmup/pre-load Hugging Face encoder models on startup to avoid lazy-loading on first request
    try:
        encoder_runtime = importlib.import_module("src.nlu.encoder_runtime")
        for key in ("intent", "category", "action_type", "record_type"):
            model_info = bundle.get(key)
            if isinstance(model_info, dict) and model_info.get("backend") == "encoder":
                inner_bundle = model_info.get("bundle")
                if isinstance(inner_bundle, dict) and "encoder_model_name" in inner_bundle:
                    model_name = inner_bundle["encoder_model_name"]
                    logger.info(f"Pre-loading/Warming up Hugging Face encoder model '{model_name}' for {key}...")
                    encoder_runtime._get_hf(model_name)
    except Exception as exc:
        logger.warning(f"Failed to pre-load Hugging Face encoder models during startup: {exc}")

    return bundle


def load_real_nlu_safe() -> bool:
    """Try to load NLU once; return True on success."""
    global _NLU_ERROR
    if _NLU_BUNDLE is not None:
        return True
    with _LOCK:
        if _NLU_BUNDLE is not None:
            return True
        try:
            _load_nlu_bundle_unlocked()
        except Exception as exc:  # noqa: BLE001
            _NLU_ERROR = str(exc)
            return False
    return True


def reload_nlu() -> bool:
    """Force reload the NLU model bundle from disk."""
    global _NLU_BUNDLE, _NLU_ERROR
    with _LOCK:
        _NLU_BUNDLE = None
        _NLU_ERROR = None
        try:
            _load_nlu_bundle_unlocked()
        except Exception as exc:  # noqa: BLE001
            _NLU_ERROR = str(exc)
            return False
    return True


def is_nlu_loaded() -> bool:
    return _NLU_BUNDLE is not None


def get_nlu_error() -> str | None:
    return _NLU_ERROR


def run_real_nlu(
    text: str,
    profile: dict[str, Any] | None = None,
    run_llm: bool = False,
    nlg_persona: str | None = None,
    emotion: str | None = None,
    user_id: str | None = None,
    user_corrections: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Call the real NLU pipeline + optional Gemini NLG layer."""
    bundle = _NLU_BUNDLE
    if bundle is None:
        raise RuntimeError("real NLU bundle not loaded")

    pipeline_module = bundle["pipeline_module"]
    llm_runner = bundle["llm_runner"]
    context_meta = bundle["context_meta"]
    json_sanitize_mod = bundle["json_sanitize"]
    action_executor = bundle["action_executor"]

    result = pipeline_module.run_nlu(
        text,
        bundle["intent"],
        bundle["category"],
        bundle["action_type"],
        bundle["record_type"],
        bundle["sentiment"],
        bundle["ner"],
        run_llm=run_llm,
        user_id=user_id,
        user_corrections=user_corrections,
    )

    if result.get("intent") == "Action":
        try:
            result["demo_execution_lines"] = action_executor.describe_action_execution(result)
        except Exception:  # noqa: BLE001
            result["demo_execution_lines"] = []

    record_type = result.get("record_type") if result.get("intent") == "Record" else None
    nlu_for_meta = {
        "intent": result.get("intent"),
        "text": text,
        "item": result.get("item"),
        "category": result.get("category"),
        "amount": result.get("amount_spent")
        if result.get("intent") == "Record"
        else result.get("action_param"),
        "record_type": record_type,
        "is_expense": record_type == "Expense" if record_type else None,
        "income_type": result.get("income_type") if result.get("intent") == "Record" else None,
        "action_type": result.get("action_type"),
        "value": result.get("action_param"),
    }
    context_metadata = context_meta.build_context_metadata(nlu_for_meta, profile or {})

    # Skip LLM call in the first pass for Action intents, since the backend will
    # enrich it with action_facts and make a second call to generate the final response.
    is_action_first_pass = (result.get("intent") == "Action") and (not profile or "action_facts" not in profile)

    if (run_llm or result.get("intent") == "Chitchat") and not is_action_first_pass:
        try:
            llm_runner.attach_nlg_and_llm(
                result,
                user_text=text,
                nlu_result=nlu_for_meta,
                context_metadata=context_metadata,
                prompts_config=bundle["prompts"],
                request_template=bundle["request_template"],
                nlg_persona=(nlg_persona or emotion or "hai_huoc"),
                run_llm=run_llm,
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("LLM enrichment failed: %s", exc)

    return json_sanitize_mod.json_sanitize(result)


# ---------------------------------------------------------------------------
# OCR
# ---------------------------------------------------------------------------


def _load_ocr_pipeline_unlocked() -> Any:
    global _OCR_PIPELINE, _OCR_ERROR
    if _OCR_PIPELINE is not None:
        return _OCR_PIPELINE

    root = _ensure_paths_on_sys_path()
    settings = get_settings()
    from receipt_ocr.model_paths import LAYOUTLMV3_MODEL_DIR, resolve_vietocr_weights_path

    weights_path = resolve_vietocr_weights_path(settings.ocr_weights_path or None)
    if not weights_path.is_file():
        _OCR_ERROR = (
            f"VietOCR weights missing at {weights_path}. "
            f"Expected: OCR/models/vietocr/vietocr_receipt.pth — "
            f"fix OCR_WEIGHTS_PATH in ai-service/.env and restart."
        )
        raise FileNotFoundError(_OCR_ERROR)

    try:
        pipeline_module = importlib.import_module("receipt_ocr.hybrid_pipeline")
    except Exception as exc:
        _OCR_ERROR = f"Hybrid OCR import failed: {exc}"
        raise

    import receipt_ocr.layoutlmv3_kie as kie_mod
    kie_mod.reset_kie_engine()

    layoutlm_dir = getattr(settings, "layoutlmv3_model_dir", None) or LAYOUTLMV3_MODEL_DIR
    _OCR_PIPELINE = pipeline_module.HybridReceiptOCRPipeline(
        vietocr_weights=weights_path,
        device=settings.device,
        layoutlmv3_dir=layoutlm_dir,
        paddle_use_gpu=(settings.device == "cuda"),
    ).load()
    kie_status = importlib.import_module("receipt_ocr.layoutlmv3_kie").layoutlmv3_weights_status(layoutlm_dir)
    logger.info(
        "Loaded hybrid OCR pipeline. LayoutLMv3 ready=%s dir=%s",
        kie_status.get("ready"),
        kie_status.get("model_dir"),
    )
    return _OCR_PIPELINE


def load_real_ocr_safe() -> bool:
    global _OCR_ERROR
    if _OCR_PIPELINE is not None:
        return True
    with _LOCK:
        if _OCR_PIPELINE is not None:
            return True
        try:
            _load_ocr_pipeline_unlocked()
        except Exception as exc:  # noqa: BLE001
            _OCR_ERROR = str(exc)
            return False
    return True


def reload_ocr() -> bool:
    """Force reload hybrid OCR pipeline (VietOCR + LayoutLMv3 KIE) from disk."""
    global _OCR_PIPELINE, _OCR_ERROR
    with _LOCK:
        _OCR_PIPELINE = None
        _OCR_ERROR = None
        try:
            _load_ocr_pipeline_unlocked()
        except Exception as exc:  # noqa: BLE001
            _OCR_ERROR = str(exc)
            return False
    return True


def is_ocr_loaded() -> bool:
    return _OCR_PIPELINE is not None


def get_ocr_error() -> str | None:
    return _OCR_ERROR


def run_real_ocr(image_bytes: bytes, filename_hint: str | None = None) -> dict[str, Any]:
    pipeline = _OCR_PIPELINE
    if pipeline is None:
        raise RuntimeError("real OCR pipeline not loaded")

    suffix = Path(filename_hint or "bill.jpg").suffix or ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(image_bytes)
        tmp_path = tmp.name
    try:
        image_rgb = pipeline._read_rgb(tmp_path)
        result = pipeline.process_image_rgb(image_rgb, split_mode=False)
        summary = result
        df_lines_data = result.get("lines", [])
        labeled_boxes = result.get("boxes", [])
        
        lines_data = []
        raw_text_list = []
        for item in df_lines_data:
            t = str(item.get("text", "")).strip()
            if t:
                raw_text_list.append(t)
                lines_data.append({
                    "text": t,
                    "bbox": item.get("bbox"),
                    "confidence": 0.90,
                })
        
        joined_text = "\n".join(raw_text_list)
    finally:
        try:
            Path(tmp_path).unlink(missing_ok=True)
        except OSError:
            pass

    return {
        "text": joined_text,
        "lines": lines_data,
        "boxes": labeled_boxes,
        "kie_fields": summary.get("kie_fields", {}),
        "kie_backend": summary.get("kie_backend", "heuristic"),
        "suggestion": {
            "amount": summary.get("amount"),
            "category": summary.get("category"),
            "confidence": 0.85 if summary.get("amount") else 0.3,
            "currency": summary.get("currency", "VND"),
        },
        "requires_confirmation": True,
        "backend": "real-hybrid",
        "warnings": summary.get("warnings", []),
        "items_count": summary.get("items_count", 0),
    }


def pre_import_real_backends() -> None:
    """Import heavy modules in the main thread to avoid thread/import lock deadlocks."""
    settings = get_settings()
    if settings.use_real_nlu:
        try:
            _ensure_paths_on_sys_path()
            importlib.import_module("src.config.env")
            importlib.import_module("src.config.settings")
            importlib.import_module("src.nlu.models")
            importlib.import_module("src.nlu.ner")
            importlib.import_module("src.nlu.pipeline")
            importlib.import_module("src.nlg.llm_runner")
            importlib.import_module("src.nlg.context_meta")
            importlib.import_module("src.nlu.json_sanitize")
            importlib.import_module("src.nlu.action_executor")
            logger.info("Main thread pre-import of real NLU modules completed.")
        except Exception as exc:
            logger.warning("Real NLU pre-import failed (will retry at load): %s", exc)

    if settings.use_real_ocr:
        try:
            _ensure_paths_on_sys_path()
            importlib.import_module("receipt_ocr.pipeline")
            logger.info("Main thread pre-import of real OCR modules completed.")
        except Exception as exc:
            logger.warning("Real OCR pre-import failed (will retry at load): %s", exc)

