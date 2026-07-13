# Tài Liệu Mô Tả Các Hiển Thị Của Action Tại Mimo Chat

Tài liệu này mô tả chi tiết cách từng `action_type` được xử lý và hiển thị dưới dạng UI (User Interface) trong tính năng Chat của trợ lý Mimo.

---

## 1. Các Action Sử Dụng UI Đặc Thù (Custom Cards & Charts)

Những action này cung cấp thông tin trực quan, vì thế thay vì trả về text thuần, Mimo sẽ kết xuất (render) thành các thành phần giao diện động.

### 1.1 `REPORT_GENERAL` & `REPORT_COMPARE`
- **Mục đích:** Báo cáo tổng quan chi tiêu theo thời gian, theo danh mục hoặc so sánh các chu kỳ (tháng này với tháng trước).
- **Hiển thị (`_ReportStoryCard`):** 
  - Render dưới dạng một khung Card lớn nổi bật.
  - Sử dụng **Biểu đồ tròn (Pie Chart)** cho `REPORT_GENERAL` để thể hiện tỷ trọng các danh mục chi tiêu.
  - Sử dụng **Biểu đồ cột (Bar Chart)** cho `REPORT_COMPARE` nhằm dễ dàng đối chiếu sự tăng/giảm giữa hai mốc thời gian hoặc danh mục.
  - Đi kèm với biểu đồ là text tóm tắt ngắn gọn như "Tổng chi", "Tăng/giảm X%".
- **Đánh giá logic:** Rất phù hợp. Người dùng dễ dàng nắm bắt tài chính qua biểu đồ hơn là đọc một đoạn văn bản dài.

### 1.2 `SEARCH_RECORD`
- **Mục đích:** Tìm kiếm các giao dịch cũ dựa trên từ khóa, số tiền hoặc danh mục.
- **Hiển thị (`_SearchResultCard`):**
  - Render một danh sách cuộn (List) tối đa 10 giao dịch gần nhất khớp với điều kiện.
  - Mỗi mục (item) hiển thị rõ: Icon danh mục, ghi chú (note), số tiền (được định dạng VND) và ngày giờ giao dịch.
  - Trả về câu thông báo cài sẵn: *"Mimo đã chuẩn bị sẵn dữ liệu: Tìm kiếm giao dịch. Bạn hãy xem qua nhé!"*
- **Đánh giá logic:** Đúng chức năng. Cho phép người dùng duyệt và kiểm tra lại lịch sử giao dịch một cách trực quan ngay trong khung chat.

### 1.3 `SUGGEST_BUDGET`
- **Mục đích:** Mimo phân tích thói quen và đề xuất hạn mức chi tiêu mới thông minh hơn.
- **Hiển thị (`_BudgetSuggestionCard`):**
  - Trình bày dạng một Check-list.
  - Liệt kê các danh mục kèm theo `số tiền đề xuất` và `số tiền cũ` (bị gạch ngang nếu có sự thay đổi).
  - Có các ô checkbox bên cạnh mỗi danh mục để người dùng tùy ý lựa chọn áp dụng hoặc không.
  - Có 2 nút hành động: **"Lưu"** (Lưu các hạn mức đã chọn) và **"Hủy/Bỏ qua"**.
- **Đánh giá logic:** Thiết kế hoàn hảo cho tính năng này. Người dùng có toàn quyền chọn lọc các gợi ý từ AI thay vì bị ép buộc thay đổi tất cả hạn mức.

---

## 2. Các Action Thao Tác (Command Actions)

Với những Action thay đổi trạng thái hoặc thiết lập của hệ thống, Mimo yêu cầu người dùng xác nhận thông qua một Card nhỏ gọi là `_ActionPreview`, trước khi gửi yêu cầu lên Backend.

### 2.1 Các Action: `SET_LIMIT`, `SET_GOAL`, `SET_TONE`, `SYSTEM_SETTING`, `SET_USERNAME`, `SET_ALERT`
- **Hiển thị (`_ActionPreview`):**
  - Xuất hiện như một tấm thẻ (Card) nhỏ màu xám nhạt với viền màu chủ đạo (Teal).
  - Có tiêu đề mô tả ngắn gọn lệnh chuẩn bị thực hiện. VD: *"Đặt hạn mức ăn uống 5.000.000đ"*, *"Tạo mục tiêu tiết kiệm Mua Xe 50.000.000đ"*.
  - Có nút **"Thực hiện"** (Execute) để xác nhận.
- **Sau khi thực hiện:**
  - Card đổi sang trạng thái đã xác nhận (dấu tick xanh).
  - Mimo sẽ trả lời lại bằng chính văn bản tự nhiên, dí dỏm do LLM sinh ra (VD: *"Đã lưu hạn mức ăn uống cho bạn rồi nha! Cố gắng giữ phong độ nhé! 😜"*).
- **Đánh giá logic:** Rất an toàn và tự nhiên. Đảm bảo người dùng không vô tình thực hiện các thao tác thay đổi dữ liệu quan trọng khi chat lầm, đồng thời giữ được sự thân thiện trong cách giao tiếp của AI sau khi hành động hoàn tất.

---

## 3. Tổng Kết

- Việc chia rẽ rõ ràng giữa **"Dữ liệu trực quan (Biểu đồ, List)"** và **"Xác nhận lệnh (Thực hiện thao tác)"** đang hoạt động chính xác theo thiết kế.
- Phần sửa đổi logic để các `action_type` đặc thù dùng câu chào cố định (`fallbackText`) còn các `action_type` thao tác dùng phản hồi sinh động của LLM (`llmText`) giúp trải nghiệm trò chuyện vừa có tính thực dụng vừa duy trì được Persona (tính cách) của Mimo.
