# CHƯƠNG 2: CƠ SỞ LÝ THUYẾT TOÀN DIỆN VỀ KIẾN TRÚC VÀ CÔNG NGHỆ DỰ ÁN MONEYSTORY

Chương này trình bày các cơ sở khoa học, mô hình toán học, kiến trúc phần mềm và công nghệ cốt lõi làm nền tảng cho hệ thống **MoneyStory** (bao gồm Backend Node.js, Frontend Mobile Flutter & WebAdmin React, và AI Pipeline Serving layer `expense-ocr-nlu`).

---

## 2.1. CƠ SỞ LÝ THUYẾT PHÂN HỆ MÁY CHỦ (BACKEND)

Phân hệ Backend đóng vai trò là bộ điều phối trung tâm (Orchestrator) chịu trách nhiệm xác thực, xử lý nghiệp vụ tài chính, quản lý trạng thái, đồng bộ dữ liệu và bảo mật.

### 2.1.1. Kiến trúc Node.js & Express
Môi trường thực thi **Node.js** hoạt động dựa trên cơ chế đơn luồng (Single-threaded Event Loop) kết hợp mô hình I/O phi chặn (Non-blocking I/O) [1]. 
- **Event Loop**: Quản lý việc thực thi các callback thông qua hàng đợi sự kiện (event queue). Khi có yêu cầu truy vấn cơ sở dữ liệu hoặc gọi API dịch vụ AI, Node.js sẽ chuyển giao tác vụ này cho nhân hệ điều hành hoặc thread pool (`libuv`), giải phóng luồng chính để tiếp tục nhận request mới.
- **Express**: Cung cấp khung định tuyến REST API tối giản, áp dụng mô hình Middleware cho phép kiểm tra, phân tích cú pháp (parser), xác thực JWT và validate đầu vào bằng thư viện **Zod** trước khi đi vào controller xử lý.

### 2.1.2. Cơ chế xác thực JWT và Refresh Token Rotation
Để bảo vệ tài nguyên người dùng mà không cần duy trì trạng thái phiên (stateless), hệ thống sử dụng **JSON Web Token (JWT)** [2]. Quy trình bảo mật bao gồm:
1. **Access Token**: Có vòng đời ngắn (ví dụ: 15 phút), chứa thông tin định danh và quyền hạn của người dùng, được mã hóa đối xứng bằng thuật toán HMAC-SHA256 (`HS256`).
2. **Refresh Token**: Có vòng đời dài hơn (ví dụ: 7 ngày), dùng để yêu cầu Access Token mới mà không bắt người dùng đăng nhập lại.
3. **Refresh Token Rotation (Xoay vòng Token)**: Mỗi khi Refresh Token được sử dụng để lấy Access Token mới, hệ thống sẽ hủy bỏ Refresh Token cũ và sinh ra một Refresh Token mới trả về cho client. Nếu kẻ tấn công đánh cắp được Refresh Token cũ và cố tình sử dụng lại, hệ thống lập tức phát hiện sự trùng lặp (replay attack), thu hồi toàn bộ các token đã phát hành cho user đó để bắt buộc đăng nhập lại từ đầu.

```
Client                     Backend Server                  Database
  │                              │                            │
  ├─ 1. POST /refresh (Token A) ─►                            │
  │                              ├─ 2. Kiểm tra Token A ─────>│
  │                              │    (Nếu hợp lệ & chưa dùng)│
  │                              │                            │
  │                              ├─ 3. Tạo Token B & Access ─>│ (Lưu Token B, hủy A)
  │                              │                            │
  │◄─ 4. Trả Token B + Access ───┤                            │
```

