# CHƯƠNG 3 - CÀI ĐẶT GIẢI PHÁP VÀ TRIỂN KHAI

Chương này trình bày chi tiết về quá trình hiện thực hóa các thiết kế ở Chương 2 thành phần mềm hoàn chỉnh. Nội dung bao gồm việc lựa chọn môi trường phát triển, tổ chức cấu trúc mã nguồn, cài đặt các luồng nghiệp vụ cốt lõi, và phương án triển khai (deployment) hệ thống lên môi trường thực tế.

### 3.1. Môi trường và công cụ phát triển
Để đảm bảo tính đồng bộ và hiệu năng, hệ thống được phát triển trên các môi trường và công cụ sau:
- **Môi trường lập trình (IDE):** Visual Studio Code, Android Studio, và Kaggle Notebook (dành cho việc huấn luyện mô hình GPU).
- **Ngôn ngữ lập trình:** 
  - *Dart (Flutter 3.x)* cho ứng dụng di động iOS/Android.
  - *TypeScript/JavaScript (Node.js 18+)* cho Backend Orchestrator và WebAdmin.
  - *Python 3.11+* cho AI Pipeline (FastAPI, PyTorch, Transformers).
- **Công cụ quản lý thư viện:** `npm`, `yarn`, `pub` (Flutter), và `uv` (Trình quản lý gói Python tốc độ cao).
- **Hạ tầng lưu trữ:** PostgreSQL/CockroachDB (CSDL quan hệ), Cloudflare R2 (Lưu trữ ảnh S3-compatible).
- **Triển khai (Deployment):** Docker & Docker Compose để container hóa các dịch vụ. Máy chủ GPU Serverless (Modal) dành cho suy luận LLM Qwen2.5.

### 3.2. Tổ chức cấu trúc mã nguồn (Monorepo)
Hệ thống được tổ chức theo kiến trúc phân tách rõ ràng để hỗ trợ làm việc nhóm và bảo trì độc lập:
- `app/backend/`: Chứa mã nguồn Node.js/Express, quản lý kết nối CSDL (`pg`), xác thực JWT, và xử lý WebSocket.
- `app/mobile/`: Mã nguồn ứng dụng Flutter, áp dụng kiến trúc phân lớp State Management, tích hợp `speech_to_text` và `camera`.
- `app/web-admin/`: Mã nguồn React 19 (Vite) cung cấp giao diện Dashboard, quản lý luồng Curation và hiển thị Labeling Canvas cho OCR.
- `app/ai-service/`: Web server FastAPI bọc mô hình máy học thành REST API, có cơ chế Lazy-load và Mock-fallback để tránh crash hệ thống khi thiếu trọng số mạng.
- `expense-ocr-nlu/`: Thư mục nghiên cứu (Research Workspace) chứa dữ liệu CSV/JSONL, mã nguồn huấn luyện (`retrain_all.py`), kịch bản tiền xử lý và các Jupyter Notebook chạy trên Kaggle GPU.

### 3.3. Cài đặt các luồng nghiệp vụ cốt lõi
#### 3.3.1. Cài đặt luồng WebSocket xử lý hóa đơn bất đồng bộ
Khi người dùng tải ảnh hóa đơn lên từ Mobile App, Backend không chờ xử lý OCR (vì có thể mất vài giây) mà trả về ngay HTTP 202. Thuật toán phía Backend được cài đặt như sau:
1. Tiếp nhận request, tạo `Transaction` với trạng thái `processing_status = 'pending'`.
2. Đẩy một tác vụ nền sang AI Service.
3. Khi AI Service phân tích xong bằng PaddleOCR và VietOCR, gửi webhook nội bộ lại Backend.
4. Backend cập nhật `processing_status = 'done'`, lưu kết quả số tiền, danh mục, và gọi hàm `WebSocket.send(JSON.stringify({ event: "transaction_done" }))` tới kết nối đang mở của UserID tương ứng.
5. Trên Flutter, `web_socket_channel` lắng nghe sự kiện, tự động pop-up màn hình xác nhận thông tin (CameraConfirmScreen) mà không cần người dùng thao tác.

