# Setup — Chạy thử dự án (Cluster + R2 + BE + AI Service + WebAdmin + Flutter)

> **Python:** 3.13 · **Node.js:** ≥18 · **Flutter SDK** đã cài sẵn

---

## 1. Cấu hình `.env` Backend (CockroachDB + R2)

File: `app/backend/.env` (copy từ `app/backend/.env.example` nếu chưa có)

```ini
PORT=4000
NODE_ENV=development

# --- CockroachDB Cloud Cluster ---
DATABASE_URL=postgresql://<user>:<password>@<host>:26257/spending-stories?sslmode=verify-full
DATABASE_SSL=true

# --- JWT ---
JWT_SECRET=<đổi thành chuỗi bí mật>
JWT_ACCESS_TTL=900
JWT_REFRESH_TTL=2592000

# --- AI Service ---
AI_SERVICE_URL=http://localhost:8000

# --- Cloudflare R2 ---
R2_ACCOUNT_ID=<account_id>
R2_ACCESS_KEY_ID=<key>
R2_SECRET_ACCESS_KEY=<secret>
R2_BUCKET=spending-stories
R2_PUBLIC_BASE_URL=<public_url>

# --- Firebase Cloud Messaging (tuỳ chọn) ---
FIREBASE_PROJECT_ID=<project_id>
FIREBASE_CLIENT_EMAIL=<service_account_email>
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

**Kaggle API (Bill OCR retrain):** đặt `kaggle.json` tại `app/backend/kaggle.json` (đã gitignore). Lần đầu copy sang `%USERPROFILE%\.kaggle\kaggle.json` để CLI hoạt động.

---

## 2. Cấu hình `.env` AI Service

File: `app/ai-service/.env` (copy từ `app/ai-service/.env.example`)

```ini
HOST=0.0.0.0
PORT=8000
DEVICE=cpu

# NLU thật — models tại expense-ocr-nlu/text_nlu/models/
USE_REAL_NLU=true

# OCR hybrid thật — PaddleOCR + VietOCR + PICK KIE
# Cần weights tại OCR/models/ (xem mục 11). Nếu thiếu weights → fallback mock, không crash.
USE_REAL_OCR=true

EXPENSE_OCR_NLU_DIR=../../expense-ocr-nlu
OCR_WEIGHTS_PATH=../../expense-ocr-nlu/OCR/models/vietocr/vietocr_receipt.pth
PICK_KIE_MODEL_PATH=../../expense-ocr-nlu/OCR/models/pick_kie/model_best.pth
VERIFIED_OCR_LABELS_DIR=../../expense-ocr-nlu/OCR/verified_ocr_labels

# Tuỳ chọn — sau Kaggle retrain
# BILL_RETRAIN_WEBHOOK_URL=http://localhost:4000/api/admin/bill-retrain/kaggle/webhook
# BILL_RETRAIN_ARTIFACT_URL=https://<cloud>/pick_kie_artifacts.zip
```

---

## 3. Chạy AI Service (Terminal 1)

Dùng `.venv` của `expense-ocr-nlu` (torch, paddleocr, vietocr, transformers).

```powershell
# Bước 1 (1 lần): cài deps ai-service vào venv
d:\Luan-Van\Project\expense-ocr-nlu\.venv\Scripts\Activate.ps1
pip install -r d:\Luan-Van\Project\app\ai-service\requirements.txt

# Bước 2: chạy service
cd d:\Luan-Van\Project\app\ai-service
d:\Luan-Van\Project\expense-ocr-nlu\.venv\Scripts\Activate.ps1
$env:USE_REAL_NLU='true'
$env:USE_REAL_OCR='true'
$env:LAZY_LOAD_MODELS='true'
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

**Kiểm tra:** http://localhost:8000/health

- `nlu_loaded: true` — NLU joblib + NER
- `ocr_loaded: true` — hybrid pipeline (Paddle + VietOCR + LayoutLMv3 nếu có weights)

**Swagger:** http://localhost:8000/docs

---

## 4. Chạy Backend (Terminal 2)

```powershell
cd d:\Luan-Van\Project\app\backend
npm install          # lần đầu
npm run migrate      # lần đầu — CockroachDB
npm run seed         # tuỳ chọn — demo@money.local / demo1234
npm run dev
```

