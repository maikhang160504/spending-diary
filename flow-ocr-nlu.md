# TÀI LIỆU LUỒNG XỬ LÝ HỆ THỐNG: NLU, OCR & CẤC PHÂN HỆ DU ÁN

Tài liệu này chuẩn hóa và mô tả chi tiết kiến trúc xử lý dữ liệu, luồng vận hành của hai động cơ AI cốt lõi (NLU, OCR) và sự tích hợp giữa các phân hệ (Backend Node.js, Web-Admin React, Mobile Flutter, expense-ocr-nlu FastAPI).

---

## I. TỔNG QUAN KIẾN TRÚC & PHÂN PHỐI TRÁCH NHIỆM

Hệ thống MoneyStory hoạt động theo mô hình hướng dịch vụ (Service-Oriented Architecture), phân rã rõ ràng giữa logic nghiệp vụ tài chính và động cơ trí tuệ nhân tạo:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        FRONTEND CLIENT LAYER                           │
│  ┌───────────────────────────────┐   ┌──────────────────────────────┐  │
│  │ Mobile Client (Flutter App)   │   │ Web-Admin Portal (ReactJS)   │  │
│  │ - Nhập liệu, Voice, Camera    │   │ - Telemetry, Curation        │  │
│  │ - Quản lý State & Offline     │   │ - Canvas labeling, Retrain   │  │
│  └───────────────┬───────────────┘   └──────────────┬───────────────┘  │
└──────────────────┼──────────────────────────────────┼──────────────────┘
                   │ HTTPS API                        │ HTTPS API
                   ▼                                  ▼
┌────────────────────────────────────────────────────────────────────────┐
│                          BACKEND SERVER LAYER                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Node.js & Express (Orchestrator & Business Logic)                │  │
│  │ - Quản lý User, Wallets, Budgets, Transactions                    │  │
│  │ - Lưu trữ Cloudflare R2 (presigned URL), WebSocket Push          │  │
│  │ - Lọc và chuẩn bị ContextMeta, Proxy Gọi AI Service              │  │
│  └───────────────┬──────────────────────────────────────────────────┘  │
└──────────────────┼─────────────────────────────────────────────────────┘
                   │ HTTPS REST / WebSocket / Local Call
                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                          AI PIPELINE LAYER                             │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ FastAPI Wrapper (Serving Layer)                                  │  │
│  │ - Chuyển đổi HTTP Requests thành Pipeline Calls                  │  │
│  │ - Quản lý Hot-Reload, Lazy Loading, Fallback "Mock" chế độ       │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ expense-ocr-nlu (Core Models / Processing Engine)                │  │
│  │ - NLU Engine: PhoBERT, SpaCy NER, NLG Gemini, Custom Overrides    │  │
│  │ - OCR Engine: PaddleOCR, VietOCR, LayoutLMv3, PICK GCN           │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## II. ĐỘNG CƠ HIỂU NGÔN NGỮ TỰ NHIÊN (NLU PIPELINE)

Phân hệ NLU chịu trách nhiệm chuyển hóa các câu chat tự do, giọng nói của người dùng thành các cấu trúc giao dịch tài chính hoặc hành động điều khiển hệ thống.

### 1. Sơ đồ xử lý NLU đa tầng (Personalization Hybrid Layer)
Khi nhận một đoạn văn bản đầu vào, NLU Service không trực tiếp đưa vào mô hình học máy toàn cục ngay lập tức mà đi qua 3 tầng phân loại để tối ưu hóa tính cá nhân hóa và giảm thiểu chi phí LLM:

