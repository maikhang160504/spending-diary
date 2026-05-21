# Expense AI Service

Microservice nhận dạng chi tiêu — **NLU văn bản tiếng Việt** + **OCR hóa đơn** — đóng gói từ repo nghiên cứu `expense-ocr-nlu/` thành một FastAPI service có schema rõ ràng, Swagger sẵn, mock fallback và logging JSON.

```
text  ──► /api/v1/nlu/infer ──► { intent, amount, category, ... }
image ──► /api/v1/ocr/image ──► { lines, suggestion }
text  ──► /api/v1/expense/from-text ──► { extracted, nlu }
image ──► /api/v1/expense/from-bill ──► { extracted, ocr, requires_confirmation }
```

## Cấu trúc

```
app/ai-service/
├── app/
│   ├── core/         # config, logging, exceptions
│   ├── schemas/      # Pydantic request/response
│   ├── adapters/
│   │   ├── mock_pipeline.py        # regex + keyword fallback (luôn chạy được)
│   │   └── expense_ocr_nlu.py      # lazy-load pipeline gốc (PaddleOCR + PhoBERT)
│   ├── services/     # nlu_service, ocr_service, expense_service
│   ├── routers/      # /nlu, /ocr, /expense, /health
│   ├── middleware.py # request logger + optional X-API-Key
│   └── main.py       # FastAPI factory
├── tests/test_smoke.py
├── requirements.txt          # service-only
├── requirements-real.txt     # + heavy ML deps (PaddleOCR, torch, transformers)
├── Dockerfile
└── .env.example
```

## Backend tự chọn

Mỗi service (NLU / OCR) tự động chọn backend:

| Env | `false` (default) | `true` |
|------|-----------------|--------|
| `USE_REAL_NLU` | Mock regex + keyword (~0 ms) | Tải `text_nlu/models/*.joblib`, PhoBERT, NER spaCy |
| `USE_REAL_OCR` | Trả ảnh mock receipt | PaddleOCR + VietOCR thật (cần `vietocr_receipt.pth`) |

Nếu bật `true` nhưng tải lỗi (thiếu weights, thiếu lib), service **không crash** — log warning + fallback sang mock. Trường `backend` trong response cho biết kết quả đến từ đâu.

## Chạy local (không cần ML deps)

```powershell
cd app/ai-service
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Mở http://127.0.0.1:8000/docs để xem Swagger UI.

## Bật pipeline thật

```powershell
# Sử dụng lại .venv của expense-ocr-nlu để tránh cài lại torch / paddleocr
cd ..\..\expense-ocr-nlu
.venv\Scripts\Activate.ps1
cd ..\app\ai-service
pip install fastapi uvicorn[standard] pydantic pydantic-settings python-multipart python-dotenv

$env:USE_REAL_NLU = "true"
$env:USE_REAL_OCR = "true"
$env:EXPENSE_OCR_NLU_DIR = "..\..\expense-ocr-nlu"
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

## Ví dụ request

### `POST /api/v1/nlu/infer`

```json
{
  "text": "ăn phở 45k",
  "profile": { "budget_total": 5000000, "budget_remain": 1200000 },
  "run_llm": false
}
```

```json
{
  "intent": "Record",
  "intent_confidence": 0.92,
  "text": "ăn phở 45k",
  "category": "Food",
  "amount": 45000,
  "record_type": "Expense",
  "is_expense": true,
  "multi_records": [],
  "backend": "real",
  "latency_ms": 38
}
```

### `POST /api/v1/expense/from-bill`

`multipart/form-data` với field `file` là ảnh hóa đơn (jpg/png, ≤ 8 MB).

```json
{
  "success": true,
  "flow": "bill",
  "extracted": {
    "amount": 152000,
    "category": "Food",
    "confidence": 0.85,
    "record_type": "Expense"
  },
  "requires_confirmation": true,
  "ocr": { "suggestion": { "amount": 152000, "category": "Food" }, "backend": "real" }
}
```

## Test

```powershell
pip install pytest
pytest tests -q
```

## Tích hợp backend Node.js

Backend chính (`app/backend`) gọi service qua biến `AI_SERVICE_URL` (mặc định `http://localhost:8000`). Khi `API_KEY` được set ở AI service, backend phải gửi header `X-API-Key`.

Xem file `app/backend/src/services/aiClient.js` để biết các endpoint được wrap thành hàm JS.
