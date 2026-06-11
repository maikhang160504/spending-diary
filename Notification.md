Duy trì tư duy sản phẩm cốt lõi: "Tính năng thông báo này có giúp người dùng bớt thao tác, tăng tỷ lệ giữ chân (Retention Rate) và làm nổi bật tính năng nhập liệu dạng Story không?". Nếu thông báo chỉ là "Bạn ơi vào nhập chi tiêu đi", ứng dụng sẽ thất bại. Thông báo của chúng ta phải mang tính cá nhân hóa, có ngữ cảnh và thúc đẩy hành động tức thì.

Dưới đây là thiết kế chi tiết về hệ thống thông báo tối ưu cho app:
1. Hiện trạng & Thách thức (The Pain Points)
Sự lười biếng của người dùng: Nhớ để ghi chép chi tiêu là một rào cản tâm lý cực kỳ lớn. 90% người dùng bỏ app tài chính vì quên hoặc ngại vào app bấm quá nhiều bước.

Thông báo chung chung (Spam): Gửi thông báo sai thời điểm (ví dụ: nhắc nhập chi tiêu lúc đang họp hoặc nửa đêm) sẽ khiến user khó chịu và tắt quyền thông báo ngay lập tức.

Thiếu tính kết nối với Core Feature: Thông báo thông thường không tận dụng được thế mạnh nhập liệu bằng Giọng nói/Hình ảnh và hiển thị dạng Story của app chúng ta.

2. Giải pháp: Hệ thống thông báo 3 tầng theo ngữ cảnh (Contextual Notification Matrix)
Chúng ta không dùng một kịch bản cho tất cả. Hệ thống sẽ chia làm 3 loại thông báo chính dựa trên dữ liệu lưu trữ trong PostgreSQL và các mô hình AI đang có.

Tầng 1: Thông báo Kích hoạt Nhập liệu (Dynamic Story Triggers) - Tăng Retention
Giải pháp: Thay vì cố định một khung giờ (ví dụ: 20h00 tối), AI sẽ phân tích lịch sử nhập liệu trong PostgreSQL để tìm ra "khoảng thời gian nhạy cảm" mà user hay tiêu tiền (ví dụ: giờ ăn trưa 12h-13h, giờ tan tầm 17h30-19h).

Tính cá nhân hóa dạng Story: Nội dung thông báo biến đổi linh hoạt theo ngữ cảnh, đóng vai trò như một người bạn đồng hành (bốc ngẫu nhiên một mẫu trong kho lưu trữ để tránh trùng lặp gây chán):

Buổi trưa: "Hôm nay cơm trưa văn phòng ngon chứ bạn? Né xếp hàng trả tiền bằng cách chụp hóa đơn hoặc nói cho SpendDiary lưu lại story trưa nay nhé!"

Cuối tuần: "Vừa đi cafe với bạn bè về đúng không? Chạm vào đây để kể nhanh khoản chi này nào!"

(Kho lưu trữ các câu thông báo mẫu:
Mẫu 1: "Trưa nay thèm gì không bạn ơi? Nếu vừa ăn trưa xong..."
Mẫu 2: "Nạp năng lượng trưa xong chưa bạn? Kể cho SpendDiary nghe...")

Tầng 2: Thông báo Cảnh báo Hạn mức (Smart Budget Alerts) - Tăng Trust
Giải pháp: Dựa vào kết quả của Model phân loại (Logistic Regression/SVM) gán nhãn danh mục chi tiêu, hệ thống liên tục tính toán ngân sách còn lại của user theo tuần/tháng.

Ngưỡng kích hoạt (Trigger Threshold): Khi một danh mục chạm ngưỡng 80% hoặc 100% giới hạn, hệ thống tự động đẩy thông báo.

Tư duy giảm ma sát: Thông báo không chỉ cảnh báo suông, mà đính kèm Deep Link đưa user tới giao diện Chat AI để nhận tư vấn cắt giảm chi tiêu ngay lập tức.

Nội dung: "🚨 Danh mục 'Ăn uống' tháng này đã chạm mức 85%. Chạm vào đây để AI thiết kế lại thực đơn tiết kiệm cho tuần tới."

Tầng 3: Thông báo "Insight Story" Tổng kết (Weekly/Monthly Financial Story) - Tạo Wow-factor
Giải pháp: Cuối tuần hoặc cuối tháng, hệ thống tổng hợp toàn bộ Timeline dữ liệu. Thay vì gửi một bảng báo cáo Excel khô khan, app sẽ gửi một thông báo dạng "Tóm tắt chương truyện".

Nội dung: "Tuần qua bạn đã viết nên một 'Story' khá tốn kém với 3 lần chốt đơn Shopee lúc nửa đêm 🌙. Xem ngay cuốn nhật ký tài chính tuần này của bạn."

3. Thiết kế Luồng xử lý và Tương tác (UX/UI & Logic Flow)
Để hiện thực hóa nguyên tắc "Bớt thao tác cho người dùng", luồng tương tác của thông báo phải được thiết kế như sau:

Hành động một chạm (Quick Actions trên Push Notification):

Khi thông báo nhắc nhập liệu hiện lên trên màn hình khóa, user có thể nhấn giữ (hoặc vuốt) để hiện ra nút bấm nhanh: [📸 Thêm story].

Nếu bấm [📸 Thêm story], app tự động mở Camera, user chụp xong rồi nhập mô tả, PaddleOCR/VietOCR xử lý ngầm, AI tự động fusion dữ liệu và đưa vào Timeline Story. User hoàn toàn không cần mở app rồi tìm nút "Thêm giao dịch".

Cơ chế kiểm soát tần suất (Frequency Capping):

Để tránh biến thành app spam, PostgreSQL sẽ lưu cấu hình: Tối đa 1 thông báo nhắc nhở/ngày. Nếu trong ngày hôm đó user đã chủ động nhập ít nhất 1 giao dịch, hệ thống sẽ tự hủy lệnh gửi thông báo nhắc nhở của ngày hôm đó.

4. Các lưu ý quan trọng khi triển khai hệ thống thông báo
Xử lý lệch múi giờ (Timezone): Toàn bộ logic quét giờ gửi thông báo (Cron job) phải dựa trên múi giờ thực tế của thiết bị user, tránh việc backend chạy theo giờ UTC rồi push thông báo nhập chi tiêu vào lúc 3 giờ sáng.

Tối ưu hóa tài nguyên: Việc quét xem ai sắp hết hạn mức để gửi thông báo tầng 2 nên được xử lý bằng các hàm trigger hoặc worker chạy ngầm định kỳ (ví dụ: 1 tiếng/lần), tránh tính toán trực tiếp realtime ngay khi user vừa bấm lưu giao dịch để giảm tải cho database PostgreSQL.

Đo lường chỉ số: Chúng ta cần tracking kỹ chỉ số Open Rate (Tỷ lệ mở thông báo) và Conversion Rate (Tỷ lệ nhập liệu thành công từ thông báo). Nếu kịch bản thông báo nào có tỷ lệ chuyển đổi thấp, ta sẽ dùng TF-IDF để phân tích và tinh chỉnh lại bộ keyword gợi ý cho phù hợp với ngôn ngữ giới trẻ (Gen Z).