```
[Văn bản đầu vào từ user]
          │
          ▼
┌────────────────────────────────────────────────────────┐
│ 1. TIỀN XỬ LÝ (Text Normalization)                     │
│ - Chuẩn hóa dấu câu, viết thường                      │
│ - Xử lý từ lóng tiền tệ (k -> 1.000, củ -> 1.000.000)   │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ TẦNG 1: EXACT MATCH OVERRIDES (Layer 1)                │
│ - Tìm chính xác cụm từ trong user_category_mappings    │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ├─── [Khớp] ───► [Trả về nhãn cá nhân hóa]
                          │
                       [Không khớp]
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ TẦNG 2: SEMANTIC SIMILARITY MATCH (Layer 2)            │
│ - Tính Cosine Similarity bằng TF-IDF Vectorizer        │
│ - So sánh với các câu đã được user sửa đổi trước đó   │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ├─── [Độ tương đồng S ≥ 0.85] ───► [Trả về nhãn cá nhân hóa]
                          │
                       [S < 0.85]
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ TẦNG 3: GLOBAL MODEL INFERENCE (PhoBERT / TF-IDF)      │
│ - Phân loại Intent chính: Record, Action, Chitchat     │
│ - Nếu Chitchat -> Gọi Gemini sinh phản hồi NLG         │
│ - Nếu Record -> Chạy SpaCy NER trích xuất Entity       │
│ - Nếu Action -> Nhận diện Action Type & Time Range     │
└────────────────────────────────────────────────────────┘
```

### 2. Chi tiết các bước xử lý NLU
1. **Tiền xử lý (Normalization)**: Hệ thống sử dụng bộ parser xử lý từ lóng (`preprocess_slang`) để chuẩn hóa các cụm từ địa phương và teencode về số tiền chuẩn:
   - "cành", "k" -> nhân $10^3$ (Ví dụ: `150 cành` -> `150000`).
   - "lít", "loét" -> nhân $10^5$ (Ví dụ: `2 loét` -> `200000`).
   - "củ", "quả", "mâm" -> nhân $10^6$ (Ví dụ: `3 củ` -> `3000000`).
   - "triệu rưỡi", "củ rưỡi" -> `1500000`.
2. **Quy tắc ghi đè cá nhân (Layer 1 & Layer 2)**: 
   - Đọc bảng `user_category_mappings` để giải quyết các trường hợp nhãn cá nhân hóa (ví dụ: "GrabBike" -> user A map vào *Transport*, user B map vào *Essentials*).
   - Nếu Layer 1 (Exact Match) không khớp, Layer 2 sẽ tính toán cosine similarity của vector TF-IDF. Nếu $S \ge 0.85$, áp dụng nhãn đã sửa trong lịch sử.
3. **Mô hình toàn cục (Global Classifier)**:
   - Trích xuất đặc trưng câu qua PhoBERT (`vinai/phobert-base`) thu về vector CLS 768 chiều.
   - Sử dụng bộ phân loại Logistic Regression đã được calibrate bằng thuật toán Sigmoid nhằm thu được xác suất phân phối đáng tin cậy.
4. **Trích xuất thực thể (NER)**:
   - Dùng mô hình SpaCy NER fine-tuned để nhận dạng thực thể: `AMOUNT` (số tiền), `TIME` (thời điểm giao dịch), `PRODUCT` (tên sản phẩm/dịch vụ), `CATEGORY` (danh mục).
5. **Guard Rules**:
   - Nếu mô hình phân loại dự đoán nhãn `Chitchat` nhưng trong câu chứa các biểu thức số tiền rõ ràng (ví dụ: "mới mua cái quần 200k"), hệ thống sẽ ép intent về `Record` để tránh mất giao dịch.
6. **Sinh câu phản hồi tự nhiên (NLG)**:
   - Tích hợp thông tin ví (spent_week, spent_month, budget_remain) do Backend cung cấp.
   - Gửi yêu cầu tích hợp sang Gemini API để sinh câu thoại sinh động theo phong cách (verbal style) và cảm xúc mascot (mimo_emotion).

---

## III. ĐỘNG CƠ TRÍCH XUẤT HÓA ĐƠN (OCR PIPELINE)

Phân hệ OCR chịu trách nhiệm số hóa ảnh chụp hóa đơn vật lý, trích xuất cấu trúc các mặt hàng, tổng tiền, cửa hàng, và phân loại danh mục hóa đơn tổng thể.

### 1. Kiến trúc nhận dạng đa tầng (OCR-KIE Pipeline)
Quy trình trích xuất hóa đơn của MoneyStory được tổ chức thành 5 bước liên tục:

```
[Ảnh hóa đơn vật lý]
          │
          ▼
┌────────────────────────────────────────────────────────┐
│ 1. PHÁT HIỆN VĂN BẢN (PaddleOCR - DBNet)               │
│ - Định vị tọa độ các bounding box chứa chữ             │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 2. HIỆU CHỈNH GÓC XOAY (MobileNetV3 Classifier)        │
│ - Phân loại hướng ảnh (0°, 90°, 180°, 270°)            │
│ - Xoay ảnh về hướng chính xác (0°)                     │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 3. NHẬN DẠNG CHỮ (VietOCR Transformer)                 │
│ - Crop các bounding box                                │
│ - Đọc nội dung chữ tiếng Việt có dấu từng box          │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 4. TRÍCH XUẤT THÔNG TIN KHÓA (LayoutLMv3 / PICK KIE)   │
│ - Phân loại thực thể ngữ nghĩa trực quan               │
│ - Trích xuất: SELLER, TIMESTAMP, TOTAL_COST            │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 5. HỢP NHẤT DỮ LIỆU & PHÂN LOẠI DANH MỤC (Fusion)       │
│ - Quy tắc hình học ghép cặp: (Tên món ↔ Đơn giá)        │
│ - Phân loại danh mục từng món qua category_model       │
│ - Weighted Voting phân loại danh mục hóa đơn tổng      │
└────────────────────────────────────────────────────────┘
```

### 2. Chi tiết các thành phần xử lý OCR
1. **Phát hiện vùng chữ (Text Detection)**: DBNet xác định các vùng có chữ, tạo ra các đa giác/hộp chứa tọa độ chuẩn hóa.
2. **Hiệu chỉnh góc xoay (Angle Corrector)**: Sử dụng MobileNetV3 để phân loại và tự động xoay ảnh bị ngược hoặc nghiêng về góc đứng giúp cải thiện độ chính xác của bước nhận dạng chữ.
3. **Nhận dạng chữ tiếng Việt (VietOCR)**:
   - Sử dụng backbone VGG19 kết hợp LSTM chuỗi và giải mã Attention (Bahdanau Attention) để đọc ký tự, đặc biệt nhận diện tốt các dấu tiếng Việt phức tạp trong điều kiện chụp thiếu sáng hoặc mờ nhòe.
4. **Trích xuất thực thể khóa (LayoutLMv3/PICK)**:
   - LayoutLMv3 kết hợp thông tin đa phương thức: hình ảnh (visual), ngữ nghĩa (textual), và vị trí không gian (layout/bounding box) để gán nhãn thực thể.
   - Nhãn gồm: `SELLER` (tên cửa hàng), `TIMESTAMP` (thời gian), `TOTAL_COST` (tổng tiền thanh toán).
5. **Weighted Voting Categorization**:
   - Sử dụng giải thuật ghép cặp dựa trên tọa độ hình học (y-axis overlap) để liên kết tên món hàng và giá tiền của nó.
   - Dự đoán danh mục của từng món hàng đơn lẻ thông qua mô hình phân loại nhanh.
   - Thực hiện bầu chọn có trọng số (Weighted Voting) theo giá trị của từng món hàng để đưa ra danh mục chung đại diện cho cả hóa đơn:
     $$\text{Score}(C) = \sum_{i \in \text{Items}} \text{Price}_i \times \text{Confidence}_i$$
     Hóa đơn được gán danh mục có điểm số $\text{Score}(C)$ lớn nhất.

---

## IV. LUỒNG XỬ LÝ PHÂN RÃ THEO PHÂN HỆ DỰ ÁN

Hệ thống được thiết kế đồng bộ dữ liệu chặt chẽ qua 4 tầng phân hệ:

### 1. Phân hệ Di động (Mobile Client - Flutter)
- **Speech-to-Text cục bộ**: Sử dụng package `speech_to_text` nhận dạng giọng nói trực tiếp trên máy client, vẽ hoạt họa sóng âm bằng Canvas ngầm, tránh gửi file âm thanh thô lên cloud.
- **Trạng thái Giao dịch chờ (Draft Transaction)**: Nếu NLU nhận dạng được ý định ghi chép giao dịch nhưng không trích xuất được số tiền (hoặc số tiền không rõ), giao dịch sẽ được lưu ở trạng thái nháp (`is_draft = true`, `amount = 0`). UI Flutter hiển thị card cảnh báo màu vàng trên dòng thời gian để nhắc user bấm vào sửa nhanh.
- **Idempotency Protection (Chống click đúp)**: 
   - Kiểm soát các nút bấm xác nhận bằng cờ `isSubmitting` trong `StatefulBuilder`. Khi đang gửi API, vô hiệu hóa các thao tác bấm tiếp theo.
   - Dialog và Bottom Sheet khóa tương tác ngay frame đầu tiên sau click nhằm tránh lỗi gọi `Navigator.pop(context)` 2 lần gây crash màn hình.

