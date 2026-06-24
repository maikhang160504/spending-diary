# MoneyStory — Fullstack Expense Management with AI

Hệ thống quản lý chi tiêu cá nhân + AI nhận dạng (NLU text tiếng Việt + **hybrid OCR hóa đơn**: PaddleOCR + VietOCR + LayoutLMv3 KIE). Gồm mobile app, **WebAdmin** (retrain & curation), backend orchestrator và AI microservice.

```
                          +----------------------+
                          |  Mobile + WebAdmin   |
                          +----------+-----------+
                                     | HTTPS (JWT)
                                     v
+-----------+    +-------------------+--------------------+   HTTP   +-----------------+
| Cloudflare|<---|         Backend (Node.js/Express)       |--------->|  AI Service     |
|  R2       |    |  /api/v1/*  +  /api/admin/*            |          |  (FastAPI)      |
+-----------+    +-------------------+--------------------+          |  NLU + Hybrid   |
                                     | pg                            |  OCR pipeline   |
                                     v                               +--------+--------+
                          +----------+----------+                              |
                          | PostgreSQL /        |                              v
                          | CockroachDB         |              +-------------------------+
                          +---------------------+              | expense-ocr-nlu         |
                                                                 | text_nlu/models/        |
                                                                 | OCR/models/vietocr/     |
                                                                 | OCR/models/layoutlmv3_kie/
                                                                 +-------------------------+
```

> **Hướng dẫn chạy đầy đủ:** xem [`../setup.md`](../setup.md) (env, terminal, smoke test, Kaggle, FCM).

## Cấu trúc thư mục

```
app/
├── ai-service/          FastAPI — NLU + hybrid OCR + bill-retrain API
├── backend/             Node.js REST + admin routes + R2 + bill queue
├── database/            schema.sql, migrations
├── frontend/
│   ├── mobile/          Flutter
│   └── web-admin/       React + Vite (Dashboard, Bill Retrain, NLU Ops)
└── docker-compose.yml
```

## Cách chạy nhanh

### Option A — docker-compose

```powershell
cd app
copy backend\.env.example backend\.env
docker compose up -d --build
docker compose exec backend npm run migrate
docker compose exec backend npm run seed
```

- Backend → http://localhost:4000/docs  
- AI service → http://localhost:8000/docs  

### Option B — dev local (khuyến nghị)

Dùng **venv của `expense-ocr-nlu`** cho AI service (PaddleOCR/VietOCR/transformers). Chi tiết từng bước: **[`setup.md`](../setup.md)**.

| # | Service | URL |
|---|---------|-----|
| 1 | AI Service | http://localhost:8000/docs |
| 2 | Backend | http://localhost:4000/docs |
| 3 | WebAdmin | http://localhost:5173 |
| 4 | Flutter | emulator / thiết bị |

```powershell
# Tóm tắt — xem setup.md để biết env đầy đủ
cd app\ai-service
# ... Activate expense-ocr-nlu\.venv, USE_REAL_NLU=true, USE_REAL_OCR=true
uvicorn app.main:app --host 0.0.0.0 --port 8000

cd app\backend && npm run dev
cd app\frontend\web-admin && npm run dev
```

## WebAdmin

| Trang | Path | Mô tả |
|-------|------|-------|
| Dashboard | `/` | Fusion metrics + **Retrain Readiness** |
| Bill OCR Retrain | `/bill-retrain` | Auto-label → duyệt bbox → export → Kaggle |
| NLU Ops | `/nlu-ops` | User corrections → curation → retrain category |
| User Inspector | `/user-inspector` | Corrections theo user |

**Retrain ngưỡng (mặc định):** Category ≥ 500 corrections · OCR/KIE ≥ 2.000 bill approved WebAdmin. Chi tiết: [`RETRAIN.md`](../RETRAIN.md).

## Endpoint Backend (`/api/v1`)

| Group | Path | Mô tả |
|-------|------|-------|
| Auth | `/api/v1/auth/*` | register, login, refresh, logout, me |
| Wallets / Transactions / Budgets / Stats | `/api/v1/...` | CRUD + dashboard |
| AI | `/api/v1/ai/nlu`, `expense/from-text`, `expense/from-bill`, `corrections` | Proxy + lưu correction |
| Upload | `/api/v1/upload/*` | R2 presign / direct |

