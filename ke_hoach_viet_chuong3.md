# Cấu trúc và Kế hoạch chi tiết Toàn bộ Chương 3 (Thiết kế và Cài đặt Hệ thống)

**[YÊU CẦU XUYÊN SUỐT TOÀN CHƯƠNG]**
*   Mỗi chức năng/phân hệ đều phải mô tả: **Cách áp dụng công nghệ từ Chương 2 vào thiết kế, logic hoạt động ra sao, đầu vào/đầu ra là gì, tại sao lại chọn logic/công nghệ đó, và lợi thế mang lại là gì.**
*   Giải thích các khái niệm mộc mạc như đang giải thích cho người chưa biết gì về công nghệ đó. Không viết công thức toán học, chỉ nêu cách dùng và mục đích.
*   Mọi hình ảnh/sơ đồ đều phải có đoạn mô tả chi tiết đi kèm (mô tả cách hoạt động).

---

## 3.1. Kiến trúc Hệ thống Tổng thể
*   **Nội dung:** Giới thiệu tổng quan hệ thống gồm 4 thành phần chính: Ứng dụng di động (Giao diện), Máy chủ xử lý trung tâm (Đóng vai trò Cổng API và phân phối điều hướng), Máy chủ trí tuệ nhân tạo (Xử lý chuyên sâu) và Cơ sở dữ liệu. Giải thích mượt mà sự luân chuyển dữ liệu giữa các tầng.
*   **Cách viết:** Khoảng 2-3 đoạn văn.
*   **Hình ảnh:** Sử dụng ảnh `D:\Luan-Van\Project\Sơ đồ tổng quát của hệ thống Spending Diary.png` kèm đoạn văn giải thích cách hoạt động của sơ đồ.

## 3.2. Sơ đồ Cơ sở dữ liệu (ERD)
*   **Nội dung:** Trình bày Sơ đồ ERD. **Chỉ tập trung giải thích các bảng quan trọng nhất** đủ để thể hiện được 4 tầng chức năng của hệ thống (sàng lọc lại các bảng không cần thiết). Ghi chú chuyển hướng người đọc xem chi tiết ở Phụ lục.
*   **Cách viết:** 1-2 đoạn văn mô tả ý nghĩa sơ đồ.
*   **Hình ảnh:** Có 1 Sơ đồ ERD.

---

## 3.3. Thiết kế Giao diện Người dùng

### 3.3.1. Ứng dụng Di động
*Lưu ý: Viết thành nhiều đoạn (dài/ngắn tùy độ phức tạp). Phải giải thích được logic, đầu vào/đầu ra.*

*   **3.3.1.1. Chức năng Ghi chép chi tiêu tự động**
    *   *Nội dung:* Mô tả tính năng ghi chép thông qua việc nhập văn bản tự nhiên. Nêu rõ luồng đi từ lúc nhập văn bản đến khi lưu thành giao dịch.
    *   *Độ dài:* 2-3 đoạn. Có ảnh giao diện.
*   **3.3.1.2. Chức năng Quét hóa đơn**
    *   *Nội dung:* Tính năng chụp/tải ảnh. Giải thích logic hệ thống chạy ngầm, bóc tách và **chỉ lấy kết quả là Tổng tiền và Tên cửa hàng (Seller)** để hiển thị lại cho người dùng, có thông báo khi hoàn thành.
    *   *Độ dài:* 2-3 đoạn. Có ảnh giao diện camera/kết quả.
*   **3.3.1.3. Chức năng Báo cáo thống kê và So sánh chi tiêu**
    *   *Nội dung:* Báo cáo biểu đồ. Chỉ nói dùng công cụ gì để tính, tính như thế nào, tại sao dùng (không viết công thức toán học). Nêu cách tổng hợp theo tháng/tuần. Kết hợp tính năng AI so sánh chi tiêu với nhóm đồng trang lứa.
    *   *Độ dài:* 3-4 đoạn. 
    *   *Hình ảnh:* Chọn lọc 1-2 ảnh tiêu biểu nhất (không đưa hết tất cả các biểu đồ vào để tránh loãng).
*   **3.3.1.4. Chức năng Quản lý Hạn mức và Gợi ý Ngân sách**
    *   *Nội dung:* Thiết lập hạn mức chi tiêu, cảnh báo. **Phải mô tả cách hệ thống gợi ý chi tiêu (ngân sách) cho tháng mới chung chung, và giải thích tại sao lại dùng cách tính toán/logic đó.**
    *   *Độ dài:* 2-3 đoạn. Có ảnh giao diện.
*   **3.3.1.5. Chức năng Trò chuyện với Trợ lý ảo MiMo**
    *   *Nội dung:* Giao diện trò chuyện. Trình bày khả năng **ra lệnh cho hệ thống thực hiện các chức năng trực tiếp từ màn hình chat** (VD: thêm giao dịch).
    *   *Độ dài:* 3 đoạn. Có ảnh giao diện.
*   **3.3.1.6. Chức năng Công cụ Tài chính và Nhìn lại hành trình (Recap)**
    *   *Nội dung:* Các công cụ phụ trợ (tiết kiệm, sổ nợ). Trình bày tính năng **Recap (nhìn lại hành trình)** thể hiện dưới dạng thẻ trượt trực quan.
    *   *Độ dài:* 3 đoạn. Có ảnh màn hình Recap.
*   **3.3.1.7. Chức năng Nâng cấp tài khoản Cao cấp**
    *   *Nội dung:* Nâng cấp mở khóa giới hạn và tắt quảng cáo. (1-2 đoạn, có ảnh).

