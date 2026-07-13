# Danh sách và Kịch bản Kiểm thử cho các LLM Actions

Tài liệu này liệt kê chi tiết các action (hành động) được hỗ trợ bởi hệ thống LLM, kèm theo mô tả, câu lệnh mẫu từ người dùng và checklist để kiểm thử (test flow) cho từng action.

---

## 1. REPORT_GENERAL (Báo cáo tổng quan)
**Chi tiết:** Trích xuất và tổng hợp dữ liệu thu/chi dựa trên các bộ lọc như thời gian (ngày, tuần, tháng, năm), theo danh mục cụ thể (ăn uống, mua sắm...), hoặc kết hợp cả hai.
**Câu text mẫu:** 
- *"Tháng này tôi đã tiêu hết bao nhiêu tiền rồi?"*
- *"Cho tôi xem tổng chi tiêu ăn uống trong tuần qua."*
- *"Tôi có bao nhiêu khoản thu nhập trong năm nay?"*
- *"Báo cáo cho tôi tình hình tài chính tổng quan hôm nay."*

**Flow check:**
- [ ] Báo cáo theo thời gian cụ thể (hôm nay, tuần này, tháng này, năm nay).
- [ ] Báo cáo theo khoảng thời gian tùy chỉnh (từ ngày X đến ngày Y).
- [ ] Báo cáo lọc theo một danh mục cụ thể (chỉ tính chi phí Đi lại).
- [ ] Báo cáo kết hợp: Danh mục + Thời gian (VD: Mua sắm trong tháng trước).
- [ ] Báo cáo tổng quan không có tham số (mặc định lấy tháng hiện tại hoặc tổng thời gian).

---

## 2. REPORT_COMPARE (So sánh chi tiêu/thu nhập)
**Chi tiết:** Thực hiện so sánh dữ liệu tài chính giữa hai khoảng thời gian khác nhau hoặc giữa hai danh mục khác nhau để xem độ chênh lệch (tăng/giảm).
**Câu text mẫu:**
- *"Tháng này tôi tiêu nhiều hơn tháng trước không?"*
- *"So sánh chi phí ăn uống của tuần này và tuần trước."*
- *"Tôi chi cho giải trí nhiều hơn hay mua sắm nhiều hơn trong tháng này?"*

**Flow check:**
- [ ] So sánh tổng chi tiêu giữa 2 khoảng thời gian liền kề (Tháng này vs Tháng trước).
- [ ] So sánh cùng 1 kỳ của 2 năm khác nhau (Tháng 5/2023 vs Tháng 5/2024).
- [ ] So sánh 2 danh mục khác nhau trong cùng 1 khoảng thời gian.
- [ ] So sánh tổng thu nhập vs tổng chi tiêu trong 1 khoảng thời gian.

---

## 3. SET_LIMIT (Cài đặt hạn mức)
**Chi tiết:** Thiết lập ngân sách/giới hạn chi tiêu tối đa cho tổng thể hoặc cho một danh mục cụ thể trong một khoảng thời gian.
**Câu text mẫu:**
- *"Đặt giới hạn chi tiêu tháng này là 10 triệu."*
- *"Tháng này tôi chỉ muốn tiêu tối đa 3 triệu cho ăn uống thôi."*
- *"Cập nhật hạn mức mua sắm thành 2 triệu nhé."*

**Flow check:**
- [ ] Thiết lập hạn mức tổng thể cho tuần/tháng/năm mới.
- [ ] Thiết lập hạn mức cho một danh mục cụ thể.
- [ ] Cập nhật/Chỉnh sửa số tiền của một hạn mức đã tồn tại.
- [ ] Xóa/Hủy một hạn mức (Nếu có hỗ trợ).

---

## 4. SET_GOAL (Cài đặt/Cập nhật mục tiêu)
**Chi tiết:** Chỉnh sửa thông tin (số tiền, thời hạn, tên) của một mục tiêu tài chính/tiết kiệm đã được tạo từ trước.
**Câu text mẫu:**
- *"Tôi muốn tăng mục tiêu tiết kiệm mua xe lên 50 triệu."*
- *"Đổi thời hạn quỹ đi du lịch sang tháng 12 năm nay."*
- *"Cập nhật mục tiêu mua điện thoại thành 25 triệu."*

**Flow check:**
- [ ] Thay đổi số tiền mục tiêu.
- [ ] Thay đổi mốc thời gian hoàn thành mục tiêu.
- [ ] Thay đổi tên mục tiêu.

---

## 5. ADD_GOAL (Thêm mục tiêu mới)
**Chi tiết:** Tạo lập một mục tiêu tài chính hoặc quỹ tiết kiệm hoàn toàn mới.
**Câu text mẫu:**
- *"Thêm mục tiêu tiết kiệm mua laptop 30 triệu trong vòng 6 tháng tới."*
- *"Tạo cho tôi một quỹ dự phòng 20 triệu."*
- *"Tôi muốn bắt đầu tiết kiệm tiền lấy vợ, mục tiêu là 100 triệu vào cuối năm sau."*

**Flow check:**
- [ ] Tạo mục tiêu chỉ với Tên và Số tiền (chưa có thời hạn).
- [ ] Tạo mục tiêu đầy đủ Tên, Số tiền và Thời hạn.
- [ ] Xử lý khi người dùng nhập số tiền không hợp lệ.