## Endpoint Admin (`/api/admin`)

| Path | Mô tả |
|------|-------|
| `GET /analytics` | Fusion convergence |
| `GET /retrain-readiness` | Ngưỡng sẵn sàng retrain (Dashboard) |
| `GET/POST /bill-retrain/*` | Label queue, export, Kaggle trigger/jobs |
| `GET/POST /nlu/*` | Aggregations, curate → `intent_record.csv` |
| `GET /user-inspector/:id` | User corrections |

## Endpoint AI service (port 8000)

| Method | Path | Mô tả |
|--------|------|-------|
| GET | `/health` | `nlu_loaded`, `ocr_loaded` (real-hybrid / mock) |
| POST | `/api/v1/nlu/infer` | NLU text |
| POST | `/api/v1/ocr/image` | Hybrid OCR ảnh |
| POST | `/api/v1/expense/from-bill` | Bill → amount + category + items |
| POST | `/api/v1/bill-retrain/*` | Prelabel, export, Kaggle, golden eval |

## Pipeline OCR (production)

1. **PaddleOCR** — detect bbox  
2. **VietOCR** — nhận dạng chữ (`OCR/models/vietocr/vgg_transformer.pth`)  
3. **LayoutLMv3 KIE** — SELLER, TOTAL_COST, … (`OCR/models/layoutlmv3_kie/model-best/`)  
4. **NLU** — weighted voting category (`split_mode=false`)

Thiếu weights hoặc `USE_REAL_OCR=false` → fallback mock, service không crash.

## Bật AI thật

Trong `app/ai-service/.env`:

```ini
USE_REAL_NLU=true
USE_REAL_OCR=true
OCR_WEIGHTS_PATH=../../expense-ocr-nlu/OCR/models/vietocr/vgg_transformer.pth
LAYOUTLMV3_MODEL_DIR=../../expense-ocr-nlu/OCR/models/layoutlmv3_kie/model-best
```

Test E2E bill:

```powershell
$env:USE_REAL_OCR='true'
d:\Luan-Van\Project\expense-ocr-nlu\.venv\Scripts\python.exe -m pytest `
  expense-ocr-nlu\OCR\tests\test_e2e_bill_demo.py -q
```

## Kaggle retrain (tuỳ chọn)

- Credentials: `app/backend/kaggle.json` → copy `%USERPROFILE%\.kaggle\kaggle.json`  
- Dataset gốc: [vietnamese-receipts-mc-ocr-2021](https://www.kaggle.com/datasets/domixi1989/vietnamese-receipts-mc-ocr-2021)  
- Incremental: WebAdmin export → `OCR/verified_ocr_labels/kaggle_upload/`  
- Kernel: `OCR/kaggle/kernels/retrain-layoutlmv3`  

Xem [`setup.md` §11](../setup.md) và [`RETRAIN.md`](../RETRAIN.md).

## Sample (PowerShell)

```powershell
Invoke-RestMethod http://localhost:8000/health
Invoke-RestMethod http://localhost:4000/api/admin/retrain-readiness

$login = Invoke-RestMethod -Method POST http://localhost:4000/api/v1/auth/login `
  -Body '{"email":"demo@money.local","password":"demo1234"}' -ContentType 'application/json'
$token = $login.data.accessToken
Invoke-RestMethod http://localhost:4000/api/v1/wallets -Headers @{ Authorization = "Bearer $token" }
```

## Tài liệu liên quan

| File | Nội dung |
|------|----------|
| [`setup.md`](../setup.md) | Chạy thử đầy đủ (env, 4 terminal, FCM, troubleshooting) |
| [`RETRAIN.md`](../RETRAIN.md) | Chiến lược retrain, WebAdmin flow, Kaggle |
| `app/ai-service/README.md` | Schemas, env AI service |
| `app/backend/README.md` | Modules backend |
| `expense-ocr-nlu/` | Models NLU/OCR, tests, Kaggle kernels |
