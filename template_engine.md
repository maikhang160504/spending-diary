Giải pháp: Cơ chế sinh thông báo theo ngữ cảnh (Contextual Notification Engine)
Câu thông báo trên được sinh ra từ 3 thành phần chính trong hệ thống của chúng ta:

Thành phần 1: Bộ phân tích hành vi thời gian (Time-Window Analyzer)
Hệ thống sử dụng Python quét vào cơ sở dữ liệu PostgreSQL để phân tích lịch sử nhập liệu của từng user_id cụ thể trong danh mục Ăn uống (Category được phân loại bởi model Logistic Regression/SVM).

Nếu dữ liệu lịch sử cho thấy user này thường có giao dịch ăn trưa phát sinh trong khoảng từ 11h45 đến 12h15, hệ thống sẽ tự động gắn một nhãn thời gian gọi là "Lunch Time Window" cho user đó.

Hệ thống sẽ đặt lịch (Schedule) gửi thông báo vào lúc 12h20 (ngay sau khung giờ họ thường ăn xong).

Thành phần 2: Bộ lọc trạng thái (State Filter)
Trước khi gửi, hệ thống kiểm tra bảng stories trong PostgreSQL xem hôm nay (ngày hiện tại) user_id này đã có giao dịch nào thuộc danh mục Ăn uống vào buổi trưa chưa.

Nếu đã nhập: Hủy lệnh gửi (Không làm phiền).

Nếu chưa nhập: Kích hoạt lệnh gửi thông báo.

Thành phần 3: Bộ sinh nội dung theo Persona (Template Engine với TF-IDF hỗ trợ)
Để tạo ra câu nói tự nhiên, Backend Python sử dụng một ma trận mẫu (Template Matrix) được phân loại theo buổi trong ngày (Sáng, Trưa, Tối, Đêm) và trạng thái ví của user.

Nó sẽ bốc ngẫu nhiên một mẫu trong kho lưu trữ để tránh trùng lặp gây chán:

# Buổi trưa (Lunch Time)

| Trạng thái ví  | Mẫu câu thông báo |
| :--- | :--- |
| **Ví cạn (< 20%)** | "Trưa nay ăn gì cho tiết kiệm để chiều còn đi làm không bạn? Chụp hóa đơn để AI lên thực đơn cho cả tuần nhé." |
| **Ví bình thường (20-80%)** | "Cơm trưa hôm nay ngon chứ? Đừng quên nhập vào SpendDiary để bạn không quên món ngon đã ăn nha." |
| **Ví đầy (> 80%)** | "Ăn trưa xong vẫn còn năng lượng à nha? Vào đây kể ngay chuyện ăn uống trưa nay cho SpendDiary nào." |

# Buổi tối (Evening Time)

| Trạng thái ví  | Mẫu câu thông báo |
| :--- | :--- |
| **Ví cạn (< 20%)** | "Tối nay ăn tối cẩn thận bạn ơi kẻo cháy ví nha. Nói cho SpendDiary biết bạn đã ăn gì nào." |
| **Ví bình thường (20-80%)** | "Hôm nay tiêu gì vào buổi tối thế bạn? Hãy kể cho SpendDiary nghe để cùng xem hôm nay tiêu bao nhiêu nha." |
| **Ví đầy (> 80%)** | "Tối nay ăn gì cho ngon miệng mà không lo về giá? Hãy kể cho SpendDiary nghe để cùng quản lý chi tiêu nào." |

# Buổi đêm (Night Time)

| Trạng thái ví  | Mẫu câu thông báo |
| :--- | :--- |
| **Ví cạn (< 20%)** | "Đêm khuya rồi mà còn đói bụng hả? Kể cho SpendDiary nghe bạn đang ăn gì nè." |
| **Ví bình thường (20-80%)** | "Vừa đi chơi về đúng không? Đừng quên nhập khoản chi vào SpendDiary nha." |
| **Ví đầy (> 80%)** | "Chốt đơn gì lúc nửa đêm không? Hãy kể cho SpendDiary biết khoản chi này nào." |


# Buổi sáng (Morning Time)

| Trạng thái ví  | Mẫu câu thông báo |
| :--- | :--- |
| **Ví cạn (< 20%)** | "Sáng nay ăn gì mà vội thế bạn? Kể nhanh cho SpendDiary để quản lý chi tiêu nào." |
| **Ví bình thường (20-80%)** | "Cà phê sáng nay ngon chứ bạn? Nhập vào SpendDiary để lưu giữ khoảnh khắc này nha." |
| **Ví đầy (> 80%)** | "Nạp năng lượng buổi sáng xong chưa bạn? Nói cho SpendDiary nghe bạn đã ăn gì nào." |