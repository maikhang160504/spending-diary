# Báo cáo kết quả triển khai Kế hoạch 5: Cập nhật giao diện kiểm thử câu lệnh hệ thống và trang quản trị Dashboard

## 1. Giới thiệu tổng quan và mục tiêu nâng cấp
Trong khuôn khổ hoàn thiện hệ thống quản trị WebAdmin cho mô hình ngôn ngữ tự nhiên hai tầng, Kế hoạch 5 tập trung vào hai thành phần cốt lõi: trang kiểm thử câu lệnh hệ thống BotPromptsPage và trang tổng quan chất lượng DashboardPage. Mục tiêu là cho phép người quản trị kiểm chứng trực tiếp cơ chế chọn lọc quy tắc theo từng ý định suy luận, hỗ trợ ngữ cảnh gọi từ các màn hình khác nhau trên ứng dụng di động, đồng thời chuẩn hóa nhãn chỉ số thống kê trên bảng điều khiển để phù hợp với kiến trúc phân loại mới.

## 2. Chi tiết cấu trúc cải tiến trên giao diện WebAdmin và máy chủ NLU

### Cải tiến trang kiểm thử câu lệnh hệ thống (BotPromptsPage)
Trên giao diện BotPromptsPage, hệ thống được bổ sung hai bộ lọc lựa chọn trực quan ngay trên vùng kiểm thử hội thoại trực tiếp:
- Ngữ cảnh gọi từ ứng dụng (caller_context): Cho phép quản trị viên giả lập luồng gọi từ màn hình trò chuyện tổng hợp hoặc màn hình ghi chép nhanh (addstory). Khi chọn ngữ cảnh ghi chép nhanh, mô hình tự động bỏ qua giai đoạn phân loại ý định tầng 1 và ép buộc toàn bộ câu thoại vào quy tắc bóc tách giao dịch.
- Ép buộc ý định suy luận (force_intent): Cho phép quản trị viên chủ động chọn chế độ tự động phân loại hoặc chỉ định cố định một trong ba ý định: ghi chép chi tiêu, thực thi hành động, hoặc trò chuyện tự do.
- Khu vực hiển thị kết quả: Hiển thị minh bạch tên quy tắc hệ thống đã được mô hình lựa chọn (rule_used), nhãn ý định dự đoán cùng độ tin cậy, và bộ giải mã đang thực thi.

| Thuộc tính đầu vào | Giá trị hỗ trợ | Ý nghĩa xử lý trên máy chủ NLU |
| --- | --- | --- |
| Ngữ cảnh gọi | chat, addstory | Xác định luồng xuất phát từ người dùng để định tuyến quy tắc suy luận phù hợp |
| Ép buộc ý định | Auto, Record, Action, Chitchat | Kiểm chứng độc lập hiệu năng của tầng 2 mà không bị ảnh hưởng bởi tầng 1 |
| Ghi đè câu lệnh | Văn bản tùy biến | Đánh giá phản ứng của trợ lý ảo Mimo khi thay đổi câu lệnh hệ thống |

Bảng mô tả các thuộc tính cấu hình mới trên giao diện kiểm thử trực tiếp của trang BotPromptsPage nhằm phục vụ kiểm chứng mô hình hai tầng.

### Chuẩn hóa nhãn chất lượng trên trang tổng quan (DashboardPage)
Trong cấu trúc cũ, chỉ số độ chính xác của tầng phân loại ý định được hiển thị chung chung là độ chính xác NLU. Trong kiến trúc hai tầng mới, nhãn hiển thị đã được chuẩn hóa để phản ánh đúng vai trò của từng giai đoạn:
- Tiêu đề khu vực thống kê được cập nhật thành: Intent Accuracy & Telemetry Runs.
- Biểu đồ theo dõi tiến trình huấn luyện ý định được đổi nhãn thành: Intent Accuracy (Stage 1).
- Biểu đồ theo dõi danh mục chi tiêu được ghi rõ thành: Category Accuracy (Stage 2).

| Thành phần biểu đồ | Nhãn hiển thị cũ | Nhãn hiển thị chuẩn hóa mới |
| --- | --- | --- |
| Tiêu đề cụm biểu đồ | Model Accuracy & Telemetry Runs | Intent Accuracy & Telemetry Runs |
| Biểu đồ tầng 1 | NLU Intent Classifier | Intent Accuracy (Stage 1) |
| Biểu đồ tầng 2 | NLU Category Model | Category Accuracy (Stage 2) |

Bảng đối chiếu danh sách các nhãn biểu đồ thống kê trước và sau khi chuẩn hóa trên trang tổng quan DashboardPage.

## 3. Cải tiến máy chủ suy luận Python FastAPI (NLU Engine)
Tại lớp xử lý suy luận của máy chủ Python, endpoint kiểm thử nhanh đã được nâng cấp để kết nối trực tiếp với hàm suy luận hai tầng mới:
- Cập nhật hàm run_llm_nlu_v2: Bổ sung tham số nhận câu lệnh hệ thống ghi đè từ người quản trị, đồng thời đảm bảo kết quả trả về luôn kèm theo trường tên quy tắc đã sử dụng (rule_used).
- Cập nhật bộ định tuyến FastAPI: Endpoint nhận tải trọng chứa ngữ cảnh gọi và ý định ép buộc, ánh xạ chính xác sang luồng xử lý tương ứng và tính toán độ trễ suy luận.

## 4. Kết quả kiểm thử tự động và xác nhận chất lượng
Toàn bộ logic mới đã được kiểm chứng bằng tập kiểm thử tự động với thư viện pytest trên máy chủ suy luận, đạt tỷ lệ thông qua tuyệt đối 3/3 kịch bản:
- Kiểm thử ép buộc ý định ghi chép: Xác nhận khi truyền ngữ cảnh addstory, hệ thống bỏ qua giai đoạn 1 và trả về đúng tên quy tắc ghi chép chi tiêu.
- Kiểm thử ghi đè câu lệnh hệ thống: Xác nhận câu lệnh tùy biến từ giao diện WebAdmin được truyền trọn vẹn vào hàm gọi mô hình ngôn ngữ lớn.
- Kiểm thử bộ định tuyến API: Xác nhận cổng giao tiếp HTTP nhận và xử lý đầy đủ các tham số mới mà không gây sai lệch cấu trúc dữ liệu trả về.

| Tên kịch bản kiểm thử | Đối tượng kiểm chứng | Kết quả thực thi |
| --- | --- | --- |
| test_run_llm_nlu_v2_forced_intent_record | Cơ chế bỏ qua tầng 1 khi ép buộc ý định ghi chép | Thông qua |
| test_run_llm_nlu_v2_override_prompt | Cơ chế áp dụng câu lệnh hệ thống ghi đè từ WebAdmin | Thông qua |
| test_router_test_prompt_addstory_force_record | Cơ chế ánh xạ tham số từ cổng giao tiếp HTTP | Thông qua |

Bảng tổng hợp kết quả thực thi bộ kiểm thử tự động cho các cải tiến của Kế hoạch 5 trên máy chủ NLU.