### 2.1.3. Hệ quản trị cơ sở dữ liệu phân tán (PostgreSQL & CockroachDB)
Để quản lý dữ liệu tài chính với độ tin cậy tuyệt đối, hệ thống hỗ trợ song song PostgreSQL và **CockroachDB** (Distributed SQL) [3].
- **ACID Transactions**: Cam kết cung cấp mức cô lập giao dịch cao nhất (Serializable Isolation) nhằm triệt tiêu các lỗi đọc rác (dirty reads), đọc không lặp lại (non-repeatable reads), hoặc đọc bóng ma (phantom reads) khi phát sinh nhiều yêu cầu ghi chép chi tiêu đồng thời.
- **Raft Consensus Protocol**: CockroachDB chia nhỏ dữ liệu thành các phân vùng 64MB (Ranges). Mỗi Range được nhân bản ra 3 nodes vật lý. Việc ghi đè dữ liệu chỉ thành công khi có sự thống nhất từ đa số thành viên thông qua biểu thức Quorum:
  $$\text{Quorum} = \lfloor N/2 \rfloor + 1$$
  Với $N=3$, hệ thống chấp nhận mất 1 node mà không gây gián đoạn dịch vụ hoặc sai lệch số liệu.

### 2.1.4. Giao thức Truyền thông thời gian thực WebSockets
Để cập nhật giao diện bất đồng bộ (như kết quả OCR hóa đơn), hệ thống sử dụng giao thức **WebSocket (`ws`)** [4]. Khác với cơ chế HTTP Polling liên tục gây tải cho server, WebSocket thiết lập kết nối TCP hai chiều bền vững, cho phép Backend chủ động đẩy (push) gói tin `{ event: "transaction_done", data }` tới thiết bị di động ngay khi tiến trình xử lý ảnh hoàn tất ở background worker.

### 2.1.5. Lưu trữ đối tượng đám mây Cloudflare R2 & Presigned URL
Hình ảnh hóa đơn được lưu trữ trên **Cloudflare R2** - hệ thống lưu trữ đối tượng tương thích API AWS S3 [5]. Để đảm bảo an toàn:
- Client không upload trực tiếp lên bucket công khai.
- Backend đóng vai trò cấp quyền bằng cách sinh **Presigned URL** thời hạn ngắn (15 phút) sử dụng chữ ký số HMAC-SHA256:
  $$\text{Signature} = \text{HMAC-SHA256}(\text{SecretKey}, \text{Method} + \text{Bucket} + \text{Key} + \text{Expires})$$
- Client dùng URL này để PUT trực tiếp file ảnh lên R2, giảm tải băng thông trung chuyển cho server backend.

---

## 2.2. CƠ SỞ LÝ THUYẾT PHÂN HỆ KHÁCH (FRONTEND)

Phân hệ Frontend bao gồm ứng dụng di động (Flutter) cho người dùng cuối và cổng quản trị (React) cho người vận hành.

### 2.2.1. Ứng dụng di động Flutter & Kiến trúc quản lý trạng thái
**Flutter** sử dụng ngôn ngữ Dart hoạt động theo cơ chế phản ứng (Reactive UI) và vẽ giao diện trực tiếp lên Canvas thông qua engine đồ họa Skia/Impeller [6].
- **State Management**: Hệ thống áp dụng mô hình kiến trúc phân lớp (UI - Logic - Data). Trạng thái của màn hình chat và timeline được quản lý tập trung qua `ChangeNotifier` hoặc `StateNotifier`, giúp tách biệt hoàn toàn mã nguồn render giao diện với mã logic xử lý API và luồng WebSocket.
- **Local Speech-to-Text (STT)**: Ứng dụng sử dụng package `speech_to_text` để gọi trực tiếp engine nhận dạng giọng nói native của hệ điều hành (Apple Speech Framework trên iOS, Google Speech Recognizer trên Android). Việc này cho phép chuyển âm thanh thành văn bản ngay trên thiết bị mà không cần truyền dữ liệu âm thanh thô qua mạng, giúp bảo vệ băng thông và tăng tốc độ xử lý.

### 2.2.2. Thuật toán kết nối lại WebSocket Exponential Backoff với Jitter
Để đảm bảo kết nối WebSocket bền bỉ khi người dùng di chuyển qua các vùng mạng yếu, hệ thống triển khai giải thuật kết nối lại tăng dần (Exponential Backoff) kết hợp nhiễu ngẫu nhiên (Jitter) [7] nhằm tránh hiện tượng nghẽn mạng do hàng loạt thiết bị cùng reconect đồng thời (Thundering Herd problem):
$$\text{Delay} = \min\left(2^{\text{attempt}} \times 1000 + \text{random}(0, 1000), 60000\right) \text{ (ms)}$$
Counter `attempt` tự động tăng sau mỗi lần thử thất bại và reset về 0 ngay khi kết nối thành công.

