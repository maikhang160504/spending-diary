
bản chất của hai luồng nhập liệu cốt lõi trong hệ thống của chúng ta được phân tách dựa trên loại dữ liệu đầu vào mà người dùng cung cấp từ Mobile:

Luồng 1 (Luồng Text): Người dùng nhập liệu bằng giọng nói/văn bản chat.

Luồng 2 (Luồng Ảnh): Người dùng chỉ chụp và gửi ảnh hóa đơn (Bill).

Dưới góc độ Kiến trúc sư AI và PO, tôi xin chuẩn hóa lại toàn bộ cấu trúc xử lý, sơ đồ dòng chảy dữ liệu (Data Flow) và logic vận hành của 2 luồng này. Chúng ta sẽ áp dụng triệt để nguyên tắc xử lý song song/bất đồng bộ tại Backend (BE) để tối ưu tốc độ, đồng thời nhúng bộ lọc ContextMeta và bộ quy tắc kích hoạt Prompt ẩn (CHA_ME, NGUOI_YEU...) đã thống nhất.

🏛️ LUỒNG 1: LUỒNG TEXT (Người dùng nhập liệu bằng Hội thoại/Văn bản)
Áp dụng khi người dùng gõ hoặc nói một câu tâm sự/ra lệnh (Ví dụ: "Dẫn bồ đi ăn kỷ niệm một năm hết 500k" hoặc "Mới chuyển khoản báo hiếu mẹ 2 triệu").

[ FE (Mobile) ]              [ Backend (BE) ]          [ PostgreSQL ]       [ LLM Engine ]
       │                            │                         │                    │
       ├─────── 1. Gửi Text ───────>│                         │                    │
       │     + Client Context       ├─ 2. Đoán Category (ML)  │                    │
       │                            ├─ 3. Bóc Số tiền (Regex) │                    │
       │                            ├─ 4. Quét Prompt Ẩn ─────>                    │
       │                            │                         │                    │
       │                            ├─ 5. Truy vấn Wallet ───>│                    │
       │                            │<── Trả Wallet Status ───┤                    │
       │                            │                                              │
       │                            ├───────────── 6. Gửi Gói Meta + Data ────────>│
       │                            │<──────────── 7. Trả câu thoại Story ─────────┤
       │                            │                                              │
       │                            ├─ 8. Lưu Transaction ───>│                    │
       │<─── 9. Trả kết quả JSON ───┤                         │                    │
       │    (Hiển thị Story ngay)   │                         │                    │

1. Hiện trạng
Hệ thống hoàn toàn không có ảnh hóa đơn. Do đó, chúng ta mất đi lớp dữ liệu kiểm chứng khách quan từ OCR (không có OCR_Raw).

Thách thức: LLM và Core ML phải tự bóc tách số tiền và danh mục hoàn toàn dựa trên câu chữ tự do, vốn có cấu trúc rất lộn xộn của Gen Z.

2. Giải pháp Kiến trúc tại Backend (BE)
Xử lý Đồng bộ Tốc độ cao (Latency < 100ms): Vì đầu vào chỉ là Text, không có tác vụ quét ảnh nặng nề của PaddleOCR, BE sẽ xử lý đồng bộ và trả kết quả ngay lập tức để app hiển thị lên Story Timeline.

Thực thi Logic Fusion & Phân loại:

Category: BE ném chuỗi text của user vào model TF-IDF + Logistic Regression/SVM để phân loại danh mục ngay lập tức.

Amount: BE dùng một bộ Parser (Regex hoặc NER nhẹ) để trích xuất con số từ câu nói (Ví dụ: "500k" -> 500000, "2 triệu" -> 2000000).

Relationship_Tag: BE quét các từ khóa nhạy cảm trong câu chat để tự động gán tag ẩn (NGUOI_YEU, CHA_ME).

Gom và Lọc lựa ContextMeta: BE tự động tính toán giờ giấc, thời tiết từ thiết bị gửi lên, truy vấn nhanh PostgreSQL để lấy trạng thái ví của riêng danh mục vừa tìm được, giới hạn chi tiêu sắp hết, số lần truy tiêu nhiều lần trong tuần, số tiền chi tiêu lớn. Sau đó đóng gói gửi sang LLM (Prompt 2 từ file promt.md) để lấy câu phản hồi sinh động theo Mood.