**Kiểm tra:** http://localhost:4000/docs

---

## 5. Chạy WebAdmin (Terminal 3)

```powershell
cd d:\Luan-Van\Project\app\frontend\web-admin
npm install          # lần đầu
npm run dev
```

**URL:** http://localhost:5173

| Trang | Path | Mô tả |
| --- | --- | --- |
| Dashboard | `/` | Fusion metrics + **Retrain Readiness** (ngưỡng category / OCR-KIE) |
| Bill OCR Retrain | `/bill-retrain` | Auto-label → duyệt bbox → export → Kaggle |
| NLU Ops | `/nlu-ops` | Duyệt user corrections → retrain category |
| User Inspector | `/user-inspector` | Xem correction theo user |

API admin: `http://localhost:4000/api/admin/...`

---

## 6. Chạy Flutter App (Terminal 4)

```powershell
cd d:\Luan-Van\Project\app\frontend\mobile
flutter pub get      # lần đầu

# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000 --dart-define=AI_BASE_URL=http://10.0.2.2:8000

# Real device (cùng WiFi — thay IP máy dev)
flutter run --dart-define=API_BASE_URL=http://<IP>:4000 --dart-define=AI_BASE_URL=http://<IP>:8000
```

---

## 7. Smoke test nhanh (PowerShell)

```powershell
# AI Service health
Invoke-RestMethod http://localhost:8000/health

# NLU
$body = @{ text='ăn phở 45k' } | ConvertTo-Json
Invoke-RestMethod -Method POST http://localhost:8000/api/v1/nlu/infer `
  -Body $body -ContentType 'application/json; charset=utf-8'

# Retrain readiness (WebAdmin dashboard)
Invoke-RestMethod http://localhost:4000/api/admin/retrain-readiness

# Login backend
$login = Invoke-RestMethod -Method POST http://localhost:4000/api/v1/auth/login `
  -Body '{"email":"demo@money.local","password":"demo1234"}' `
  -ContentType 'application/json'
$token = $login.data.accessToken

Invoke-RestMethod http://localhost:4000/api/v1/wallets `
  -Headers @{ Authorization = "Bearer $token" }
```

### Test OCR hybrid (Python)

```powershell
$env:USE_REAL_OCR='true'
$env:DEVICE='cpu'
d:\Luan-Van\Project\expense-ocr-nlu\.venv\Scripts\python.exe -m pytest `
  d:\Luan-Van\Project\expense-ocr-nlu\OCR\tests\test_e2e_bill_demo.py -q
```

Ảnh mẫu: `expense-ocr-nlu/OCR/tests/bill-demo/*.jpg`

---

## 8. Thứ tự khởi động

| # | Service | Cwd | URL |
| --- | --- | --- | --- |
| 1 | **AI Service** | `app/ai-service` | http://localhost:8000/docs |
| 2 | **Backend** | `app/backend` | http://localhost:4000/docs |
| 3 | **WebAdmin** | `app/frontend/web-admin` | http://localhost:5173 |
| 4 | **Flutter** | `app/frontend/mobile` | emulator / thiết bị |

---

## 9. Lưu ý vận hành

- **Database:** CockroachDB cloud — không cần Postgres local (trừ khi dùng docker-compose).
- **NLU:** models tại `expense-ocr-nlu/text_nlu/models/*.joblib`.
- **OCR hybrid:** PaddleOCR detect → VietOCR recognize → LayoutLMv3 KIE (SELLER, TOTAL_COST, …) → NLU weighted voting category.
- **OCR mock:** nếu thiếu `vietocr_receipt.pth` hoặc `USE_REAL_OCR=false`, service fallback mock — không crash.
- **R2:** upload bill lưu bucket `spending-stories`.
- **Retrain:** không train mỗi bill — xem ngưỡng trên Dashboard WebAdmin hoặc `RETRAIN.md`.
- Warning `httpx` khi cài ai-service requirements vào venv OCR — thường không nghiêm trọng.

---

## 10. Cấu trúc weights OCR

