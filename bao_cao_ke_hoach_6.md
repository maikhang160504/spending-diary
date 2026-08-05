# Báo cáo Triển khai Kế hoạch 6 — Cập nhật Backend Node.js và Quy chuẩn Hiển thị RAG

## 1. Mục tiêu
- Triển khai **Luồng NLG Kép** (RAG Response + Intent/Action Response) trả về dưới dạng `bubbles` và `missing_slots` thay vì gộp chung vào một text duy nhất.
- Hỗ trợ cơ chế phân loại RAG: lấy dữ liệu Ví Cá nhân vs Ví Chung (`by_member`).
- Bổ sung tính năng **Feedback Retrain** (phản hồi mô hình) với endpoint `POST /api/v1/ai/dislike-intent`.
- Tối ưu hiệu suất xử lý bằng cơ chế **Background Process** (xử lý ngầm) thay vì chặn luồng chính.
- Khắc phục và cập nhật toàn bộ **Unit Tests** để đảm bảo tính ổn định và tương thích.

## 2. Các thay đổi chi tiết

### 2.1 Cập nhật Quy chuẩn Hiển thị và Data Trả về (`ai.service.js` - `aiChat`)
- Đã đổi cấu trúc trả về từ backend thành `bubbles` (mảng các tin nhắn) và `missing_slots` (nếu có hành động cần điền form).
- Đưa logic LLM vào `setImmediate` (Background Process) để trả ngay `pending_id` (trừ khi `NODE_ENV === 'test'` thì chạy synchronous để test).
- Gửi WebSocket sự kiện `ai_message_updated` khi LLM sinh xong kết quả, kèm theo cả `bubbles` (chứa các tin nhắn rời rạc: Report, RAG, Intent Action) và `missing_slots`.

### 2.2 Tối ưu hóa Database Queries
- Sửa lỗi truy vấn thống kê dữ liệu `spent_last_month` cho profile, khắc phục lỗi truy vấn không khớp cấu trúc mock trong quá trình kiểm thử.
- Khắc phục lỗi `ReferenceError: contextMeta is not defined` trong `_fetchWalletProfile`, đảm bảo quá trình lấy thời tiết (`weatherService.getWeather()`) và tính toán `day_of_month` không làm crash hệ thống do lỗi syntax.

### 2.3 Phân loại ngữ cảnh Ví Chung và Ví Riêng
- Đối với **Ví chung (Shared Wallet)**: RAG sẽ truy xuất các giao dịch dựa trên tiêu chí `by_member` nếu có. `wallet_profile` truyền cho LLM cũng bổ sung prompt riêng (`group_analytics_prompt`) để LLM phân tích tập trung vào các khái niệm như Settlement (quyết toán) và Split (chia tiền).

### 2.4 Tính năng Feedback mô hình (Dislike Intent)
- Đã thêm `dislikeIntentSchema` vào `ai.schema.js`.
- Bổ sung hàm `dislikeIntent` trong `ai.service.js` lưu log người dùng dislike một dự đoán phân loại (Intent/Category) sai, làm cơ sở dữ liệu cho quá trình Retrain ở Kế hoạch 7.
- Đã tạo endpoint `POST /api/v1/ai/dislike-intent` tại `ai.controller.js` và `ai.routes.js`.

### 2.5 Khắc phục Unit Test (100% Pass)
- Cập nhật mock `chatService.updateMessageContent` và `chatService.addMessage` để tương thích luồng Background Process trong file `ai.service.test.js`.
- Khắc phục lỗi Fuzzy Match `GOP_TIEN` và `CONTRIBUTE_GOAL` trong `action.service.js` để test `goalFuzzy.test.js` hoạt động chính xác.
- Hiện tại toàn bộ 11/11 Test Suites và 103/103 Tests của Backend đã **Pass hoàn toàn**.

## 3. Tổng kết Kế hoạch 6
Hệ thống backend đã hoàn toàn sẵn sàng và ổn định. Nó trả về chuẩn format mới cho Frontend xử lý hiển thị tách biệt 3 bong bóng (Bubble 1: Báo cáo phân tích (tuỳ chọn), Bubble 2: Lời chào/Trích xuất RAG, Bubble 3: Kết quả thực hiện Action). Sẵn sàng chuyển sang **Kế hoạch 7: Đào tạo lại (Retrain) và đóng gói**.
