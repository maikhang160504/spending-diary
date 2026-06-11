# Báo cáo công nghệ — MoneyStory (Quản lý chi tiêu + AI)

> Tài liệu mô tả **công nghệ sử dụng**, **cách thức triển khai**, **khó khăn gặp phải** và **hướng tối ưu** cho ba thành phần chính: Backend, Frontend Mobile và module nghiên cứu `expense-ocr-nlu`.  
> Không chứa mã nguồn — chỉ giải thích bằng ngôn ngữ dễ hiểu.

---

## 1. Tổng quan kiến trúc

Hệ thống được thiết kế theo mô hình **microservice phân tầng**, mở rộng thêm phân hệ **Web Admin Dashboard** để phục vụ quản trị và huấn luyện lại AI:

```
Mobile App (Flutter)            Web Admin (React + Vite)
        │  HTTPS + JWT                      │  HTTPS + JWT
        ▼                                   ▼
Backend Node.js (Orchestrator)  ──HTTP──►  AI Service (FastAPI)
        │                                          │
        │ PostgreSQL / CockroachDB                 │ lazy-load
        ▼                                          ▼
   Cloudflare R2 (ảnh)                    expense-ocr-nlu (NLU + OCR + Retrain)
```

**Nguyên tắc quan trọng:**

- **Mobile là client mỏng**: chỉ gửi text/ảnh, hiển thị kết quả, xác nhận hành động — không chạy model ML nặng trên điện thoại.
- **Web Admin là công cụ quản trị**: quản lý quy tắc ghi đè tĩnh, duyệt dữ liệu gom cụm chỉnh sửa, cập nhật prompt và kích hoạt huấn luyện lại mô hình AI.
- **Backend là trung tâm điều phối**: xác thực user, validate dữ liệu, lưu DB, lưu vết các chỉnh sửa (user corrections), làm cầu nối gọi AI Service và quản lý dữ liệu tĩnh.
- **AI Service là lớp inference & training runner**: bọc repo `expense-ocr-nlu` thành API chuẩn, chạy tiến trình train nền (background task) và tải lại model (hot-reload) mà không gây gián đoạn server.
- **expense-ocr-nlu là repo nghiên cứu/train**: chứa dataset (`intent_record.csv`), mã nguồn huấn luyện (`retrain_all.py`) và model weights.

---

## 2. Backend (Node.js / Express)

### 2.1. Công nghệ sử dụng

| Thành phần | Công nghệ | Vai trò |
|------------|-----------|---------|
| Runtime | Node.js ≥ 18 | Chạy server |
| Web framework | Express 4 | REST API |
| Cơ sở dữ liệu | PostgreSQL 14+ hoặc CockroachDB | Lưu user, ví, giao dịch, ngân sách, log AI |
| ORM / query | `pg` (raw SQL) | Truy vấn trực tiếp, không dùng ORM nặng |
| Xác thực | JWT (access + refresh token) | Bearer token trên mọi API (trừ auth) |
| Mật khẩu | bcryptjs | Hash password khi đăng ký |
| OAuth | Google Sign-In (`google-auth-library`) | Đăng nhập bằng Google |
| Validation | Zod | Kiểm tra request trước khi xử lý |
| Upload ảnh | Multer + Cloudflare R2 (S3-compatible) | Presigned URL hoặc proxy upload |
| Gọi AI | Axios → AI Service (port 8000) | Proxy NLU/OCR |
| Real-time | WebSocket (`ws`) | Push kết quả OCR hóa đơn bất đồng bộ |
| API docs | Swagger UI (`/docs`) | Tài liệu OpenAPI tự sinh |
| Logging | Pino | Log JSON có cấu trúc |
| Bảo mật HTTP | Helmet | Header bảo vệ cơ bản |
| Test | Jest + Supertest | Smoke test route/schema |

### 2.2. Cách thức triển khai

Backend đóng vai **orchestrator** — không tự train model, mà điều phối luồng nghiệp vụ:

**Cấu trúc module:**

- `auth` — đăng ký, đăng nhập, refresh token (rotation), logout, `/me`
- `categories` — danh mục hệ thống + user tùy chỉnh
- `wallets` — ví cá nhân/nhóm, thành viên ví chung
- `transactions` — CRUD giao dịch, lọc theo ngày/danh mục/loại
- `budgets` — ngân sách + summary (đã chi / còn lại / vượt hạn mức)
- `stats` — dashboard, thống kê theo tháng
- `ai` — proxy NLU, tạo giao dịch từ text/bill, correction, action confirm/reject
- `upload` — presign R2 hoặc upload trực tiếp qua backend

**Ba luồng nhập chi tiêu chính:**

| Luồng | AI có tham gia? | Cách xử lý |
|-------|-----------------|------------|
| **Text** ("ăn phở 45k") | Có — NLU | BE gọi AI → trích amount + category → auto-save nếu confidence đủ |
| **Story** (ảnh + user nhập tay) | Không | Lưu trực tiếp amount/category user nhập kèm URL ảnh |
| **Scan bill** (ảnh hóa đơn) | Có — OCR + NLU | BE trả HTTP 202 ngay → xử lý nền → push WebSocket khi xong |

**Luồng chat AI (Intent):**

1. Mobile gửi câu → `POST /api/v1/ai/nlu`
2. Backend lấy `profile` ví (spent_week, spent_month, budget_remain…) gửi kèm sang AI Service
3. AI trả intent: `Record` | `Action` | `Chitchat`
4. Backend xử lý tiếp:
   - **Record**: gợi ý/lưu giao dịch
   - **Action** (báo cáo): query DB thật → gắn số liệu vào story LLM
   - **Chitchat**: Gemini viết câu trả lời + chọn emotion mascot
5. Mobile hiển thị bubble chat + sticker MiMo

**WebSocket cho scan bill:**

- Client kết nối `ws://host/ws?token=<JWT>`
- Khi upload bill: BE tạo transaction `processing_status='pending'`, trả `transactionId` ngay
- Background job: OCR → trích xuất → cập nhật DB → gửi `transaction_done` qua WS
- Flutter cập nhật UI không cần polling

**Lưu trữ ảnh:**

- Không lưu file local trên server
- Upload lên Cloudflare R2, DB chỉ lưu `image_url` + `thumbnail_url`
- Giới hạn upload: 8 MB

### 2.3. Khó khăn gặp phải

1. **Đồng bộ async OCR**: User upload bill cần phản hồi nhanh nhưng OCR mất vài giây → giải pháp HTTP 202 + WebSocket push thay vì chờ đồng bộ.
2. **Phân tách trách nhiệm AI vs nghiệp vụ**: NLU chỉ trả structured output (intent, amount, category); BE phải tự query DB cho báo cáo, đặt hạn mức, xóa giao dịch — tránh AI "bịa" số liệu.
3. **CockroachDB vs PostgreSQL**: Schema viết tương thích cả hai; SSL cluster cloud đôi khi cần cấu hình `DATABASE_SSL=no-verify` khi thiếu CA cert.
4. **Action popup & nhớ xác nhận**: Cần bảng `user_confirmed_actions` để không hỏi lại user mỗi lần cùng một loại hành động (ví dụ "xóa giao dịch gần nhất").
5. **Rate limit & chi phí LLM**: Mỗi câu chat có thể gọi Gemini → cần giới hạn theo user_id ở tầng BE.

### 2.4. Hướng tối ưu tiếp theo

