# Setup — Chạy thử dự án (Cluster + R2 + BE + AI Service + Flutter App)

> **Python:** 3.13 | **Node.js:** ≥18 | **Flutter SDK** đã cài sẵn

---

## 1. Cấu hình `.env` Backend (CockroachDB + R2)

File: `app/backend/.env` (copy từ `.env.example` nếu chưa có)

```ini
PORT=4000
NODE_ENV=development

# --- CockroachDB Cloud Cluster ---
DATABASE_URL=postgresql://khangb2205881:<password>@spending-stories-15879.jxf.gcp-asia-southeast1.cockroachlabs.cloud:26257/spending-stories?sslmode=verify-full
DATABASE_SSL=true

# --- JWT ---
JWT_SECRET=<đổi thành chuỗi bí mật>
JWT_ACCESS_TTL=900
JWT_REFRESH_TTL=2592000

# --- AI Service ---
AI_SERVICE_URL=http://localhost:8000

# --- Cloudflare R2 ---
R2_ACCOUNT_ID=50905d6bc974e5e0dcf6631d2f112b51
R2_ACCESS_KEY_ID=<điền key>
R2_SECRET_ACCESS_KEY=<điền secret>
R2_BUCKET=spending-stories
R2_PUBLIC_BASE_URL=https://pub-cd3feb925e7842d992cb977ca4e5b92d.r2.dev

# --- Firebase Cloud Messaging (push khi app background/killed) ---
# Tạo service account trong Firebase Console → Project settings → Service accounts
FIREBASE_PROJECT_ID=powerful-bounty-477016-u8
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@powerful-bounty-477016-u8.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

---

## 2. Cấu hình `.env` AI Service

File: `app/ai-service/.env` (copy từ `.env.example` nếu chưa có)

```ini
HOST=0.0.0.0
PORT=8000

# NLU thật (dùng models joblib/sklearn từ expense-ocr-nlu)
USE_REAL_NLU=true
# OCR dùng mock (vietocr/paddleocr không tương thích Python 3.13)
USE_REAL_OCR=false

# Đường dẫn repo expense-ocr-nlu (tương đối từ ai-service/)
EXPENSE_OCR_NLU_DIR=../../expense-ocr-nlu
```

---

## 3. Chạy AI Service (Terminal 1)

> Dùng lại `.venv` của `expense-ocr-nlu` vì đã có đủ torch, paddleocr, vietocr tương thích Python 3.13.

```powershell
# Bước 1 (chỉ làm 1 lần): cài thêm deps nhẹ của ai-service vào venv expense-ocr-nlu
d:\Luan-Van\Project\expense-ocr-nlu\.venv\Scripts\Activate.ps1
pip install -r d:\Luan-Van\Project\app\ai-service\requirements.txt

# Bước 2: chạy service
cd d:\Luan-Van\Project\app\ai-service
d:\Luan-Van\Project\expense-ocr-nlu\.venv\Scripts\Activate.ps1
$env:RUN_LLM='1'; $env:RUN_LLM_CHITCHAT='1'; $env:LOG_MIMO_EMOTION='1' ; uvicorn app.main:app --host 0.0.0.0 --port 8000
```

**Kiểm tra:** http://localhost:8000/health → `nlu_loaded: true, ocr_loaded: false`\
**Swagger:** http://localhost:8000/docs

---

## 4. Chạy Backend (Terminal 2)

```powershell
cd d:\Luan-Van\Project\app\backend

# Lần đầu
npm install

# Tạo bảng trên CockroachDB cluster (chạy 1 lần)
npm run migrate

# Tạo user demo: demo@money.local / demo1234 (tuỳ chọn)
npm run seed

# Khởi động
cd d:\Luan-Van\Project\app\backend
npm run dev
```

**Kiểm tra:** http://localhost:4000/docs → Swagger UI

---

## 5. Chạy Flutter App (Terminal 3)

```powershell
cd d:\Luan-Van\Project\app\frontend\mobile

# Lần đầu
flutter pub get

# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000 --dart-define=AI_BASE_URL=http://10.0.2.2:8000

# Real device (cùng WiFi — thay bằng IP máy dev)
flutter run --dart-define=API_BASE_URL=http://10.190.86.24:4000 --dart-define=AI_BASE_URL=http://10.190.86.24:8000 --release
```

## 6. Chạy webadmin (terminal 4)

```

cd d:\Luan-Van\Project\app\frontend\web-admin

# Lần đầu
npm install

# Khởi động

npm run dev
```

---

## 6. Smoke test nhanh (PowerShell)

```powershell
# AI Service health
Invoke-RestMethod http://localhost:8000/health

# Test NLU
$body = @{ text='ăn phở 45k' } | ConvertTo-Json
Invoke-RestMethod -Method POST http://localhost:8000/api/v1/nlu/infer `
  -Body $body -ContentType 'application/json; charset=utf-8'

# Login backend
$login = Invoke-RestMethod -Method POST http://localhost:4000/api/v1/auth/login `
  -Body '{"email":"demo@money.local","password":"demo1234"}' `
  -ContentType 'application/json'
$token = $login.data.accessToken

# Lấy danh sách ví
Invoke-RestMethod http://localhost:4000/api/v1/wallets `
  -Headers @{ Authorization = "Bearer $token" }
