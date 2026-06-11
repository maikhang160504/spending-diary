"""Combined "expense extraction" service: text → expense, image → expense."""
from __future__ import annotations

import re
import time
import unicodedata
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


MERCHANT_RULES = [
    ("WinMart", re.compile(r"winmart|vinmart|win\s*\+", re.I)),
    ("Grab", re.compile(r"grab", re.I)),
    ("Circle K", re.compile(r"circle\s*k", re.I)),
    ("Phúc Long", re.compile(r"phuc\s*long|phúc\s*long", re.I)),
    ("Highlands Coffee", re.compile(r"highlands", re.I)),
    ("Starbucks", re.compile(r"starbucks", re.I)),
    ("Lotte Mart", re.compile(r"lotte", re.I)),
    ("Aeon Mall", re.compile(r"aeon", re.I)),
    ("KFC", re.compile(r"kfc", re.I)),
    ("McDonald's", re.compile(r"mcdonald", re.I)),
    ("Jollibee", re.compile(r"jollibee", re.I)),
    ("Phano Pharmacy", re.compile(r"phano", re.I)),
    ("Nhà Thuốc An Khang", re.compile(r"an\s*khang", re.I)),
    ("Pharmacity", re.compile(r"pharmacity", re.I)),
    ("Co.opmart", re.compile(r"co\.?op\s*smart|coop\s*smart|coop\s*mart|co\.?op\s*mart", re.I)),
    ("Bách Hóa Xanh", re.compile(r"bach\s*hoa\s*xanh|bách\s*hóa\s*xanh", re.I)),
    ("Gong Cha", re.compile(r"gong\s*cha", re.I)),
    ("The Coffee House", re.compile(r"the\s*coffee\s*house", re.I)),
    ("Mixue", re.compile(r"mixue", re.I)),
    ("Katinat", re.compile(r"katinat", re.I)),
    ("Phúc Lộc Thọ", re.compile(r"phuc\s*loc\s*tho|phúc\s*lộc\s*thọ", re.I)),
    ("GS25", re.compile(r"gs25", re.I)),
    ("FamilyMart", re.compile(r"family\s*mart", re.I)),
    ("7-Eleven", re.compile(r"7\s*-\s*eleven|7\s*eleven", re.I)),
    ("MiniStop", re.compile(r"ministop|mini\s*stop", re.I)),
]


def _normalize_str(text: str) -> str:
    text = unicodedata.normalize("NFD", text or "")
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    return text.lower()


def extract_merchant(lines: list[str]) -> str | None:
    header_lines = lines[:6]
    # 1. So khớp từ điển thương hiệu
    for line in header_lines:
        line_norm = _normalize_str(line)
        for merchant, pat in MERCHANT_RULES:
            if pat.search(line) or pat.search(line_norm):
                return merchant

    # 2. Dự phòng: lấy dòng đầu tiên hợp lệ không chứa các từ khóa hóa đơn/ngày tháng/mst
    for line in header_lines:
        clean = line.strip()
        if not clean:
            continue
        if re.search(r"hoa don|hóa đơn|phiếu|phieu|mst|tel|phone|ngày|ngay|date|thu ngân|thu ngan|địa chỉ|dia chi|address", clean, re.I):
            continue
        if clean.isdigit() or len(clean) < 3 or len(clean) > 50:
            continue
        num_digits = sum(1 for c in clean if c.isdigit())
        if num_digits > len(clean) * 0.3:
            continue
        return clean
    return None


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
        
        # Trích xuất tên merchant từ lines nhận dạng được
        lines_txt = [line.text for line in ocr_response.lines]
        merchant = extract_merchant(lines_txt or [ocr_response.text])

        extracted = ExpenseExtracted(
            amount=suggestion.amount,
            category=suggestion.category,
            note=merchant,
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
