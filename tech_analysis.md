# TECH ANALYSIS — Spending Diary
> **Mục đích:** Tài liệu tham chiếu kỹ thuật để kiểm tra tính chính xác khi biên tập luận văn.  
> **Cập nhật lần cuối:** 2026-07-31  
> **Dựa trên:** Phân tích toàn bộ source code thực tế trong repo.

---

## 1. KIẾN TRÚC TỔNG QUAN

```
Spending Diary
├── app/
│   ├── backend/          → Node.js (Express) — REST API + WebSocket
│   ├── frontend/
│   │   ├── mobile/       → Flutter (Dart) — ứng dụng di động
│   │   └── web-admin/    → React + Vite — trang quản trị
│   └── database/         → PostgreSQL (tương thích CockroachDB)
└── expense-ocr-nlu/      → Python (FastAPI trên Modal Cloud) — AI Engine
    ├── bill_ocr/         → OCR pipeline (hóa đơn)
    ├── text_nlu/         → NLU pipeline (văn bản tự nhiên)
    └── src/              → Core modules: nlu, llm, nlg, api, config
```

---

## 2. BACKEND (Node.js)

### 2.1 Tech Stack
- **Runtime:** Node.js ≥ 18
- **Framework:** Express 4.x
- **Database driver:** pg (node-postgres)
- **Auth:** JWT (jsonwebtoken) + bcryptjs
- **Storage:** AWS S3-compatible (Cloudflare R2) — @aws-sdk/client-s3
- **Realtime:** WebSocket — ws
- **Push notification:** Firebase Admin SDK (FCM)
- **Email:** Nodemailer
- **Logging:** Pino + pino-pretty
- **Validation:** Zod
- **Cron:** node-cron
- **API Docs:** Swagger (swagger-jsdoc + swagger-ui-express)

### 2.2 Modules chính
| Module | Chức năng |
|--------|-----------|
| `auth` | Đăng nhập, đăng ký, Google OAuth, refresh token, reset OTP |
| `transactions` | CRUD giao dịch thu/chi |
| `wallets` | Quản lý ví cá nhân và ví nhóm |
| `categories` | Danh mục chi tiêu (hệ thống + cá nhân) |
| `budgets` | Ngân sách theo tháng + gợi ý tự động |
| `goals` | Mục tiêu tiết kiệm |
| `loans` | Quản lý khoản vay/cho vay |
| `stats` | Thống kê chi tiêu cá nhân + so sánh nhóm ngang hàng |
| `ai` | Proxy AI: gọi Python AI Engine + xử lý kết quả NLU |
| `chat` | Chat session (Mimo chatbot), lưu lịch sử |
| `recurring` | Giao dịch định kỳ |
| `stories` | Nhật ký chi tiêu (Stories) |
| `upload` | Upload ảnh hóa đơn lên R2 |
| `fcm` | Firebase Cloud Messaging (push notification) |
| `weather` | Tích hợp thời tiết |

### 2.3 Cơ chế an toàn số dư
- Số dư KHÔNG được AI tự tính toán hay suy đoán.
- Mỗi khi cần số dư, backend bắt buộc truy vấn trực tiếp bảng `wallets` trong PostgreSQL.
- Hàm `_resolveWalletId(userId)` truy vấn bảng `wallet_members` để tìm ví hợp lệ.
- AI Engine (Python) KHÔNG có quyền truy cập trực tiếp database; mọi data thực đều do Node.js backend cung cấp.

### 2.4 Mascot "Mimo" & Verbal Style
- Hỗ trợ 5 phong cách giao tiếp: `funny`, `gentle`, `serious`, `sarcastic`, `strict`
- Phong cách được lưu trong bảng `user_settings` (cột `verbal_style`).
- Mỗi phiên chat tạo mới: backend đọc `verbal_style` từ DB và chọn câu chào tương ứng.
- Cảm xúc mascot (Mimo emotion) được xác định qua `pickMimoEmotionFromNlu()`.

---

## 3. AI ENGINE (Python — Modal Cloud)

