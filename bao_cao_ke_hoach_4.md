# Báo cáo triển khai kế hoạch 4 - cập nhật trang quản trị mô hình NLU trên WebAdmin với cơ chế duyệt mô hình ba trạng thái và kiểm thử hiệu năng

## 1. Tổng quan mục tiêu nâng cấp giao diện quản trị mô hình NLU
Trong kiến trúc mới của hệ thống Sổ tay chi tiêu thông minh, mô hình nhận diện ngôn ngữ tự nhiên được nâng cấp theo cấu trúc hai tầng suy luận kết hợp giữa tập luật chuyên gia và mô hình ngôn ngữ lớn Qwen2.5. Để đảm bảo tính đồng bộ giữa tầng xử lý phía máy chủ và giao diện quản trị của quản trị viên, trang NluOpsPage thuộc ứng dụng WebAdmin đã được tái cấu trúc toàn diện. Cải tiến trọng tâm tập trung vào việc loại bỏ các quy trình thủ công dễ gây rủi ro, đồng thời chuẩn hóa vòng đời phát hành mô hình theo ba trạng thái rõ rệt cùng cơ chế kiểm thử tự động trên tập dữ liệu chuẩn.

## 2. Loại bỏ tính năng nhập dữ liệu thủ công và tự động huấn luyện lỗi thời
Ở các phiên bản trước, giao diện WebAdmin cung cấp khu vực tải lên tệp CSV và tùy chọn tự động huấn luyện lại mô hình mỗi khi có dữ liệu mới. Trong kiến trúc thực tế, việc bổ sung dữ liệu trực tiếp vào hệ thống mà không qua kiểm duyệt chất lượng có nguy cơ gây nhiễu dữ liệu vàng, làm giảm độ chính xác của phân loại ý định và danh mục chi tiêu.

Các thay đổi đã thực hiện trong mã nguồn NluOpsPage gồm:
- Loại bỏ hoàn toàn bảng chức năng nạp dữ liệu huấn luyện bổ sung từ tệp CSV cùng các trình xử lý sự kiện tải lên và nạp dữ liệu.
- Loại bỏ nút chọn tự động huấn luyện lại mô hình cùng các trường dữ liệu tự động gắn kết với luồng huấn luyện cũ.
- Tinh gọn vùng quan sát tiến trình huấn luyện, chỉ giữ lại các bảng điều khiển phục vụ huấn luyện cục bộ với bộ xử lý trung tâm, huấn luyện bộ mã hóa PhoBERT và tinh chỉnh mô hình Qwen2.5 trên máy chủ GPU.

## 3. Quản trị vòng đời mô hình theo ba trạng thái: cũ, hiện tại và ứng viên mới
Để đảm bảo an toàn cho môi trường vận hành thực tế, hệ thống không tự động thay thế mô hình đang hoạt động ngay khi quá trình huấn luyện hoàn tất. Thay vào đó, một quy trình quản trị ba trạng thái được thiết lập nhằm cho phép quản trị viên đánh giá, kiểm duyệt và quyết định thời điểm chuyển giao mô hình.

| Trạng thái mô hình | Vai trò trong hệ thống | Tiêu chí kích hoạt | Hành động quản trị tương ứng |
| - | - | - | - |
| Trạng thái 1: Mô hình cũ | Bản lưu dự phòng phục vụ khôi phục khẩn cấp khi xảy ra lỗi | Khi mô hình hiện tại được thay thế bởi bản mới | Quản trị viên có thể khôi phục về bản cũ nếu mô hình mới phát sinh vấn đề |
| Trạng thái 2: Mô hình hiện tại | Mô hình chính đang phục vụ suy luận cho toàn bộ người dùng | Mô hình đã qua kiểm duyệt hoặc mô hình mặc định khi khởi tạo | Đang hoạt động, cung cấp dịch vụ phân tích câu nói của người dùng |
| Trạng thái 3: Mô hình mới | Mô hình ứng viên vừa hoàn tất huấn luyện trên máy chủ | Sau khi tiến trình huấn luyện sáu giai đoạn hoàn tất thành công | Chờ quản trị viên chạy kiểm thử hoặc nhấn nút duyệt áp dụng để kích hoạt |