- **Cache thực tế**: Tích hợp Redis thực tế thay vì mock cache để giảm tải lượng truy vấn profile ví và các quy tắc ghi đè tĩnh.
- **Queue job OCR**: Sử dụng BullMQ hoặc RabbitMQ để hàng đợi xử lý hóa đơn mượt mà hơn.
- **Phân tách Cluster**: Deploy AI Service trên các node GPU độc lập để tối ưu chi phí hạ tầng và thời gian suy luận.

### 2.5. Phân hệ Web Admin Backend (`/api/admin`)

Backend Node.js mở rộng router chuyên biệt để cung cấp dữ liệu cho Web Admin dashboard qua giao thức REST API:

- **Giám sát chất lượng (Analytics)**: Endpoint `/analytics` tính toán tổng số người dùng, số giao dịch và đặc biệt là **Tỷ lệ Hội tụ (Fusion Success Rate)** — phần trăm giao dịch tự động điền thành công cả 3 trường từ NLU/OCR mà không bị người dùng chỉnh sửa.
- **Tra cứu NLU cá nhân (User Inspector)**: Endpoint `/user-inspector/:userId` trích xuất các từ khóa ghi đè tĩnh (`user_category_mappings`), các câu chỉnh sửa gần đây (`user_corrections`) và thông tin cache của từng tài khoản.
- **Quản lý quy tắc ghi đè (Overrides CRUD)**: Endpoint `/nlu/overrides` (GET/POST/DELETE) cho phép xem và cấu hình thủ công các từ khóa gán nhãn cứng cho từng user.
- **Gom cụm & Duyệt dữ liệu (Curation)**:
  - `/nlu/aggregations`: Nhóm các từ khóa bị sửa đổi nhiều nhất bởi nhiều user khác nhau để phát hiện nhãn sai diện rộng (ví dụ: nhiều user đổi "GrabBike" từ *Entertainment* sang *Transport*).
  - `/nlu/curate`: Duyệt các cụm từ này để **ghi trực tiếp (append)** dưới dạng dòng mới chuẩn hóa vào dataset `intent_record.csv` của AI.
- **Cầu nối điều phối NLU**: `/prompts` (GET/POST) chỉnh sửa system prompts của trợ lý và `/train` (POST) kích hoạt huấn luyện lại model trên FastAPI.

---

## 3. Frontend Mobile (Flutter)

### 3.1. Công nghệ sử dụng

| Thành phần | Package / Công nghệ | Vai trò |
|------------|---------------------|---------|
| Framework | Flutter (Dart SDK ≥ 3.11) | Cross-platform iOS + Android |
| Routing | go_router | Điều hướng declarative, deep link |
| HTTP | http + dio | Gọi REST API backend |
| Auth token | flutter_secure_storage | Lưu JWT an toàn trên device |
| Cache API | cached_query | Cache response, giảm gọi lại |
| Ảnh mạng | cached_network_image | Cache thumbnail/list view |
| Nén ảnh | flutter_image_compress | Giảm dung lượng trước upload |
| Chụp ảnh | camera + image_picker | Story / scan bill |
| Giọng nói | speech_to_text | Nhập câu bằng voice |
| Real-time | web_socket_channel | Nhận kết quả OCR bill |
| Animation | lottie | Hiệu ứng mascot MiMo |
| Google login | google_sign_in | OAuth |
| UI | Material 3 + google_fonts | Theme tùy chỉnh (AppColors, spacing, radii) |

**Web Admin** (phụ): React 19 + Vite — dashboard admin, chưa là trọng tâm mobile.

### 3.2. Cách thức triển khai

**Kiến trúc phân lớp:**

- **Screens** — màn hình UI (home, chat, camera, report, settings, onboarding…)
- **Services** — `ApiClient` tập trung mọi HTTP call + refresh token tự động
- **State** — `TransactionNotifier`, `ThemeController`, onboarding state
- **Widgets** — component tái sử dụng (chat bubble, transaction tile, MiMo overlay…)
- **Utils** — format tiền VND, parse NLU response, map emotion → asset PNG

**Các màn hình chính:**

| Màn hình | Chức năng |
|----------|-----------|
| Splash / Onboarding | Giới thiệu app, chọn vibe MiMo |
| Auth (Login/Register) | JWT + Google Sign-In |
| Home | Tổng quan chi tiêu, gallery story, lịch |
| Chat | Nhập text/voice → NLU → hiển thị bubble + mascot emotion |
| Camera | Chụp story hoặc scan bill |
| Report / Limits / Goals | Xem báo cáo, hạn mức, mục tiêu tiết kiệm |
| Settings | Đổi giọng nói MiMo (Dui Dẻ / Dận Dữ) |

**Luồng Chat AI trên mobile:**

1. User gõ hoặc nói câu → lưu tin nhắn user
2. Gọi `POST /api/v1/ai/nlu` với `runLlm: true`
3. Parse response an toàn (`nlu_parse.dart`)
4. Hiển thị:
   - Text: `gemini_json.story` hoặc `nlg_response`
   - Sticker: `gemini_json.emotion` → file `assets/MiMo/emotions/{Emotion}.png`
5. Nếu `intent == Action`:
   - Báo cáo: hiển thị card số liệu thật trong chat
   - LIMIT/DELETE/GOAL: card xác nhận → user bấm → `POST actions/execute`
6. Nếu `intent == Record`: có thể auto tạo giao dịch

**Quy tắc hiển thị ảnh:**

- List view: chỉ load `thumbnail_url`
- Detail view: load `image_url` full
- Luôn dùng `cached_network_image` — không load binary từ DB

**Cấu hình API:**

- Base URL qua `--dart-define=API_BASE_URL=...` khi build/run
- Android emulator mặc định: `http://10.0.2.2:4000` (map localhost máy host)

### 3.3. Khó khăn gặp phải

1. **Parse NLU không ổn định**: Response AI có nhiều field legacy (`mascot_mood`, `llm_emotion`, `gemini_json.emotion`) → cần layer parse thống nhất.
2. **Phân biệt emotion vs verbalStyle**: Avatar header chat = phong cách user chọn (Cool/Angry); sticker từng câu = emotion LLM trả về — dễ nhầm nếu không tách rõ.
3. **Action confirm chưa dùng hết API**: Backend có `is-confirmed` nhưng mobile đôi khi luôn hiện popup — cần đồng bộ logic "nhớ xác nhận".
4. **Network trên thiết bị thật**: Phải truyền IP LAN (`10.82.57.24:4000`) thay localhost khi test phone + PC cùng mạng.
5. **Kích thước ảnh bill**: Ảnh gốc lớn → nén trước upload để tránh timeout 8 MB.

### 3.4. Hướng tối ưu

- **Offline-first nhẹ**: Cache danh mục + giao dịch gần đây bằng `cached_query` — đã có nền tảng.
- **Skeleton loading** — đã có shimmer widget; mở rộng cho chat và home.
- **Tách ViewModel/Bloc** cho chat screen (hiện logic nặng trong State) — dễ test và maintain.
- **Deep link** qua go_router cho notification "OCR xong".
- **Widget test** cho bubble chat và action confirm card.

---

## 4. expense-ocr-nlu (Module nghiên cứu AI)

Đây là **repo nghiên cứu và train model** — gồm hai nhánh lớn: **NLU văn bản tiếng Việt** và **OCR hóa đơn**. Production không chạy trực tiếp repo này mà qua **AI Service** (`app/ai-service`) bọc lại.