### 2.2.3. Cổng quản trị WebAdmin React 19 & SPA
Ứng dụng **React 19** được xây dựng dưới dạng ứng dụng trang đơn (Single Page Application - SPA) kết hợp công cụ đóng gói **Vite** [8].
- **Virtual DOM**: React duy trì một cây DOM ảo trong bộ nhớ. Khi có sự thay đổi về danh mục hay log huấn luyện, React tính toán sự khác biệt tối thiểu (reconciliation) và cập nhật lên DOM thật, mang lại hiệu năng dựng trang cực nhanh.
- **Labeling Canvas Workspace**: Sử dụng phần tử HTML5 Canvas để vẽ trực quan các tọa độ bounding box của ảnh hóa đơn thô, cho phép người quản trị kéo thả điều chỉnh nhãn ngữ nghĩa (`SELLER`, `TOTAL_COST`) để xuất file huấn luyện đạt chuẩn.

---

## 2.3. CƠ SỞ LÝ THUYẾT ĐỘNG CƠ AI (EXPENSE-OCR-NLU)

Phân hệ AI thực thi hai nhiệm vụ cốt lõi: Số hóa thông tin hóa đơn (OCR) và hiểu ý định văn bản (NLU).

### 2.3.1. Nhận dạng ký tự hóa đơn tiếng Việt (Receipt OCR)
Quy trình trích xuất thông tin hóa đơn dựa trên các nghiên cứu hàng đầu về xử lý tài liệu thông minh (Document AI) và được thiết kế theo cấu trúc kế thừa từ các giải pháp xuất sắc của cuộc thi **MC-OCR Challenge 2021** (Mã định danh DOI: 10.1109/RIVF51545.2021.9642083) [9].

#### 1. Phát hiện chữ bằng mạng DBNet (Differentiable Binarization)
DBNet định vị các hộp chứa văn bản bằng cách nhị phân hóa khả vi trực tiếp trong quá trình học [10]. Thay vì nhị phân hóa cứng không thể tính đạo hàm, mạng sử dụng nhị phân hóa xấp xỉ mềm:
$$\hat{B}_{i,j} = \frac{1}{1 + e^{-k(P_{i,j} - T_{i,j})}}$$
Trong đó $P_{i,j}$ là bản đồ xác suất vùng chữ, $T_{i,j}$ là bản đồ ngưỡng thích ứng và $k=50$ là hệ số dốc. Công thức này cho phép lan truyền ngược đạo hàm đầy đủ để tối ưu mạng phát hiện cả các vùng chữ bị cong, nghiêng.

#### 2. Hiệu chỉnh hướng ảnh bằng MobileNetV3
Mô hình phân loại góc xoay ảnh (0°, 90°, 180°, 270°) sử dụng **MobileNetV3** gọn nhẹ để tối ưu hóa hiệu năng tính toán [11]. MobileNetV3 áp dụng tích chập phân tách chiều sâu (Depthwise Separable Convolution) để phân rã phép tích chập thông thường thành hai bước: Depthwise Convolution và Pointwise $1 \times 1$ Convolution. Tỷ lệ tiết kiệm tài nguyên tính toán đạt:
$$\text{Ratio} = \frac{1}{N} + \frac{1}{D_K^2}$$
Với bộ lọc $3 \times 3$ ($D_K = 3$), lượng tính toán giảm đi 9 lần giúp chạy mượt mà trên CPU máy chủ.

