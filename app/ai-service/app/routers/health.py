"""Health & readiness endpoints."""
from __future__ import annotations

from fastapi import APIRouter

from app import __version__
from app.adapters import expense_ocr_nlu as adapter
from app.core.config import get_settings
from app.schemas.common import HealthResponse


router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse, summary="Liveness probe")
def health() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        version=__version__,
        environment=settings.environment,
        nlu_real=settings.use_real_nlu,
        ocr_real=settings.use_real_ocr,
        nlu_loaded=adapter.is_nlu_loaded(),
        ocr_loaded=adapter.is_ocr_loaded(),
    )