### 4.1. Tổng quan hai pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  NLU TEXT                                                    │
│  "ăn phở 45k" → Intent → Amount → Category → Record type    │
│  "tổng chi tuần này" → Intent Action → action_type + time   │
│  "chào Mimo" → Chitchat → Gemini viết trả lời + emotion     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  OCR BILL                                                    │
│  ảnh hóa đơn → PaddleOCR (detect) → VietOCR (recognize)     │
│              → trích dòng text → rule/keyword → amount + cat  │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.2. NLU văn bản — Công nghệ & cách train

#### 4.2.1. Ba lớp intent (phân loại chính)

| Intent | Ý nghĩa | Ví dụ |
|--------|---------|-------|
| **Record** | Ghi chép giao dịch mới | "Mua trà sữa 45k", "Lương về 12tr" |
| **Action** | Thao tác trên dữ liệu đã có | "Tổng chi tháng này", "Đặt hạn mức 10tr" |
| **Chitchat** | Tán gẫu, không liên quan tiền | "Chào bot", "Cảm ơn nha" |

#### 4.2.2. Model được train

| Task | Phương pháp train | Model / thư viện | Output |
|------|-------------------|------------------|--------|
| **Intent** (Record/Action/Chitchat) | Fine-tune head trên embedding | **PhoBERT** (`vinai/phobert-base`) + Logistic Regression + CalibratedClassifierCV | `intent_encoder.joblib` |
| **Action type** (REPORT, SET_LIMIT, DELETE…) | Tương tự encoder hoặc TF-IDF | PhoBERT encoder hoặc TF-IDF + sklearn | `action_type_encoder.joblib` |
| **Category** (Food, Transport, Shopping…) | TF-IDF hoặc PhoBERT encoder | TF-IDF + Logistic hoặc PhoBERT + head | `category_model.joblib` / `category_encoder.joblib` |
| **Record type** (Expense vs Income) | TF-IDF hoặc encoder | TF-IDF hoặc PhoBERT | `record_type_model.joblib` |
| **NER** (AMOUNT, TIME, PRODUCT, CATEGORY…) | Train spaCy NER | spaCy 3.x pipeline | `models/ner_model/model-best/` |
| **Chitchat sentiment/tone** | **Không train** — dùng LLM | Gemini API | — |

**Lưu ý quan trọng:** Hệ thống **không train PhoBERT end-to-end**. Cách làm phổ biến là:
1. Dùng PhoBERT (hoặc XLM-R) **embed câu** thành vector 768 chiều
2. Train **Logistic Regression** nhẹ trên vector đó
3. Calibrate xác suất bằng sigmoid — trả confidence đáng tin hơn

Cách này nhanh train, inference nhẹ hơn full fine-tune, phù hợp dataset ~15k câu.

#### 4.2.3. Dữ liệu train

**Nguồn dataset** (`text_nlu/datasets/`):

| File | Nội dung | Quy mô (ước lượng) |
|------|----------|---------------------|
| `intent_record.csv` | Câu ghi chép chi tiêu/thu nhập | ~15.000 dòng (sinh + augment) |
| `intent_action.csv` | Câu hành động/báo cáo | Hàng nghìn dòng |
| `intent_chitchat.csv` | Câu tán gẫu | Hàng trăm–nghìn dòng |
| `ner_dataset.jsonl` | Entity gán nhãn cho NER | Nhiều mẫu AMOUNT, TIME, PRODUCT… |

**Cách sinh dữ liệu:**

1. **Local generator** — script sinh câu mẫu theo template (mua/bán, đi cafe vs mua cafe, số tiền VN…)
2. **Gemini augment** — dùng Google Gemini sinh thêm câu đa dạng, rồi audit/sửa nhãn
3. **Fix scripts** — sửa nhãn mơ hồ (`fix_disambiguation_labels.py`, `improve_datasets.py`)
4. **Boost action** — oversample câu Action vì Record chiếm ~10× nhiều hơn → tránh model luôn đoán Record

**Quy tắc gán nhãn** được chốt trong `intent_label_rules.md` — ưu tiên Action/Record khi câu vừa xã giao vừa có nội dung tài chính.

#### 4.2.4. Quy trình train (tóm tắt)

```
Chuẩn bị CSV/JSONL
       ↓
Train TF-IDF models (category, record_type)     ← nhanh, baseline
       ↓
Train PhoBERT encoders (intent, action_type)      ← chính xác hơn
       ↓
ner_prepare.py → train_ner_only.py (spaCy)      ← trích slot
       ↓
Smoke test (smoke_intent_samples.py, verify_task*.py)
       ↓
Deploy weights vào text_nlu/models/
```

**Biến môi trường train:** `ENCODER_MODEL_NAME` (mặc định PhoBERT), `INTENT_ENCODER_MAX_SAMPLES`, `NER_MAX_STEPS` (mặc định 6000 bước spaCy).

#### 4.2.5. Inference NLU (khi chạy thật)

Pipeline `run_nlu()` thực hiện tuần tự:

1. **Tiền xử lý text** — chuẩn hóa tiếng Việt (PyVi tokenizer), bỏ dấu thừa.
2. **Kiểm tra lớp cá nhân hóa (Personalization Hybrid Layer)** — quét qua quy tắc ghi đè tĩnh (Layer 1) và đối chiếu độ tương đồng (Layer 2).
3. **Phân intent toàn cục** (nếu không có nhãn cá nhân hóa) — encoder PhoBERT hoặc TF-IDF fallback.
4. **Guard rules** — nếu có pattern tiền (`45k`, `12tr`) mà intent = Chitchat → ép về Record.
5. **Nếu Record:**
   - NER spaCy trích AMOUNT, PRODUCT, TIME, CATEGORY.
   - Phân loại category + record_type (nếu không có nhãn cá nhân hóa).
   - Hỗ trợ **multi-record** (một câu nhiều khoản).
   - Detect tag đặc biệt: CHA_ME, NGUOI_YEU (ảnh hưởng tone LLM).
6. **Nếu Action:**
   - Phân action_type (REPORT_GENERAL, SET_LIMIT, DELETE_RECORD…).
   - Parse time_range ("tuần này", "tháng 5"…).
   - Parse action_details (verb SET/INCREASE/DECREASE, target category, value).
7. **Nếu Chitchat:**
   - Không train sentiment — gọi **Gemini** viết câu trả lời.
8. **NLG (Natural Language Generation):**
   - Build prompt từ `prompts.json` + profile user (budget_remain, spent_week…).
   - Gemini trả JSON: `{ story, emotion, status }`.
   - Emotion = tên file PNG mascot (Success, Thinking, Hello…).

**LLM backends:** Gemini (chính), Groq (fallback tùy cấu hình). Có retry tự động khi Gemini 503/429 và đổi model dự phòng.

#### 4.2.6. Lớp cá nhân hóa Hybrid (Personalization Hybrid Layer) [TASK-08]

Để giải quyết vấn đề mỗi người dùng có thói quen phân loại khác nhau (ví dụ: cùng là câu "đi Grab", user A coi là *Essentials*, user B coi là *Transport*, user C coi là *Entertainment*), hệ thống triển khai một **Lớp cá nhân hóa Hybrid** gồm 2 tầng bảo vệ chạy trực tiếp trước mô hình phân loại toàn cục:

```
Nhập câu chat của User ──► [Tiền xử lý text]
                                │
                                ▼
              [Layer 1: Exact Overrides Mapping] ── Có match ──► [Trả về nhãn cá nhân hóa]
                                │
                            Không match
                                ▼
              [Layer 2: Cosine Similarity Matching] ── S ≥ 0.85 ──► [Trả về nhãn cá nhân hóa]
                                │
                            Không match
                                ▼
              [Global Model Inference (PhoBERT / TF-IDF)] ───────► [Trả về nhãn mặc định]
```

