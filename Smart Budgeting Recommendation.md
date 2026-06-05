Phân tích dữ liệu để gợi ý hạn mức chi tiêu cho tháng tiếp theo (Smart Budgeting Recommendation) chính là bước chuyển hóa từ một ứng dụng "ghi chép bị động" sang "trợ lý chủ động".

Dưới đây là mô tả chi tiết về các vấn đề cốt lõi trong dữ liệu chi tiêu và phương án thiết kế thuật toán tối ưu để đưa ra gợi ý thông minh, giảm thiểu tối đa thao tác cho người dùng.

1. Hiện trạng & Bản chất các vấn đề trong dữ liệu chi tiêu
Để đưa ra một con số gợi ý hạn mức vừa vặn (không quá thắt lưng buộc bụng gây ức chế, cũng không quá lỏng lẻo), hệ thống phải giải quyết được 3 bài toán dữ liệu sau:

A. Nhiễu do các khoản chi tiêu bất thường (One-off/Anomaly Expenses)
Vấn đề: Trong tháng này, người dùng có thể phát sinh một khoản chi rất lớn nhưng cả năm chỉ xuất hiện một lần (Ví dụ: Mua điện thoại mới 15 triệu, đóng tiền học phí cả năm 20 triệu, hoặc sửa xe do tai nạn 3 triệu).

Hậu quả: Nếu hệ thống lấy tổng chi tiêu tháng này làm mốc để gợi ý cho tháng sau, hạn mức mới sẽ bị đẩy lên quá cao. Ngược lại, nếu ép họ cắt giảm dựa trên tháng có biến động lớn đó, gợi ý sẽ trở nên phi thực tế.

B. Tính mùa vụ và ngày lễ (Seasonal & Holiday Trends)
Vấn đề: Chi tiêu tháng 1, tháng 2 (mùa Tết) luôn cao hơn hẳn các tháng khác do nhu cầu mua sắm, quà cáp, di chuyển. Chi tiêu mùa hè (tháng 6, 7) của nhóm Sinh viên lại giảm mạnh ở mục ăn uống/học tập do các bạn về quê.

Hậu quả: Gợi ý hạn mức nếu chỉ nhìn vào 1-2 tháng gần nhất sẽ bị "lệch pha" hoàn toàn với thực tế đời sống của tháng tiếp theo.

C. Tâm lý học hành vi: "Bẫy thiết lập" (Setup Friction)
Vấn đề: Người dùng rất lười tự ngồi tính toán xem tháng sau mình nên tiêu bao nhiêu cho từng mục (Ăn uống, Cafe, Quần áo). Nếu app bắt họ tự điền một form dài, họ sẽ bỏ qua tính năng này.

Hậu quả: Hạn mức không được thiết lập, app mất đi tính năng cảnh báo và trở lại thành một chiếc app ghi chép thông thường.

2. Giải pháp Thiết kế Hệ thống & Thuật toán Tối ưu
Chúng ta sẽ không dùng các mô hình Machine Learning quá cồng kềnh cho bài toán này ở giai đoạn đầu. Thay vào đó, hệ thống sử dụng Thuật toán Phân tích Chuỗi thời gian dựa trên Quy tắc (Rule-based Time Series Analysis) kết hợp bộ lọc nhiễu, chạy qua Batch Job vào ngày cuối cùng của tháng.
Bước 1: Bộ lọc loại bỏ biến động đột biến (Denoising Filter)
Trước khi tính toán, hệ thống sẽ quét qua lịch sử chi tiêu 3 tháng gần nhất của User và gắn cờ (Flag) loại bỏ các giao dịch có giá trị lớn hơn $3 \times$ (3 lần) độ lệch chuẩn trung bình của danh mục đó, hoặc các giao dịch được gán nhãn thuộc danh mục phi định kỳ (Ví dụ: Medical/Y tế, Thuế, Thiết bị điện tử lớn).

Bước 2: Công thức tính Hạn mức Gợi ý (Smart Budget Formula)
Hệ thống sẽ tính toán hạn mức gợi ý cho từng danh mục dựa trên 3 chỉ số:
- Mức tiêu dùng cơ sở ($B$ - Base Spending): Trung bình trượt (Moving Average) của danh mục đó trong 3 tháng gần nhất sau khi đã lọc nhiễu.
- Tỷ lệ Thu nhập thay đổi ($I$ - Income Factor): Nếu thu nhập thực tế (income_earned) của 3 tháng gần nhất có xu hướng giảm, hệ thống sẽ tự động siết hạn mức lại.
- Mục tiêu tiết kiệm ($S$ - Saving Goal): Mặc định hệ thống hướng user cắt giảm nhẹ 5% - 10% ở các danh mục "Lãng phí" (Ví dụ: Cafe, Shopping, Giải trí) nếu tháng trước họ tiêu vượt định mức của nhóm đồng trang lứa. Các danh mục cố định như Tiền nhà, Điện nước sẽ giữ nguyên $100\%$.
$$\text{Hạn mức gợi ý} = B \times I \times (1 - S)$$

Bước 3: Cơ chế "Một chạm" (1-Click Apply) để giải quyết Bẫy thiết lập
Vào ngày 1 hàng tháng, AI sẽ chủ động sinh một Morning Story trên giao diện chính của User.

AI không đưa ra một bảng số liệu, mà đưa ra một câu chuyện ngắn gọn kèm 1 nút bấm duy nhất.

3. Kịch bản hiển thị UI/UX & Nội dung AI phản hồi
Mẫu câu thoại của AI (AI Speech Style):
"Tháng trước bạn đã tiêu tổng cộng 6.200.000đ, trong đó trà sữa và shopping đang chiếm tới 35% đấy nhé.

Để tháng này ví tiền dày hơn, MiMo đã thiết kế riêng cho bạn một Hạn mức thông minh: 5.500.000đ (Giúp bạn tiết kiệm thêm 700.000đ để nuôi heo đất mà vẫn ăn ngon mặc đẹp). Bạn có muốn áp dụng ngay không?"
Giao diện hiển thị :
Hiển thị một biểu đồ đường (Line Chart) mô phỏng dự báo: Nếu giữ nguyên tốc độ tiêu cũ (Đường màu đỏ đi lên) vs. Nếu đi theo hạn mức mới của AI (Đường màu xanh đi ngang ổn định).

Bên dưới là 30% danh mục chi tiết (Ví dụ: Ăn uống: 2.5tr | Cafe: 500k | Di chuyển: 400k).

Một nút bấm Call-to-Action (CTA) cực lớn: [Áp dụng hạn mức này ngay] và một nút nhỏ [Để mình tự chỉnh lại].

4. Lưu ý Vận hành & Tư duy Sản phẩm (PO Takeaway)📌 "Tính năng này có giúp người dùng bớt thao tác không?" $\rightarrow$ CÓ, GIẢM ĐẾN 90% THAO TÁC.Instead of forcing the user to be a financial accountant, the AI does 100% of the heavy lifting background data crunching. The user only needs to perform a single tap (1-Click Apply) to set up their entire guardrail for the new month.Về mặt kỹ thuật (Performance): Toàn bộ việc quét dữ liệu 3 tháng và tính công thức gợi ý cho toàn bộ User sẽ được chạy bằng Batch Job vào lúc 12h00 đêm ngày cuối tháng. Kết quả được lưu sẵn vào bảng user_budget_suggestions. Khi user mở app vào sáng ngày mùng 1, API chỉ mất < 2ms để load dữ liệu tĩnh này lên Story, đảm bảo hệ thống mượt mà tuyệt đối không bị nghẽn I/O hay RAM.