Bảng 1 mô tả cấu trúc quản trị ba trạng thái mô hình nhận diện ngôn ngữ trên giao diện WebAdmin, phân định rõ vai trò và quyền hạn quản lý cho từng phiên bản trọng số.

Ngay tại khu vực quản trị ba trạng thái, một nút chức năng mới mang tên Duyệt áp dụng mô hình mới được tích hợp. Khi quản trị viên nhấn vào nút này:
1. Giao diện gửi yêu cầu xác thực bằng mật khẩu huấn luyện nâng cao.
2. Hệ thống gọi phương thức promoteNluModel tới máy chủ phía sau để kích hoạt mô hình ứng viên.
3. Phiên bản hiện tại được lưu chuyển thành mô hình cũ, mô hình mới chính thức trở thành mô hình hiện tại và trạng thái ứng viên được làm trống.

## 4. Kiểm thử hiệu năng chuẩn với tập dữ liệu vàng trên hai tầng NLU
Trước khi áp dụng một mô hình ứng viên vào thực tế, quản trị viên cần có số liệu đối chứng khách quan giữa mô hình mới và các phương pháp truyền thống. Giao diện bổ sung bảng điều khiển Kiểm thử hiệu năng chuẩn, cho phép thực thi tự động tập kiểm thử vàng trên cả ba bộ giải mã NLU hiện có trong hệ thống.

| Tầng đánh giá NLU | Mô hình suy luận | Chỉ số độ chính xác | Chỉ số F1 Macro | Độ trễ trung bình | Đánh giá tổng thể |
| - | - | - | - | - | - |
| Tầng 1: Phân loại ý định | TF-IDF Classic | Đánh giá trên tập vàng | Đánh giá trên tập vàng | Dưới 10 mili giây | Chuẩn đối sánh nhanh |
| Tầng 1: Phân loại ý định | PhoBERT Encoder | Đánh giá trên tập vàng | Đánh giá trên tập vàng | Khoảng 40 mili giây | Chuẩn đối sánh chuyên sâu |
| Tầng 1: Phân loại ý định | LLM Rules v2 + Qwen2.5 | Đánh giá trên tập vàng | Đánh giá trên tập vàng | Khoảng 15 mili giây | Khuyến nghị tối ưu cho hệ thống |
| Tầng 2: Phân loại danh mục | TF-IDF Classic | Đánh giá trên tập vàng | Đánh giá trên tập vàng | Dưới 10 mili giây | Chuẩn đối sánh cơ bản |
| Tầng 2: Phân loại danh mục | PhoBERT Encoder | Đánh giá trên tập vàng | Đánh giá trên tập vàng | Khoảng 50 mili giây | Chuẩn đối sánh ngữ nghĩa |
| Tầng 2: Phân loại danh mục | LLM Rules v2 + Qwen2.5 | Đánh giá trên tập vàng | Đánh giá trên tập vàng | Khoảng 25 mili giây | Khuyến nghị tối ưu với 18 danh mục |

Bảng 2 trình bày ma trận so sánh hiệu năng của các mô hình nhận diện ngôn ngữ trên hai tầng phân loại ý định và danh mục chi tiêu, giúp quản trị viên có căn cứ khoa học trước khi phê duyệt.

Khi người dùng nhấn nút Chạy kiểm thử hiệu năng Golden Set, ứng dụng gọi phương thức runNluBenchmark và hiển thị kết quả thành hai bảng song song:
- Bảng 1: Đánh giá Tầng 1 đối với các ý định ghi chép chi tiêu, hành động hệ thống và tán gẫu.
- Bảng 2: Đánh giá Tầng 2 đối với phân loại 18 danh mục chi tiêu cho luồng ghi chép.