1. **Layer 1: Exact Match Overrides (Ánh xạ ghi đè tĩnh)**
   - Khi người dùng sửa đổi danh mục của một giao dịch đã được AI nhận diện trên thiết bị di động, backend tự động lưu cụm từ gốc vào bảng `user_category_mappings` kèm theo danh mục mới.
   - Lần suy luận tiếp theo của user đó, hệ thống chuẩn hóa câu (`clean_category_text`) và đối chiếu chính xác (case-insensitive). Nếu trùng khớp từ khóa đã cấu hình ghi đè, hệ thống bỏ qua suy luận của mô hình toàn cục và trả về nhãn của người dùng ngay lập tức.
2. **Layer 2: Semantic Similarity Match (Đối chiếu độ tương đồng ngữ nghĩa)**
   - Nếu Layer 1 không khớp, hệ thống sử dụng **Global TF-IDF Vectorizer** (trích xuất từ mô hình phân loại danh mục toàn cục) để chuyển đổi cụm từ đầu vào và các câu sửa đổi của user đó thành vector đặc trưng.
   - Tính toán **Cosine Similarity** giữa vector đầu vào và tất cả các vector của cụm từ sửa đổi trong lịch sử của người dùng.
   - Nếu giá trị tương đồng lớn nhất $S \ge 0.85$, hệ thống tự động suy diễn rằng câu này đồng nghĩa với câu đã được sửa đổi trước đó và áp dụng nhãn tương ứng (ví dụ: user đã sửa "mua cốc trà sữa" -> nhãn *Food*, thì câu "mua ly trà sữa" sẽ có Cosine Similarity cao và được tự động map vào nhãn *Food*).
3. **Fallback: Global Model Inference**
   - Nếu cả 2 lớp cá nhân hóa không có kết quả, hệ thống chuyển giao cho mô hình học máy toàn cục (PhoBERT hoặc TF-IDF) phân loại bình thường.

#### 4.2.7. Cơ chế Tái huấn luyện & Tải nóng (Retraining & Hot-reload)

Khi dữ liệu gom cụm sửa đổi từ các người dùng được Admin phê duyệt (Curated), luồng tái huấn luyện sẽ được thực thi bất động bộ:

1. **Tích hợp dữ liệu**: Backend ghi các mẫu duyệt mới dưới dạng định dạng CSV vào `text_nlu/datasets/intent_record.csv`.
2. **Kích hoạt ngầm**: Web Admin gọi `/api/admin/train`, backend chuyển tiếp đến FastAPI AI Service gọi `POST /api/v1/nlu/train`.
3. **Background Subprocess**: FastAPI chạy script `retrain_all.py` ở chế độ ngầm bằng trình thông dịch python của môi trường ảo (virtual environment).
4. **Hot-reload trong bộ nhớ**: Sau khi script huấn luyện hoàn tất tạo ra các file `.joblib` mới trên đĩa, tiến trình train gọi `get_nlu_service().reload()`. Hàm này sẽ giải phóng bundle model cũ và nạp lại toàn bộ file weight/model mới vào RAM. Toàn bộ quá trình diễn ra tức thời và không yêu cầu khởi động lại Server FastAPI.

---

### 4.3. OCR hóa đơn — Công nghệ & cách train

#### 4.3.1. Kiến trúc nhận dạng

Pipeline **2 tầng OCR** + **rule extraction**:

| Bước | Công nghệ | Vai trò |
|------|-----------|---------|
| 1. Text detection | **PaddleOCR** | Tìm vùng chữ trên ảnh hóa đơn (bounding box) |
| 2. Text recognition | **VietOCR** (Transformer + VGG19 backbone) | Đọc nội dung từng dòng tiếng Việt |
| 3. Field extraction | Rule-based + keyword | Trích `TOTAL_COST`, danh mục, merchant… |

**Không dùng LLM cho OCR** — toàn bộ nhận dạng chữ bằng deep learning; chỉ phần gợi ý category sau OCR dùng keyword map sang nhãn NLU (Food, Essentials, Shopping…).

#### 4.3.2. Dữ liệu train OCR

| Nguồn | Mô tả |
|-------|-------|
| **MC-OCR 2021** — Vietnamese Receipts | Dataset hóa đơn Việt Nam công khai (Kaggle) |
| Train images | 1.155 ảnh |
| Validation | 391 ảnh |
| Text crops | 6.585 vùng chữ đã crop |

Nhãn gốc MC-OCR: SELLER, ADDRESS, TIMESTAMP, TOTAL_COST, TAX_ID, PRODUCT.

#### 4.3.3. Cách train VietOCR

1. **Pretrain**: Tải weight gốc `vgg_transformer.pth` từ VietOCR (trained trên văn bản tiếng Việt tổng quát)
2. **Fine-tune** trên crop hóa đơn MC-OCR:
   - Backbone: VGG19-BN
   - Sequence model: Transformer (6 encoder + 6 decoder layers)
   - Image height: 32px, max width: 512px
   - Batch size: 16, 8000 iterations
   - Optimizer: OneCycleLR, max_lr 0.0003
   - Augmentation: image aug + masked language model
3. **Output**: `vietocr_receipt.pth` — weight chuyên cho receipt

Train chạy trên **Kaggle GPU** (notebook `vietnamese_receipts_mc_ocr_train.ipynb`) — log và config lưu trong `receipt_ocr_artifacts/`.

**PaddleOCR** dùng model pretrained có sẵn — không fine-tune riêng trong repo; chỉ detect box, VietOCR đọc chữ.

#### 4.3.4. Inference OCR

1. Nhận ảnh (jpg/png)
2. PaddleOCR detect → danh sách bounding box
3. Crop từng vùng → VietOCR recognize → DataFrame các dòng text
4. `extract_receipt_summary()`:
   - Tìm dòng TOTAL / TỔNG CỘNG / THANH TOÁN → parse số tiền VN
   - Quét keyword sản phẩm/merchant → gợi ý category NLU
   - Trả `{ amount, category, confidence, lines[] }`
5. BE yêu cầu user **confirm** trước khi lưu (vì OCR có thể sai)

---

### 4.4. AI Service — lớp bọc production

Repo `app/ai-service` (FastAPI) kết nối `expense-ocr-nlu` với backend:

| Chế độ | Biến env | Hành vi |
|--------|----------|---------|
| Mock (mặc định) | `USE_REAL_NLU=false`, `USE_REAL_OCR=false` | Regex + keyword, ~0ms, không cần GPU |
| Real | `USE_REAL_NLU=true`, `USE_REAL_OCR=true` | Load joblib + PhoBERT + PaddleOCR + VietOCR |

**Lazy load + fallback:** Nếu thiếu weight hoặc import lỗi → log warning, tự fallback mock — **service không crash**.

Response luôn có field `backend: "real" | "mock"` để biết nguồn kết quả.

**Endpoints AI Service:**

| Endpoint | Input | Output |
|----------|-------|--------|
| `POST /api/v1/nlu/infer` | text + profile | intent, amount, category, gemini_json… |
| `POST /api/v1/ocr/image` | multipart image | lines OCR + suggestion |
| `POST /api/v1/expense/from-text` | text | extracted expense + nlu |
| `POST /api/v1/expense/from-bill` | image | extracted + requires_confirmation |

---

### 4.5. Khó khăn trong expense-ocr-nlu