### 3.3.2. Trang Quản trị Hệ thống
*Lưu ý: Viết thành nhiều đoạn dài ngắn tùy độ phức tạp.*

*   **3.3.2.1. Chức năng Thống kê Tổng quan**
    *   *Nội dung:* Theo dõi các chỉ số quan trọng thực tế của hệ thống (Lượng request API, số lượng người dùng...). Có ảnh giao diện.
*   **3.3.2.2. Chức năng Quản lý Người dùng**
    *   *Nội dung:* Khóa/mở tài khoản vi phạm. (1 đoạn, có ảnh).
*   **3.3.2.3. Chức năng Thu thập và Huấn luyện Mô hình Nhận dạng Ngôn ngữ Tự nhiên**
    *   *Nội dung:* Nơi thu thập các câu lệnh người dùng mà AI đoán sai, cung cấp giao diện để admin sửa lại nhãn cho đúng và nhấn nút tái huấn luyện (Retrain). 
    *   *Độ dài:* 2-3 đoạn. Có ảnh giao diện thực tế của chức năng này.
*   **3.3.2.4. Chức năng Tiền xử lý và Gán nhãn Dữ liệu Hóa đơn**
    *   *Nội dung:* Tính năng **thu thập ảnh hóa đơn từ người dùng**. Quản trị viên dùng công cụ để gán nhãn cho hóa đơn mờ nhòe. Mô tả dùng thư viện/công cụ gì để gán nhãn, và gán như thế nào (chung chung, không đi sâu vào code).
    *   *Độ dài:* 2 đoạn. Có ảnh màn hình gán nhãn.
*   **3.3.2.5. Chức năng Quản lý Prompt và Kiểm thử Trợ lý ảo**
    *   *Nội dung:* Nơi quản trị viên cấu hình, chỉnh sửa các Prompt chỉ thị (System Prompt) cho mô hình LLM, và có màn hình để nhập thử đầu vào (Input) xem đầu ra (Output) phản hồi như thế nào.
    *   *Độ dài:* 1-2 đoạn. Có ảnh giao diện quản lý prompt.
*   **3.3.2.6. Chức năng Giám sát Lịch sử Thanh toán**
    *   *Nội dung:* Xem danh sách giao dịch chuyển khoản. (1 đoạn, có ảnh).

---

## 3.4. Thiết kế Máy chủ Xử lý Trung tâm (Backend)
*   **Mục đó cần có gì:** Máy chủ Node.js đóng vai trò **Cổng API (API Gateway), trung tâm phân phối và điều hướng** yêu cầu. 
    *   **Cần có 1 Sơ đồ luồng hoạt động (Flowchart) mô tả logic tổng thể của Backend.**
    *   3.4.1. Cơ chế Chống tấn công mạng: Ngăn chặn gửi quá nhiều yêu cầu cùng lúc.
    *   3.4.2. Cơ chế Gửi thông báo tự động: Nhắc nhở người dùng ghi chép hàng ngày.
    *   3.4.3. Cơ chế Xử lý câu lệnh thiếu thông tin: Hỏi lại để bổ sung dữ liệu.
    *   3.4.4. Cơ chế Nhận diện thanh toán tự động: Lắng nghe tin nhắn ngân hàng.
*   **Cách viết:** Giải thích rõ đầu vào/đầu ra, tại sao dùng logic này. Có Sơ đồ mô tả.

---

## 3.5. Thiết kế Tầng Trí tuệ Nhân tạo
*   **Nội dung cốt lõi:** Trình bày máy chủ xử lý AI (lý do tách riêng để chạy GPU).
    *   **3.5.1. Phân hệ Xử lý Ngôn ngữ Tự nhiên (NLU):** 
        *   **Mô tả dữ liệu:** Viết ngắn gọn về tập dữ liệu trước khi train/fine-tune (tạo như thế nào, lấy ở đâu, chia tập train/test ra sao).
        *   **Luồng hoạt động:** Khi có yêu cầu đến, đầu vào là gì, luồng xử lý luân chuyển giữa mô hình nhỏ gọn và mô hình LLM như thế nào, đầu ra là gì.
        *   **Xử lý phản hồi LLM:** Cách hệ thống nhận chuỗi phản hồi từ LLM và định dạng lại.
        *   **[QUAN TRỌNG]** Đưa Kết quả đánh giá hiệu năng (Benchmark) vào đây.
    *   **3.5.2. Phân hệ Xử lý và Nhận diện Hóa đơn:** 
        *   **Logic và lý do:** Giải thích tại sao lại sử dụng luồng 3 bước (Phát hiện -> Đọc -> Phân tích bố cục). Đầu vào của bước 1 là gì, đầu ra bước 3 là gì.
        *   **[QUAN TRỌNG]** Đưa Kết quả so sánh hiệu năng vào đây.

---

## 3.6. Thiết kế Cơ sở Dữ liệu và Lưu trữ
*   **Nội dung:** 
    *   3.6.1. Hệ thống Cơ sở dữ liệu CockroachDB: Tại sao dùng cơ sở dữ liệu phân tán.
    *   3.6.2. Hệ thống Lưu trữ Hình ảnh Cloudflare R2: Tại sao lưu trên đám mây.
    *   3.6.3. Hệ thống Khởi tạo Dữ liệu Giả lập: Tạo dữ liệu ảo thử tải và nạp Khảo sát mức sống.