### 3.1 Triển khai hạ tầng
- **Platform:** Modal (serverless GPU cloud)
- **Container base:** Debian Slim, Python 3.10
- **GPU:** H100 / A10G (tùy task)
- **Storage:** Modal Volume ("expense-ocr-nlu-storage") — lưu model weights
- **Framework API:** FastAPI 0.115 + Uvicorn

### 3.2 NLU Pipeline (Xử lý văn bản tự nhiên)

#### Ba backend inference — chọn động qua registry:
```
nlu_model_registry.json → inference_backend: "llm" | "encoder" | "tfidf"
```

| Backend | Mô hình | Khi nào dùng |
|---------|---------|--------------|
| `llm` (chính) | **Qwen 2.5-14B** (fine-tuned, chạy trên Modal GPU) | **Mô hình NLU chính trong production** |
| `encoder` | PhoBERT/XLM-R + Logistic (CalibratedClassifierCV) | Dùng để so sánh (benchmark track A/B) |
| `tfidf` | TF-IDF Vectorizer + Logistic | Dùng để so sánh (benchmark track B) |

> **LƯU Ý QUAN TRỌNG:**
> - **Qwen 2.5-14B** là backbone NLU chính — chạy serverless GPU trên Modal Cloud. Ưu tiên dùng weights đã fine-tune (`text_nlu/models/qwen_vismimo`), nếu không có thì dùng base model `Qwen/Qwen2.5-14B-Instruct`.
> - **PhoBERT** và **TF-IDF** là hai track benchmark để so sánh, KHÔNG phải production.
> - **Gemini** (gemini-2.5-flash) đóng hai vai trò: (1) fallback cuối cùng cho NLU nếu Qwen lỗi; (2) mô hình chính cho **NLG** — sinh câu phản hồi tự nhiên, sinh động cho người dùng.
> - Routing: `_call_llm()` ưu tiên Qwen Modal → Qwen local → Gemini (fallback).

#### Các classifier trong NLU:
- **Intent classifier:** Record / Action / Chitchat / Unknown
- **Category classifier:** Food, Transport, Housing, Shopping, Entertainment, Health, Education, Others, Beauty, Social, Salary, Bonus, Business...
- **Record type classifier:** Expense / Income
- **Action type classifier:** loại hành động (SEARCH_RECORD, SET_TONE, SUGGEST_BUDGET, SET_GOAL, SET_LIMIT...)
- **NER (Named Entity Recognition):** trích xuất AMOUNT, ITEM, TIME, COMPANION từ câu

#### Personalization Layer (ưu tiên cao nhất):
1. **Exact match** — so khớp tuyệt đối với lịch sử chỉnh sửa của user
2. **Semantic similarity** — cosine similarity với TF-IDF vectorizer (ngưỡng 0.85)
3. Nếu không match → gọi LLM

#### Quy trình NLU đầy đủ:
```
User text
  → [Personalization Layer] → match? → trả kết quả ngay
  → [Intent Classify]
  → [NER slot extraction]
  → [Category predict]
  → [Record type predict]
  → [Time parse]
  → [LLM fallback nếu confidence thấp < 0.65]
  → [NLG response generation]
```

#### Qwen 2.5-14B (mô hình NLU chính):
- Model: `Qwen/Qwen2.5-14B-Instruct` — ưu tiên dùng bản fine-tune (`qwen_vismimo` / LoRA adapter `qwen_vismimo_lora`)
- Chạy trên Modal GPU (A10G/H100), load 4-bit quantization (bitsandbytes nf4)
- Vai trò chính: **NLU classification** — phân tích câu người dùng, trích xuất intent, slot, category, amount
- File: `expense-ocr-nlu/src/nlu/local_llm.py`

#### Gemini (NLG + fallback NLU):
- Model: `gemini-2.5-flash` (xoay vòng nhiều API key qua `gemini_keys.py`)
- Vai trò 1: **NLG (Natural Language Generation)** — sinh câu phản hồi tự nhiên, sinh động cho Mimo (file: `src/nlg/llm_runner.py`)
- Vai trò 2: **Fallback NLU** — chỉ được gọi khi Qwen không khả dụng
- File: `expense-ocr-nlu/src/llm/gemini_keys.py`