#### 3. Nhận dạng chữ viết bằng VietOCR (VGG19 + BiLSTM + Attention)
**VietOCR** giải quyết bài toán đọc chữ tiếng Việt có dấu phức tạp bằng bộ giải mã chú ý Bahdanau [12].
- **Feature Extractor**: VGG19-BN trích xuất đặc trưng hình ảnh của dòng chữ.
- **Sequence Modeling**: BiLSTM tổng hợp ngữ cảnh ký tự hai chiều (trước và sau).
- **Bahdanau Attention**: Tính toán trọng số chú ý $\alpha_{i,j}$ tại bước giải mã $i$ trên trạng thái ẩn encoder $h_j$:
  $$e_{i,j} = v_a^T \tanh(W_a s_{i-1} + U_a h_j)$$
  $$\alpha_{i,j} = \frac{\exp(e_{i,j})}{\sum_{k=1}^{T_x} \exp(e_{i,k})}$$
  Vector ngữ cảnh tích hợp $c_i = \sum_{j} \alpha_{i,j} h_j$ giúp bộ giải mã GRU tái tạo nguyên âm tiếng Việt chính xác vượt trội so với giải pháp CTC truyền thống.

#### 4. Trích xuất thông tin khóa bằng LayoutLMv3
**LayoutLMv3** hợp nhất thông tin văn bản (Text), bố cục 2D (Layout) và hình ảnh (Visual) trong một kiến trúc Transformer đa phương thức [13]. Mô hình được pre-train bằng tác vụ MLM (Masked Language Modeling) và MIM (Masked Image Modeling), giúp gán nhãn thực thể ngữ nghĩa (`SELLER`, `TIMESTAMP`, `TOTAL_COST`) trực tiếp từ cấu trúc không gian hóa đơn.

---

### 2.3.2. Hiểu ngôn ngữ tự nhiên tiếng Việt (NLU)

#### 1. Sentence Embeddings bằng PhoBERT
Hệ thống sử dụng **PhoBERT** (kiến trúc RoBERTa tiền huấn luyện cho tiếng Việt) để chuyển hóa câu chat thành vector đặc trưng ngữ nghĩa [14]. Đặc trưng toàn câu được trích xuất từ trạng thái ẩn đầu ra của token đặc biệt `<s>`:
$$\mathbf{h}_{\text{CLS}} \in \mathbb{R}^{768}$$

#### 2. Phân loại hiệu chỉnh (Platt Scaling)
Để phân loại ý định (Record, Action, Chitchat) với độ chính xác cao và tránh hiện tượng quá tự tin của mô hình, vector đặc trưng $\mathbf{h}_{\text{CLS}}$ được đưa vào Logistic Regression kết hợp **Platt Scaling** để hiệu chỉnh xác suất đầu ra [15]:
$$P(y = c \mid \mathbf{h}_{\text{CLS}}) = \frac{1}{1 + e^{-(A \cdot f(\mathbf{h}_{\text{CLS}}) + B)}}$$

#### 3. Nhận dạng thực thể bằng SpaCy NER
Thực thể số tiền (`AMOUNT`), thời gian (`TIME`), sản phẩm (`PRODUCT`) được trích xuất bằng bộ phân tích cú pháp chuyển trạng thái (Transition-based parser) của **SpaCy** thông qua ba hành động dịch chuyển toán học: $\text{SHIFT}$, $\text{REDUCE}$, và $\text{OUT}$ [16].

#### 4. Tinh chỉnh mô hình ngôn ngữ lớn Qwen2.5 bằng LoRA
Đối với luồng suy luận nâng cao và sinh câu thoại Gen Z tự nhiên, hệ thống sử dụng mô hình **Qwen2.5-14B-Instruct** tinh chỉnh bằng phương pháp cập nhật trọng số thứ hạng thấp **LoRA (Low-Rank Adaptation)** [17]. Thay vì cập nhật toàn bộ tham số $W_0 \in \mathbb{R}^{d \times k}$, LoRA đóng băng $W_0$ và phân tích ma trận gia số $\Delta W$ thành tích của hai ma trận thứ hạng thấp $A \in \mathbb{R}^{r \times k}$ và $B \in \mathbb{R}^{d \times r}$ với $r \ll \min(d, k)$:
$$W = W_0 + \Delta W = W_0 + \frac{\alpha}{r} B A$$
Mô hình được chạy ở định dạng **BFloat16** trên GPU Nvidia H100 serverless của Modal và nạp vào bộ nhớ RAM GPU thông qua lượng tử hóa **4-bit Nf4 (NormalFloat4)** để tối ưu hóa bộ nhớ và tốc độ suy luận.

