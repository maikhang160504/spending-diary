# Cấu trúc và Kế hoạch chi tiết Toàn bộ Chương 4 (Kiểm thử và Đánh giá)

**[YÊU CẦU XUYÊN SUỐT TOÀN CHƯƠNG]**
*   Trình bày kết quả kiểm thử một cách khách quan, rõ ràng, dễ hiểu. Không dùng từ ngữ quá kỹ thuật hàn lâm.
*   Các kịch bản kiểm thử phải được trình bày dưới dạng bảng ngắn gọn (Mục đích, Kịch bản, Kết quả mong đợi).
*   Đánh giá hệ thống bằng các đoạn văn tự nhiên, mộc mạc, có kèm hình ảnh minh họa thực tế để tăng tính thuyết phục.

---

## 4.1. Mục tiêu và Phương pháp Kiểm thử
*   **Nội dung:** Mô tả mục đích cốt lõi của việc kiểm thử hệ thống (đảm bảo độ chính xác của luồng AI, tính ổn định của Backend, trải nghiệm của App/Web). Trình bày tóm tắt 3 phương pháp sẽ sử dụng: 
    *   **Kiểm thử tính khả dụng (Usability Testing):** Trải nghiệm người dùng có dễ dùng không.
    *   **Kiểm thử chức năng (Functional Testing):** Các nút bấm, luồng xử lý có chạy đúng không.
    *   **Kiểm thử cơ sở dữ liệu (Database Testing):** Dữ liệu có lưu đúng, lưu đủ, không mất mát không.
*   **Cách viết:** Khoảng 3-4 đoạn văn tự nhiên, giải thích mộc mạc.

## 4.2. Kịch bản Kiểm thử Chức năng Hệ thống (Test Cases)
*   **Nội dung:** Lập các bảng kịch bản kiểm thử cho các chức năng chính đã đề cập ở Chương 3. Trình bày gọn gàng, dễ hiểu.
*   **Cấu trúc bảng chuẩn:** `| Chức năng | Mục đích kiểm thử | Kịch bản (Thao tác) | Kết quả mong đợi |`
*   **Các cụm chức năng cần liệt kê trong bảng:**
    *   **Nhóm App:** Nhập chi tiêu bằng văn bản (NLU), Quét hóa đơn (OCR), Nhắn tin với MiMo, Cảnh báo vượt hạn mức ngân sách.
    *   **Nhóm Web Admin:** Khóa/Mở tài khoản người dùng, Kéo thả gán nhãn hóa đơn mờ, Sửa System Prompt của LLM.
*   **Cách viết:** Chỉ dùng bảng biểu, nội dung điền vào bảng không viết rườm rà.

## 4.3. Kết quả Kiểm thử và Đánh giá Thực tế
*   **Nội dung:** Dựa trên các kịch bản ở 4.2, trình bày kết quả thực tế đạt được, kết hợp đánh giá trải nghiệm và ảnh giao diện minh họa. (Riêng phần kết quả kiểm thử độ chính xác AI đã đưa lên Chương 3, nên ở đây chỉ tập trung vào chức năng hệ thống).

### 4.3.1. Đánh giá trên Ứng dụng Di động (Mobile App)
*   **Nội dung:** Đánh giá bằng đoạn văn tự nhiên về độ mượt mà khi sử dụng. Giao diện có phản hồi nhanh không khi người dùng quét hóa đơn hoặc chat với AI? Cảm nhận về tính năng Recap.
*   **Minh họa:** Chèn 1-2 ảnh giao diện kết quả test thành công (VD: ảnh màn hình báo đã thêm giao dịch thành công).

### 4.3.2. Đánh giá trên Trang Quản trị (Web Admin)
*   **Nội dung:** Đánh giá tính tiện dụng khi Admin phải xử lý lượng dữ liệu lớn. Thao tác gán nhãn trên Canvas có bị giật lag không? Chức năng cập nhật Prompt phản hồi tức thời như thế nào?
*   **Minh họa:** Chèn 1 ảnh giao diện thao tác thành công trên Web.

### 4.3.3. Đánh giá Tính toàn vẹn Cơ sở dữ liệu và Unit Test
*   **Nội dung:** Đánh giá độ tin cậy của CockroachDB (dữ liệu giao dịch có lưu đúng sau khi AI bóc tách xong không). Nêu ngắn gọn kết quả chạy Unit Test của các hàm Backend cốt lõi (tỷ lệ Pass/Fail).
*   **Cách viết:** 1-2 đoạn văn tự nhiên.