### 2. Phân hệ Máy chủ (Backend Orchestrator - Node.js/Express)
- **Xử lý hóa đơn bất đồng bộ**: Khi nhận ảnh hóa đơn, API trả về mã HTTP `202 Accepted` ngay lập tức kèm theo mã `transactionId` ở trạng thái `pending`.
- **WebSocket Gateway (`ws`)**: Quản lý các kết nối thời gian thực của các thiết bị. Khi Background Worker xử lý xong OCR hóa đơn ở phía AI Service, backend cập nhật DB và phát tín hiệu `transaction_done` qua WebSocket đến thiết bị tương ứng để tự động cập nhật giao diện.
- **Cơ chế nén bối cảnh chat (Sliding Window & Summary)**: 
   - Backend lọc metadata ví, chỉ gửi các chỉ số cần thiết (spent_last_month) sang LLM khi NLU phát hiện câu hỏi so sánh thời gian.
   - Chỉ giữ tối đa 4 tin nhắn gần nhất làm context đầy đủ. Các tin nhắn cũ hơn được tóm tắt thành các nhãn hành động gọn nhẹ nhằm giảm tối đa 60% lượng token tiêu thụ.

### 3. Phân hệ Quản trị (Web-Admin Portal - ReactJS & Vite)
- **Fusion Telemetry**: Hiển thị biểu đồ **Tỷ lệ Hội tụ (Fusion Success Rate)** — tỷ lệ % hóa đơn/câu thoại được hệ thống tự động nhận dạng chính xác hoàn toàn cả 3 trường (Amount, Category, Date) mà không cần người dùng sửa đổi.
- **Labeling Canvas Workspace**: Giao diện trực quan cho phép Admin xem các bounding box, văn bản đã nhận dạng của hóa đơn, vẽ/điều chỉnh tọa độ và nhãn thực thể (`SELLER`, `TOTAL_COST`...), phục vụ gán nhãn chính xác.
- **Curation & Retraining Ops**:
   - Tự động gom cụm các chỉnh sửa của người dùng (`user_corrections`) theo tần suất từ cao xuống thấp.
   - Admin duyệt (Curate) để tự động xuất và làm giàu dataset `intent_record.csv` của NLU hoặc đóng gói dữ liệu hình ảnh gửi lên Kaggle để tái huấn luyện LayoutLMv3.
   - Nút trigger chạy script huấn luyện lại ngầm và tự động gửi lệnh reload mô hình cho RAM mà không khởi động lại server AI.

### 4. Module Nghiên cứu & FastAPI (expense-ocr-nlu)
- **FastAPI Endpoint Hub**: Cung cấp API suy luận NLU và OCR, bọc các thư viện Python chuyên biệt (PyTorch, PaddleOCR, VietOCR, Transformers).
- **Hot-Reload Service**: Hỗ trợ nạp đè mô hình mới từ thư mục lưu trữ `/storage/` trực tiếp vào RAM bằng hàm reload nội bộ, đảm bảo tính sẵn sàng cao của API suy luận.
- **Chế độ Mock & Real Fallback**: Nếu không tìm thấy weight thật hoặc lỗi phần cứng (GPU không sẵn dùng), hệ thống tự động chuyển sang chế độ Mock sử dụng Regex và từ điển tĩnh để phục vụ suy luận thô, giúp dịch vụ không bao giờ bị sập.

---

## V. CÁC LUỒNG END-TO-END CHÍNH CỦA HỆ THỐNG

### 1. Luồng nhập chi tiêu bằng Câu chat/Giọng nói (Luồng Text)
Luồng này thực hiện xử lý đồng bộ hoàn toàn vì tải tính toán thấp:

```
[Mobile (Flutter)]         [Backend (Node.js)]       [FastAPI AI Service]      [Database (PostgreSQL)]
        │                           │                         │                           │
        ├─────── 1. Gửi Text ──────>│                         │                           │
        │                           ├─ 2. Truy vấn Wallet ───>│                           │
        │                           │  & Profile chi tiêu     │                           │
        │                           │<─ 3. Trả Wallet Profile─┤                           │
        │                           │                         │                           │
        │                           ├────── 4. Gọi NLU ──────>│                           │
        │                           │  (Chạy 3 tầng phân loại,│                           │
        │                           │   trích NER & sinh NLG) │                           │
        │                           │<───── 5. Trả JSON ──────┤                           │
        │                           │   (Intent, Amount, Cat) │                           │
        │                           │                         │                           │
        │                           ├─ 6. INSERT Transaction ────────────────────────────>│
        │<─ 7. Trả kết quả JSON ────┤  (Hoặc lưu Draft)       │                           │
        │   (Hiển thị Story + Card) │                         │                           │
```

### 2. Luồng quét ảnh hóa đơn chụp (Luồng Ảnh - Bất đồng bộ)
Luồng này sử dụng cơ chế xử lý bất đồng bộ kết hợp WebSockets để tránh khóa giao diện người dùng:

```
[Mobile (Flutter)]         [Backend (Node.js)]       [FastAPI AI Service]      [Database (PostgreSQL)]
        │                           │                         │                           │
        ├───── 1. Gửi ảnh Bill ────>│                         │                           │
        │                           ├─ 2. INSERT Transaction ────────────────────────────>│
        │                           │  (status = 'pending')   │                           │
        │<── 202 Accepted ──────────┤                         │                           │
        │   (Hiển thị loading)      │                         │                           │
        │                           ├─ 3. Gọi xử lý ngầm ────>│                           │
        │                           │  (setImmediate)         │                           │
        │                           │                         ├─ 4. Chạy OCR Pipeline     │
        │                           │                         │  (PaddleOCR, VietOCR,     │
        │                           │                         │   LayoutLMv3, Voting)     │
        │                           │<─ 5. Trả OCR JSON ──────┤                           │
        │                           │                         │                           │
        │                           ├─ 6. UPDATE Transaction ────────────────────────────>│
        │                           │  (status = 'done')      │                           │
        │<── 7. Bắn WebSocket ──────┤                         │                           │
        │   (transaction_done)      │                         │                           │
```

### 3. Luồng gom dữ liệu sửa đổi & Tái huấn luyện (Curation & Retrain)
Luồng vận hành của Quản trị viên để nâng cấp độ chính xác của các mô hình AI:

```
[Web-Admin Portal]         [Backend (Node.js)]       [FastAPI AI Service]      [Database (PostgreSQL)]
        │                           │                         │                           │
        ├─ 1. Yêu cầu gom cụm ─────>│                         │                           │
        │                           ├─ 2. Query Corrections ─────────────────────────────>│
        │                           │  (nhóm cụm bị sửa nhiều)│                           │
        │<─ 3. Trả danh sách cụm ───┤                         │                           │
        │                           │                         │                           │
        │ (Duyệt & Lưu tập Train)   │                         │                           │
        ├─ 4. Duyệt các cụm từ ────>│                         │                           │
        │                           ├─ 5. Ghi tập dữ liệu ───────────────────────────────>│
        │                           │  (intent_record.csv)    │                           │
        │<─ 6. Xác nhận thành công ─┤                         │                           │
        │                           │                         │                           │
        │ (Kích hoạt Huấn luyện)    │                         │                           │
        ├─ 7. Bấm Huấn luyện lại ──>│                         │                           │
        │                           ├─ 8. Gọi API Train ─────>│                           │
        │                           │                         ├─ 9. Chạy retrain ngầm     │
        │                           │                         │  (retrain_all.py)         │
        │                           │                         ├─ 10. Hot-Reload weights   │
        │                           │<─ 11. Báo cáo F1-Score ─┤                           │
        │<─ 12. Trả log/F1-Score ───┤                         │                           │
```