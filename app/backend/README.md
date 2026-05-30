# MoneyStory Backend (Node.js / Express)

Orchestrator REST API cho hệ thống quản lý chi tiêu. Stack: **Express 4 + Postgres + JWT + Cloudflare R2**, có **Swagger UI** ở `/docs` và proxy đến **AI service** (`app/ai-service`).

## Cấu trúc

```
src/
├── config/       # env, logger (pino), db pool (pg), swagger spec
├── middlewares/  # auth (JWT), errorHandler, validate (zod), requestId, requestLogger
├── utils/        # ApiError, asyncHandler, jwt helpers, paginate
├── db/           # migrate.js (chạy schema.sql + migrations/), seed.js
├── services/
│   ├── aiClient.js   # axios -> http://ai-service:8000
│   ├── r2Client.js   # @aws-sdk/client-s3 + presigned URL
│   └── wsHub.js      # WebSocket server (ws pkg) — real-time bill processing updates
├── modules/
│   ├── auth/          # register, login, refresh, logout, me
│   ├── categories/    # CRUD danh mục (system + user)
│   ├── wallets/       # CRUD ví + members ví chung
│   ├── transactions/  # CRUD + filter, multi-wallet
│   ├── budgets/       # CRUD + summary (spent/remain/over)
│   ├── stats/         # dashboard + by-month
│   ├── ai/            # /nlu, /expense/from-text, /expense/from-bill, corrections, actions
│   └── upload/        # /presign, /direct (R2)
├── routes/index.js
├── app.js            # express factory
└── index.js          # main entry
```

## API tổng quan

Mọi endpoint dưới `/api/v1` đều dùng định dạng:

```json
{ "success": true, "data": ... }
```

hoặc khi lỗi:

```json
{ "success": false, "error": { "code": "validation_error", "message": "...", "details": {} } }
```

| Group | Endpoint chính |
|------|----------------|
| `auth/` | `POST /register`, `POST /login`, `POST /refresh`, `POST /logout`, `GET /me` |
| `categories/` | `GET`, `POST`, `PATCH /:id`, `DELETE /:id` |
| `wallets/` | `GET`, `POST`, `GET /:id`, `PATCH /:id`, `DELETE /:id`, `/:id/members*` |
| `transactions/` | `GET` (filter), `POST`, `GET /:id`, `PATCH /:id`, `DELETE /:id` |
| `budgets/` | `GET`, `GET /summary`, `POST`, `PATCH /:id`, `DELETE /:id` |
| `stats/` | `GET /dashboard`, `GET /by-month` |
| `ai/` | `GET /health`, `POST /nlu`, `POST /expense/from-text`, `POST /expense/from-bill`, `POST /corrections`, `POST /actions/confirm`, `POST /actions/reject`, `GET /actions/is-confirmed` |
| `upload/` | `POST /presign`, `POST /direct` |

Tất cả (trừ `/health`, `/docs`, `/openapi.json`, `auth/{register,login,refresh,logout}`) yêu cầu header `Authorization: Bearer <accessToken>`.

## Setup local

```powershell
cd app/backend
copy .env.example .env       # sửa lại JWT_SECRET, AI_SERVICE_URL, DATABASE_URL...
npm install
```

### 1) Khởi động Postgres + AI service (docker-compose)

```powershell
cd ..\
docker compose up postgres ai-service -d
```

### 2) Migrate + seed

```powershell
cd backend
npm run migrate
npm run seed       # tuỳ chọn, tạo user demo@money.local / demo1234 + 5 giao dịch mẫu
```

### 3) Chạy dev

```powershell
npm run dev
```

→ Mở Swagger: http://localhost:4000/docs  
→ Openapi JSON: http://localhost:4000/openapi.json

### 4) Chạy production (Docker)

```powershell
cd ..\
docker compose up -d --build
```

## Smoke tests

```powershell
npm test
```