---

## 6. SET_TONE (Cài đặt giọng điệu)
**Chi tiết:** Thay đổi phong cách giao tiếp, xưng hô hoặc thái độ của AI Assistant khi trả lời người dùng.
**Câu text mẫu:**
- *"Từ nay hãy nói chuyện với tôi một cách chuyên nghiệp và nghiêm túc."*
- *"Đổi sang giọng điệu cà khịa, châm biếm đi để tôi bớt tiêu tiền."*
- *"Hãy nói chuyện nhẹ nhàng, an ủi tôi nhé."*

**Flow check:**
- [ ] Chuyển đổi sang giọng điệu nghiêm túc/chuyên nghiệp.
- [ ] Chuyển đổi sang giọng điệu hài hước/cà khịa/gắt gỏng.
- [ ] Chuyển đổi sang giọng điệu nhẹ nhàng/động viên.
- [ ] Kiểm tra phản hồi ở câu lệnh tiếp theo xem AI có giữ đúng tone giọng đã cài hay không.

---

## 7. SEARCH_RECORD (Tìm kiếm giao dịch)
**Chi tiết:** Truy vấn và tìm kiếm các khoản thu/chi cụ thể dựa trên từ khóa (ghi chú), số tiền, hoặc khoảng thời gian.
**Câu text mẫu:**
- *"Tìm cho tôi các khoản chi trên 500k trong tuần trước."*
- *"Hôm qua tôi có mua ly trà sữa nào không?"*
- *"Liệt kê tất cả các khoản tiền lương tôi nhận được từ đầu năm đến nay."*
- *"Tôi đã mua cái áo màu đỏ bao nhiêu tiền nhỉ?"*

**Flow check:**
- [ ] Tìm kiếm theo từ khóa xuất hiện trong ghi chú (note).
- [ ] Tìm kiếm theo một khoảng số tiền (lớn hơn, nhỏ hơn, từ X đến Y).
- [ ] Tìm kiếm giao dịch chính xác theo ngày cụ thể.
- [ ] Tìm kiếm kết hợp (Danh mục + Khoảng tiền + Thời gian).

---

## 8. SUGGEST_BUDGET (Gợi ý ngân sách)
**Chi tiết:** Yêu cầu LLM tư vấn cách phân bổ ngân sách, mẹo tiết kiệm tiền dựa trên thu nhập dự kiến hoặc thói quen chi tiêu trong quá khứ.
**Câu text mẫu:**
- *"Lương tôi 15 triệu 1 tháng, hãy gợi ý cách chia ngân sách hợp lý giúp tôi."*
- *"Làm sao để tiết kiệm được 3 triệu mỗi tháng với thu nhập 12 triệu?"*
- *"Dựa vào chi tiêu tháng trước, gợi ý cho tôi cách cắt giảm chi phí."*

**Flow check:**
- [ ] Tư vấn phân bổ ngân sách dựa trên số tiền thu nhập giả định (vd theo rule 50/30/20).
- [ ] Đưa ra kế hoạch tiết kiệm để đạt được một số tiền cụ thể.
- [ ] (Nếu có data) Phân tích dữ liệu cũ và gợi ý danh mục cần cắt giảm.

---

## 9. SYSTEM_SETTING (Cài đặt hệ thống)
**Chi tiết:** Điều chỉnh các thông số kỹ thuật hoặc giao diện của ứng dụng thông qua câu lệnh.
**Câu text mẫu:**
- *"Chuyển ứng dụng sang chế độ tối (dark mode)."*

**Flow check:**
- [ ] Thay đổi Theme (Sáng/Tối/Hệ thống).


---

## 10. SET_USERNAME (Đổi tên người dùng)
**Chi tiết:** Thay đổi danh xưng, tên gọi mà AI sử dụng để gọi người dùng trong các cuộc hội thoại.
**Câu text mẫu:**
- *"Từ nay hãy gọi tôi là Sếp."*
- *"Đổi tên tôi thành Khang."*
- *"Tôi muốn bạn gọi tôi là Hoàng tử."*

**Flow check:**
- [ ] Đổi sang một tên thật (Khang, Nam...).
- [ ] Đổi sang một biệt danh/chức danh (Sếp, Chủ tịch...).
- [ ] Kiểm tra phản hồi ngay sau đó xem AI đã cập nhật cách xưng hô mới chưa.

---

## 11. SET_ALERT (Cài đặt cảnh báo/nhắc nhở)
**Chi tiết:** Kích hoạt, vô hiệu hóa hoặc cấu hình các thông báo nhắc nhở nhập liệu, cảnh báo vượt hạn mức.
**Câu text mẫu:**
- *"Nhắc tôi ghi chép chi tiêu vào lúc 8h tối mỗi ngày."*
- *"Bật cảnh báo cho tôi nếu tôi tiêu vượt quá 80% ngân sách tháng."*
- *"Tắt hết các nhắc nhở hàng ngày đi."*

**Flow check:**
- [ ] Thiết lập nhắc nhở theo giờ cố định trong ngày.
- [ ] Thiết lập cảnh báo dựa trên ngưỡng phần trăm (%) của hạn mức/ngân sách.
- [ ] Tắt/Xóa một cảnh báo đã được cài đặt trước đó.
- [ ] Tắt toàn bộ thông báo.
