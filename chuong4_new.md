# CHƯƠNG 4: KIỂM THỬ VÀ ĐÁNH GIÁ

## 4.1. Mục tiêu và phương pháp kiểm thử

Mục tiêu của quy trình kiểm thử là đảm bảo hệ thống Spending Diary vận hành ổn định, chính xác và đáp ứng toàn bộ các yêu cầu kỹ thuật đã đề ra. Quá trình này giúp phát hiện và khắc phục các khiếm khuyết phần mềm trước khi phát hành, từ đó tối ưu hóa trải nghiệm và xây dựng lòng tin cho người dùng cuối. Quy trình đánh giá được tiến hành toàn diện qua bốn phương diện chính:

- **Kiểm thử tính khả dụng:** Đánh giá mức độ thân thiện của giao diện người dùng trên cả nền tảng di động và quản trị web. Quá trình kiểm tra đảm bảo tính nhất quán của nội dung, độ chính xác của các thông báo lỗi theo ngữ cảnh và tính hợp lý trong luồng điều hướng giữa các màn hình chức năng.
- **Kiểm thử chức năng:** Xác minh tính đúng đắn của toàn bộ các luồng nghiệp vụ. Việc kiểm thử tập trung vào khả năng bóc tách dữ liệu của hệ thống trí tuệ nhân tạo (xử lý ngôn ngữ tự nhiên và thị giác máy tính), tính chính xác của các thuật toán thống kê, và các thao tác tương tác cơ bản (thêm, đọc, sửa, xóa) đối với dữ liệu người dùng.
- **Kiểm thử cơ sở dữ liệu:** Đối chiếu tính đồng nhất giữa dữ liệu hiển thị trên giao diện người dùng và dữ liệu vật lý lưu trữ trong hệ quản trị CockroachDB. Các kịch bản kiểm tra đảm bảo thông tin không bị thất thoát hoặc sai lệch trong quá trình truyền tải và truy vấn.
- **Kiểm thử tính bảo mật:** Rà soát các lỗ hổng tiềm ẩn trong luồng xác thực. Quá trình kiểm thử xác nhận cơ chế mã hóa mật khẩu và tính toàn vẹn của hệ thống xác thực mã thông báo (token) nhằm bảo vệ quyền truy cập giao diện lập trình ứng dụng (API).

**Môi trường kiểm thử:**
- **Thiết bị di động:** Điện thoại ViVo iQOO Neo 10 (Hệ điều hành Android, 12GB RAM).
- **Trình duyệt Web:** Google Chrome và Microsoft Edge phiên bản mới nhất.
- **Cơ sở dữ liệu:** Cụm máy chủ CockroachDB.

## 4.2. Kịch bản kiểm thử

Các kịch bản kiểm thử được thiết kế nhằm mô phỏng lại toàn bộ hành trình trải nghiệm của người dùng trên hệ thống, từ các thao tác đăng nhập cơ bản đến các tính năng cốt lõi sử dụng trí tuệ nhân tạo và các phân hệ quản trị.

*Bảng 4.1: Danh sách tổng hợp kịch bản kiểm thử chức năng*

| STT | Tên chức năng | Nền tảng | Ngày test |
|:---:|:---|:---|:---|
| 1 | Đăng nhập và xác thực tài khoản | Ứng dụng di động | 01/08/2026 |
| 2 | Nâng cấp tài khoản cao cấp (Premium) | Ứng dụng di động | 01/08/2026 |
| 3 | Quản lý ví tiền và giao dịch thủ công | Ứng dụng di động | 01/08/2026 |
| 4 | Ghi chép chi tiêu tự động bằng văn bản (AI NLU) | Ứng dụng di động | 01/08/2026 |
| 5 | Quét và bóc tách dữ liệu hóa đơn (AI OCR) | Ứng dụng di động | 01/08/2026 |
| 6 | Báo cáo thống kê và so sánh chi tiêu | Ứng dụng di động | 01/08/2026 |
| 7 | Quản lý hạn mức ngân sách | Ứng dụng di động | 01/08/2026 |
| 8 | Trò chuyện với trợ lý ảo MiMo | Ứng dụng di động | 01/08/2026 |
| 9 | Thống kê doanh thu và quản lý người dùng | Quản trị Web | 02/08/2026 |
| 10 | Dán nhãn dữ liệu ảnh hóa đơn | Quản trị Web | 02/08/2026 |
| 11 | Tinh chỉnh nhân cách và huấn luyện AI | Quản trị Web | 02/08/2026 |
| 12 | Xử lý tài chính và tự động hóa Webhook | Máy chủ Backend | 03/08/2026 |