---

## 2.4. PHÂN TÍCH BỐN LUỒNG NGHIỆP VỤ CỐT LÕI (CORE FLOWS)

Hệ thống MoneyStory vận hành trơn tru dựa trên sự phối hợp đồng bộ của 4 luồng xử lý chính:

### 2.4.1. Luồng Quy tắc người dùng (RuleUser Flow)
Luồng này thực hiện cá nhân hóa việc phân loại danh mục chi tiêu cho từng người dùng thông qua bộ lọc 3 tầng (Layer 1, Layer 2 và Global Inference):
1. **Layer 1 (Exact Overrides Match)**: Khi người dùng sửa đổi danh mục của một giao dịch, backend ghi nhận từ khóa thô vào bảng `user_category_mappings`. Khi nhận yêu cầu mới, hệ thống chuẩn hóa câu và so khớp chính xác (case-insensitive). Nếu trùng khớp, áp dụng ngay nhãn cá nhân hóa mà không gọi mô hình.
2. **Layer 2 (Semantic Similarity Match)**: Nếu Layer 1 không khớp, hệ thống chuyển câu chat thành vector TF-IDF và tính toán Cosine Similarity với các câu đã được sửa đổi trong lịch sử của chính user đó:
   $$\text{Cosine}(A, B) = \frac{A \cdot B}{\|A\| \|B\|}$$
   Nếu giá trị tương đồng lớn nhất $S \ge 0.85$, tự động map vào danh mục tương ứng.
3. **Layer 3 (Global Inference)**: Nếu cả hai tầng cá nhân hóa thất bại, câu chat mới chuyển sang mô hình toàn cục (PhoBERT/Qwen) xử lý.

```
[Văn bản đầu vào từ user] ──► [Layer 1: So khớp tĩnh] ──► Match ──► [Trả nhãn cá nhân]
                                      │
                                  Không match
                                      ▼
                              [Layer 2: Cosine] ───────► S ≥ 0.85 ──► [Trả nhãn cá nhân]
                                      │
                                  S < 0.85
                                      ▼
                              [Layer 3: PhoBERT/Qwen] ───────────────► [Trả nhãn mặc định]
```

### 2.4.2. Luồng xử lý Hóa đơn (Bill Flow)
Luồng xử lý hóa đơn hoạt động theo mô hình bất đồng bộ thông qua cổng WebSocket để tối ưu hóa trải nghiệm người dùng:
1. **Upload & Khởi tạo**: Thiết bị di động gửi ảnh hóa đơn lên Backend Node.js. Server tạo ngay một giao dịch trong cơ sở dữ liệu với trạng thái `processing_status = 'pending'` và trả về HTTP `202 Accepted` kèm theo ID giao dịch.
2. **Xử lý nền (Background Job)**: Backend gọi API sang FastAPI AI Service xử lý:
   - **PaddleOCR** định vị các hộp chứa văn bản.
   - **MobileNetV3** xác định và xoay lại ảnh bị ngược.
   - **VietOCR** đọc nội dung chữ tiếng Việt của từng box.
   - **LayoutLMv3** nhận dạng các trường `SELLER`, `TIMESTAMP`, `TOTAL_COST`.
   - **Geometric Pairing** ghép nối tên mặt hàng và giá tương ứng trên cùng dòng.
   - **Weighted Voting**: Phân loại danh mục chung dựa trên tổng điểm số có trọng số của các mặt hàng:
     $$\text{Score}(C) = \sum_{i \in \text{Items}} \text{Price}_i \times \text{Confidence}_i$$
3. **Đồng bộ thời gian thực**: Khi AI Service trả kết quả, Backend cập nhật thông tin giao dịch, chuyển trạng thái thành `done` và bắn tín hiệu `transaction_done` qua WebSocket để Mobile tự động tải lại UI. Người dùng xác nhận hoặc sửa lại thông tin thô trực tiếp trên ứng dụng.