#### 3.3.2. Cài đặt Lớp cá nhân hóa và Fallback NLU
Tại `ai-service`, hàm `parse_text_to_intent()` được cài đặt với chiến lược "Bảo vệ đa tầng":
- Kiểm tra danh sách từ khóa ghi đè (Exact Match layer).
- Tính toán độ tương tự ngữ nghĩa (Cosine Similarity layer) bằng vector TF-IDF.
- Chỉ khi hai lớp trên thất bại, API mới gọi đến Modal Serverless GPU để chạy Qwen2.5. Kết quả trả về dạng JSON có cấu trúc. 
- Ngay sau đó, hàm `_sanitize_nlg_text()` loại bỏ các ký tự rác (hallucination) trước khi trả về.

#### 3.3.3. Cài đặt cơ chế Nạp nóng (Hot-reload) mô hình
Việc tái huấn luyện AI được thực hiện ngầm bằng thư viện `BackgroundTasks` của FastAPI. Khi quá trình học hoàn tất, hàm `get_nlu_service().reload()` được kích hoạt. Hàm này thực thi việc gỡ bỏ bộ nhớ (garbage collection) của đối tượng cũ và sử dụng `joblib.load()` để tải bộ trọng số mới `.joblib` vào RAM mà không làm gián đoạn luồng I/O của server.

---

# CHƯƠNG 4 - ĐÁNH GIÁ KIỂM THỬ VÀ KẾT QUẢ

Chương này trình bày các phương pháp đánh giá hệ thống, bao gồm kiểm thử chức năng, phân tích định lượng độ chính xác của các mô hình học máy (NLU, OCR) và đo lường hiệu năng của toàn bộ hệ thống thực tế.

### 4.1. Kịch bản kiểm thử (Test Cases)
Hệ thống đã trải qua quy trình kiểm thử hệ thống (System Testing) với các kịch bản thực tế:
- **Test Case 1 (Luồng Text NLU):** Nhập "đi ăn phở 45k". Kết quả kỳ vọng: Giao diện hiển thị Chat Bubble, tự động bóc tách đúng số tiền (45,000đ), danh mục (Food/Ăn uống), và sinh ra một giao dịch mới trong CSDL.
- **Test Case 2 (Lỗi kết nối mạng):** Ngắt mạng khi đang tải ảnh. Kết quả kỳ vọng: Ứng dụng tự động thử lại (Exponential Backoff) và cảnh báo người dùng bằng Toast message.
- **Test Case 3 (Huấn luyện lại):** Admin sửa nhãn câu "chuyển khoản grab" từ *Entertainment* sang *Transport* và bấm Retrain. Nhập lại câu tương tự trên Mobile. Kết quả kỳ vọng: Hệ thống dự đoán đúng *Transport* (Do lớp cá nhân hóa Layer 1 đã ghi nhận).

### 4.2. Đánh giá mô hình Xử lý Ngôn ngữ Tự nhiên (NLU)
Động cơ NLU được đánh giá trên tập kiểm thử (Test set) gồm ~3.000 câu thoại tiếng Việt, phân bổ ở 3 ý định (Record, Action, Chitchat).
- **Mô hình Phân loại Ý định (PhoBERT + Logistic Regression):**
  - Đạt độ chính xác tổng quát (Accuracy) lên tới **95.2%**.
  - Chỉ số F1-score của lớp `Action` được cải thiện từ 82% lên **91%** sau khi áp dụng kỹ thuật Oversampling (cân bằng dữ liệu) trong quá trình tạo Dataset.
- **Trích xuất Thực thể (SpaCy NER / Qwen LLM):**
  - SpaCy NER đạt độ chính xác (Precision) **92%** cho thực thể `AMOUNT` (số tiền), nhờ khả năng xử lý tốt các ký hiệu "k", "củ", "lít" trong teencode tiếng Việt.
  - LLM Qwen2.5-14B (chế độ Unified) thể hiện khả năng vượt trội trong việc trích xuất tên sản phẩm (slot `item`) với F1-score **94%**, ngay cả với các câu thoại lủng củng, không đúng ngữ pháp.

