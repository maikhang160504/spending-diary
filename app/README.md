# MoneyStory — Fullstack Expense Management with AI

Hệ thống quản lý chi tiêu cá nhân + AI nhận dạng (NLU text tiếng Việt + OCR hóa đơn). Đã được refactor thành 3 service rõ ràng + docker-compose chạy được toàn bộ ở local.

```
                          +----------------------+
                          |  Mobile / Web-admin  |
                          +----------+-----------+
                                     | HTTPS (JWT)
                                     v
+-----------+    +-------------------+--------------------+   HTTP   +-----------------+
| Cloudflare|<---|         Backend (Node.js/Express)       |--------->|  AI Service     |
|  R2       |    |  /api/v1/{auth,wallets,transactions,    |          |  (FastAPI)      |
|  bucket   |    |          budgets,stats,categories,      |          |  /api/v1/{nlu,  |
+-----------+    |          ai,upload}                     |          |        ocr,     |
                 |  Swagger UI @ /docs                     |          |        expense} |
                 +-------------------+--------------------+          |  Swagger /docs  |
                                     | pg                            +--------+--------+
                                     v                                        |
                          +----------+----------+                              |
                          |   PostgreSQL /      |                              |
                          |   CockroachDB       |                              |
                          +---------------------+                              |
                                                                               v
                                                                +-------------------------+
                                                                | expense-ocr-nlu (repo)  |
                                                                | text_nlu/models/        |
                                                                | OCR/models/             |
                                                                +-------------------------+
```

## Cấu trúc thư mục

```
app/
├── ai-service/          FastAPI microservice nhận dạng (NLU + OCR)
│   ├── app/{core,schemas,services,adapters,routers}/
│   ├── tests/
│   ├── Dockerfile
│   └── README.md
├── backend/             Node.js orchestrator REST API
│   ├── src/
│   │   ├── modules/{auth,categories,wallets,transactions,budgets,stats,ai,upload}/
│   │   ├── services/{aiClient,r2Client}.js
│   │   ├── middlewares/, utils/, config/, routes/
│   │   └── db/{migrate,seed}.js
│   ├── tests/unit/
│   ├── Dockerfile
│   └── README.md
├── database/
│   ├── schema.sql       Master schema (Postgres + Cockroach)
│   └── README.md
├── frontend/
│   ├── mobile/          (Flutter)
│   └── web-admin/       (React + Vite)
└── docker-compose.yml   postgres + ai-service + backend
```

## Cách chạy nhanh nhất

### Option A — docker-compose (đầy đủ)

```powershell
cd app
copy backend\.env.example backend\.env    # mở ra sửa JWT_SECRET, R2 keys nếu cần
docker compose up -d --build
docker compose exec backend npm run migrate
docker compose exec backend npm run seed
```

- Backend → http://localhost:4000/docs
- AI service → http://localhost:8000/docs
- Postgres → localhost:5432 (user/pass `postgres`)

### Option B — chạy thủ công (dev nhanh)

```powershell
# 1) DB local (1 trong 2):
#    docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=expense_ai postgres:16-alpine
#    hoặc dùng CockroachDB cluster có sẵn trong app\backend\.env (DATABASE_URL=cluster_connect)

# 2) AI service
cd app\ai-service
python -m venv .venv-lite
.venv-lite\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --host 127.0.0.1 --port 8000

# 3) Backend (terminal khác)
cd app\backend
copy .env.example .env
npm install
npm run migrate            # tạo bảng
npm run seed               # tuỳ chọn: tạo demo@money.local / demo1234
npm run dev                # http://localhost:4000/docs
```

## Endpoint chính (Backend)

| Group | Method | Path | Mô tả |
|-------|--------|------|------|
| Auth | POST | `/api/v1/auth/register` | Đăng ký |
| | POST | `/api/v1/auth/login` | Đăng nhập, trả `accessToken` + `refreshToken` |
| | POST | `/api/v1/auth/refresh` | Cấp lại token (rotation) |
| | POST | `/api/v1/auth/logout` | Revoke refresh token |
| | GET | `/api/v1/auth/me` | User hiện tại |
| Categories | GET / POST / PATCH / DELETE | `/api/v1/categories/...` | System + user-defined |
| Wallets | GET / POST / PATCH / DELETE | `/api/v1/wallets/...` | Ví cá nhân & nhóm |
| | GET / POST / DELETE | `/api/v1/wallets/:id/members[/:memberId]` | Thành viên |
| Transactions | GET / POST / PATCH / DELETE | `/api/v1/transactions/...` | CRUD + filter date/category/type |
| Budgets | GET / POST / PATCH / DELETE | `/api/v1/budgets/...` | |
| | GET | `/api/v1/budgets/summary` | Spent / remain / over budget |
| Stats | GET | `/api/v1/stats/dashboard` | Tổng quan + breakdown theo category & day |
| | GET | `/api/v1/stats/by-month` | Thu/chi theo tháng cả năm |
| AI | POST | `/api/v1/ai/nlu` | Text → intent + amount + category |
| | POST | `/api/v1/ai/expense/from-text` | "ăn phở 45k" → tạo giao dịch |
| | POST | `/api/v1/ai/expense/from-bill` | Upload ảnh hóa đơn → suggestion |
| | POST | `/api/v1/ai/corrections` | User sửa nhãn (TASK-08) |
| | POST | `/api/v1/ai/actions/{confirm,reject}` | Popup Action (TASK-09) |
| Upload | POST | `/api/v1/upload/presign` | Presigned R2 URL |
| | POST | `/api/v1/upload/direct` | Proxy upload qua backend |

