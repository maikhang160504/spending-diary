import re

replacements = [
(
r"""```mermaid
flowchart TD
    A[Người dùng nhập văn bản và bấm Gửi] --> B{Văn bản có rỗng?}
    B -- Có --> C[Bỏ qua, không xử lý]
    B -- Không --> D[Hiển thị trạng thái Loading trên UI]
    D --> E[Dùng thư viện Dio gọi HTTP POST lên Máy chủ]
    E --> F[Máy chủ phân tích NLU]
    F --> G[Trả về dữ liệu JSON chứa Số tiền & Danh mục]
    G --> H[Ứng dụng giải mã JSON]
    H --> I[Cập nhật biến trạng thái cục bộ]
    I --> J[Tự động vẽ lại màn hình UI và trừ tiền ví]
```""",
r"""```plantuml
@startuml
start
:Người dùng nhập văn bản và bấm Gửi;
if (Văn bản có rỗng?) then (Có)
  :Bỏ qua, không xử lý;
  stop
else (Không)
  :Hiển thị trạng thái Loading trên UI;
  :Dùng thư viện Dio gọi HTTP POST lên Máy chủ;
  :Máy chủ phân tích NLU;
  :Trả về dữ liệu JSON chứa Số tiền & Danh mục;
  :Ứng dụng giải mã JSON;
  :Cập nhật biến trạng thái cục bộ;
  :Tự động vẽ lại màn hình UI và trừ tiền ví;
  stop
endif
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Người dùng chụp ảnh hóa đơn] --> B[Ứng dụng nén dung lượng ảnh trực tiếp trên máy]
    B --> C[Tải ảnh đã nén lên kho lưu trữ R2]
    C --> D[Lấy đường dẫn URL của ảnh]
    D --> E[Gửi URL lên Máy chủ qua thư viện Dio]
    E --> F[Giải phóng giao diện, người dùng được dùng tiếp App]
    F --> G[Máy chủ gọi AI quét ảnh Luồng hoạt động của chức năng quét hóa đơn.chạy ngầm]
    G --> H[Hoàn tất, gửi thông báo Push báo kết quả]
```""",
r"""```plantuml
@startuml
start
:Người dùng chụp ảnh hóa đơn;
:Ứng dụng nén dung lượng ảnh trực tiếp trên máy;
:Tải ảnh đã nén lên kho lưu trữ R2;
:Lấy đường dẫn URL của ảnh;
:Gửi URL lên Máy chủ qua thư viện Dio;
:Giải phóng giao diện, người dùng được dùng tiếp App;
:Máy chủ gọi AI quét ảnh chạy ngầm;
:Hoàn tất, gửi thông báo Push báo kết quả;
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Người dùng chọn mốc thời gian] --> B[Truy vấn giao dịch từ cơ sở dữ liệu]
    B --> C{Chọn thẻ báo cáo nào?}
    C -- Chi phí / Thu nhập --> D[Luồng Isolate gom nhóm và tính %]
    C -- So sánh chi tiêu --> E[Gọi API lên Máy chủ đối chiếu mức sống]
    D --> F[Vẽ biểu đồ bằng fl_chart]
    E --> G[Nhận kết quả % và lời bình luận]
    F --> H[Cập nhật UI màn hình]
    G --> H
```""",
r"""```plantuml
@startuml
start
:Người dùng chọn mốc thời gian;
:Truy vấn giao dịch từ cơ sở dữ liệu;
if (Chọn thẻ báo cáo nào?) then (Chi phí / Thu nhập)
  :Luồng Isolate gom nhóm và tính %;
  :Vẽ biểu đồ bằng fl_chart;
else (So sánh chi tiêu)
  :Gọi API lên Máy chủ đối chiếu mức sống;
  :Nhận kết quả % và lời bình luận;
endif
:Cập nhật UI màn hình;
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A1[Thêm giao dịch mới] --> A2[Lấy tổng chi & hạn mức từ cơ sở dữ liệu]
    A2 --> A3[Tính tỷ lệ % = Chi tiêu / Hạn mức]
    A3 --> A4{Tỷ lệ % >= 80%?}
    A4 -- Có --> A5[Hiển thị thanh tiến trình màu Đỏ báo động]
    A4 -- Không --> A6[Hiển thị thanh tiến trình màu Xanh an toàn]
```""",
r"""```plantuml
@startuml
start
:Thêm giao dịch mới;
:Lấy tổng chi & hạn mức từ cơ sở dữ liệu;
:Tính tỷ lệ % = Chi tiêu / Hạn mức;
if (Tỷ lệ % >= 80%?) then (Có)
  :Hiển thị thanh tiến trình màu Đỏ báo động;
else (Không)
  :Hiển thị thanh tiến trình màu Xanh an toàn;
endif
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    B1[Bấm nút gợi ý ngân sách] --> B2[Lấy lịch sử chi tiêu và thu nhập 3 tháng gần nhất]
    B2 --> B3[Tính chi tiêu nền theo trung bình trượt có trọng số]
    B3 --> B4[Đối chiếu lịch sử hạn mức tháng trước: sử dụng - hạn mức]
    B4 --> B5[Hiệu chuẩn tăng nếu vượt hạn mức hoặc giảm nếu dưới hạn mức]
    B5 --> B6[Cân đối tỷ lệ 50/30/20]
    B6 --> B7[Điền sẵn con số đề xuất sát thực tế lên giao diện]
```""",
r"""```plantuml
@startuml
start
:Bấm nút gợi ý ngân sách;
:Lấy lịch sử chi tiêu và thu nhập 3 tháng gần nhất;
:Tính chi tiêu nền theo trung bình trượt có trọng số;
:Đối chiếu lịch sử hạn mức tháng trước: sử dụng - hạn mức;
:Hiệu chuẩn tăng nếu vượt hạn mức hoặc giảm nếu dưới hạn mức;
:Cân đối tỷ lệ 50/30/20;
:Điền sẵn con số đề xuất sát thực tế lên giao diện;
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Người dùng gửi câu lệnh] --> B[Hiển thị tin nhắn chờ]
    B --> C[Gửi dữ liệu lên API Server]
    C --> D[Máy chủ AI phân tích ý định]
    D --> E{Ý định là gì?}
    E -- Trả lời thông thường --> F[Trả về văn bản]
    E -- Yêu cầu chuyển hướng --> G[Trả về văn bản kèm Nút bấm điều hướng]
    F --> H[Cập nhật giao diện trò chuyện]
    G --> H
    H --> I[Người dùng chạm vào nút bấm]
    I --> J[Chuyển sang màn hình Báo cáo]
```""",
r"""```plantuml
@startuml
start
:Người dùng gửi câu lệnh;
:Hiển thị tin nhắn chờ;
:Gửi dữ liệu lên API Server;
:Máy chủ AI phân tích ý định;
if (Ý định là gì?) then (Trả lời thông thường)
  :Trả về văn bản;
  :Cập nhật giao diện trò chuyện;
else (Yêu cầu chuyển hướng)
  :Trả về văn bản kèm Nút bấm điều hướng;
  :Cập nhật giao diện trò chuyện;
  :Người dùng chạm vào nút bấm;
  :Chuyển sang màn hình hệ thống tương ứng;
endif
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Người dùng khởi động Nhìn lại hành trình] --> B[Ứng dụng gửi yêu cầu lên Máy chủ]
    B --> C[Máy chủ truy vấn giao dịch lớn nhất, tháng tốn kém từ cơ sở dữ liệu]
    C --> D[Gửi dữ liệu thô sang máy chủ AI]
    D --> E[AI phân tích và sinh lời bình luận hóm hỉnh]
    E --> F[Đóng gói toàn bộ thành dữ liệu Recap]
    F --> G[Trả dữ liệu về Ứng dụng]
    G --> H[Vẽ giao diện Story tràn màn hình]
    H --> I{Người dùng vuốt sang thẻ khác?}
    I -- Có --> J[Chạy hiệu ứng chuyển cảnh và tải thẻ mới]
    I -- Không --> H
    J --> I
```""",
r"""```plantuml
@startuml
start
:Người dùng khởi động Nhìn lại hành trình;
:Ứng dụng gửi yêu cầu lên Máy chủ;
:Máy chủ truy vấn giao dịch lớn nhất, tháng tốn kém từ cơ sở dữ liệu;
:Gửi dữ liệu thô sang máy chủ AI;
:AI phân tích và sinh lời bình luận hóm hỉnh;
:Đóng gói toàn bộ thành dữ liệu Recap;
:Trả dữ liệu về Ứng dụng;
repeat
  :Vẽ giao diện Story tràn màn hình;
repeat while (Người dùng vuốt sang thẻ khác?) is (Có)
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Gửi yêu cầu tạo đơn hàng lên Máy chủ] --> B[Nhận URL thanh toán VNPay]
    B --> C[Mở trình duyệt nhúng tải URL thanh toán]
    C --> D[Gửi truy vấn trạng thái đơn hàng liên tục]
    D --> E{Trạng thái thanh toán?}
    E -- Đang chờ --> D
    E -- Thất bại / Hủy --> F[Đóng trình duyệt nhúng và báo lỗi]
    E -- Hoàn tất --> G[Đóng trình duyệt nhúng]
    G --> H[Cập nhật UI và gắn huy hiệu Cao cấp]
```""",
r"""```plantuml
@startuml
start
:Gửi yêu cầu tạo đơn hàng lên Máy chủ;
:Nhận URL thanh toán VNPay;
:Mở trình duyệt nhúng tải URL thanh toán;
repeat
  :Gửi truy vấn trạng thái đơn hàng liên tục;
repeat while (Trạng thái thanh toán?) is (Đang chờ)
if (Kết quả thanh toán?) then (Thất bại / Hủy)
  :Đóng trình duyệt nhúng và báo lỗi;
else (Hoàn tất)
  :Đóng trình duyệt nhúng;
  :Cập nhật UI và gắn huy hiệu Cao cấp;
endif
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Truy cập màn hình quản lý Ví tiền] --> B{Chọn nhóm thao tác?}
    B -- Thêm ví mới --> C[Nhập thông tin: tên, màu sắc, loại ví, số dư]
    B -- Tham gia ví --> D[Nhập mã xác nhận để tham gia Ví chung]
    B -- Xóa ví --> F[Xác nhận yêu cầu gỡ bỏ Ví khỏi hệ thống]
    C --> G[Gửi yêu cầu API tương ứng lên Máy chủ]
    D --> G
    F --> G
    G --> H{Phản hồi từ API?}
    H -- Lỗi --> I[Hiển thị cảnh báo Snackbar/Toast]
    H -- Thành công --> J[Cập nhật dữ liệu vào bộ nhớ đệm cục bộ]
    J --> K[Tải lại danh sách Ví trên giao diện]
```""",
r"""```plantuml
@startuml
start
:Truy cập màn hình quản lý Ví tiền;
if (Chọn nhóm thao tác?) then (Thêm ví mới)
  :Nhập thông tin: tên, màu sắc, loại ví, số dư;
else if (Thao tác?) then (Tham gia ví)
  :Nhập mã xác nhận để tham gia Ví chung;
else (Xóa ví)
  :Xác nhận yêu cầu gỡ bỏ Ví khỏi hệ thống;
endif
:Gửi yêu cầu API tương ứng lên Máy chủ;
if (Phản hồi từ API?) then (Lỗi)
  :Hiển thị cảnh báo Snackbar/Toast;
else (Thành công)
  :Cập nhật dữ liệu vào bộ nhớ đệm cục bộ;
  :Tải lại danh sách Ví trên giao diện;
endif
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Truy cập Quản lý giao dịch] --> B{Chọn chế độ xem}
    B -- Story / Gallery --> C[Xem giao dịch dạng thẻ ảnh trực quan]
    B -- Calendar --> D[Xem giao dịch phân bổ theo ngày trên Lịch]
    C --> E[Nhấn vào một giao dịch]
    D --> E
    E --> F[Hiển thị màn hình chi tiết giao dịch]
    F --> G{Loại thao tác?}
    G -- Xóa --> H[Xác nhận xóa và gửi yêu cầu API]
    G -- Sửa --> I[Thay đổi Danh mục, Số tiền, hoặc Ghi chú]
    I --> J[Nhấn Lưu và gửi yêu cầu cập nhật API]
    H --> K{Phản hồi API?}
    J --> K
    K -- Lỗi --> L[Hiển thị thông báo lỗi trên giao diện]
    K -- Thành công --> M[Cập nhật bộ nhớ đệm cục bộ]
    M --> N[Đóng màn hình và tải lại danh sách giao dịch]
```""",
r"""```plantuml
@startuml
start
:Truy cập Quản lý giao dịch;
if (Chọn chế độ xem) then (Story / Gallery)
  :Xem giao dịch dạng thẻ ảnh trực quan;
else (Calendar)
  :Xem giao dịch phân bổ theo ngày trên Lịch;
endif
:Nhấn vào một giao dịch;
:Hiển thị màn hình chi tiết giao dịch;
if (Loại thao tác?) then (Xóa)
  :Xác nhận xóa và gửi yêu cầu API;
else (Sửa)
  :Thay đổi Danh mục, Số tiền, hoặc Ghi chú;
  :Nhấn Lưu và gửi yêu cầu cập nhật API;
endif
if (Phản hồi API?) then (Lỗi)
  :Hiển thị thông báo lỗi trên giao diện;
else (Thành công)
  :Cập nhật bộ nhớ đệm cục bộ;
  :Đóng màn hình và tải lại danh sách giao dịch;
endif
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Màn hình Đăng nhập / Đăng ký] --> B{Hành động?}
    B -- Đăng nhập Google --> C[Gửi Token sang Firebase Auth]
    B -- Đăng nhập Email --> D[Kiểm tra thông tin tại Máy chủ]
    B -- Quên mật khẩu --> E[Gửi liên kết khôi phục qua Email]
    E --> F[Người dùng đặt lại mật khẩu mới]
    F --> A
    C --> G{Xác thực thành công?}
    D --> G
    G -- Lỗi --> H[Trả về thông báo lỗi cho người dùng]
    G -- Thành công --> I[Máy chủ sinh chuỗi mã thông báo bảo mật]
    I --> J[Trả mã thông báo an toàn về Ứng dụng]
    J --> K[Mở khóa truy cập vào màn hình chính]
```""",
r"""```plantuml
@startuml
start
repeat
  :Màn hình Đăng nhập / Đăng ký;
  if (Hành động?) then (Đăng nhập Google)
    :Gửi Token sang Firebase Auth;
  else if (Đăng nhập Email) then
    :Kiểm tra thông tin tại Máy chủ;
  else (Quên mật khẩu)
    :Gửi liên kết khôi phục qua Email;
    :Người dùng đặt lại mật khẩu mới;
    backward:Quay lại màn hình đăng nhập;
  endif
repeat while (Xác thực thành công?) is (Lỗi, trả thông báo lỗi)
:Máy chủ sinh chuỗi mã thông báo bảo mật (JWT);
:Trả mã thông báo an toàn về Ứng dụng;
:Mở khóa truy cập vào màn hình chính;
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Quản trị viên truy cập Bảng điều khiển] --> B[Hệ thống gửi đa luồng yêu cầu dữ liệu]
    B --> C[Truy xuất nhật ký AI và số liệu huấn luyện/RAG]
    B --> D[Truy xuất dữ liệu giao dịch thanh toán Premium]
    C --> E[Đóng gói 4 thẻ chỉ số AI và thanh tiến trình Readiness]
    D --> F[Dựng biểu đồ doanh thu và danh sách giao dịch]
    E --> G[Trả dữ liệu về Cổng Quản trị]
    F --> G
    G --> H[Làm mới giao diện Dashboard đa chức năng]
```""",
r"""```plantuml
@startuml
start
:Quản trị viên truy cập Bảng điều khiển;
fork
  :Truy xuất nhật ký AI và số liệu huấn luyện/RAG;
  :Đóng gói 4 thẻ chỉ số AI và thanh tiến trình Readiness;
fork again
  :Truy xuất dữ liệu giao dịch thanh toán Premium;
  :Dựng biểu đồ doanh thu và danh sách giao dịch;
end fork
:Trả dữ liệu về Cổng Quản trị;
:Làm mới giao diện Dashboard đa chức năng;
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Quản trị viên thao tác trên một tài khoản] --> B{Loại thao tác?}
    B -- Khóa tài khoản --> C[Cập nhật trạng thái Cấm truy cập vào Cơ sở dữ liệu]
    B -- Mở khóa tài khoản --> D[Gỡ bỏ trạng thái Cấm truy cập khỏi Cơ sở dữ liệu]
    C --> E[Gửi lệnh đồng bộ cấm/mở khóa sang Firebase Auth]
    D --> E
    E --> F{Thực thi thành công?}
    F -- Lỗi --> G[Hiển thị thông báo thất bại cho Quản trị viên]
    F -- Thành công --> H[Hiển thị thông báo thành công và làm mới danh sách]
```""",
r"""```plantuml
@startuml
start
:Quản trị viên thao tác trên một tài khoản;
if (Loại thao tác?) then (Khóa tài khoản)
  :Cập nhật trạng thái Cấm truy cập vào Cơ sở dữ liệu;
else (Mở khóa tài khoản)
  :Gỡ bỏ trạng thái Cấm truy cập khỏi Cơ sở dữ liệu;
endif
:Gửi lệnh đồng bộ cấm/mở khóa sang Firebase Auth;
if (Thực thi thành công?) then (Lỗi)
  :Hiển thị thông báo thất bại cho Quản trị viên;
else (Thành công)
  :Hiển thị thông báo thành công và làm mới danh sách;
endif
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Người dùng báo sai ý định trên App] --> B[Backend lưu vào bảng nlu_logs]
    B --> C[WebAdmin hiển thị danh sách phản hồi]
    C --> D[Quản trị viên phê duyệt nhãn đúng]
    D --> E[Tích lũy dữ liệu sạch]
    E --> F[Kích hoạt huấn luyện 2 tầng: Intent + Category]
    F --> G[Mô hình ứng viên lưu vào models_new]
    G --> H{Quản trị viên so sánh benchmark}
    H -->|Chất lượng đạt| I[Duyệt áp dụng: models_new đổi thành models]
    H -->|Chưa đạt| J[Giữ nguyên mô hình hiện tại]
```""",
r"""```plantuml
@startuml
start
:Người dùng báo sai ý định trên App;
:Backend lưu vào bảng nlu_logs;
:WebAdmin hiển thị danh sách phản hồi;
:Quản trị viên phê duyệt nhãn đúng;
:Tích lũy dữ liệu sạch;
:Kích hoạt huấn luyện 2 tầng: Intent + Category;
:Mô hình ứng viên lưu vào models_new;
if (Quản trị viên so sánh benchmark) then (Chất lượng đạt)
  :Duyệt áp dụng: models_new đổi thành models;
else (Chưa đạt)
  :Giữ nguyên mô hình hiện tại;
endif
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Hệ thống ghi nhận hóa đơn bị lỗi nhận diện] --> B[Đẩy ảnh vào Hàng đợi trên WebAdmin]
    B --> C[Quản trị viên mở ảnh trên Khung vẽ tương tác]
    C --> D{Chế độ gán nhãn?}
    D -- Thủ công --> E[Tự vẽ khung tọa độ và gán nhãn nghiệp vụ]
    D -- Tự động --> F[AI gợi ý khung tọa độ có sẵn]
    F --> G[Quản trị viên tinh chỉnh lại các khung bị lệch]
    E --> H[Nhấn nút Phê duyệt dữ liệu]
    G --> H
    H --> I[Xuất tập dữ liệu chuẩn để huấn luyện lại mô hình]
```""",
r"""```plantuml
@startuml
start
:Hệ thống ghi nhận hóa đơn bị lỗi nhận diện;
:Đẩy ảnh vào Hàng đợi trên WebAdmin;
:Quản trị viên mở ảnh trên Khung vẽ tương tác;
if (Chế độ gán nhãn?) then (Thủ công)
  :Tự vẽ khung tọa độ và gán nhãn nghiệp vụ;
else (Tự động)
  :AI gợi ý khung tọa độ có sẵn;
  :Quản trị viên tinh chỉnh lại các khung bị lệch;
endif
:Nhấn nút Phê duyệt dữ liệu;
:Xuất tập dữ liệu chuẩn để huấn luyện lại mô hình;
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A[Quản trị viên chọn Nhân cách và Tham số] --> B[Thiết lập Ngữ cảnh gọi và Ý định ép buộc]
    B --> C[Nhập câu thoại mẫu vào Môi trường kiểm thử]
    C --> D[Hệ thống nạp Quy tắc tương ứng và gọi mô hình AI]
    D --> E{Kiểm tra Rule Used và Đánh giá phản hồi?}
    E -- Chưa đạt --> A
    E -- Đạt yêu cầu --> F[Lưu cấu hình và Triển khai đồng loạt]
    F --> G[Thiết bị di động của người dùng tự động cập nhật]
```""",
r"""```plantuml
@startuml
start
repeat
  :Quản trị viên chọn Nhân cách và Tham số;
  :Thiết lập Ngữ cảnh gọi và Ý định ép buộc;
  :Nhập câu thoại mẫu vào Môi trường kiểm thử;
  :Hệ thống nạp Quy tắc tương ứng và gọi mô hình AI;
repeat while (Kiểm tra Rule Used và Đánh giá phản hồi?) is (Chưa đạt)
:Lưu cấu hình và Triển khai đồng loạt;
:Thiết bị di động của người dùng tự động cập nhật;
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    Input(["Tin nhắn người dùng + caller_context"]) --> Check{"Ngữ cảnh gọi?"}

    Check -->|"addstory (phím tắt ghi chép)"| ForceRecord["Bỏ qua tầng 1, ép intent = Record"]
    Check -->|"chat (trò chuyện)"| Stage1["Tầng 1: Phân loại ý định"]

    Stage1 --> Conf{"Độ tin cậy >= 0.65?"}
    Conf -->|"Đạt ngưỡng"| LoadRule
    Conf -->|"Dưới ngưỡng"| Vote["Bỏ phiếu đa số: TF-IDF + PhoBERT + LLM"]
    Vote --> LoadRule

    ForceRecord --> LoadRule["Chọn quy tắc tầng 2 từ llm_rules.json"]

    LoadRule -->|Record| RecordRule["Quy tắc ghi chép chi tiêu"]
    LoadRule -->|Action| ActionRule["Quy tắc lệnh điều khiển"]
    LoadRule -->|Chitchat| ChitchatRule["Quy tắc trò chuyện xã giao"]

    RecordRule & ActionRule & ChitchatRule --> LLM["Gọi Qwen 2.5 trên Modal GPU"]
    LLM --> Output(["Kết quả JSON: slots, response, emotion"])
```""",
r"""```plantuml
@startuml
start
:Nhận tin nhắn người dùng + caller_context;
if (Ngữ cảnh gọi?) then (addstory - phím tắt ghi chép)
  :Bỏ qua tầng 1, ép intent = Record;
else (chat - trò chuyện)
  :Tầng 1: Phân loại ý định;
  if (Độ tin cậy >= 0.65?) then (Dưới ngưỡng)
    :Bỏ phiếu đa số: TF-IDF + PhoBERT + LLM;
  else (Đạt ngưỡng)
  endif
endif
:Chọn quy tắc tầng 2 từ llm_rules.json;
if (Intent) then (Record)
  :Áp dụng quy tắc ghi chép chi tiêu;
else if (Intent) then (Action)
  :Áp dụng quy tắc lệnh điều khiển;
else (Chitchat)
  :Áp dụng quy tắc trò chuyện xã giao;
endif
:Gọi Qwen 2.5 trên Modal GPU;
:Kết quả JSON: slots, response, emotion;
stop
@enduml
```"""
),
(
r"""```mermaid
flowchart TD
    A([Ảnh hóa đơn chụp từ Mobile]) --> B[Bước 1: Phát hiện chữ\n(PaddleOCR)]
    B -->|Tọa độ khung chữ| C[Bước 2: Giải mã ký tự\n(VietOCR)]
    C -->|Văn bản thuần túy| D[Bước 3: Phân tích không gian\n(LayoutLMv3)]
    D -->|Nhận diện quy luật bố cục| E([Trích xuất JSON:\nTổng tiền & Tên cửa hàng])
```""",
r"""```plantuml
@startuml
start
:Nhận ảnh hóa đơn chụp từ Mobile;
:Bước 1: Phát hiện chữ (DBNet);
:Tọa độ khung chữ;
:Bước 2: Giải mã ký tự (VietOCR);
:Văn bản thuần túy;
:Bước 3: Phân tích không gian (LayoutLMv3);
:Nhận diện quy luật bố cục;
:Trích xuất JSON: Tổng tiền & Tên cửa hàng;
stop
@enduml
```"""
)
]

with open('d:/Luan-Van/Project/Luan_van_Hoan_chinh.md', 'r', encoding='utf-8') as f:
    text = f.read()

count = 0
for old, new in replacements:
    if old in text:
        text = text.replace(old, new)
        count += 1
    else:
        print("COULD NOT FIND:")
        print(old[:100])

print(f"Replaced {count} diagrams.")

with open('d:/Luan-Van/Project/Luan_van_Hoan_chinh.md', 'w', encoding='utf-8') as f:
    f.write(text)
