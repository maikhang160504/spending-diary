Trong tâm lý học hành vi, khái niệm này gọi là Social Proof (Bằng chứng xã hội) hoặc Peer Comparison (So sánh đồng trang lứa).

Khi người dùng thấy một con số chi tiêu khô khan, họ khó biết mình đang tiêu hoang hay tiết kiệm. Nhưng nếu AI nói: "Bạn tiêu cho ăn uống nhiều hơn 80% những người có cùng mức thu nhập", họ sẽ giật mình và lập tức có động lực điều chỉnh tài chính.

Tuy nhiên, dưới góc nhìn Kiến trúc hệ thống, tính năng này ẩn chứa nhiều bài toán khó về Bảo mật danh tính (Privacy) và Hiệu năng truy vấn (Query Performance). Hãy cùng phân tích chi tiết.

1. Hiện trạng & Thách thức kỹ thuật
Vấn đề 1: Định nghĩa thế nào là "Cùng nhóm"? Nếu so sánh một bạn sinh viên với một người đã đi làm có thu nhập 30 triệu/tháng thì mọi chỉ số đều khập khiễng. Hệ thống cần phân nhóm (Clustering) người dùng một cách thông minh.

Vấn đề 2: Rủi ro rò rỉ dữ liệu (Privacy Leak): Tài chính là dữ liệu nhạy cảm tối mật. Tuyệt đối không được để lộ danh tính (User A nhìn thấy tên hoặc chi tiết giao dịch của User B). Mọi dữ liệu so sánh phải được Nặc danh (Anonymized) và Gom cụm (Aggregated).

Vấn đề 3: Nghẽn hệ thống do tính toán Real-time quá nặng: Nếu mỗi lần user yêu cầu so sánh, hệ thống lại chạy lệnh SQL AVG() hoặc PERCENTILE trên bảng user_expense_stories có hàng triệu dòng của tất cả user khác, database sẽ lập tức bị "treo".

2. Giải pháp: Phân nhóm tĩnh qua Profile & Tính toán Batch Job
Để xử lý triệt để các thách thức trên, chúng ta sẽ áp dụng mô hình tính toán bất đồng bộ theo các bước sau:

Bước 1: Phân nhóm Người dùng (User Clustering)
Hệ thống không tự động phân cụm bằng các thuật toán phức tạp ngay từ đầu để tránh nặng máy. Thay vào đó, khi user đăng ký app, ta cho họ chọn nhanh một Hồ sơ định danh (Demographic Profile) bao gồm:

Độ tuổi (Age Group): 18-22 tuổi, 23-30 tuổi, 31-40 tuổi, 41-50 tuổi, Trên 50.

Nghề nghiệp (Job Type): Sinh viên, Văn phòng, Freelancer, Kinh doanh, Khác.

Ví dụ: User A thuộc nhóm: 18-22 tuổi - Sinh viên.

Bước 2: Cơ chế Tính toán Bất đồng bộ (Cron Job / Batch Processing)
Hệ thống không tính toán real-time.

Mỗi đêm (vào lúc 2h00 sáng khi hệ thống ít người dùng), một script ngầm sẽ chạy qua bảng dữ liệu tổng để tính toán các con số trung bình, phân vị (percentile) của từng nhóm người dùng rồi lưu sẵn kết quả tổng hợp (Aggregated Data) vào một bảng riêng có tên là group_spending_benchmarks.

3. ví dụ Thiết kế Cơ sở Dữ liệu & Mẫu phản hồi của AI
Cấu trúc bảng Lưu trữ kết quả tính sẵn (PostgreSQL)
SQL
CREATE TABLE group_spending_benchmarks (
    age_group VARCHAR(40) NOT NULL,    -- Ví dụ: '18-22 tuổi'
    job_type VARCHAR(40) NOT NULL,     -- Ví dụ: 'Sinh viên'
    category_id VARCHAR(50) NOT NULL,  -- Ví dụ: 'Food', 'Entertainment'
    period VARCHAR(10) NOT NULL,       -- 'month' hoặc 'week'
    avg_amount DECIMAL(15, 2) NOT NULL,-- Số tiền tiêu trung bình của nhóm này
    p80_amount DECIMAL(15, 2) NOT NULL,-- Ngưỡng chi tiêu của top 80% (để bắt lệnh tiêu hoang)
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (age_group, job_type, category_id, period)
);
Kịch bản AI phản hồi & Biểu đồ hiển thị (UI/UX)
Khi người dùng hỏi: "Tháng này mình tiêu ăn uống có nhiều hơn các bạn sinh viên khác không?", hoặc hệ thống chủ động sinh một Story so sánh vào cuối tháng:

Cách AI trả lời (Giữ vững phong cách Story đầy cảm xúc):

"Nè bạn ơi, tháng này bạn đã chi 3.500.000đ cho mục Ăn uống rồi đó. Trông thì bình thường nhưng con số này đang cao hơn 25% so với mức trung bình của nhóm 18-22 tuổi làm nghề Sinh viên (2.800.000đ) rồi nè! Thử tự nấu ăn nhiều hơn hoặc cân nhắc điều chỉnh lại xem sao nha!"

Biểu đồ hiển thị phù hợp nhất (Biểu đồ Cột Đôi - Grouped Bar Chart):

Hiển thị hai cột đứng cạnh nhau cho từng danh mục chi tiêu: Cột màu xanh đại diện cho "Bạn", cột màu xám đại diện cho "Nhóm tương đồng".

Cách hiển thị này giúp người dùng ngay lập tức thấy phần chênh lệch cao/thấp trực quan mà không cần đọc số liệu chi tiết.

5. Cập nhật bổ sung cho Web Admin (Phần bổ sung từ yêu cầu trước)
Vì chúng ta vừa thêm tính năng so sánh nhóm này, Website Admin cần bổ sung thêm một chức năng nhỏ nhưng quan trọng trong Phân hệ 1 (Dashboard) hoặc Phân hệ 3 (Quản trị User):

Quản lý Danh mục Nhóm (Group/Cluster Management): Giao diện cho phép Admin định nghĩa các nhóm người dùng mới hoặc điều chỉnh ngưỡng thu nhập của nhóm khi lạm phát/thị trường thay đổi.

Trigger Chạy Batch Job Thủ Công: Một nút bấm cho phép Kỹ sư hệ thống ép buộc chạy script tính toán lại dữ liệu trung bình nhóm ngay lập tức (nếu có cập nhật dữ liệu lớn đột xuất) mà không cần đợi đến 2h00 sáng.

Tư duy sản phẩm từ PO: Tính năng so sánh này sẽ tạo ra một hiệu ứng "Gamification" (Trò chơi hóa) rất tốt. Người dùng sẽ có tâm lý thi đua xem ai giữ được cột chi tiêu của mình thấp hơn cột trung bình của nhóm. Điều này làm tăng tỷ lệ giữ chân người dùng (Retention Rate) của ứng dụng một cách tự nhiên.