(Test chạy được mà không cần DB — chỉ dùng supertest gọi vào express factory để xác nhận route 401/404/200, schema validation, Swagger spec đầy đủ.)

## Sample curl

```powershell
# 1) Login (sau khi seed)
curl -X POST http://localhost:4000/api/v1/auth/login `
  -H "Content-Type: application/json" `
  -d '{"email":"demo@money.local","password":"demo1234"}'

# 2) Lưu access token rồi gọi
$TOKEN = "<accessToken>"
curl http://localhost:4000/api/v1/wallets -H "Authorization: Bearer $TOKEN"

# 3) Phân tích câu chi tiêu (NLU mock)
curl -X POST http://localhost:4000/api/v1/ai/nlu `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/json" `
  -d '{"text":"ăn phở 45k"}'

# 4) Lưu giao dịch từ text (auto-save khi AI đủ confidence)
$WALLET = "<walletId>"
curl -X POST http://localhost:4000/api/v1/ai/expense/from-text `
  -H "Authorization: Bearer $TOKEN" `
  -H "Content-Type: application/json" `
  -d "{`"walletId`":`"$WALLET`",`"text`":`"trà sữa 35k`"}"

# 5) Upload bill → OCR
curl -X POST http://localhost:4000/api/v1/ai/expense/from-bill `
  -H "Authorization: Bearer $TOKEN" `
  -F "file=@./bill.jpg"
```

## Kết nối với CockroachDB cluster (file `.env` của bạn)

```ini
DATABASE_URL=postgresql://khangb2205881:...@spending-stories-15879.jxf.gcp-asia-southeast1.cockroachlabs.cloud:26257/spending-stories?sslmode=verify-full
DATABASE_SSL=true
```

> Khi Cockroach yêu cầu CA cert riêng, set `DATABASE_SSL=no-verify` hoặc cài root cert + mount vào container.

## Biến môi trường quan trọng

| Biến | Mô tả |
|------|-------|
| `DATABASE_URL` | PostgreSQL / CockroachDB connection string |
| `JWT_SECRET` | Secret ký JWT — đặt mạnh ở production |
| `AI_SERVICE_URL` | URL của ai-service (mặc định `http://localhost:8000`) |
| `GOOGLE_CLIENT_ID` | OAuth 2.0 Client ID từ Google Cloud Console — cần cho `POST /auth/google` |

> **GL-07 (manual):** Để Google Sign-In hoạt động trên mobile, cần thêm:
> - Android: `android/app/google-services.json` (tải từ Firebase Console)
> - iOS: `ios/Runner/GoogleService-Info.plist`

## WebSocket — Real-time Bill Processing

Server expose WebSocket tại `ws://<host>/ws` (chia sẻ cùng HTTP port).

**Kết nối:**
```
ws://localhost:4000/ws?token=<accessToken>
```

**Server → Client messages:**

| type | Mô tả | Payload |
|------|--------|---------|
| `transaction_done` | OCR+LLM hoàn tất | `{ transactionId, data: { amount, category, note, imageUrl, mascot_mood, story } }` |
| `transaction_failed` | Job thất bại | `{ transactionId, error }` |

**Flow `POST /ai/expense/from-bill`:**
1. BE tạo tx `processing_status='pending'` → trả `{ transactionId, status:'pending' }` HTTP 202 ngay lập tức
2. Background job (`setImmediate`): OCR → ML → LLM → `UPDATE tx processing_status='done'` → `sendToUser`
3. Flutter lắng nghe WebSocket → khi nhận `transaction_done` → cập nhật UI

## Lưu ý security

- JWT secret: đừng commit, hãy set `JWT_SECRET` mạnh trong production.
- Helmet đã bật, CSP tắt vì Swagger UI cần inline scripts.
- File upload giới hạn 8 MB (multer).
- Refresh token lưu hash (sha256) + rotation (revoke khi dùng).
- `password_hash` là nullable sau migration 003 — user Google đăng nhập không có password.