Bảng 4.1 tổng hợp 12 chức năng cốt lõi được thiết lập kịch bản kiểm thử, bao phủ toàn bộ luồng nghiệp vụ từ nền tảng ứng dụng di động, quản trị web trung tâm đến hệ thống máy chủ tự động xử lý tài chính ngầm.

*Bảng 4.2: Danh sách tổng hợp kịch bản kiểm thử tính khả dụng, cơ sở dữ liệu và bảo mật*

| STT | Hạng mục kiểm thử | Trọng tâm đánh giá | Ngày test |
|:---:|:---|:---|:---|
| 1 | Tính khả dụng giao diện | Bố cục, điều hướng, phản hồi thao tác | 03/08/2026 |
| 2 | Tính toàn vẹn cơ sở dữ liệu | Đồng bộ dữ liệu máy trạm và máy chủ CockroachDB | 03/08/2026 |
| 3 | Bảo mật hệ thống | Mã hóa mật khẩu, phân quyền, rò rỉ token | 03/08/2026 |

Bảng 4.2 liệt kê các hạng mục kiểm thử phi chức năng, tập trung vào trải nghiệm người dùng, độ tin cậy của luồng dữ liệu phân tán và tính toàn vẹn của hệ thống xác thực.

## 4.3. Kết quả kiểm thử chức năng hệ thống

### 4.3.1. Chức năng xác thực và đăng nhập

*Bảng 4.3: Trường hợp kiểm thử chức năng đăng nhập*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Đăng nhập sai | - Bước 1: Mở ứng dụng<br>- Bước 2: Nhập email sai định dạng<br>- Bước 3: Bấm Đăng nhập | Hệ thống hiển thị thông báo lỗi định dạng email | Hiển thị đúng thông báo lỗi | Thành công | 01/08/2026 |
| 2 | Đăng nhập Google | - Bước 1: Bấm "Tiếp tục với Google"<br>- Bước 2: Chọn tài khoản Google | Trình duyệt chuyển hướng xác thực và tự động đưa vào màn hình Home | Điều hướng chính xác, nạp dữ liệu người dùng thành công | Thành công | 01/08/2026 |

Kết quả từ Bảng 4.3 cho thấy cơ chế xác thực hoạt động ổn định, hệ thống chặn đứng thành công các nỗ lực truy cập sai lệch và điều hướng mượt mà qua Google OAuth2.

### 4.3.2. Chức năng nâng cấp tài khoản cao cấp (Premium)

*Bảng 4.4: Trường hợp kiểm thử chức năng thanh toán tự động*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Mở luồng thanh toán | - Bước 1: Chọn gói Cao cấp<br>- Bước 2: Nhấn Nâng cấp | Ứng dụng sinh mã QR thanh toán cá nhân hóa kèm nội dung chuyển khoản chuẩn xác | QR sinh ra tức thời, đúng số tiền và nội dung | Thành công | 01/08/2026 |
| 2 | Hệ thống ghi nhận | - Bước 1: Chuyển khoản thực tế<br>- Bước 2: Chờ ứng dụng phản hồi | Giao diện tự động mở khóa các tính năng sau khi SePay báo webhook thành công | Hệ thống hiển thị màn hình chúc mừng trong vòng 10 giây | Thành công | 01/08/2026 |

Thông qua Bảng 4.4, quy trình thanh toán số diễn ra mượt mà, kết nối API webhook với hệ thống ngân hàng SePay xử lý giao dịch tức thời mà không cần sự can thiệp của quản trị viên.

### 4.3.3. Chức năng quản lý ví tiền và giao dịch thủ công

