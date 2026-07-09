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

---

## 2. Cấu hình `.env` AI Service (Hợp Nhất)

File: `expense-ocr-nlu/.env` (Tạo hoặc chỉnh sửa trực tiếp)

```ini
HOST=0.0.0.0
PORT=8000
DEVICE=cpu              # Thiết bị chạy OCR/NLU: 'cpu' hoặc 'cuda'

# --- Trạng thái Bật/Tắt Service Thật ---
USE_REAL_NLU=true       # true: Dùng spaCy + TF-IDF (hoặc PhoBERT Encoder). false: Mock NLU
USE_REAL_OCR=true       # true: Dùng pipeline PaddleOCR + VietOCR + LayoutLMv3. false: Mock OCR

# --- Cấu hình Mô hình Sinh câu thoại (NLG / LLM) ---
RUN_LLM='1'             # Bật LLM hỗ trợ NLU fallback và phản hồi chitchat
RUN_LLM_CHITCHAT='1'    # Bật LLM riêng cho các yêu cầu Chitchat phiếm
LOG_MIMO_EMOTION='1'    # Ghi nhận log trạng thái cảm xúc của Mimo
LAZY_LOAD_MODELS=true   # Tải chậm các model nặng để khởi động nhanh hơn

# --- Chế độ chạy LLM/PhoGPT (Chọn 1 trong 3 cách sau) ---
# Cách 1 (Mặc định - Khuyên dùng khi phát triển): Dùng API Gemini/ChatGPT qua internet
gemini_API_v1=<api_key_1>   # Cung cấp khóa API Gemini (hỗ trợ nhiều key xoay vòng)
gemini_API_v2=<api_key_2>
# Cách 2 (Chạy local PhoGPT): Cần GPU CUDA >= 16GB VRAM và tải sẵn weights phogpt_vismimo
# USE_LOCAL_PHOGPT=1
# Cách 3 (Chạy PhoGPT qua Modal Serverless): Gọi model chạy trên GPU Cloud của Modal
# USE_MODAL_PHOGPT=1

# --- Đường dẫn Trọng số / Weights OCR KIE ---
EXPENSE_OCR_NLU_DIR=.
OCR_WEIGHTS_PATH=bill_ocr/models/vietocr/vgg_transformer.pth
LAYOUTLMV3_MODEL_PATH=bill_ocr/models/layoutlmv3/model_best.pth
ROTATION_MODEL_PATH=bill_ocr/models/rotation_corrector/mobilenetv3-Epoch-487-Loss-0.03-Acc-0.99.pth
VERIFIED_OCR_LABELS_DIR=bill_ocr/exported
```

---

## 3. Chạy AI Service

### 3.1 Chạy local

Dùng `.venv` của `expense-ocr-nlu` (Đã cài đặt PyTorch, PaddleOCR, VietOCR, Transformers).

```powershell
# Bước 1 (1 lần duy nhất): Kích hoạt venv và cài đặt dependencies
d:\Luan-Van\Project\expense-ocr-nlu\.venv\Scripts\Activate.ps1
pip install -r d:\Luan-Van\Project\expense-ocr-nlu\requirements.txt

# Bước 2: Chạy service FastAPI
cd d:\Luan-Van\Project\expense-ocr-nlu
d:\Luan-Van\Project\expense-ocr-nlu\.venv\Scripts\Activate.ps1
uvicorn src.api.app:app --host 0.0.0.0 --port 8000
```

> [!NOTE]
> * **Nếu không có GPU:** Chạy OCR trên `DEVICE=cpu` và dùng **Cách 1** (API Gemini/ChatGPT) cho LLM để không bị quá tải máy tính.
> * **Nếu có GPU CUDA:** Có thể bật `DEVICE=cuda` cho OCR chạy nhanh hơn và tùy chọn bật `USE_LOCAL_PHOGPT=1` để tự sinh phản hồi Gen Z offline.

**Kiểm tra trạng thái tải mô hình:** `GET http://localhost:8000/health`
* `nlu_loaded: true` — Đã nạp thành công mô hình NLU (TF-IDF/PhoBERT) & Spacy NER.
* `ocr_loaded: true` — Đã nạp thành công Pipeline OCR (Paddle + VietOCR + LayoutLMv3 KIE).

**Swagger API Docs:** http://localhost:8000/docs

### 3.2 Chạy trên Cloud (Modal Serverless GPU)

Modal cho phép triển khai toàn bộ AI Service (bao gồm OCR, NLU PhoBERT và mô hình LLM Qwen2.5-14B) lên GPU Cloud với tốc độ cao.