#### NLU

1. **Mất cân bằng lớp** — Record >> Action >> Chitchat → model hay đoán Record cho câu báo cáo → cần oversample Action + guard rules.
2. **Câu mơ hồ đa nghĩa** — "đi cafe 50k" (chi tiêu) vs "đi cafe với bạn" (không có tiền) → cần dataset disambiguation + NER TIME/AMOUNT.
3. **Tiếng Việt không dấu / GenZ** — User gõ "an pho 45k" → PyVi + normalize phải robust.
4. **PhoBERT nặng RAM** — Mỗi uvicorn worker load full model → RAM × số worker.
5. **Phụ thuộc Gemini** — Chitchat và NLG cần API key, bị rate limit; cần fallback model và cache.
6. **Không train sentiment** — Quyết định đúng: tone Chitchat do LLM, không PhoBERT — tránh over-engineering.

#### OCR

1. **Hóa đơn đa dạng** — Layout khác nhau (siêu thị, cafe, điện thoại…) → rule extract TOTAL không luôn đúng.
2. **Ảnh mờ/nghiêng** — PaddleOCR miss box → VietOCR không có gì để đọc.
3. **PaddleOCR + Python version** — Paddle 2.x vs 3.x khác nhau theo Python 3.12 → cần `paddle_compat.py`.
4. **GPU vs CPU** — Train trên Kaggle GPU; inference local CPU chậm (~vài giây/ảnh).
5. **Không có end-to-end deep extraction** — Category sau OCR dựa keyword, chưa train model riêng cho field TOTAL.

### 4.6. Hướng tối ưu expense-ocr-nlu

| Hạng mục | Tối ưu đề xuất |
|----------|----------------|
| NLU intent | Tiếp tục augment Action + hard negative; thử XLM-R multilingual |
| NLU category | Chuyển dần từ TF-IDF sang encoder-only khi đủ GPU |
| NER | Thêm entity MERCHANT, PAYMENT_METHOD; tăng data PRODUCT |
| OCR | Fine-tune Paddle detection trên receipt VN; thêm deskew/preprocess ảnh |
| Inference | ONNX export PhoBERT head; 1 GPU server + request queue |
| User learning (TASK-08) | Exact match correction → user model logistic trên embedding |
| Confidence | Threshold rõ: < 0.7 → bắt user nhập tay, không auto-save |
| LLM cost | Cache câu Chitchat phổ biến; `run_llm=false` cho Record thuần |

---

## 5. Luồng dữ liệu end-to-end (tóm tắt)

### 5.1. User chat "Tổng chi tuần này"

```
Flutter → POST /ai/nlu
    → BE lấy profile ví
    → AI Service → run_nlu → intent=Action, action_type=REPORT_GENERAL, time_range=tuần này
    → BE query stats.dashboard(userId, from, to)
    → BE gắn số liệu thật vào gemini_json.story
    → Flutter hiển thị bubble + card báo cáo + mascot Thinking
```

### 5.2. User scan hóa đơn

```
Flutter chụp ảnh → nén → POST /ai/expense/from-bill
    → BE tạo tx pending, trả 202 + transactionId
    → Background: AI Service OCR (Paddle+VietOCR) → amount + category
    → BE update tx, gửi WebSocket transaction_done
    → Flutter hiện form confirm → user sửa → PATCH transaction → lưu
```

### 5.3. User nhập "trà sữa 35k"

```
Flutter → POST /ai/expense/from-text (autoSave=true)
    → NLU: intent=Record, amount=35000, category=Food
    → BE tạo transaction ngay nếu confidence đủ
    → Flutter refresh home + streak celebration
```

### 5.4. Quy trình Curation & Huấn luyện lại NLU

```
User sửa giao dịch (Mobile) ──► Lưu user_corrections (Postgres)
                                          │
                                   Web Admin tải dữ liệu
                                          │
                                          ▼
Web Admin duyệt chỉnh sửa ──► API /nlu/curate ──► Ghi vào intent_record.csv
                                                           │
                                                           ▼
Web Admin bấm "Retrain"  ──► API /train ────────► Chạy retrain_all.py (ngầm)
                                                           │
                                                           ▼
FastAPI reload bundle ◄── Tải model .joblib mới ◄── Model mới lưu lên đĩa
```

---

## 6. Cơ sở dữ liệu (liên quan BE)

Các bảng chính:

| Bảng | Mục đích |
|------|----------|
| `users` | Tài khoản, vibe, role |
| `wallets` / `wallet_members` | Ví cá nhân & nhóm |
| `transactions` | Giao dịch (amount, category, source, ai_extracted, image_url, processing_status, ai_meta) |
| `categories` | Danh mục (code khớp nhãn AI: Food, Transport…) |
| `budgets` | Hạn mức chi tiêu |
| `ai_logs` | Log mọi request AI (debug, admin, latency_ms, backend) |
| `user_corrections` | Lưu log lịch sử sửa nhãn NLU của người dùng để admin gom cụm và làm giàu dữ liệu train |
| `user_category_mappings` | Bảng quy tắc ghi đè tĩnh (Layer 1 exact match) map keyword -> category của từng user |
| `user_confirmed_actions` | Nhớ các hành động nguy hiểm đã được xác nhận (TASK-09) |
| `chat_messages` | Lịch sử chat |

### Chi tiết các bảng cá nhân hóa NLU:

#### Bảng `user_category_mappings` (Layer 1 Exact Match)
- `user_id`: UUID (Khóa ngoại tham chiếu `users`)
- `keyword`: VARCHAR (Từ khóa được chuẩn hóa viết thường, ví dụ: 'grab')
- `category_code`: VARCHAR (Danh mục đích, ví dụ: 'Transport')
- `updated_at`: TIMESTAMP
- *Ràng buộc khóa chính hợp phần*: `(user_id, keyword)`

#### Bảng `user_corrections` (Nhãn sửa đổi & Dataset Curation)
- `id`: UUID (Khóa chính)
- `user_id`: UUID (Khóa ngoại tham chiếu `users`)
- `text`: TEXT (Cụm từ gốc user đã nhập)
- `intent`: VARCHAR (Intent sửa đổi, ví dụ: 'Record')
- `category_code`: VARCHAR (Danh mục đích)
- `record_type`: VARCHAR (Loại giao dịch, 'Expense' hoặc 'Income')
- `action_type`: VARCHAR (Loại hành động nếu có)
- `predicted`: JSONB (Kết quả dự đoán gốc của AI trước khi sửa)
- `source`: VARCHAR (Nguồn ghi nhận, mặc định 'user')
- `created_at`: TIMESTAMP

Hỗ trợ **PostgreSQL** local và **CockroachDB** cloud (GCP asia-southeast1).

---

## 7. Kết luận

| Thành phần | Điểm mạnh | Hạn chế hiện tại |
|------------|-----------|------------------|
| **Backend** | Orchestration rõ, JWT + R2 + WS async bill, API Admin tích hợp đầy đủ | Chưa hỗ trợ đa vùng thực tế cho cache |
| **Frontend** | Flutter cross-platform mượt mà, chat + mascot UX sinh động | Logic chat screen còn dày, cần tách state |
| **Web Admin** | Giao diện React 19 tối giản, Fusion telemetry, curation trực quan, retraining hot-reload tiện lợi | Giao diện quản lý phân quyền còn đơn giản |
| **expense-ocr-nlu** | Pipeline NLU 3 intent + NER + OCR 2 tầng VN, Personalization Hybrid Layer tối ưu, Retraining hot-reload ngầm | PhoBERT nặng RAM; OCR rule-based |