*Bảng 4.5: Trường hợp kiểm thử thao tác cơ sở dữ liệu (CRUD)*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Thêm ví mới | - Bước 1: Vào mục Ví tiền<br>- Bước 2: Nhập tên "Tiền mặt", số dư "2tr"<br>- Bước 3: Lưu | Ví hiển thị với số dư 2.000.000 VNĐ | Ví hiển thị ngay lập tức với số dư chuẩn xác | Thành công | 01/08/2026 |
| 2 | Xóa ví có giao dịch | - Bước 1: Vuốt xóa ví<br>- Bước 2: Xác nhận xóa | Cảnh báo xóa sẽ mất dữ liệu giao dịch liên quan | Cảnh báo xuất hiện, xóa thành công khi đồng ý | Thành công | 01/08/2026 |

Dựa vào Bảng 4.5, các truy vấn thêm, sửa, xóa ví tiền và giao dịch được xử lý chính xác tuyệt đối, đảm bảo tính nhất quán của dòng tiền.

### 4.3.4. Chức năng ghi chép tự động bằng văn bản (AI NLU)

*Bảng 4.6: Trường hợp kiểm thử phân hệ hiểu ngôn ngữ tự nhiên*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Nhập câu lệnh chuẩn | - Bước 1: Vào thanh nhập liệu<br>- Bước 2: Gõ "Sáng nay đi ăn phở hết 35k"<br>- Bước 3: Bấm Gửi | Trích xuất: Số tiền (35.000), Danh mục (Ăn uống), Ghi chú (Ăn phở) | Trích xuất chính xác 100% | Thành công | 01/08/2026 |
| 2 | Quản lý hộp thoại | - Bước 1: Nhập "Mua ly trà sữa"<br>- Bước 2: AI hỏi tiền<br>- Bước 3: Nhập "50k" | Hệ thống nối ghép ngữ cảnh và tạo ra giao dịch Ăn uống 50.000 VNĐ | Khôi phục luồng hộp thoại (State Management) chính xác | Thành công | 01/08/2026 |

Bảng 4.6 chứng minh khả năng bóc tách thông tin chính xác của mô hình hiểu ngôn ngữ tự nhiên, kể cả khi quản lý trạng thái hộp thoại nhiều vòng.

### 4.3.5. Chức năng quét và bóc tách hóa đơn (AI OCR)

*Bảng 4.7: Trường hợp kiểm thử phân hệ thị giác máy tính LayoutLMv3*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Gửi hóa đơn rõ nét | - Bước 1: Mở Camera<br>- Bước 2: Chụp hóa đơn siêu thị<br>- Bước 3: Đợi AI xử lý | Trích xuất đủ: Tên cửa hàng, Địa chỉ, Ngày giờ, Tổng tiền | Trả về dữ liệu đầy đủ sau 5 giây | Thành công | 01/08/2026 |
| 2 | Lưu giao dịch OCR | - Bước 1: Kiểm tra dữ liệu AI<br>- Bước 2: Bấm Lưu giao dịch | Lưu vào CSDL với ảnh gốc đính kèm trên Cloudflare R2 | Dữ liệu đồng bộ, ảnh tải mượt mà | Thành công | 01/08/2026 |

Dữ liệu Bảng 4.7 khẳng định luồng trích xuất thông tin hóa đơn vận hành trơn tru ở chế độ nền và đồng bộ ảnh gốc lên Cloudflare R2 an toàn.

### 4.3.6. Chức năng báo cáo thống kê và so sánh

*Bảng 4.8: Trường hợp kiểm thử giao diện phân tích dữ liệu*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Xem biểu đồ tròn | - Bước 1: Vào mục Báo cáo<br>- Bước 2: Chọn thẻ Chi phí | Render biểu đồ phân bổ danh mục trong tháng | Đồ thị render mượt mà, tỷ lệ chính xác | Thành công | 01/08/2026 |
| 2 | So sánh chi tiêu | - Bước 1: Vào mục Báo cáo<br>- Bước 2: Chọn thẻ So sánh | Đối chiếu dữ liệu với hồ sơ giả lập, hiển thị thanh đo | Đưa ra nhận xét (Vượt mức / Tiết kiệm) chính xác | Thành công | 01/08/2026 |

Bảng 4.8 xác nhận tốc độ kết xuất biểu đồ nhanh chóng không độ trễ và khả năng đối chiếu định mức chi tiêu giả lập hoạt động đúng logic.

### 4.3.7. Chức năng quản lý hạn mức và trò chuyện MiMo

