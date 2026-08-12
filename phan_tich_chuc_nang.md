# Báo cáo Phân tích Yêu cầu Chức năng (Mục 1.2)

Dựa trên quá trình quét và đối chiếu trực tiếp Bảng 1.1 trong `Luan_van_Hoan_chinh.md` với mã nguồn thực tế tại thư mục `app/backend/src/routes` và `app/frontend/web-admin/src/pages`, dưới đây là các đánh giá chi tiết:

## 1. Hệ thống đã liệt kê ĐỦ chức năng chưa?
**Kết luận:** Bảng 1.1 hiện đang bị **THIẾU** một số chức năng lớn đã được lập trình trong source code. 
Đặc biệt, một số chức năng đã được bạn nhắc đến ở Chương 3 (Mục 3.3.1.6) nhưng lại quên không liệt kê vào Bảng Use Case 1.1 ở Chương 1.

**Các chức năng cần bổ sung vào Bảng 1.1 (Phân hệ Người dùng trên app):**
- **Quản lý Mục tiêu tiết kiệm (Goals):** Đã có route `goals.routes.js` và có nhắc trong mục 3.3.1.6, nhưng thiếu trong bảng 1.1.
- **Quản lý Sổ nợ (Loans):** Đã có route `loans.route.js` và có nhắc trong mục 3.3.1.6.
- **Nhìn lại hành trình (Recap/Stories):** Tính năng tổng kết dạng thẻ giống Spotify Wrapped (route `stories.routes.js`).
- **Giao dịch lặp lại định kỳ (Recurring):** Hệ thống có route `recurring.routes.js` nhưng chưa được nhắc đến trong Bảng 1.1.
- ** / Gamification (Streak):** Hệ thống có logic tính streak (route `users/me/streak`), nếu bạn dự định đưa vào báo cáo thì cần bổ sung.
- **Chia Bill Nhóm (Expense Groups):** Có route `groups.routes.js` chuyên xử lý chia tiền. (Đang được gộp chung vào dòng "Quản lý ví tiền" nhưng tách ra sẽ hay hơn).

**Các chức năng cần bổ sung vào Bảng 1.1 (Phân hệ Quản trị trên Web):**
- **Cấu hình luồng AI dự phòng (NLU Tiered Config):** Tính năng chọn chạy mô hình trên Modal hay Gemini chưa được liệt kê rõ ở WebAdmin.

---

## 2. Tên chức năng có khó hiểu / quá hàn lâm không?
**Kết luận:** Một số tên chức năng đang hơi cứng nhắc hoặc dùng từ vựng kỹ thuật quá sâu đối với một bảng mô tả "Yêu cầu chức năng" (Vốn dành cho người đọc hiểu nghiệp vụ, thay vì kỹ thuật). Dựa theo quy tắc "Tone: Dễ hiểu & Tự nhiên", đề xuất sửa như sau:

- **"Phản hồi ý định sai"** (App) 
  => Đổi thành: **"Báo cáo lỗi nhận diện AI"** hoặc **"Góp ý sửa lỗi trợ lý ảo"**.
- **"Xử lý ngôn ngữ tự nhiên hai tầng"** (Máy chủ AI) 
  => Đổi thành: **"Nhận diện ý định và trích xuất thông tin"**. (Việc dùng 2 tầng là chi tiết triển khai kỹ thuật, không nên đặt làm tên Use Case).
- **"Quản lý trạng thái hộp thoại"** (Máy chủ Backend) 
  => Đổi thành: **"Lưu trữ và duy trì ngữ cảnh trò chuyện"**.
- **"Ra lệnh huấn luyện AI" / "Xuất dữ liệu huấn luyện LLM"** (WebAdmin) 
  => Đổi thành: **"Quản lý tiến trình huấn luyện AI"** (Mô tả gộp việc xuất dữ liệu và kích hoạt huấn luyện).

---

## 3. Có mô tả thừa (Fake features) so với những gì đã thiết kế không?
**Kết luận:** KHÔNG CÓ FAKE FEATURES NÀO NGHIÊM TRỌNG.
Những tính năng mang tính chất "quảng cáo" cao trong bảng đều thực sự tồn tại trong code:
- **Tự động gợi ý ngân sách 50/30/20:** Code backend thực sự có hàm tính toán `50/30/20 Financial Calibration` tại file `suggestion.service.js`. Nên đây là tính năng thật 100%.
- **Chụp ảnh hóa đơn (OCR):** Code có phân hệ pipeline gọi LayoutLMv3 và upload.
- **Dán nhãn dữ liệu ảnh trên web:** File `BillRetrainPage.jsx` trên Frontend Admin thực sự tồn tại.

## Tóm lại (Hành động cần làm):
Bạn cần mở file `Luan_van_Hoan_chinh.md`, di chuyển đến phần Bảng 1.1 và:
1. Thêm khoảng 3-4 hàng mới để mô tả Mục tiêu tiết kiệm, Sổ nợ, Giao dịch lặp lại.
2. Điều chỉnh lại một số cụm từ hàn lâm cho tự nhiên hơn.
3. Sửa lại Sơ đồ Use Case (Hình 1.2, 1.3) ở mục 1.3 để các bong bóng Use Case khớp chính xác 100% với Bảng 1.1 vừa sửa.