3. Sơ đồ Luồng Dữ liệu (Data Flow)
[Mobile: Chỉ gửi Text] ──> [Backend API]
                                │
                                ├──> Core ML: Đoán Category (TF-IDF)
                                ├──> Regex/NER: Trích xuất Số tiền (Amount) & Gán Tag Ẩn Relationships
                                └──> BE Aggregator: Gom nhanh ContextMeta từ PostgreSQL
                                │
                                ▼
                  [Gộp nguyên liệu & Lọc lựa] ──> [LLM Prompt 2] ──> [Trả JSON về Mobile hiển thị Story]
🏛️ LUỒNG 2: LUỒNG ẢNH (Người dùng chỉ gửi ảnh hóa đơn - Bill)
Áp dụng khi người dùng lười gõ phím, họ chỉ mở camera chụp chiếc bill thanh toán (Ví dụ: Ảnh bill Highlands Coffee, ảnh hóa đơn nhà thuốc) rồi tắt app.
[ FE (Mobile) ]             [ Backend (BE) ]         [ Message Queue ]     [ Module OCR ]     [ LLM Engine ]
       │                           │                         │                    │                  │
       ├────── 1. Gửi Ảnh Bill ───>│                         │                    │                  │
       │       + Client Meta       ├─ 2. Tạo bản ghi NHÁP    │                    │                  │
       │<── 3. Trả mã story_id ────┤  (Pending Amount)       │                    │                  │
       │   (UI hiển thị Loading)   │                         │                    │                  │
       │                           ├─ 4. Đẩy Task nặng ─────>│                    │                  │
       │                           │                         ├─ 5. Nhận nhiệm vụ >│                  │
       │                           │                         │  (Quét ảnh bill)   ├─ 6. Trả Text thô ┤
       │                           │                         │                    │                  │
       │                           ├─ 7. Chạy Core ML ──────>│                    │                  │
       │                           │    (Đoán Category từ OCR)                    │                  │
       │                           ├─ 8. Gom ContextMeta ────>                    │                  │
       │                           │                                                                 │
       │                           ├─────────────────── 9. Gọi Prompt sinh Story ───────────────────>│
       │                           │<────────────────── 10. Trả kết quả JSON ────────────────────────┤
       │                           │
       │                           ├─ 11. Ghi đè PostgreSQL dữ liệu thật
       │<── 12. Bắn WebSocket ─────┤
       │    (Đổi UI sang DONE)     │
1. Hiện trạng
Hệ thống hoàn toàn không có text nhập tay chủ quan từ người dùng.

Thách thức: Module OCR (PaddleOCR/VietOCR) xử lý ảnh rất nặng và tốn thời gian (1.5s - 2s). Chữ bóc ra bị nhiễu, mất dấu, đảo dòng.

2. Giải pháp Kiến trúc tại Backend (BE)
Xử lý Bất đồng bộ (Async Queue) + Tạo bản ghi nháp: Để đảm bảo tính năng "đăng Story" mượt mà, ngay khi nhận ảnh, BE tạo ngay một bản ghi nháp trạng thái PENDING và trả về mã story_id để Mobile hiển thị hiệu ứng Loading lướt lướt. User không phải chờ đợi vòng xoay.

Xử lý song song ngầm (Background Worker):

Nhánh 1: Đẩy ảnh vào Module OCR để lấy text thô (ocr_raw_text).

Nhánh 2: Trong lúc đợi OCR quét chữ, BE tận dụng thời gian trống để gom sẵn gói ContextMeta tổng thể từ thiết bị và PostgreSQL.

Hợp nhất & Lọc lựa dữ liệu sau OCR: Khi OCR trả về chữ thô, BE thực hiện:

Amount & Date: Áp dụng Logic Fusion, ưu tiên tuyệt đối dữ liệu trích xuất toán học từ hóa đơn (bốc con số tổng cộng cuối bill).

Category: Ném toàn bộ cục chữ thô OCR vào model TF-IDF + Logistic Regression/SVM để ép ra danh mục chính xác nhất.

Relationship_Tag: **KHÔNG áp dụng cho Luồng Ảnh** — bill không có câu text chủ quan của user nên không quét relationship_tag. Tag ẩn chỉ tồn tại trong Luồng 1 (Text).