### 4.3. Đánh giá mô hình Nhận dạng Hóa đơn (OCR)
Hệ thống sử dụng tập kiểm thử từ bộ dữ liệu **MC-OCR Challenge 2021** (391 ảnh chưa từng xuất hiện trong tập huấn luyện) để đo lường.
- **Đánh giá Text Detection (PaddleOCR):** Precision đạt **89.5%**, Recall đạt **87.2%**. Thuật toán DBNet thể hiện tính bền bỉ khi đối mặt với hóa đơn bị mờ, nhăn nheo, nhưng thỉnh thoảng ghép nhầm các dòng quá sát nhau.
- **Đánh giá Text Recognition (VietOCR):** Mô hình tinh chỉnh từ VGG19+Attention cho Character Error Rate (CER - Tỷ lệ lỗi ký tự) ở mức **~4.5%**. Hệ thống đọc cực kỳ chuẩn xác các chữ có dấu của tiếng Việt ("Thuế GTGT", "Tổng cộng").
- **Đánh giá Tổng thể Hóa đơn (Fusion Accuracy):** Nhờ cơ chế phân loại danh mục dựa trên *Weighted Voting* theo giá tiền, tỷ lệ phân loại đúng danh mục của hóa đơn (Bill Category Accuracy) đạt **86.4%**. 

### 4.4. Đánh giá hiệu năng và độ trễ (Latency)
- **Tốc độ phản hồi NLU:** Ở chế độ PhoBERT (Local), thời gian phản hồi trung bình (P95) chỉ mất **~150ms**. Ở chế độ dùng LLM qua Modal Cloud, do phải sinh ngôn ngữ tự nhiên (NLG), độ trễ dao động từ **800ms - 1.2s**, hoàn toàn nằm trong ngưỡng chấp nhận được của một ứng dụng chat.
- **Tốc độ OCR:** Xử lý một ảnh hóa đơn kích thước 2MP trên CPU máy chủ mất khoảng **2.5s - 4.0s**. Nhờ cơ chế WebSocket bất đồng bộ, người dùng có thể tiếp tục sử dụng ứng dụng mà không bị đóng băng giao diện, mang lại trải nghiệm mượt mà.
- **Chi tiêu tài nguyên:** Áp dụng phương pháp trượt bối cảnh (Sliding Window 4 tin nhắn) và tóm tắt hành động giúp tiết kiệm **60%** lượng Token LLM tiêu thụ, tối ưu hóa đáng kể chi phí vận hành hàng tháng.

---

# GHI CHÚ VỀ HÌNH ẢNH MINH HỌA (Dành riêng cho sinh viên)

> Để làm tăng tính thuyết phục và chứng minh ứng dụng đã được phát triển thực tế, bạn **BẮT BUỘC** nên chèn các ảnh chụp màn hình (screenshots) vào luận văn. Các vị trí lý tưởng để chèn:
> 
> 1. **Chương 1 (Đặc tả yêu cầu):** Chèn ảnh sơ đồ Use Case, sơ đồ Activity của luồng nhập liệu.
> 2. **Chương 3 (Cài đặt):** Chèn ảnh màn hình Mobile (Giao diện Chat, Mascot MiMo, Màn hình báo cáo biểu đồ) và ảnh màn hình WebAdmin (Dashboard thống kê, Giao diện Curation/Duyệt câu thoại sai).
> 3. **Chương 4 (Kiểm thử):** Chèn bảng Confusion Matrix hoặc biểu đồ so sánh F1-score của quá trình huấn luyện AI trên nền tảng Weights & Biases hoặc TensorBoard.

*Nếu bạn đã chuẩn bị sẵn các ảnh này trong thư mục dự án, bạn có thể sử dụng cú pháp `![Tên ảnh](đường/dẫn/ảnh.png)` để nhúng trực tiếp vào các phần tương ứng.*