```
expense-ocr-nlu/OCR/
├── models/
│   ├── vietocr/
│   │   ├── vietocr_receipt.pth    ← bắt buộc cho USE_REAL_OCR
│   │   ├── config.yml
│   │   └── meta.json
│   └── layoutlmv3_kie/
│       └── model-best/            ← LayoutLMv3 KIE (model.safetensors, config, tokenizer)
├── artifacts/                     ← log train, zip backup (không dùng inference)
├── verified_ocr_labels/           ← export WebAdmin (incremental + kaggle_upload)
├── manifests/ocr_models.json
└── kaggle/kernels/
    ├── train-pick-kie/        ← Train mới model PICK KIE từ dataset gốc
    └── retrain-pick-kie/      ← Retrain model PICK KIE bằng cách merge data WebAdmin
```

Train ban đầu / retrain: dataset gốc [vietnamese-receipts-mc-ocr-2021](https://www.kaggle.com/datasets/domixi1989/vietnamese-receipts-mc-ocr-2021) + incremental WebAdmin.

---

## 11. Kaggle (Bill OCR retrain — Tự động qua WebAdmin)

Hệ thống hỗ trợ kích hoạt pipeline retrain OCR-KIE (model PICK) trực tiếp từ **React WebAdmin Dashboard** hoặc trigger thủ công bằng CLI:

```powershell
# 1. Cấu hình Credentials
copy app\backend\kaggle.json %USERPROFILE%\.kaggle\kaggle.json

# 2. Sinh Notebook mới nhất cho Kaggle
python expense-ocr-nlu/OCR/kaggle/kernels/build_pick_kaggle_notebooks.py

# 3. Trigger retrain trên Kaggle tự động từ WebAdmin:
# - Vào http://localhost:5173/bill-retrain
# - Bấm "Export approved" -> Bật "Auto Kaggle" để hệ thống tự đóng gói zip, tải ảnh tự động từ Cloudflare R2 (nếu ở cloud), upload dataset và push kernel lên Kaggle.
# - Theo dõi tiến độ trực quan ngay trên WebAdmin Dashboard.
```

Kernel: https://www.kaggle.com/code/mainhatkhangb2205881/retrain-pick-kie  
Dataset incremental: `mainhatkhangb2205881/webadmin-verified-receipts`

---

## 12. Firebase Cloud Messaging (FCM)

Push remote khi app **background/killed**. In-app dùng WebSocket + local notification.

### Backend

1. `npm run migrate` — bảng `user_fcm_tokens`.
2. Thêm `FIREBASE_*` vào `app/backend/.env`.
3. Khởi động lại backend.

**API:** `POST/DELETE /api/v1/users/me/fcm/token`

### Flutter (Android)

1. Tải `google-services.json` → `app/frontend/mobile/android/app/`.
2. `flutter pub get` → chạy app → token FCM đăng ký sau login.

### iOS

Cần `GoogleService-Info.plist` + cấu hình Firebase iOS.

---

## 13. Troubleshooting Google Sign-In

### 1. Thiếu SHA-1 (Android)

```powershell
cd app/frontend/mobile/android
./gradlew signingReport
```

Copy SHA-1 debug → Firebase Console → app Android → Add fingerprint → tải lại `google-services.json`.

### 2. Emulator không có Google Play Services

Tạo AVD có cột **Play Store**, đăng nhập Google trong emulator.

### 3. App đã release lên Play Store

Thêm SHA-1 từ Play Console → App integrity → App signing key vào Firebase.

---

## 14. Troubleshooting OCR / Retrain

| Triệu chứng | Cách xử lý |
| --- | --- |
| `ocr_loaded: false` | Kiểm tra `OCR/models/vietocr/vietocr_receipt.pth`, `USE_REAL_OCR=true` |
| LayoutLMv3 heuristic thay vì model | Kiểm tra `OCR/models/layoutlmv3_kie/model-best/model.safetensors` |
| Backend crash `billRetrainStore` | `npm run dev` — nodemon tự restart sau sửa |
| Kaggle `kaggle_configured: false` | Copy `kaggle.json` → `%USERPROFILE%\.kaggle\`, `pip install kaggle` trong venv |
| Retrain readiness 0% | Duyệt bill trên `/bill-retrain`; category trên `/nlu-ops` |

Tài liệu chiến lược retrain: **`RETRAIN.md`** · Brainstorm OCR: **`solutions_brainstorm.md`**