### 2.4.3. Luồng phân loại Hành động & Ý định (Intent Action Flow)
Luồng này thực thi các yêu cầu phân tích dữ liệu hoặc thay đổi thiết lập hệ thống bằng giọng nói/văn bản:
1. **Phát hiện Hành động**: Khi câu thoại đi vào NLU Pipeline, hệ thống chạy qua bộ lọc regex `action_query.py` (Guard Rule) kết hợp mô hình phân loại toàn cục. Nếu câu nói chứa các từ khóa báo cáo ("tổng chi", "hôm nay tiêu gì") hoặc cài đặt ("đặt hạn mức", "đổi giao diện tối"), hệ thống gán nhãn `intent = 'Action'`.
2. **Quy đổi thời gian (Date Parsing)**: Hệ thống sử dụng bộ phân tích thời gian tiếng Việt tự sinh để dịch các thực thể thời gian thô (ví dụ: "tuần này", "tháng trước") thành khoảng ngày cụ thể `(from_date, to_date)`.
3. **Làm giàu bối cảnh (Enrichment)**: Backend Node.js chặn kết quả `Action`, thực hiện truy vấn cơ sở dữ liệu thật của user đó để lấy số liệu tổng chi tiêu hoặc danh sách danh mục tiêu dùng nhiều nhất, sau đó gắn số liệu thật vào trường `action_result` và chuyển sang Gemini sinh câu thoại NLG hiển thị kèm theo Card báo cáo chuyên biệt (ví dụ: `_ReportStoryCard`).
4. **Xác nhận hành động (Action Confirmation)**: Đối với các hành động nguy hiểm như xóa giao dịch (`DELETE_RECORD`), hệ thống hiển thị Card xác nhận dạng Dialog. Khi người dùng bấm đồng ý, client gửi request lên `/ai/actions/execute` để thực thi thay đổi nghiệp vụ thật trong database.

### 2.4.4. Luồng Tái huấn luyện (Retrain Flow)
Luồng này cho phép cập nhật liên tục mô hình để tăng độ chính xác theo thời gian:
1. **Ghi nhận lỗi**: Khi người dùng chỉnh sửa thông tin giao dịch (NLU đoán sai category, hoặc OCR nhận dạng sai số tiền), backend ghi lại nhãn đúng và nhãn dự đoán cũ vào bảng `user_corrections`.
2. **Duyệt dữ liệu (Curation)**: Người quản trị truy cập WebAdmin, xem danh sách các lỗi được gom cụm theo tần suất xuất hiện. Admin phê duyệt và bấm nút **Curate**, Backend sẽ tự động append các câu thoại này vào dataset `intent_record.csv`.
3. **Huấn luyện nền (Background Training)**: Admin bấm nút **Trigger Retrain** trên WebAdmin. Backend gửi lệnh sang AI Service để chạy ngầm kịch bản `retrain_all.py` sử dụng luồng phụ (BackgroundTasks) của FastAPI để tránh block API chính.
4. **Nạp nóng mô hình (Hot-reload)**: Sau khi hoàn thành huấn luyện, mô hình Logistic Regression hoặc spaCy NER mới được nạp đè trực tiếp vào bộ nhớ RAM của tiến trình đang chạy (`get_nlu_service().reload()`), giúp hệ thống nâng cấp thông minh hơn ngay lập tức mà không cần khởi động lại container Docker.

---

## TÀI LIỆU THAM KHẢO (BIBLIOGRAPHY)

[1] Ryan Dahl, **"Node.js: A JavaScript runtime built on Chrome's V8 JavaScript engine,"** *GitHub repository*, 2009. [Online]. Available: https://github.com/nodejs/node.