```

---

## 7. Thứ tự khởi động

| \# | Service | Cwd | Lệnh | URL |
| --- | --- | --- | --- | --- |
| 1 | **AI Service** | `app/ai-service` | `uvicorn app.main:app --host 0.0.0.0 --port 8000` (dùng `.venv` của expense-ocr-nlu) | :8000/docs |
| 2 | **Backend** | `app/backend` | `npm run dev` | :4000/docs |
| 3 | **Flutter** | `app/frontend/mobile` | `flutter run --dart-define=...` | thiết bị/emulator |

---

## 8. Lưu ý

- **Không cần** chạy Postgres local hay Docker — dùng CockroachDB cluster có sẵn.
- **OCR** dùng mock (`USE_REAL_OCR=false`) vì `vietocr`/`paddlepaddle` chưa hỗ trợ Python 3.13 đầy đủ.
- **NLU** chạy thật với models `.joblib` từ `expense-ocr-nlu/text_nlu/models/`.
- **R2** keys đã có trong `app/backend/.env` — upload ảnh hoá đơn sẽ lưu vào bucket `spending-stories`.
- Warning `httpx 0.27.2 incompatible` khi cài requirements.txt vào venv expense-ocr-nlu là **không nghiêm trọng**, service vẫn chạy bình thường.

---

## 9. Firebase Cloud Messaging (FCM)

Push remote khi app **background/killed** (budget alert, recurring). In-app vẫn dùng WebSocket + local notification.

### Backend

1. Chạy migration (nếu chưa): `npm run migrate` — tạo bảng `user_fcm_tokens`.
2. Thêm `FIREBASE_*` vào `app/backend/.env` (xem mục 1).
3. Khởi động lại backend — log `Firebase Admin initialized for FCM`.

**API (auth bắt buộc):**

- `POST /api/v1/users/me/fcm/token` — body: `{ "token": "...", "platform": "android" | "ios" }`
- `DELETE /api/v1/users/me/fcm/token` — body: `{ "token": "..." }`

### Flutter (Android)

1. Firebase Console → thêm app Android `com.spendingdairy.app` → tải **`google-services.json`** (phải có `current_key` không rỗng).
2. Đặt file tại `app/frontend/mobile/android/app/google-services.json`.
3. (Tuỳ chọn) Cập nhật `lib/firebase_options.dart` hoặc build với:
   ```powershell
   flutter run --dart-define=FIREBASE_ANDROID_API_KEY=<api_key_từ_console> ...
   ```
4. `flutter pub get` rồi chạy app — sau login, token FCM được đăng ký tự động.

### iOS (chưa cấu hình)

Cần thêm `GoogleService-Info.plist` và bổ sung `ios` trong `firebase_options.dart`.

### QA push

1. Đăng nhập app trên thiết bị thật/emulator có Google Play.
2. Vượt ngưỡng budget hoặc chờ recurring scheduler → notification trên status bar.
3. Tap notification → mở đúng deep link (ví dụ `/report`).

---

## 10. Troubleshooting Google Sign-In

Khi chạy trên Emulator hoặc môi trường phát triển, Google Sign-In có thể thất bại (gây ra cảnh báo: *"Google Sign-In lỗi (SHA-1/Emulator)..."* và tự động kích hoạt tài khoản Dev Thử nghiệm). Dưới đây là các nguyên nhân phổ biến và cách khắc phục:

### 1. Thiếu mã vân tay SHA-1 của thiết bị phát triển (Android)
Google Sign-In yêu cầu mã băm SHA-1 của keystore dùng để ký ứng dụng phải được đăng ký trong Firebase Console.
* **Cách lấy mã SHA-1 (Debug Keystore):**
  Mở terminal tại thư mục dự án và chạy:
  ```powershell
  cd app/frontend/mobile/android
  ./gradlew signingReport
  ```
  Tìm phần cấu hình `Variant: debug` và copy dòng `SHA-1` (ví dụ: `5E:8F:16:C2:...`).
* **Đăng ký trên Firebase Console:**
  1. Vào **Firebase Console** -> **Project Settings** (Cài đặt dự án).
  2. Chọn app Android `com.spendingdairy.app` dưới mục **My Apps**.
  3. Nhấn **Add fingerprint** (Thêm vân tay) và dán mã SHA-1 vào.
  4. Tải lại file `google-services.json` mới và ghi đè vào thư mục `app/frontend/mobile/android/app/`.

### 2. Thiết bị giả lập (Emulator) không có Google Play Services
Google Sign-In yêu cầu thiết bị phải cài đặt Google Play Services.
* **Khắc phục:** Hãy tạo một thiết bị ảo (AVD) mới có biểu tượng Google Play Store trong cột **Play Store** của trình quản lý AVD Manager trong Android Studio. Đảm bảo bạn đã đăng nhập tài khoản Google của mình bên trong Emulator trước khi nhấn nút đăng nhập.

### 3. Cấu hình xác thực Google Play App Signing (nếu đã release)
Nếu ứng dụng đã xuất bản lên Google Play, mã SHA-1 dùng để ký ứng dụng trên máy của bạn sẽ bị thay thế bằng mã ký của Google Play App Signing.
* **Khắc phục:** Copy mã SHA-1 từ **Play Console** -> **Setup** -> **App integrity** -> **App signing key certificate** và dán vào Firebase Console tương tự như bước 1.