Ba phần được **tách biệt có chủ đích**: nghiên cứu/train ở `expense-ocr-nlu`, inference bọc ở `ai-service` (FastAPI), nghiệp vụ và bảo mật ở `backend` (Express), trải nghiệm ở `mobile` (Flutter) và quản trị tại `web-admin`. Cách này cho phép train lại model mà không rebuild app, và scale AI service độc lập với API chính.

---

## 8. Phân hệ Web Admin Dashboard (Vận hành & Giám sát NLU)

Web Admin được thiết kế dành cho Đội ngũ Vận hành (Ops) và Kỹ sư AI để kiểm soát chất lượng nhập liệu của hệ thống mà không cần thao tác qua cơ sở dữ liệu.

### 8.1. Các thành phần giao diện chính

1. **Dashboard Hội tụ (Fusion Telemetry)**
   - Trực quan hóa số liệu tổng quan hệ thống: Số lượng người dùng, tổng số giao dịch chi tiêu, tổng số tiền.
   - **Chỉ số Hội tụ (Fusion Success Rate)**: Phản ánh khả năng làm việc chính xác đồng thời của cả NLU và OCR (tự động nhận diện chính xác toàn bộ Số tiền, Danh mục và Ngày tháng của giao dịch mà người dùng không cần sửa đổi bất kỳ trường nào).
2. **Quản lý Quy tắc Ghi đè Tĩnh (Layer 1 Config)**
   - Hiển thị danh sách toàn bộ quy tắc ghi đè `user_category_mappings` của toàn hệ thống.
   - Cho phép Admin thêm mới hoặc xóa bỏ thủ công các quy tắc map cứng keyword cho một người dùng bất kỳ.
3. **Gom cụm & Duyệt dữ liệu (Correction Clusters & Dataset Curation)**
   - Tự động thống kê, gom cụm các câu bị người dùng sửa nhãn nhiều nhất từ bảng `user_corrections` (được sắp xếp theo tần số xuất hiện giảm dần).
   - Admin có thể chọn một hoặc nhiều câu sửa đổi tiêu biểu, kiểm tra nhãn gốc và nhãn sửa đổi rồi bấm **Duyệt (Curate)**. Hệ thống sẽ tự động format và append các câu này vào dataset huấn luyện `intent_record.csv`.
4. **Quản lý Vòng đời Huấn luyện (Retraining Ops)**
   - Hiển thị trạng thái huấn luyện thời gian thực (Đang train / Rảnh rỗi).
   - Nút **Huấn luyện lại (Trigger Retrain)**: Chạy subprocess huấn luyện ngầm `retrain_all.py` ở AI Service, sau khi hoàn tất sẽ tự động nạp chồng (hot-reload) model mới trong RAM.
5. **Tra cứu & Khôi phục NLU Cá nhân (User NLU Inspector)**
   - Cho phép nhập `user_id` để kiểm tra chi tiết cấu hình cá nhân hóa của tài khoản đó.
   - Hiển thị chi tiết danh sách mappings và corrections của người dùng.
   - Nút **Clear & Reload Cache**: Invalid cache của user đó để giải phóng bộ nhớ đệm (hoạt động giống như lệnh xóa khóa `user_exact:{userId}` và nạp lại dữ liệu đồng bộ).
6. **Quản lý Kịch bản Chat & Prompt (Bot Prompts Management)**
   - Giao diện chỉnh sửa trực tiếp cấu hình file `prompts.json` (System Prompt và các kịch bản Persona cho mascot MiMo).
   - Sau khi lưu, model NLG sẽ tự động reload cấu hình mới mà không cần khởi động lại.

---

*Tài liệu tham chiếu nội bộ: `app/README.md`, `app/backend/README.md`, `app/ai-service/README.md`, `expense-ocr-nlu/ARCHITECTURE_TRIEN_KHAI.md`, `expense-ocr-nlu/command.md`, `flow_intent_action.md`, `architecure_webadmin.md`.*

## 9. Tối ưu hóa Token & Bảo vệ Idempotency (Cập nhật 05/06/2026)

Hệ thống đã triển khai hai nhóm cải tiến quan trọng liên quan đến tối ưu hóa tài nguyên AI và chống lỗi trùng lặp dữ liệu do thao tác phía Client:

### 9.1. Tối ưu hóa Token tiêu thụ (Token Consumption Optimization)
Nhằm giảm thiểu dung lượng Token đẩy vào LLM (Gemini/Groq) trong các cuộc hội thoại dài và phức tạp, 3 tầng tối ưu hóa đã được áp dụng:
1. **Lớp nén dữ liệu Wallet Profile**:
   - Tích hợp tính toán lũy kế MoM (Month-over-Month) trực tiếp trong một query SQL ở Backend (`spent_last_month`), giúp AI so sánh được chi tiêu tháng trước mà không cần kéo danh sách giao dịch thô.
   - Lớp NLU lọc metadata động: Chỉ đính kèm số liệu `spent_last_month` vào prompt khi phát hiện người dùng hỏi các câu có ý định so sánh thời gian (ví dụ: "tháng trước", "MoM").
2. **Cơ chế Sliding Window (Cửa sổ trượt)**:
   - Trong luồng chat dài, Backend chỉ giữ lại tối đa **4 tin nhắn gần nhất** (2 lượt tương tác đầy đủ) làm bối cảnh chi tiết.
3. **Rule-based Session Summarization (Tóm tắt hành động cũ)**:
   - Các tin nhắn vượt ngoài sliding window sẽ được tóm tắt rút gọn tự động thông qua việc giữ lại nhãn hành động chính (như `REPORT`, `SEARCH`, `SUGGEST_BUDGET`), loại bỏ các chi tiết thừa thãi và lưu trữ trong `chat_summary` để làm bối cảnh rút gọn.
   - Nhờ vậy, lượng Token tiêu thụ cho bối cảnh chat giảm tới **60%**, đồng thời giữ được tính liên kết (multi-turn) như khi người dùng ra lệnh tiếp nối: "xóa giao dịch thứ hai vừa tìm được".

### 9.2. Bảo vệ tính Idempotency (Anti-Double-Tap Guard)
Để loại bỏ hoàn toàn các lỗi tạo giao dịch trùng lặp, tạo mục tiêu trùng lặp, hoặc double pop/double action do người dùng bấm liên tục vào các nút xác nhận trên Mobile, các cơ chế sau đã được thiết lập:
1. **Trạng thái vô hiệu hóa nút (isSubmitting State)**:
   - Tất cả các form Bottom Sheet quan trọng (Tạo mục tiêu, Sửa mục tiêu, Thêm tiền đóng góp, Đặt hạn mức chi tiêu mới) đều được bọc trong `StatefulBuilder` và kiểm soát bởi biến cờ `isSubmitting`. Khi nút được bấm, cờ này ngay lập tức chuyển sang `true`, vô hiệu hóa (`onPressed: null`) toàn bộ tương tác cho đến khi tiến trình đóng modal hoặc gọi API hoàn tất.
2. **Ngăn chặn Double-Pop trong Dialog xác nhận**:
   - Khi bấm "Xóa" trên các `AlertDialog` (Xóa mục tiêu, Xóa lịch sử chat, Xóa thành viên ví chung), trạng thái `isSubmitting = true` lập tức được kích hoạt để chặn người dùng click double. Điều này ngăn việc Flutter gọi `Navigator.pop(context)` hai lần liên tiếp (gây lỗi pop nhầm màn hình cha phía sau).