### 3.3 OCR Pipeline (Xử lý hình ảnh hóa đơn)

#### Kiến trúc 2 lớp:
```
Ảnh hóa đơn
  → PaddleOCR (detect vùng text + nhận dạng sơ bộ)
  → VietOCR (vgg_transformer) — đọc lại từng crop để nâng độ chính xác tiếng Việt
  → group_lines() — gom các bounding box thành dòng
  → extract_receipt_summary() — trích xuất tổng tiền, ngày, danh mục
```

#### Các thành phần OCR:
| Thư viện | Version | Vai trò |
|----------|---------|---------|
| PaddleOCR | 2.7.3 | Text detection & recognition (layout detection) |
| PaddlePaddle-GPU | 2.6.1 | Backend GPU cho PaddleOCR |
| VietOCR | 0.3.13 | Nhận dạng chữ tiếng Việt (vgg_transformer model) |
| OpenCV | headless | Xử lý ảnh: decode, crop, color convert |

#### LayoutLMv3:
- Thư mục: `expense-ocr-nlu/bill_ocr/layoutlmv3/`
- Vai trò: Key Information Extraction (KIE) — trích xuất trường dữ liệu (total_amount, date...) từ document layout
- Kết hợp text + bounding box position + visual features
- Được fine-tune trên tập hóa đơn bán lẻ Việt Nam
- Training script: `train_eval.py`, deploy qua Modal GPU

#### PICK KIE:
- File: `expense-ocr-nlu/bill_ocr/receipt_ocr/pick_kie.py`
- Kiến trúc KIE thay thế LayoutLMv3 (trong pipeline thử nghiệm)

#### Rotation Corrector:
- File: `rotation_corrector.py`
- Tự động phát hiện và xoay ảnh hóa đơn chụp nghiêng trước khi đưa vào OCR

### 3.4 System Settings (Backend → AI Engine)
Các thông số được lưu trong bảng `system_settings`:
- `ocr_weight` (default 0.75): trọng số OCR trong fusion
- `nlu_threshold` (default 0.85): ngưỡng confidence NLU
- `date_fallback` (default 'transaction'): cách xử lý ngày khi OCR không đọc được

---

## 4. DATABASE (PostgreSQL)

### 4.1 Các bảng core
| Bảng | Mô tả |
|------|-------|
| `users` | Tài khoản người dùng + profile |
| `refresh_tokens` | JWT refresh token |
| `categories` | Danh mục (system + user-owned) |
| `wallets` | Ví tiền (personal / group) |
| `wallet_members` | Thành viên ví nhóm |
| `transactions` | Giao dịch thu/chi |
| `budgets` | Ngân sách theo tháng |
| `goals` | Mục tiêu tiết kiệm |
| `loans` | Khoản vay/cho vay |
| `chat_sessions` | Phiên chat với Mimo |
| `chat_messages` | Tin nhắn trong phiên chat |
| `user_settings` | Cài đặt cá nhân (verbal_style, theme...) |
| `system_settings` | Cài đặt hệ thống (ocr_weight, nlu_threshold...) |
| `recurring_transactions` | Giao dịch định kỳ |
| `stories` | Nhật ký chi tiêu |
| `bill_retrain_queue` | Hàng đợi fine-tune OCR từ hóa đơn user |

### 4.2 Đặc điểm
- UUID primary key (gen_random_uuid())
- Tương thích PostgreSQL 14+ và CockroachDB
- Số dư ví (`wallets.balance`) là nguồn truth duy nhất — không được tính từ AI

---

## 5. MOBILE APP (Flutter)

