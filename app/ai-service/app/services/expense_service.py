"""Combined "expense extraction" service: text → expense, image → expense."""
from __future__ import annotations

import time
from typing import Any

from app.core.logging import get_logger
from app.schemas.expense import (
    ExpenseExtracted,
    ExpenseFromImageResponse,
    ExpenseFromTextRequest,
    ExpenseFromTextResponse,
)
from app.schemas.nlu import NLURequest, NLUResponse
from app.services.nlu_service import get_nlu_service
from app.services.ocr_service import get_ocr_service


logger = get_logger(__name__)


class ExpenseService:
    def from_text(self, request: ExpenseFromTextRequest) -> ExpenseFromTextResponse:
        start = time.perf_counter()
        nlu_request = NLURequest(
            text=request.text,
            profile=None if not request.profile else request.profile,  # type: ignore[arg-type]
            user_id=request.user_id,
            run_llm=request.run_llm,
        )
        nlu_response: NLUResponse = get_nlu_service().infer(nlu_request)

        confidence = nlu_response.intent_confidence
        amount = nlu_response.amount
        category = nlu_response.category
        record_type = nlu_response.record_type or ("Expense" if nlu_response.intent == "Record" else None)

        extracted = ExpenseExtracted(
            amount=amount,
            category=category,
            note=request.text,
            record_type=record_type,
            confidence=confidence,
        )
        requires_category_selection = nlu_response.intent == "Record" and (
            not category or category == "Others"
        )
        return ExpenseFromTextResponse(
            extracted=extracted,
            requires_category_selection=requires_category_selection,
            nlu=nlu_response,
            latency_ms=int((time.perf_counter() - start) * 1000),
        )

    def from_image(self, image_bytes: bytes, filename: str | None) -> ExpenseFromImageResponse:
        start = time.perf_counter()
        ocr_response = get_ocr_service().infer_image(image_bytes, filename)
        suggestion = ocr_response.suggestion
        extracted = ExpenseExtracted(
            amount=suggestion.amount,
            category=suggestion.category,
            note=None,
            record_type="Expense" if suggestion.amount else None,
            confidence=suggestion.confidence,
        )
        return ExpenseFromImageResponse(
            extracted=extracted,
            requires_confirmation=True,
            ocr=ocr_response,
            latency_ms=int((time.perf_counter() - start) * 1000),
        )


_singleton: ExpenseService | None = None


def get_expense_service() -> ExpenseService:
    global _singleton
    if _singleton is None:
        _singleton = ExpenseService()
    return _singleton