3. **Cập nhật trạng thái tức thời (Optimistic UI Flags)**:
   - Đối với các nút xác nhận hành động AI (Confirm / Reject) hoặc Lưu giao dịch từ bubble chat, ứng dụng chuyển đổi ngay cờ `msg.isSaved = true` / `msg.isConfirmed = true` tại entry-point của hàm gọi API, khiến các nút biến mất/chuyển thành trạng thái thành công ngay lập tức ở frame vẽ tiếp theo. Nếu API lỗi, hệ thống sẽ khôi phục lại trạng thái `false` và hiển thị Banner thông báo.

*Cập nhật: 05/06/2026*

## 10. Nhập liệu Giọng nói, Giao dịch chờ & Quản lý Quyền Graceful (Cập nhật 08/06/2026)

Hệ thống đã tích hợp toàn diện module giọng nói kết hợp cơ chế xử lý giao dịch chờ (Draft) và kiến trúc cấp quyền động native trên ứng dụng di động:

### 10.1. Xử lý âm thanh & Chuẩn hóa Từ lóng Tiếng Việt
1. **Thu âm & STT cục bộ**:
   - Để tối ưu hóa băng thông mạng và độ nhạy của phản hồi, Client sử dụng thư viện `speech_to_text` thực hiện Speech-to-Text trực tiếp trên thiết bị (Local STT).
   - Thiết kế widget hoạt họa sóng âm `WaveformVisualizer` vẽ dải thanh biên độ động theo thời gian thực (Microphone amplitude) trong composer chat để tăng trải nghiệm tương tác.
2. **Bộ chuẩn hóa từ lóng tiền tệ (Teencode Normalizer)**:
   - Bản dịch thô được chuyển lên FastAPI NLU để đi qua bộ lọc `preprocess_slang` trong `text.py`.
   - Sử dụng Regex kết hợp bảng ánh xạ để xử lý các từ lóng:
     - `cành`, `k` -> nhân 1.000 (Ví dụ: `120 cành` -> `120.000`)
     - `lít`, `xị`, `sị`, `loét` -> nhân 100.000 (Ví dụ: `3 loét` -> `300.000`)
     - `củ`, `quả`, `mâm` -> nhân 1.000.000 (Ví dụ: `1.5 củ` -> `1.500.000`)
     - `chục` -> nhân 10.000 (Ví dụ: `2 chục` -> `20.000`)
     - `nửa triệu` / `nửa củ` -> `500.000`
     - `củ rưỡi` / `triệu rưỡi` -> `1.500.000`
     - Tự động map các chữ số tiếng Việt (`một`, `hai`, `ba`...) đứng trước đơn vị tiền tệ lóng sang chữ số tương ứng trước khi parse.

### 10.2. Cơ chế Giao dịch chờ (Draft Fallback) & Timeline Card
1. **Fallback khi thiếu tiền**:
   - Nếu người dùng nói câu ghi chép chi tiêu nhưng quên hoặc không thể phát âm rõ số tiền (ví dụ: "đi mua sắm đồ Tết"), NLU vẫn phân tích intent là `Record` và category là `Shopping`.
   - Backend Node.js thực thi lưu giao dịch với `is_draft = true` và `amount = 0` thay vì bỏ qua hay báo lỗi.
2. **Timeline Draft UI**:
   - Giao dịch nháp được biểu diễn bằng một thẻ màu vàng nổi bật kèm icon Micro và lời nhắc: *"Bạn quên chưa nhập số tiền, chạm vào đây để sửa nhanh nhé!"*.
   - Chạm vào thẻ sẽ mở Bottom Sheet điền nhanh số tiền (hỗ trợ nhập nhanh 50k, 100k, 200k, 500k) và lưu chính thức về thẻ thường tức thời qua API.

### 10.3. Logic Fusion (Gộp Bill + Voice)
- Khi chụp hóa đơn trong Camera, tại màn hình xác nhận (CameraConfirmScreen), người dùng có thể nhấn giữ nút Microphone để nói mô tả ngắn (ví dụ: "cái này ăn trưa với đồng nghiệp").
- App gửi file text giọng nói lên `/ai/nlu` lấy `category` và `note` ghi đè vào form, đồng thời vẫn bảo toàn số tiền (`amount`) chính xác được bóc tách từ ảnh hóa đơn qua OCR.

### 10.4. Quản lý Quyền hệ thống Graceful (Dynamic Permissions)
- Áp dụng triệt để nguyên tắc **Cấp quyền tại thời điểm sử dụng (Just-in-Time Request)** thay vì xin cấp quyền dồn dập lúc khởi động:
  - **Camera**: Chỉ kiểm tra và xin cấp khi mở tính năng chụp bill/story.
  - **Microphone**: Kiểm tra và yêu cầu khi nhấn giữ thu âm chat hoặc màn hình xác nhận hóa đơn.
  - **Photos Library**: Kiểm tra và yêu cầu khi chọn ảnh từ Gallery hoặc cập nhật ảnh đại diện ở Settings.
  - **Notification**: Yêu cầu khi người dùng gạt bật switch thông báo ở Settings.
- Nếu quyền bị từ chối vĩnh viễn (Permanently Denied), ứng dụng tự động hiển thị AlertDialog giải thích native và cung cấp nút liên kết mở thẳng trang Cài đặt (Settings) của ứng dụng trên hệ điều hành.
- Toàn bộ callbacks được kiểm tra `mounted` an toàn để triệt tiêu lỗi rò rỉ hay crash giao diện Flutter.

*Cập nhật: 08/06/2026*

## 11. Cải Thiện Trải Nghiệm & Ổn Định — Phase 1 (Cập nhật 08/06/2026)

### 11.1. WebSocket Exponential Backoff Reconnect
- Nâng cấp cơ chế kết nối lại WebSocket trong `AppShell` từ **delay cố định 5 giây** sang **Exponential Backoff + Jitter**:
  - Công thức tính delay: `min(2^attempt × 1000ms + random(0..1000ms), 60000ms)`
  - Lần thử 1: ~1-2s, lần 2: ~2-5s, lần 3: ~4-9s,... tối đa 60 giây.
  - Khi kết nối thành công, counter `_reconnectAttempt` tự động reset về 0.
- Sau mỗi lần reconnect thành công, client tự động gửi event `SYNC_STATUS` qua WebSocket để backend kiểm tra và đẩy lại các event đã bỏ lỡ trong thời gian mất kết nối (ví dụ: kết quả OCR bill đã xử lý xong).

### 11.2. Draft Reminder Banner (Nhắc nhở Giao dịch Chờ)
- Thêm banner nổi bật hiển thị ở **đầu màn hình Home** (ngay dưới Dashboard summary, trước Timeline) khi có giao dịch chờ (Draft) chưa điền số tiền.
- **Thiết kế Banner**: Gradient vàng (Amber) với hiệu ứng slide-in + fade animation khi xuất hiện, hiển thị icon ⚡, text "Bạn có N giao dịch chưa điền tiền" và badge đếm số lượng.
- **Tap vào Banner**: Mở `_DraftListSheet` — Bottom Sheet liệt kê tất cả Draft kèm danh mục, thời gian tạo (timeAgo: "3 ngày trước") và nút "Điền ngay" màu cam cho từng mục.
- **Quick Fill**: Mỗi Draft item khi tap vào sẽ mở Bottom Sheet điền tiền nhanh (TextField + 4 quick chips: 50k, 100k, 200k, 500k), gọi API cập nhật `amount` và `isDraft = false`, sau đó tự động refresh Timeline.

