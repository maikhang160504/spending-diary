"""High-level NLU service. Picks real pipeline or mock based on settings + availability."""
from __future__ import annotations

import time
from typing import Any

from app.adapters import expense_ocr_nlu as adapter
from app.adapters.mock_pipeline import run_nlu_mock
from app.core.config import get_settings
from app.core.exceptions import NLUProcessingError
from app.core.logging import get_logger
from app.schemas.nlu import NLURequest, NLUResponse


logger = get_logger(__name__)

_VALID_ASSETS = {
    "Alert", "Angry", "Approved", "Celebrate", "Chill", "Cooking", "Cool",
    "Determined", "Error", "Excited", "Gigle", "Happy", "Hello", "Loading",
    "Love", "Proud", "Relax", "Sad", "Sleepy", "Sassy", "Shopping", "Travel",
    "Sorry", "Success", "Taunting", "Thankful", "Thinking", "Working", "Worried",
}

_STATUS_TO_ASSET: dict[str, str] = {
    "vui": "Happy",
    "buon": "Sad",
    "canh_bao": "Thinking",
    "trung_lap": "Chill",
}


def _resolve_mascot_mood(
    gemini_emotion: str | None,
    status: str | None,
    intent: str | None,
    personality_emotion: str | None,
) -> str:
    """Map gemini emotion field (PascalCase) → Flutter MiMo asset name.

    Priority: gemini_emotion (already normalized PascalCase) > status fallback > intent default.
    """
    if gemini_emotion and gemini_emotion in _VALID_ASSETS:
        return gemini_emotion
    if status and status in _STATUS_TO_ASSET:
        return _STATUS_TO_ASSET[status]
    if intent == "Record":
        return "Success"
    if intent == "Action":
        return "Thinking"
    return "Chill"


class NLUService:
    def __init__(self) -> None:
        self._tried_load = False
        self._real_available = False

    def try_load(self) -> bool:
        if self._tried_load:
            return self._real_available
        self._tried_load = True
        if not get_settings().use_real_nlu:
            logger.info("USE_REAL_NLU=false → mock pipeline only.")
            return False
        self._real_available = adapter.load_real_nlu_safe()
        if not self._real_available:
            logger.warning("Real NLU not loadable: %s", adapter.get_nlu_error())
        return self._real_available

    def infer(self, request: NLURequest) -> NLUResponse:
        start = time.perf_counter()
        try:
            payload = self._infer_inner(request)
        except Exception as exc:
            raise NLUProcessingError(f"NLU inference failed: {exc}") from exc
        payload["latency_ms"] = int((time.perf_counter() - start) * 1000)
        return NLUResponse.model_validate(payload)

    def _infer_inner(self, request: NLURequest) -> dict[str, Any]:
        text = request.text
        if self.try_load():
            try:
                profile = request.profile.model_dump(exclude_none=True) if request.profile else {}
                raw = adapter.run_real_nlu(
                    text,
                    profile=profile,
                    run_llm=request.run_llm,
                    emotion=request.emotion,
                )
                return self._normalize_real(raw, text)
            except Exception as exc:  # noqa: BLE001
                logger.warning("Real NLU failed at runtime, falling back to mock: %s", exc)
        return self._normalize_mock(text)

    def _normalize_real(self, raw: dict[str, Any], text: str) -> dict[str, Any]:
        intent = raw.get("intent") or "Unknown"
        record_type = raw.get("record_type")
        amount = raw.get("amount_spent") if intent == "Record" else raw.get("action_param")

        multi_records_raw = raw.get("multi_records") or []
        multi_records = [
            {
                "text": m.get("text", ""),
                "amount": m.get("amount"),
                "category": m.get("category"),
                "record_type": m.get("record_type"),
            }
            for m in multi_records_raw
        ]

        gemini_json = raw.get("gemini_json")
        api_status = (gemini_json or {}).get("status") if isinstance(gemini_json, dict) else None
        gemini_emotion = (gemini_json or {}).get("emotion") if isinstance(gemini_json, dict) else None
        personality_emotion = raw.get("emotion")
        mascot_mood = _resolve_mascot_mood(gemini_emotion, api_status, intent, personality_emotion)

        return {
            "intent": intent,
            "intent_confidence": raw.get("intent_confidence"),
            "text": text,
            "item": raw.get("item"),
            "category": raw.get("category"),
            "amount": amount,
            "record_type": record_type,
            "is_expense": record_type == "Expense" if intent == "Record" else None,
            "income_type": raw.get("income_type"),
            "action_type": raw.get("action_type"),
            "action_details": raw.get("action_details"),
            "multi_records": multi_records,
            "multi_record_task": bool(raw.get("multi_record_task")),
            "sentiment": raw.get("sentiment"),
            "nlg_prompt": raw.get("nlg_prompt"),
            "gemini_json": gemini_json,
            "mascot_mood": mascot_mood,
            "backend": "real",
        }

    def _normalize_mock(self, text: str) -> dict[str, Any]:
        result = run_nlu_mock(text)
        multi = []
        if result.multi_amounts:
            multi = [
                {"text": text, "amount": amt, "category": result.category, "record_type": result.record_type}
                for amt in result.multi_amounts
            ]
        mascot_mood = _resolve_mascot_mood(None, None, result.intent, None)
        return {
            "intent": result.intent,
            "intent_confidence": result.intent_confidence,
            "text": text,
            "item": None,
            "category": result.category,
            "amount": result.amount,
            "record_type": result.record_type,
            "is_expense": result.record_type == "Expense" if result.record_type else None,
            "income_type": None,
            "action_type": None,
            "action_details": None,
            "multi_records": multi,
            "multi_record_task": len(multi) >= 1,
            "sentiment": None,
            "nlg_prompt": None,
            "gemini_json": None,
            "mascot_mood": mascot_mood,
            "backend": "mock",
        }


_singleton: NLUService | None = None


def get_nlu_service() -> NLUService:
    global _singleton
    if _singleton is None:
        _singleton = NLUService()
    return _singleton