Bộ lọc Meta: Lọc gói ContextMeta đã chuẩn bị sẵn, chỉ giữ lại biến số tài chính trùng với Category vừa nhận dạng để làm sạch dữ liệu trước khi ném vào LLM.

Cập nhật Động: LLM trả về câu nhận xét theo Mood, BE cập nhật đè số liệu thật vào DB và bắn tín hiệu qua WebSocket để đổi UI trên Mobile từ Loading thành trang Story hoàn chỉnh.

3. Sơ đồ Luồng Dữ liệu (Data Flow) — Đã triển khai
[Mobile: Chỉ gửi Ảnh + walletId] ──> [Backend API: POST /ai/expense/from-bill]
        │
        ├─ Upload ảnh lên R2 (nếu có)
        ├─ INSERT transactions WHERE processing_status='pending' → trả { transactionId, status:'pending' } HTTP 202
        │
        └─ setImmediate(_processBillBackground) ── chạy ngầm:
                │
                ├──> [AI Service / PaddleOCR]: OCR ảnh → text thô
                ├──> [Core ML]: Đoán Category từ text thô
                ├──> [LLM Prompt 2]: Sinh Story (không có relationship_tag)
                ├──> UPDATE transactions SET processing_status='done', amount, category, ai_meta
                └──> [wsHub.sendToUser]: bắn { type:'transaction_done', transactionId, data }
                                                        │
                                        [Flutter WebSocket listener]
                                        ├─ Khi pending: hiển thị CircularProgressIndicator
                                        └─ Khi nhận transaction_done: cập nhật UI + MiMo story

Tiêu chí kỹ thuật,LUỒNG 1: LUỒNG TEXT,LUỒNG 2: LUỒNG ẢNH
Đầu vào từ Mobile,Câu lệnh văn bản / File âm thanh Voice chat,File hình ảnh hóa đơn (Bill/Invoice)
Phương thức xử lý API,Đồng bộ (Synchronous) - Trả kết quả tức thì,Bất đồng bộ (Asynchronous) - Xử lý qua hàng đợi ngầm
Tốc độ phản hồi UI,Siêu nhanh (< 100ms),"Trả UI nháp ngay lập tức, UI thật cập nhật sau 2-3s"
Nguồn trích xuất Số tiền,Trích xuất bằng Regex/NER dựa trên câu nói của user,Trích xuất bằng quy tắc toán học dựa trên text thô OCR
Nguồn đoán Danh mục,Core ML đọc từ câu chat chủ quan của user,Core ML đọc từ danh sách các món hàng bóc từ ảnh bill
Cách quét Prompt ẩn,Keyword/regex scanner trong pipeline.py (CHA_ME / NGUOI_YEU) — hỗ trợ text có dấu và không dấu,KHÔNG ÁP DỤNG — bill không có câu text chủ quan của user
Cơ chế lọc ContextMeta,Lấy Category trước -> Truy vấn PostgreSQL lấy đúng Meta danh mục đó,Truy vấn PostgreSQL lấy toàn bộ Meta trước -> Có Category từ OCR -> Áp bộ lọc (Filter) giữ lại Meta trùng

Lưu Ý Sống Còn Cho Cả 2 Luồng
Luồng Text - Tránh hiểu nhầm con số: Nếu user gõ: "Dẫn bồ đi ăn tiệm đồ cũ hết 200k", bộ Parser Regex ở Backend có thể bị lầm lẫn giữa chữ "cũ" (chữ) hoặc các con số ngày tháng với số tiền. Hàm trích xuất ở BE cần được cài đặt trọng số ưu tiên cho các chữ đi kèm ký tự đơn vị tệ như k, đ, vnd, triệu.

Luồng Ảnh - Tiết kiệm Token cho LLM: Kết quả trả về từ PaddleOCR rất dài và chứa nhiều ký tự rác (ký tự đặc biệt, mã vạch...). BE sau khi dùng Core ML để đoán Category và trích xuất số tiền xong, chỉ nên gửi các thông tin cốt lõi (Số tiền đã lọc, Danh mục đã đoán, Tên các món ăn chính) kèm gói ContextMeta sang cho LLM sinh lời thoại, tuyệt đối không quăng nguyên cục text thô OCR vào LLM để tránh làm loãng ngữ cảnh và tốn chi phí API.