### 11.3. Nâng cấp Biểu đồ Report với fl_chart
- Thay thế toàn bộ 3 biểu đồ vẽ tay bằng `CustomPaint` trong Report Screen bằng thư viện `fl_chart` (v0.69.2) chuyên nghiệp:
  1. **Bar Chart (Chi tiêu theo ngày)**: Cột bo tròn với gradient teal, trục Y tự động scale (`_niceInterval`), tooltip hiển thị VND formatted khi chạm, animation 400ms.
  2. **Pie/Donut Chart (Chi tiêu theo danh mục)**: Hiệu ứng touch-expand (phóng to section khi chạm), hiển thị % tại section đang chạm, text "Tổng" + formatVnd ở tâm donut, animation 600ms.
  3. **Line Chart (Xu hướng tiết kiệm)**: Đường cong Bezier mượt (curveSmoothness 0.35), gradient fill phía dưới, dots tại mỗi data point với tooltip, trục tự động scale.
- Tất cả biểu đồ đều sử dụng `context.palette` để tương thích Dark/Light mode.

*Cập nhật: 08/06/2026*

## 12. Khắc phục lỗi và Đề xuất tối ưu hóa Load dữ liệu (Cập nhật 11/06/2026)

Hệ thống đã triển khai nhóm sửa lỗi giao diện, nghiệp vụ di động và cơ sở dữ liệu backend liên quan đến tệp `fix_app.json`, đồng thời đề xuất phương án tối ưu hóa hiệu năng tải dữ liệu:

### 12.1. Nhóm sửa lỗi Backend & PostgreSQL
1. **Lỗi cú pháp DISTINCT ON**:
   - Sửa lỗi truy vấn `SELECT DISTINCT ON` trong hàm `_fetchUserCorrections` tại [ai.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/ai/ai.service.js) bằng cách đưa mệnh đề xử lý chuẩn hóa chuỗi và sắp xếp thời gian vào một subquery riêng. Điều này giúp đảm bảo tuân thủ cấu trúc cú pháp của PostgreSQL khi cột trong `DISTINCT ON` bắt buộc phải khớp chính xác với cột đầu tiên trong `ORDER BY`.
2. **Quyền truy cập Story trong ví chung**:
   - Chỉnh sửa logic truy vấn chi tiết Story tại [stories.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/stories/stories.service.js), cho phép thành viên thuộc ví chung được phép xem chi tiết Story của nhau thay vì chỉ giới hạn cho chủ sở hữu Story, loại bỏ lỗi phân quyền xem Story.

### 12.2. Nhóm sửa lỗi và Tối ưu hóa UI Mobile (Flutter)
1. **Đồng bộ hóa Trạng thái Ví khi Thêm Story/Ảnh**:
   - Khắc phục sự cố nhầm lẫn ví khi chụp hóa đơn/thêm ảnh:
     - Khi quay lại màn hình Home từ ví chung, ứng dụng tự động khôi phục biến tĩnh `ApiClient.lastSelectedWalletId` về đúng ví cá nhân đang active của Home screen.
     - Danh sách ví tải về từ API được sắp xếp thống nhất (`personal` lên đầu) trong các màn hình Camera để đảm bảo ví mặc định khi scan hóa đơn luôn nhất quán.
     - Bổ sung ô chọn ví (**Ví lưu**) trực tiếp dạng Dropdown trong Bottom Sheet chỉnh sửa giao dịch tại màn hình xác nhận hóa đơn [camera_confirm_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/camera/camera_confirm_screen.dart).
2. **Tắt Thông báo Tự động**:
   - Khi truy cập ví chung, ứng dụng tự động đóng các Banner thông báo dạng nổi (In-app Notification) và dọn sạch (Dismiss) các thông báo liên quan trên thanh trạng thái hệ thống của thiết bị di động bằng phương thức `cancelAll()`.
3. **Hiển thị Vương Miện Trưởng Nhóm**:
   - Sửa đổi hiển thị vương miện (`showCrown`) trên danh sách story, chỉ gán biểu tượng vương miện cho người dùng là Chủ ví (`ownerId`), loại bỏ việc tự hiển thị cho mọi người dùng tự tạo story.
4. **Cấp quyền Gallery Trực tiếp**:
   - Loại bỏ lớp kiểm tra quyền lưu trữ/ảnh thủ công khi đổi ảnh đại diện hay upload hóa đơn. Sử dụng trực tiếp trình chọn ảnh hệ thống của package `image_picker` (vốn tự động phân quyền context-less trên iOS và Android 10+), tránh các lỗi từ chối giả lập.
5. **Mic Thu âm & Trạng thái Lưu Giao dịch**:
   - Nút Mic thu âm được hiển thị mặc định, bổ sung SnackBar hướng dẫn khi hệ thống STT không hoạt động (như trên emulator).
   - Nút "Lưu giao dịch" trong chat không bị ẩn đi sau khi lưu mà chuyển sang trạng thái vô hiệu hóa kèm nhãn `✓ Đã lưu` / `✓ Đã lưu tất cả` để tránh hiện tượng giật màn hình (layout jumping).

### 12.3. Đề xuất Kiến trúc Tối ưu hóa Tải dữ liệu & Đồng bộ hóa
Nhằm giải quyết vấn đề ứng dụng phải gọi API và tải lại dữ liệu quá nhiều lần, chúng tôi đề xuất kiến trúc đồng bộ hóa chia làm 4 giai đoạn:
1. **Giai đoạn 1: Query Caching**:
   - Chuyển đổi toàn bộ luồng load dữ liệu tại `ShareWalletScreen` sang thư viện `cached_query` (sử dụng các key cache động giống như trang Home). Dữ liệu sẽ được giữ trong bộ nhớ 10 phút và tự động cập nhật ngầm nếu quá 30 giây stale, triệt tiêu việc hiện vòng quay loading mỗi lần chuyển màn hình.
2. **Giai đoạn 2: WebSocket Reactive Sync (Đồng bộ thời gian thực)**:
   - Tận dụng kết nối WebSocket sẵn có tại `AppShell`. Khi backend nhận được yêu cầu thêm/sửa giao dịch từ bất kỳ user nào trong nhóm, backend sẽ broadcast một event `DB_UPDATE` qua WebSocket. Mobile nhận event này sẽ tự động gọi `AppQueries.invalidateWalletData()` để tải lại ngầm phần dữ liệu bị thay đổi mà không cần người dùng kéo thả refresh.
3. **Giai đoạn 3: Phân trang (Pagination / Lazy-load)**:
   - Triển khai cuộn vô hạn (infinite scroll) cho lịch sử giao dịch. Chỉ tải 15-20 giao dịch đầu tiên và tải tiếp trang sau khi user cuộn xuống cuối màn hình.
4. **Giai đoạn 4: Đồng bộ hóa cơ sở dữ liệu cục bộ (Offline-First Local DB)**:
   - Tích hợp SQLite (thông qua Drift ORM) hoặc Hive trên thiết bị di động.
   - Thiết lập giao thức đồng bộ hóa delta (`/api/v1/sync?since=timestamp`). Client chỉ lấy các phần dữ liệu thay đổi kể từ lần đồng bộ trước đó và ghi đè vào DB cục bộ. UI sẽ lắng nghe (stream) trực tiếp từ DB cục bộ, cho phép app hiển thị dữ liệu tức thời (0ms load) và hoạt động offline hoàn toàn.

*Cập nhật: 11/06/2026*