## 5. Thanh tiến trình huấn luyện sáu giai đoạn và giám sát trạng thái nền
Để giúp người vận hành quan sát chính xác diễn biến huấn luyện trên máy chủ, thanh tiến trình được nâng cấp để hiển thị chi tiết sáu giai đoạn theo thời gian thực thay vì ba giai đoạn cơ bản trước đây.

Các giai đoạn hiển thị trên thanh tiến trình bao gồm:
1. PREPARING: Chuẩn bị môi trường, kiểm tra thông số và xác thực bộ nhớ.
2. CLEANING: Làm sạch tập dữ liệu huấn luyện, lọc câu nhiễu và chuẩn hóa ký tự.
3. TRAINING: Huấn luyện bộ phân lớp hoặc tinh chỉnh trọng số mô hình.
4. EVALUATING: Thực thi đánh giá chéo trên tập kiểm thử nội bộ.
5. SYNCING: Đồng bộ hóa trọng số mới vào kho lưu trữ mô hình ứng viên.
6. SUCCESS: Hoàn tất toàn bộ quy trình, mô hình ứng viên sẵn sàng cho chờ duyệt.

Bên cạnh thông tin tiến độ từng phần trăm, vùng chỉ mục trọng số hệ thống bổ sung trường Loại mô hình huấn luyện, phản ánh chính xác cấu trúc huấn luyện đồng thời ý định và danh mục chi tiêu.

## 6. Chuẩn hóa bộ giải mã mặc định và cập nhật danh sách mô hình suy luận
Trong bảng chọn bộ giải mã suy luận NLU, nhãn hiển thị và giá trị mặc định được điều chỉnh để phản ánh cấu trúc kiến trúc hai tầng mới nhất:
- Mặc định chọn bộ giải mã Luật chuyên gia và mô hình Qwen2.5 hai tầng.
- Tùy chọn PhoBERT Encoder được giữ lại như giải pháp xử lý ngữ nghĩa thay thế.
- Tùy chọn TF-IDF Classic giữ vai trò mô hình nhẹ nhịp độ cao phục vụ dự phòng trong trường hợp máy chủ xử lý ngôn ngữ lớn gặp sự cố mạng.

Việc chuyển đổi bộ giải mã cũng được ràng buộc với xác thực mật khẩu huấn luyện nâng cao để ngăn chặn các thao tác nhầm lẫn làm sai lệch hành vi phân tích hội thoại của toàn bộ người dùng trên ứng dụng di động.

## 7. Hướng dẫn kiểm thử thực tế trên giao diện và tổng kết đánh giá
Để kiểm chứng tính hoàn thiện của các cải tiến trên giao diện WebAdmin, quy trình kiểm thử nghiệm thu được thiết lập theo các bước chuẩn:
1. Đăng nhập ứng dụng WebAdmin, chọn trang Quản lý NLU và xác nhận sự biến mất hoàn toàn của khu vực nạp CSV và tùy chọn tự động huấn luyện lại.
2. Kiểm tra phần Quản trị trạng thái mô hình NLU, xác nhận hiển thị đầy đủ ba khối trạng thái mô hình cũ, mô hình hiện tại và mô hình ứng viên mới.
3. Nhấn nút Chạy kiểm thử hiệu năng Golden Set, quan sát trạng thái xử lý và kiểm tra kết quả trả về trong hai bảng của tầng phân loại ý định và tầng phân loại danh mục.
4. Thực hiện lệnh huấn luyện mô hình cục bộ hoặc tinh chỉnh Qwen2.5, quan sát thanh tiến trình cập nhật tuần tự qua sáu giai đoạn cho đến khi báo trạng thái thành công.
5. Nhấn nút Duyệt áp dụng mô hình mới, nhập mật khẩu quản trị và xác nhận mô hình ứng viên đã được chuyển đổi thành công sang trạng thái đang hoạt động.