[2] M. Jones, J. Bradley, and N. Sakimura, **"JSON Web Token (JWT),"** *Internet Engineering Task Force (IETF), RFC 7519*, 2015. DOI: [10.17487/RFC7519](https://doi.org/10.17487/RFC7519).

[3] R. Taft, U. Sharif, et al., **"CockroachDB: The Resilient Geo-Distributed SQL Database,"** in *Proceedings of the 2020 ACM SIGMOD International Conference on Management of Data*, 2020, pp. 1493-1509. DOI: [10.1145/3318464.3386134](https://doi.org/10.1145/3318464.3386134).

[4] I. Fette and A. Melnikov, **"The WebSocket Protocol,"** *Internet Engineering Task Force (IETF), RFC 6455*, 2011. DOI: [10.17487/RFC6455](https://doi.org/10.17487/RFC6455).

[5] Cloudflare, **"R2 Object Storage: S3-compatible, zero-egress object storage,"** Cloudflare Docs, 2022. [Online]. Available: https://developers.cloudflare.com/r2/.

[6] Google, **"Flutter: Beautiful native apps in record time,"** *Flutter SDK Docs*, 2018. [Online]. Available: https://flutter.dev.

[7] M. Newman, **"Exponential Backoff and Jitter,"** AWS Architecture Blog, 2015. [Online]. Available: https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/.

[8] Dan Abramov, **"React: A JavaScript library for building user interfaces,"** *Meta Open Source*, 2013. [Online]. Available: https://react.dev.

[9] N. D. Cuong, M. P. Hoang, et al., **"MC-OCR Challenge 2021: End-to-end system to extract key information from Vietnamese Receipts,"** in *Proceedings of the 2021 IEEE RIVF International Conference on Computing and Communication Technologies (RIVF)*, 2021, pp. 1-6. DOI: [10.1109/RIVF51545.2021.9642083](https://doi.org/10.1109/RIVF51545.2021.9642083).

[10] M. Liao, Z. Wan, et al., **"Real-time Scene Text Detection with Differentiable Binarization,"** in *Proceedings of the AAAI Conference on Artificial Intelligence*, vol. 34, no. 07, 2020, pp. 11474-11481. DOI: [10.1609/aaai.v34i07.6812](https://doi.org/10.1609/aaai.v34i07.6812).

[11] A. Howard, M. Sandler, et al., **"Searching for MobileNetV3,"** in *Proceedings of the IEEE/CVF International Conference on Computer Vision (ICCV)*, 2019, pp. 1314-1324. DOI: [10.1109/ICCV.2019.00140](https://doi.org/10.1109/ICCV.2019.00140).

[12] D. Bahdanau, K. Cho, and Y. Bengio, **"Neural machine translation by jointly learning to align and translate,"** in *3rd International Conference on Learning Representations (ICLR)*, 2015, pp. 1-15. arXiv: [1409.0473](https://arxiv.org/abs/1409.0473).

[13] Y. Huang, T. Lv, et al., **"LayoutLMv3: Pre-training for Document AI with Unified Text and Image Masking,"** in *Proceedings of the 30th ACM International Conference on Multimedia (MM)*, 2022, pp. 4083-4091. DOI: [10.1145/3503161.3548112](https://doi.org/10.1145/3503161.3548112).

[14] D. Q. Nguyen, and T. Nguyen, **"PhoBERT: Pre-trained language models for Vietnamese,"** in *Findings of the Association for Computational Linguistics: EMNLP 2020*, 2020, pp. 1037-1042. DOI: [10.18653/v1/2020.findings-emnlp.92](https://doi.org/10.18653/v1/2020.findings-emnlp.92).

[15] A. Niculescu-Mizil, and R. Caruana, **"Predicting good probabilities with supervised learning,"** in *Proceedings of the 22nd International Conference on Machine Learning (ICML)*, 2005, pp. 625-632. DOI: [10.1145/1102351.1102430](https://doi.org/10.1145/1102351.1102430).

[16] M. Honnibal, and I. Montani, **"spaCy 2: Natural language understanding with Bloom embeddings, convolutional neural networks and incremental parsing,"** *Sentient NLP*, vol. 7, no. 1, pp. 411-420, 2017.

[17] E. J. Hu, Y. Shen, et al., **"LoRA: Low-Rank Adaptation of Large Language Models,"** in *10th International Conference on Learning Representations (ICLR)*, 2022. arXiv: [2106.09685](https://arxiv.org/abs/2106.09685).