*Bảng 4.9: Trường hợp kiểm thử tính năng hỗ trợ kiểm soát tài chính*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Cảnh báo hạn mức | - Bước 1: Đặt hạn mức 3tr<br>- Bước 2: Tiêu 2.5tr | Thanh tiến trình chuyển màu đỏ (vượt 80%) và báo động | Giao diện cảnh báo hoạt động chuẩn xác | Thành công | 01/08/2026 |
| 2 | Hỏi đáp với MiMo | - Bước 1: Vào chat MiMo<br>- Bước 2: Gõ "Tháng này tiêu nhiều nhất vào đâu?" | MiMo trả lời bằng văn bản đúng danh mục tốn nhất | Phản hồi đúng danh mục có tổng chi lớn nhất | Thành công | 01/08/2026 |

Kết quả Bảng 4.9 phản ánh độ nhạy của thanh cảnh báo hạn mức, đồng thời cho thấy trợ lý MiMo có khả năng phân tích và phản hồi dữ liệu theo thời gian thực.

### 4.3.8. Chức năng thống kê doanh thu và quản lý người dùng (Web Admin)

*Bảng 4.10: Trường hợp kiểm thử trang quản trị trung tâm*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Tải Dashboard | - Bước 1: Truy cập web<br>- Bước 2: Đăng nhập Admin | Biểu đồ doanh thu, lượng user và hiệu suất API hiển thị đầy đủ số liệu | Layout render chính xác, lấy số liệu CockroachDB ổn định | Thành công | 02/08/2026 |
| 2 | Khóa tài khoản | - Bước 1: Vào Quản lý User<br>- Bước 2: Bấm Ban user | Trạng thái chuyển sang vô hiệu hóa, user bị đẩy ra ngoài | Thao tác cập nhật tức thời, bảo mật chặt chẽ | Thành công | 02/08/2026 |

Theo Bảng 4.10, phân hệ quản trị web đảm bảo khả năng giám sát tài nguyên hệ thống, theo dõi doanh thu và khóa tài khoản vi phạm tức thời.

### 4.3.9. Chức năng tiền xử lý, gán nhãn và huấn luyện AI (Web Admin)

*Bảng 4.11: Trường hợp kiểm thử quy trình tái huấn luyện dữ liệu AI*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Dán nhãn hóa đơn | - Bước 1: Mở hóa đơn mờ<br>- Bước 2: Vẽ khung tọa độ và gán nhãn Tên cửa hàng | Công cụ vẽ phản hồi nhạy, tọa độ được lưu chuẩn xác định dạng JSON | Dữ liệu hình học lưu chính xác, giao diện mượt | Thành công | 02/08/2026 |
| 2 | Ra lệnh huấn luyện | - Bước 1: Chọn tập dữ liệu mới<br>- Bước 2: Kích hoạt nút Retrain | Trạng thái máy chủ AI chuyển sang Đang huấn luyện và cập nhật trọng số mới | Kích hoạt luồng huấn luyện nền FastAPI thành công | Thành công | 02/08/2026 |

Bảng 4.11 khẳng định luồng xử lý dữ liệu ảnh khép kín trên trình duyệt hoạt động hoàn hảo, bảo vệ quyền riêng tư và thúc đẩy quá trình nâng cấp AI liên tục.

### 4.3.10. Chức năng tinh chỉnh nhân cách AI và quản lý Webhook (Backend)

*Bảng 4.12: Trường hợp kiểm thử cấu hình hệ thống máy chủ tự động*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Đổi tính cách MiMo | - Bước 1: Chuyển cấu hình sang "Khó tính"<br>- Bước 2: Lưu câu lệnh | Trợ lý ảo lập tức đổi văn phong trả lời người dùng gay gắt hơn | Cập nhật cấu hình nóng (hot-reload) thành công | Thành công | 03/08/2026 |
| 2 | Chữ ký HMAC SePay | - Bước 1: Giả mạo webhook gửi request nạp tiền | Máy chủ từ chối yêu cầu do chữ ký SHA256 không khớp | Hệ thống ngăn chặn tấn công giả mạo tiền chuẩn xác | Thành công | 03/08/2026 |

