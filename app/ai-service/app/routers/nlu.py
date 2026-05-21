"""NLU endpoints."""
from __future__ import annotations

from fastapi import APIRouter

from app.schemas.nlu import NLURequest, NLUResponse
from app.services.nlu_service import get_nlu_service


router = APIRouter(prefix="/nlu", tags=["nlu"])


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
