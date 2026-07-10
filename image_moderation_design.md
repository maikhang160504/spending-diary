# Thiết kế Hệ thống Kiểm duyệt Hình ảnh (Image Moderation System)

Tài liệu này mô tả chi tiết các giải pháp kỹ thuật để tự động nhận diện và ngăn chặn hình ảnh nhạy cảm (NSFW - Not Safe For Work, bạo lực, đồi trụy) tải lên ứng dụng (qua luồng Hóa đơn hoặc Story).

---

## 1. Vấn đề hiện tại
- Tính năng **Quét hóa đơn (Bill OCR)** sử dụng LayoutLMv3, PaddleOCR, VietOCR. Đây là các mô hình trích xuất văn bản (Text Extraction) chuyên biệt. Chúng hoàn toàn mù tịt về ý nghĩa hình ảnh và không có bộ lọc an toàn.
- Tính năng **Thêm Story bằng Camera** đẩy trực tiếp ảnh lên Storage (Cloudflare R2) làm hình nền.
- **Rủi ro:** Người dùng có thể cố tình chụp và tải lên các hình ảnh phản cảm. App hiện tại sẽ lưu và hiển thị chúng công khai trong nhóm (Shared Wallet), vi phạm chính sách nội dung.
- **Thách thức UX:** Nếu hệ thống kiểm duyệt đặt ở Server (như Google Cloud Vision) bắt người dùng phải "Đợi duyệt xong mới được Upload", nó sẽ gây ra độ trễ (latency), làm app có cảm giác chậm chạp.

---

## 2. Các Mẫu Kiến trúc Giải quyết (Architectural Patterns)

Để giải quyết bài toán vừa lọc được ảnh rác, vừa giữ cho luồng Upload siêu mượt, chúng ta có 3 phương pháp thiết kế (từ cơ bản đến nâng cao):

### Phương pháp 1: Post-Moderation (Hậu kiểm - Xóa ngầm)
* **Luồng chạy:** 
  1. Người dùng upload -> App báo thành công lập tức (UX siêu nhanh).
  2. Server lưu Data và tạo Giao dịch/Story.
  3. Server bắn 1 Job chạy ngầm (Background Worker) đi kiểm tra ảnh qua API hoặc Local AI.
  4. Nếu ảnh NSFW -> Tự động kích hoạt luồng "Xóa giao dịch", xóa ảnh trên Cloud, và gửi Push Notification về máy người dùng: *"Giao dịch đã bị gỡ do hình ảnh vi phạm tiêu chuẩn cộng đồng"*.
* **Đánh giá:** Rất dễ làm, UX nhanh. Tuy nhiên có rủi ro "lọt ảnh": trong khoảng 2-3 giây hình ảnh chờ được quét xong, thành viên khác trong Ví chung có thể đã vô tình nhìn thấy ảnh nhạy cảm đó.

### Phương pháp 2: Blur-First, Moderate-Later (Làm mờ trước, duyệt sau)
Đây là cách các mạng xã hội lớn xử lý nội dung.
* **Luồng chạy:**
  1. Khi upload ảnh lên, database thêm trường `moderation_status = 'pending'`. 
  2. Ở màn hình hiển thị Story hoặc Chi tiết giao dịch, nếu ảnh đang là `pending`, ứng dụng Flutter sẽ phủ một lớp làm mờ cực mạnh (Blur) lên bức ảnh kèm dòng chữ *"Đang kiểm duyệt hình ảnh..."*.
  3. Background Worker trên Server chạy quét ảnh.
  4. Nếu An toàn -> Đổi `status` thành `approved`, bắn WebSocket để app tự động gỡ lớp Blur.
  5. Nếu Vi phạm -> Đổi `status` thành `rejected`, server tự xóa ảnh, app thay bằng hình placeholder *"Ảnh vi phạm"*.
* **Đánh giá:** Là giải pháp cân bằng tuyệt vời. Vừa đảm bảo upload tức thì (Zero latency), vừa bảo vệ 100% người dùng khác trong Ví chung không bị thấy ảnh nhạy cảm.

### Phương pháp 3: Edge Moderation (Kiểm duyệt tại thiết bị)
Đưa AI xuống thẳng điện thoại của người dùng.
* **Luồng chạy:** 
  1. Nhúng một mô hình AI siêu nhẹ (TensorFlow Lite - `nsfwjs_mobile`) trực tiếp vào app Flutter. 
  2. Khi người dùng vừa chọn ảnh xong từ Thư viện/Camera, chip CPU của điện thoại sẽ quét bức ảnh đó (mất khoảng 0.1 giây và **không cần mạng**).
  3. Nếu phát hiện nhạy cảm, App sẽ báo lỗi *"Ảnh nhạy cảm"* và cấm nút Upload.
* **Đánh giá:** Giải pháp triệt để và hoàn hảo nhất về mặt Server (0 đồng chi phí server, 0 giây upload delay).
* **Độ chính xác:** Tuy nhiên, vì Model siêu nhẹ (chỉ ~2-5MB), độ chính xác chỉ đạt khoảng 85-90%. Mô hình nhận diện cực tốt ảnh khỏa thân (Porn) hoặc Hentai, nhưng dễ bị đánh lừa bởi ảnh nhiều màu da (chụp cận cảnh đùi gà, ngón tay) và kém nhạy với ảnh máu me, bạo lực phức tạp.

---

## 3. Khuyến nghị Giải pháp Tối ưu: Mô hình Kết hợp (Hybrid)

Đối với một ứng dụng Quản lý chi tiêu, mục tiêu chính là ngăn chặn những trò đùa ác ý tải ảnh khỏa thân/đồi trụy. Việc yêu cầu độ chính xác 99.9% (cho cả bạo lực/vũ khí) như mạng xã hội là không bắt buộc.

Do đó, **Mô hình Hybrid (Kết hợp Phương pháp 3 và Phương pháp 2)** là tối ưu nhất:

1. **Tầng 1 - Edge Moderation (Tại App):** 
   - Tích hợp TensorFlow Lite (Gói TFLite nặng khoảng 3MB).
   - Chặn ngay lập tức (> 95% độ tin cậy) các ảnh đồi trụy rõ ràng ngay tại thiết bị. Người dùng không tốn băng thông, server không tốn tài nguyên.
2. **Tầng 2 - Blur-First (Tại Server):**
   - Nếu App cho phép qua, Server nhận ảnh nhưng đánh dấu `pending` (làm mờ).
   - Chạy ngầm một Local AI Model (như `Falconsai/nsfw_image_detection`) trên Backend để quét cẩn thận hơn (bắt bạo lực, bắt các ảnh lách luật). 
   - An toàn 100% mới gỡ làm mờ.

### Kế hoạch Triển khai (Đề xuất ban đầu)
Nếu muốn triển khai nhanh và dễ nhất trước mắt, nên chọn **Phương pháp 2 (Làm mờ trước, Duyệt ngầm sau bằng TensorFlow Node.js)**. 
- Nó không làm nặng file cài đặt App Flutter.
- Upload vẫn mượt.
- Chỉ tốn một ít RAM trên Node.js Server.