```bash
# 1. Chạy thử nghiệm tạm thời (Hot-reload, tự tắt ngay khi tắt terminal)
modal serve modal_app.py

# 2. Triển khai lên cloud (Production Deployment)
modal deploy modal_app.py

# 3. Dừng ứng dụng hoàn toàn (Tắt toàn bộ container GPU để tránh tốn tiền khi không sử dụng)
modal app stop expense-ocr-nlu

# 4. Kích hoạt train / fine-tune Qwen LoRA trên GPU H100 Cloud
modal run modal_app.py::train_qwen_model --num-epochs=3 --learning-rate=2e-4 --batch-size=4
```

#### Quản lý chi phí GPU & Cơ chế hoạt động của LLM (`keep_warm` vs Auto Scale-to-Zero)

Khi triển khai `modal_app.py`, ứng dụng khởi tạo **2 dịch vụ GPU song song**:
1. **Web Service FastAPI (`fastapi_app`) trên GPU L4**: Chạy OCR (PaddleOCR + VietOCR + LayoutLMv3) và NLU PhoBERT Encoder.
2. **LLM Worker (`QwenModel`) trên GPU A10G**: Nạp mô hình `Qwen/Qwen2.5-14B-Instruct` lượng tử hóa 4-bit (24GB VRAM) phục vụ phân tích tài chính sâu, fallback ý định và chitchat Gen Z.

**Cấu hình giữ ấm / Tiết kiệm chi phí trong `modal_app.py`:**
- **Chế độ Phản hồi tức thì 0ms (Hiện tại - `keep_warm=1`)**:
  - Modal luôn giữ **1 container L4** và **1 container A10G** bật liên tục 24/7 trên VRAM.
  - *Ưu điểm*: Không có độ trễ cold-start, gọi API là LLM Qwen và OCR phản hồi ngay lập tức.
  - *Nhược điểm*: Tính phí giây GPU liên tục 24/7. **Khi không làm việc, bạn nên chạy `modal app stop expense-ocr-nlu` để dừng tính tiền.**
- **Chế độ Tiết kiệm tự động (Serverless Auto-scale về 0đ)**:
  - Nếu chuyển `keep_warm=0` và đặt `container_idle_timeout=300` (5 phút) trong `modal_app.py`:
  - Khi có request đến, container bật lên nạp weights vào VRAM. Sau 5 phút không có request nào mới, Modal tự động hủy container GPU $\rightarrow$ **chi phí về 0đ**.
- **Chế độ LLM qua Cloud API (Gemini / OpenAI fallback)**:
  - Nếu không muốn chạy riêng container GPU A10G cho Qwen LLM, hệ thống tự động fallback sử dụng khóa API `GEMINI_API_KEY` (hoặc `gemini_API_v1` trong `.env`), giúp giảm hoàn toàn chi phí duy trì GPU cho LLM.

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
flutter run --dart-define=API_BASE_URL=http://10.191.165.24:4000 --dart-define=AI_BASE_URL=http://10.191.165.24:8000
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
- **OCR mock:** nếu thiếu `vgg_transformer.pth` hoặc `USE_REAL_OCR=false`, service fallback mock — không crash.
- **R2:** upload bill lưu bucket `spending-stories`.
- **Retrain:** không train mỗi bill — xem ngưỡng trên Dashboard WebAdmin hoặc `RETRAIN.md`.
- Warning `httpx` khi cài ai-service requirements vào venv OCR — thường không nghiêm trọng.

---

## 10. Cấu trúc weights OCR

```
expense-ocr-nlu/bill_ocr/
├── models/
│   ├── vietocr/
│   │   ├── vgg_transformer.pth        ← Bắt buộc cho USE_REAL_OCR
│   │   ├── config.yml
│   │   └── meta.json
│   ├── layoutlmv3/
│   │   └── model_best.pth             ← Model LayoutLMv3 KIE (SELLER, TOTAL_COST, ...)
├── exported/                          ← Nơi lưu dữ liệu đã gán nhãn từ WebAdmin
└── receipt_ocr/                       ← Logic KIE và pipeline nhận diện hóa đơn
```

Train ban đầu / retrain: dataset gốc [vietnamese-receipts-mc-ocr-2021](https://www.kaggle.com/datasets/domixi1989/vietnamese-receipts-mc-ocr-2021) + incremental WebAdmin.



## 11. Firebase Cloud Messaging (FCM)

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

## 12. Troubleshooting Google Sign-In

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

## 13. Troubleshooting OCR / Retrain

| Triệu chứng | Cách xử lý |
| --- | --- |
| `ocr_loaded: false` | Kiểm tra `bill_ocr/models/vietocr/vgg_transformer.pth`, `USE_REAL_OCR=true` |
| LayoutLMv3 KIE không hoạt động | Kiểm tra `bill_ocr/models/layoutlmv3/model_best.pth` |
| Backend crash `billRetrainStore` | `npm run dev` — nodemon tự restart sau sửa |
| Retrain readiness 0% | Duyệt bill trên `/bill-retrain`; category trên `/nlu-ops` |

Tài liệu chiến lược retrain: **`RETRAIN.md`** · Brainstorm OCR: **`solutions_brainstorm.md`**