Dữ liệu từ Bảng 4.12 cho thấy hệ thống máy chủ Backend duy trì độ tin cậy tuyệt đối khi xử lý bảo mật tài chính Webhook, đồng thời linh hoạt thay đổi ngữ cảnh AI.

## 4.4. Kết quả kiểm thử tính khả dụng, cơ sở dữ liệu và bảo mật

### 4.4.1. Kết quả kiểm thử tính khả dụng

*Bảng 4.13: Trường hợp kiểm thử tính khả dụng của giao diện*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Kiểm tra điều hướng | - Bước 1: Khởi động app<br>- Bước 2: Chuyển đổi giữa 5 tab chính | Không giật lag, màn hình chuyển tiếp mượt mà dưới 1 giây | Tốc độ khung hình 60fps, điều hướng nhanh | Thành công | 03/08/2026 |
| 2 | Kiểm tra phản hồi | - Bước 1: Thêm một chi tiêu mới<br>- Bước 2: Nhấn nút Lưu | Hiển thị thông báo (Snackbar) thành công | Hiển thị thông báo rõ ràng, dễ nhìn | Thành công | 03/08/2026 |

Bảng 4.13 cho thấy ứng dụng duy trì tốc độ khung hình lý tưởng, phản hồi thao tác ngay lập tức, mang lại trải nghiệm người dùng liền mạch.

### 4.4.2. Kết quả kiểm thử cơ sở dữ liệu

*Bảng 4.14: Trường hợp kiểm thử đối soát cơ sở dữ liệu CockroachDB*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Lưu trữ giao dịch | - Bước 1: Tạo giao dịch 150k trên app<br>- Bước 2: Dùng truy vấn SQL kiểm tra DB | Dữ liệu lưu xuống CockroachDB đúng kiểu dữ liệu và số tiền | Dữ liệu chính xác hoàn toàn trong bảng Transaction | Thành công | 03/08/2026 |
| 2 | Xử lý đa luồng | - Bước 1: Gửi 100 giao dịch cùng lúc qua script (stress test) | Prisma ORM phân luồng, CockroachDB không bị rớt kết nối | 100/100 bản ghi được lưu an toàn | Thành công | 03/08/2026 |

Dựa vào Bảng 4.14, CockroachDB chứng minh năng lực xử lý đa luồng ưu việt khi vượt qua bài kiểm thử chịu tải mà không rớt bất kỳ bản ghi nào.

### 4.4.3. Kết quả kiểm thử tính bảo mật

*Bảng 4.15: Trường hợp kiểm thử bảo mật dữ liệu và phiên bản*

| STT | Miêu tả test case | Các bước kiểm thử | Kết quả mong đợi | Kết quả thực tế | Thành công / Thất bại | Ngày test |
|:---:|:---|:---|:---|:---|:---:|:---:|
| 1 | Mã hóa mật khẩu | - Bước 1: Đăng ký tài khoản<br>- Bước 2: Xem mật khẩu trong DB | Mật khẩu hiển thị chuỗi băm (Hash Bcrypt) không thể dịch ngược | Mật khẩu đã được băm an toàn | Thành công | 03/08/2026 |
| 2 | Hết hạn Token | - Bước 1: Lấy JWT Token<br>- Bước 2: Chờ 24h và gửi request API | Máy chủ Node.js từ chối request với mã lỗi 401 Unauthorized | API từ chối truy cập chính xác | Thành công | 03/08/2026 |

Bảng 4.15 khẳng định dữ liệu nhạy cảm được băm chuẩn xác, cùng với cơ chế vô hiệu hóa mã thông báo nghiêm ngặt giúp chống rò rỉ phiên làm việc.

Đánh giá tổng quan, toàn bộ kịch bản kiểm thử trên cả phân hệ ứng dụng di động và nền tảng quản trị web đều đạt trạng thái nghiệm thu. Các chức năng ứng dụng trí tuệ nhân tạo (OCR, NLU) vận hành ổn định trong môi trường thực tế, đáp ứng được các tiêu chuẩn khắt khe về độ chính xác dữ liệu và tốc độ phản hồi. Cơ sở dữ liệu phân tán CockroachDB thể hiện năng lực truy xuất dữ liệu đồng bộ và mượt mà, đảm bảo khả năng đáp ứng quy mô mở rộng (scalability) của dự án.
