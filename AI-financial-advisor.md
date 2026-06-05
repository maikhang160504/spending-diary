1. Kịch bản 1: Báo cáo Tổng chi tiêu (Ví dụ: "Tháng này tiêu hết bao nhiêu rồi?")
Mục đích người dùng: Muốn biết nhanh tổng quan ngân sách để "kiềm chế" bản thân, cần một con số tổng và sự so sánh với tháng trước để biết mình đang tiêu nhanh hay chậm.

Cách AI trả lời (Tone giọng thân thiện, trực diện):

"Tính đến hôm nay, bạn đã tiêu tổng cộng 5.450.000đ rồi nè. Tốc độ tiêu xài đang nhanh hơn 12% so với cùng kỳ tháng trước đó nha, tém tém lại thôi!"

Biểu đồ hiển thị phù hợp nhất: * Biểu đồ Vòng tròn (Donut/Pie Chart): Hiển thị tổng số tiền ở tâm vòng tròn, các cung tròn xung quanh chia theo tỷ lệ các danh mục lớn (Food, Entertainment, Transport...) để nhìn thoáng qua là biết tiền đổ vào đâu nhiều nhất.

Biểu đồ Tiến độ (Progress Bar): Nếu user có đặt hạn mức tháng (ví dụ 10 triệu), hiển thị thanh tiến độ đã chạm mức 54.5%.

2. Kịch bản 2: Báo cáo Chi tiêu cao nhất (Ví dụ: "Khoản nào tốn tiền nhất tuần này?")
Mục đích người dùng: Tìm ra "thủ phạm" hoặc "gánh nặng" lớn nhất trong ví tiền của mình để lên kế hoạch cắt giảm.

Cách AI trả lời:

"Quán quân 'đốt ví' tuần này gọi tên khoản: Sửa xe máy hết 1.200.000đ vào thứ Ba. Á quân là vụ Đi ăn lẩu với công ty hết 850.000đ. Hai khoản này đã chiếm gần một nửa chi tiêu tuần của bạn rồi!"

Biểu đồ hiển thị phù hợp nhất:

Biểu đồ Cột ngang (Horizontal Bar Chart): Sắp xếp các khoản chi từ cao xuống thấp (Top Spending). Việc dùng cột ngang giúp hiển thị tên nhãn hoặc nội dung chi tiêu (raw_text) rất rõ ràng mà không bị che khuất chữ như cột dọc.

3. Kịch bản 3: Báo cáo Chi tiêu theo chu kỳ (Ví dụ: "Cho xin báo cáo tuần này", "Chi tiêu tuần này thế nào?")
Mục đích người dùng: Xem xu hướng chi tiêu biến động như thế nào qua các ngày trong tuần, ngày nào tiêu hoang nhất (thường là cuối tuần).

Cách AI trả lời:

"Tuần này bạn tiêu tổng cộng 2.100.000đ. Nhìn chung từ thứ Hai đến thứ Sáu bạn tiêu rất chuẩn chỉ, nhưng thứ Bảy vừa rồi bùng nổ nhất với hơn 900.000đ cho việc mua sắm đấy nhé!"

Biểu đồ hiển thị phù hợp nhất:

Biểu đồ Đường (Line Chart) hoặc Biểu đồ Cột dọc (Vertical Bar Chart): Trục X là các ngày trong tuần (T2, T3, T4... CN), trục Y là số tiền. Biểu đồ này giúp thể hiện cực kỳ rõ ràng "đỉnh và đáy" chi tiêu, giúp user nhận ra mô thức hành vi của mình (ví dụ: hội chứng "cuối tuần xõa cánh").

4. Kiến trúc hạ tầng để xử lý Request Report (Dưới góc nhìn Hệ thống)
Để làm được điều này một cách mượt mà và không bị nghẽn hệ thống, luồng xử lý NLU và Data sẽ vận hành như sau:
┌─────────────────┐      ┌─────────────────────────┐      ┌──────────────────────────┐
│ User Text Input │ ───► │  NLU: Nhận diện Intent  │ ───► │  SQL Parser: Trích xuất  │
│ "Chi tuần này"  │      │     (intent_report)     │      │   Thời gian & Danh mục   │
└─────────────────┘      └─────────────────────────┘      └────────────┬─────────────┘
                                                                       │
                                                                       ▼
┌─────────────────┐      ┌─────────────────────────┐      ┌──────────────────────────┐
│  Render UI Chat │ ◄─── │  Trả về JSON data cho   │ ◄─── │   PostgreSQL thực thi    │
│ (Text + Chart)  │      │  Front-end tự vẽ chart  │      │   Query (SUM, GROUP BY)  │
└─────────────────┘      └─────────────────────────┘      └──────────────────────────┘

Chi tiết các bước:
1. NLU xác định Intent: Hệ thống nhận diện từ khóa "tuần", "tháng", "cao nhất", "tổng" $\rightarrow$ Phân loại vào intent_report.
2. Trích xuất Slot (Thực thể thời gian/loại hình): * Từ "tuần này" $\rightarrow$ Hệ thống tự động tính toán ra khoảng ngày start_date và end_date của tuần hiện tại trong hệ thống.Từ "cao nhất" $\rightarrow$ Hệ thống hiểu cần gán lệnh SQL ORDER BY amount DESC LIMIT 1 (hoặc LIMIT 3).
3. Back-end KHÔNG trả về hình ảnh biểu đồ tĩnh: Để hệ thống nhẹ và scale tốt, Back-end chỉ chạy câu lệnh SQL (ví dụ: GROUP BY category) rồi trả về cho Front-end một chuỗi JSON sạch sẽ.
4. Front-end (Mobile/Web) nhận JSON và render: Đội Front-end sẽ dùng các thư viện chart nhẹ (như Chart.js, Recharts hoặc ApexCharts) để vẽ các biểu đồ động trực tiếp trên app.

💡 Lời khuyên của PO cho tính năng này:
Để đúng tinh thần "Hệ thống quản lý chi tiêu dạng Story", thay vì bắt user lúc nào cũng phải gõ câu hỏi thì AI mới trả lời báo cáo, chúng ta nên làm tính năng "Chủ động gửi Story báo cáo định kỳ" (Proactive Reporting):Cứ đúng 20h00 tối Chủ Nhật hàng tuần, hệ thống sẽ tự động tổng hợp dữ liệu, tự động sinh ra một "Weekly Story" bao gồm các biểu đồ trên kèm lời nhận xét của AI và gửi thông báo (Push Notification) cho user.