### 5.1 Tech Stack
- **Framework:** Flutter SDK ^3.11.1 (Dart)
- **App name:** SpendingDiary, version 1.1.7+17
- **Routing:** go_router ^17.2.3
- **HTTP:** Dio ^5.7.0 + http ^1.2.2
- **State/Cache:** cached_query + cached_query_flutter
- **Charts:** fl_chart ^0.69.2
- **Auth secure storage:** flutter_secure_storage
- **Push notification:** firebase_messaging + flutter_local_notifications
- **Animation:** Lottie (mascot Mimo)
- **Camera/Gallery:** camera + image_picker
- **Font:** Google Fonts

---

## 6. WEB ADMIN (React)

- **Framework:** React 19 + Vite 8
- **Routing:** react-router-dom v7
- **Dành cho:** admin quản trị hệ thống

---

## 7. CÁC ĐIỂM CẦN LƯU Ý KHI BIÊN TẬP LUẬN VĂN

### Đúng với thực tế:
- **Qwen 2.5-14B** (fine-tuned) là backbone NLU chính trong production — chạy trên Modal GPU
- **Gemini** đóng vai trò: (1) sinh câu phản hồi NLG; (2) fallback NLU khi Qwen lỗi
- **PhoBERT** (encoder) và **TF-IDF** là hai track dùng để so sánh/benchmark — không phải production
- Thứ tự ưu tiên gọi LLM: Qwen Modal → Qwen local → Gemini (fallback cuối)
- LayoutLMv3 + VietOCR là OCR pipeline cho hóa đơn — đúng
- PaddleOCR detect vùng text, VietOCR đọc chữ tiếng Việt — đúng (2 bước)
- Số dư luôn lấy từ DB (không AI tự tính) — đúng
- User có thể chỉnh sửa kết quả NLU trước khi lưu — đúng (personalization layer)
- Backend Node.js, mobile Flutter, web-admin React — đúng
- Database: PostgreSQL — đúng
- Deploy AI trên Modal Cloud (serverless GPU) — đúng

### Dễ nhầm / Cần cẩn thận:
- KHÔNG nói PhoBERT là mô hình production chính — PhoBERT chỉ dùng để so sánh benchmark
- KHÔNG nói Gemini là backbone NLU — Gemini chủ yếu lo NLG (sinh câu phản hồi)
- KHÔNG nói Qwen 2.5 là "fallback" — Qwen 2.5 là mô hình NLU chính, Gemini mới là fallback của NLU
- Sentiment analysis: KHÔNG dùng PhoBERT sentiment trong production (`load_chitchat_sentiment_model()` trả về `{"backend": "llm"}`)
- LayoutLMv3 được fine-tune (không phải chỉ dùng off-the-shelf)
- Mascot tên là "Mimo" (không phải tên khác)
- App name trong code là "SpendingDiary" (ghép liền), hiển thị là "Spending Diary"

---

## 8. CẤU TRÚC FILE THAM CHIẾU NHANH

| Muốn kiểm tra | File cần xem |
|--------------|-------------|
| NLU pipeline đầy đủ | `expense-ocr-nlu/src/nlu/pipeline.py` |
| Backend chọn model gì | `expense-ocr-nlu/src/nlu/models.py` |
| LLM handler (Gemini) | `expense-ocr-nlu/src/nlu/llm_intent_handler.py` |
| Encoder (PhoBERT) | `expense-ocr-nlu/src/nlu/encoder_runtime.py` |
| OCR pipeline | `expense-ocr-nlu/bill_ocr/receipt_ocr/pipeline.py` |
| LayoutLMv3 | `expense-ocr-nlu/bill_ocr/layoutlmv3/train_eval.py` |
| Backend AI proxy | `app/backend/src/modules/ai/ai.service.js` |
| Chat service | `app/backend/src/modules/chat/chat.service.js` |
| DB Schema | `app/database/schema.sql` |
| Deploy (Modal) | `expense-ocr-nlu/modal_app.py` |
| Mobile deps | `app/frontend/mobile/pubspec.yaml` |
| Web admin deps | `app/frontend/web-admin/package.json` |

---

*File này được tạo tự động từ phân tích source code. Cập nhật khi có thay đổi kiến trúc lớn.*
