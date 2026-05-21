"""OCR endpoints."""
from __future__ import annotations

from fastapi import APIRouter, File, Form, UploadFile

from app.schemas.ocr import OCRResponse, OCRTextRequest
from app.services.ocr_service import get_ocr_service


router = APIRouter(prefix="/ocr", tags=["ocr"])


MAX_BYTES = 8 * 1024 * 1024  # 8 MB


@router.post(
    "/image",
    response_model=OCRResponse,
    summary="OCR ảnh hóa đơn → text + amount + category",
)
async def ocr_image(
    file: UploadFile = File(..., description="Receipt image (jpg/png)"),
    locale: str | None = Form(default="vi"),
) -> OCRResponse:
    raw = await file.read()
    if len(raw) > MAX_BYTES:
        from app.core.exceptions import InvalidInputError

        raise InvalidInputError("Image is larger than 8 MB.")
    return get_ocr_service().infer_image(raw, file.filename)


@router.post(
    "/text",
    response_model=OCRResponse,
    summary="Parse ảnh đã được OCR bên ngoài (đưa thẳng text)",
)
def ocr_from_text(payload: OCRTextRequest) -> OCRResponse:
    return get_ocr_service().infer_text(payload.text)