Toàn bộ trừ `/health`, `/docs`, `/openapi.json`, `/auth/*` (trừ `/me`) đều yêu cầu header `Authorization: Bearer <accessToken>`.

## Endpoint AI service (riêng, port 8000)

| Method | Path | Mô tả |
|--------|------|------|
| GET | `/health` | Liveness + xem backend nào loaded (real/mock) |
| POST | `/api/v1/nlu/infer` | NLU text |
| POST | `/api/v1/ocr/image` | OCR ảnh (multipart) |
| POST | `/api/v1/ocr/text` | Parse text đã OCR sẵn |
| POST | `/api/v1/expense/from-text` | Text → expense |
| POST | `/api/v1/expense/from-bill` | Image → expense |

## Sample (PowerShell)

```powershell
# 1) Health
Invoke-RestMethod http://localhost:8000/health

# 2) NLU mock
$body = @{ text='ăn phở 45k' } | ConvertTo-Json
Invoke-RestMethod -Method POST http://localhost:8000/api/v1/nlu/infer `
  -Body $body -ContentType 'application/json; charset=utf-8'

# 3) Login (sau khi seed user demo)
$login = Invoke-RestMethod -Method POST http://localhost:4000/api/v1/auth/login `
  -Body '{"email":"demo@money.local","password":"demo1234"}' `
  -ContentType 'application/json'
$token = $login.data.accessToken

# 4) Lấy danh sách ví
Invoke-RestMethod http://localhost:4000/api/v1/wallets `
  -Headers @{ Authorization = "Bearer $token" }

# 5) Tạo giao dịch tay
$wid = (Invoke-RestMethod http://localhost:4000/api/v1/wallets `
   -Headers @{ Authorization = "Bearer $token" }).data[0].id
$tx = @{ walletId=$wid; amount=45000; categoryCode='Food'; note='Phở' } | ConvertTo-Json
Invoke-RestMethod -Method POST http://localhost:4000/api/v1/transactions `
  -Body $tx -ContentType 'application/json' `
  -Headers @{ Authorization = "Bearer $token" }

# 6) Parse + lưu tự động từ text
$nl = @{ walletId=$wid; text='trà sữa 35k' } | ConvertTo-Json
Invoke-RestMethod -Method POST http://localhost:4000/api/v1/ai/expense/from-text `
  -Body $nl -ContentType 'application/json; charset=utf-8' `
  -Headers @{ Authorization = "Bearer $token" }
```

## Trạng thái triển khai (smoke kiểm thử)

| Hạng mục | Kiểm thử | Kết quả |
|----------|----------|--------|
| AI service mock NLU `ăn phở 45k` | `pytest tests` | 6/6 passed |
| AI service `/health`, `/docs`, `/nlu/infer`, `/ocr/text` live | curl PowerShell | 200, JSON đúng (amount=45000, cat=Food) |
| Backend Jest (schema + supertest 401/404/200 + OpenAPI 28 paths) | `npm test` | 9/9 passed |
| Backend boot + Swagger UI live | `node src/index.js` | http://localhost:4000/docs trả 200 |
| Backend AI proxy 401 khi không token | curl | đúng 401 |

## Bật pipeline AI thật

`USE_REAL_NLU=true` + `USE_REAL_OCR=true` để service load `text_nlu/models/*.joblib` + `OCR/models/vietocr_receipt.pth` từ `expense-ocr-nlu/`. Nếu thiếu weights → log warning, fallback mock (không crash). Xem `app/ai-service/README.md`.

## Bật CockroachDB cloud cluster (.env đã có sẵn)

Backend `.env`:

```ini
DATABASE_URL=postgresql://khangb2205881:eF84GjVt2rKM2OlhiR01gw@spending-stories-15879.jxf.gcp-asia-southeast1.cockroachlabs.cloud:26257/spending-stories?sslmode=verify-full
DATABASE_SSL=true
```

R2 keys (cũng có sẵn trong file `.env` ban đầu):

```ini
R2_ACCOUNT_ID=50905d6bc974e5e0dcf6631d2f112b51
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET=spending-stories
R2_PUBLIC_BASE_URL=https://pub-cd3feb925e7842d992cb977ca4e5b92d.r2.dev
```

## Tài liệu chi tiết

- `app/ai-service/README.md` — schemas, mock/real backend, env, train Gemini.
- `app/backend/README.md` — modules, endpoints, sample curl, security note.
- `app/database/README.md` — sơ đồ quan hệ + chạy migration.
- `expense-ocr-nlu/ARCHITECTURE_TRIEN_KHAI.md` — kiến trúc gốc, TASK-08/09 (correction + action confirm) đã được map vào DB schema.
