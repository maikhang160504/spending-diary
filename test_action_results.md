# Kết quả Kiểm thử LLM Actions & RAG Flow

**Thời gian:** 7/27/2026, 1:05:16 AM
**User ID:** 01b77dd6-172d-49a0-8fc1-38d0d02e1865 (thành Khang) | **Wallet ID:** 5ebc9563-ed4c-42a2-b956-673c81dbdbed

---

## 1. REPORT_GENERAL - ❌ FAIL (Timeout after 60s waiting for AI)

---

## 2. REPORT_GENERAL - ✅ PASS
**Câu lệnh:** "Từ ngày 1 đến ngày 10 tháng này tôi chi bao nhiêu?"

- **Intent:** `Action`
- **Action Type (Thực tế):** `REPORT_GENERAL`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `null`
  - **Time Range:** `{"from":"2026-07-01T00:00:00+07:00","granularity":"month","period_label":"Tháng này (01/07 - 27/07/2026)","to":"2026-07-27T23:59:59+07:00"}`
  - **Raw Slots:** `{"category":"null","target":null,"target_type":null,"time_range":"từ ngày 1 đến ngày 10 tháng này","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Tính đến hôm nay, bạn đã tiêu tổng cộng 0đ cho danh mục null rồi nè. Tốc độ tiêu xài tương đương cùng kỳ tháng trước đó nha. Tém tém lại thôi!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **ReportGeneralWidget** (Biểu đồ tổng quan hoặc thống kê danh mục).
> Dữ liệu RAG trả về: `{"by_category":[],"by_day":[{"day":"2026-06-30","expense":0,"income":0},{"day":"2026-07-01","expense":0,"income":0},{"day":"2026-07-02","expense":0,"income":0},{"day":"2026-07-03","expense":0,"income"...`

---

## 3. REPORT_GENERAL - ✅ PASS
**Câu lệnh:** "Tuần qua tiêu bao nhiêu tiền ăn uống?"

- **Intent:** `Action`
- **Action Type (Thực tế):** `REPORT_GENERAL`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `Food`
  - **Time Range:** `{"from":"2026-07-27T00:00:00+07:00","granularity":"week","period_label":"Tuần này (27/07/2026)","to":"2026-07-27T23:59:59+07:00"}`
  - **Raw Slots:** `{"category":"Food","target":null,"target_type":null,"time_range":"tuần qua","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** So sánh chi tiêu: Tuần này (27/07/2026) bạn chi cho ăn uống và Ăn uống bằng nhau luôn, đều là 0đ!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **ReportGeneralWidget** (Biểu đồ tổng quan hoặc thống kê danh mục).
> Dữ liệu RAG trả về: `{"by_category":[],"by_day":[{"day":"2026-07-26","expense":0,"income":0},{"day":"2026-07-27","expense":0,"income":0}],"categoryCode":"Food","compareCategories":["Food","Food & Drink"],"compare_percent"...`

---

## 4. REPORT_GENERAL - ✅ PASS
**Câu lệnh:** "Mua sắm trong tháng trước tốn bao nhiêu?"

- **Intent:** `Action`
- **Action Type (Thực tế):** `REPORT_GENERAL`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `Shopping`
  - **Time Range:** `{"from":"2026-06-01T00:00:00+07:00","granularity":"last_month","period_label":"Tháng trước (01/06 - 30/06/2026)","to":"2026-06-30T23:59:59+07:00"}`
  - **Raw Slots:** `{"category":"Shopping","target":null,"target_type":null,"time_range":"tháng trước","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Tính đến hôm nay, bạn đã tiêu tổng cộng 320.000đ cho danh mục Mua sắm rồi nè. Tốc độ tiêu xài đang chậm hơn 36% so với cùng kỳ tháng trước đó nha. Tém tém lại thôi!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **ReportGeneralWidget** (Biểu đồ tổng quan hoặc thống kê danh mục).
> Dữ liệu RAG trả về: `{"by_category":[{"categoryCode":"Shopping","count":3,"percent":100,"total":320000}],"by_day":[{"day":"2026-05-31","expense":0,"income":0},{"day":"2026-06-01","expense":0,"income":0},{"day":"2026-06-02...`

---

## 5. REPORT_GENERAL - ✅ PASS
**Câu lệnh:** "Báo cáo tổng quan cho tôi"

- **Intent:** `Action`
- **Action Type (Thực tế):** `REPORT_GENERAL`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `{"from":"2026-06-30T17:00:00.000Z","granularity":"month","period_label":"Tháng này (01/07 - 27/07/2026)","to":"2026-07-27T16:59:59.000Z"}`
  - **Raw Slots:** `{"target":null,"target_type":null,"time_range":null,"unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Tính đến hôm nay, bạn đã tiêu tổng cộng 1.590.000đ rồi nè. Tốc độ tiêu xài đang nhanh hơn 20% so với cùng kỳ tháng trước đó nha. Tém tém lại thôi!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **ReportGeneralWidget** (Biểu đồ tổng quan hoặc thống kê danh mục).
> Dữ liệu RAG trả về: `{"by_category":[{"categoryCode":"Housing","count":2,"percent":37,"total":590000},{"categoryCode":"Shopping","count":2,"percent":16,"total":260000},{"categoryCode":"Social","count":2,"percent":15,"tota...`

---

## 6. REPORT_COMPARE - ✅ PASS
**Câu lệnh:** "Tháng này tôi tiêu nhiều hơn tháng trước không?"

- **Intent:** `Action`
- **Action Type (Thực tế):** `REPORT_COMPARE`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `null`
  - **Time Range:** `[{"from":"2026-07-01T00:00:00+07:00","granularity":"month","period_label":"Tháng này (01/07 - 27/07/2026)","to":"2026-07-27T23:59:59+07:00"}]`
  - **Raw Slots:** `{"category":"null","target":null,"target_type":null,"time_range":"tháng này","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Tính đến hôm nay, bạn đã tiêu tổng cộng 0đ cho danh mục null rồi nè. Tốc độ tiêu xài tương đương cùng kỳ tháng trước đó nha. Tém tém lại thôi!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **ReportCompareWidget** (So sánh tăng/giảm giữa 2 mốc).
> Dữ liệu RAG trả về: `{"by_category":[],"by_day":[{"day":"2026-06-30","expense":0,"income":0},{"day":"2026-07-01","expense":0,"income":0},{"day":"2026-07-02","expense":0,"income":0},{"day":"2026-07-03","expense":0,"income"...`

---

## 7. REPORT_COMPARE - ✅ PASS
**Câu lệnh:** "Tháng 5/2023 so với tháng 5/2024 thì sao"

- **Intent:** `Action`
- **Action Type (Thực tế):** `REPORT_COMPARE`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `null`
  - **Time Range:** `[{"from":"2026-07-01T00:00:00+07:00","granularity":"month","period_label":"Tháng này (01/07 - 27/07/2026)","to":"2026-07-27T23:59:59+07:00"}]`
  - **Raw Slots:** `{"category":"null","target":null,"target_type":null,"time_range":"tháng 5/2023 và tháng 5/2024","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Tính đến hôm nay, bạn đã tiêu tổng cộng 0đ cho danh mục null rồi nè. Tốc độ tiêu xài tương đương cùng kỳ tháng trước đó nha. Tém tém lại thôi!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **ReportCompareWidget** (So sánh tăng/giảm giữa 2 mốc).
> Dữ liệu RAG trả về: `{"by_category":[],"by_day":[{"day":"2026-06-30","expense":0,"income":0},{"day":"2026-07-01","expense":0,"income":0},{"day":"2026-07-02","expense":0,"income":0},{"day":"2026-07-03","expense":0,"income"...`

---

## 8. REPORT_COMPARE - ✅ PASS
**Câu lệnh:** "So sánh chi phí ăn uống và đi lại tháng này"

- **Intent:** `Action`
- **Action Type (Thực tế):** `REPORT_COMPARE`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `Food`
  - **Time Range:** `[{"from":"2026-07-01T00:00:00+07:00","granularity":"month","period_label":"Tháng này (01/07 - 27/07/2026)","to":"2026-07-27T23:59:59+07:00"}]`
  - **Raw Slots:** `{"category":"Food","target":null,"target_type":null,"time_range":"tháng này","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** So sánh chi tiêu: Tháng này (01/07 - 27/07/2026) bạn chi cho ăn uống (170.000đ) nhiều hơn cho đi lại (0đ) nha.

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **ReportCompareWidget** (So sánh tăng/giảm giữa 2 mốc).
> Dữ liệu RAG trả về: `{"by_category":[{"categoryCode":"Housing","count":2,"percent":37,"total":590000},{"categoryCode":"Shopping","count":2,"percent":16,"total":260000},{"categoryCode":"Social","count":2,"percent":15,"tota...`

---

## 9. REPORT_COMPARE - ✅ PASS
**Câu lệnh:** "So sánh thu nhập và chi tiêu tháng này"

- **Intent:** `Action`
- **Action Type (Thực tế):** `REPORT_COMPARE`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `{"from":"2026-06-30T17:00:00.000Z","granularity":"month","period_label":"Tháng này (01/07 - 27/07/2026)","to":"2026-07-27T16:59:59.000Z"}`
  - **Raw Slots:** `{"target":null,"target_type":null,"time_range":null,"unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Tháng này (01/07 - 27/07/2026): tổng thu nhập 5.000.000đ, chi tiêu 1.590.000đ.

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **ReportCompareWidget** (So sánh tăng/giảm giữa 2 mốc).
> Dữ liệu RAG trả về: `{"by_category":[{"categoryCode":"salary","count":4,"percent":100,"total":5000000}],"by_day":[{"day":"2026-06-30","expense":0,"income":0},{"day":"2026-07-01","expense":40000,"income":1300000},{"day":"2...`

---

## 10. SET_LIMIT - ✅ PASS
**Câu lệnh:** "Đặt hạn mức tháng này 20 triệu"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_LIMIT`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `20000000`
  - **Category:** `N/A`
  - **Time Range:** `"tháng này"`
  - **Raw Slots:** `{"amount":20000000,"target":null,"target_type":null,"time_range":"tháng này","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Được rồi Thành Khang, Mimo đã đặt hạn mức tháng này là 20 triệu cho bạn nè! Đêm khuya mà vẫn chăm chỉ quản lý tài chính đấy, vibe cực 🔥!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{}...`

---

## 11. SET_LIMIT - ✅ PASS
**Câu lệnh:** "Giới hạn ăn uống 3 triệu"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_LIMIT`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `3000000`
  - **Category:** `Food`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"amount":3000000,"category":"Food","item":"ăn uống","target":null,"target_type":null,"unit":null,"value":null,"verb":"SET"}`
- **NLG Response (Câu thoại của AI):** Được rồi Thành Khang, Mimo đã set giới hạn ăn uống cho bạn là 3 triệu nè. Đêm khuya mà còn nghĩ đến chuyện ăn uống vậy đó, chắc bụng đang kêu inh ỏi rồi phải không? 😴

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{}...`

---

## 12. SET_LIMIT - ✅ PASS
**Câu lệnh:** "Đổi hạn mức tháng này thành 10 triệu"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_LIMIT`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `10000000`
  - **Category:** `N/A`
  - **Time Range:** `"tháng này"`
  - **Raw Slots:** `{"amount":10000000,"target":null,"target_type":null,"time_range":"tháng này","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Được rồi Thành Khang, Mimo sẽ đổi hạn mức tháng này thành 10 triệu cho bạn nhé! 🌟 Đêm khuya mà vẫn chăm chỉ quản lý tài chính, thật là đỉnh luôn ấy! 😎

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{}...`

---

## 13. SET_GOAL - ✅ PASS
**Câu lệnh:** "Tăng mục tiêu mua xe lên 50 triệu"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_GOAL`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `50000000`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"amount":50000000,"category":null,"contact_name":null,"due_date":null,"enabled":null,"goal_name":"mua xe","item":"xe","loan_type":null,"query":null,"target":null,"target_type":null,"theme":null,"time_range":null,"tool_type":"saving_personal","unit":null,"value":null,"verb":"SET","verbal_style":null}`
- **NLG Response (Câu thoại của AI):** Thành Khang ơi, tăng mục tiêu mua xe lên 50 triệu à? Vibe cực 🔥, chốt đơn thôi nào! 🚗 Đêm khuya mà vẫn quyết tâm vậy đó, Thành Khang sẽ sớm có xe mới thôi! 😎

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{}...`

---

## 14. SET_GOAL - ✅ PASS
**Câu lệnh:** "Cập nhật mục tiêu quỹ du lịch sang tháng 12 năm nay"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_GOAL`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `"tháng 12 năm nay"`
  - **Raw Slots:** `{"goal_name":"quỹ du lịch","target":null,"target_type":null,"time_range":"tháng 12 năm nay","tool_type":"saving_group","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Thành Khang ơi, mục tiêu du lịch tháng 12 đã được cập nhật rồi đó! Đếm ngược đến kỳ lương mới để chuẩn bị cho chuyến đi nhé, chốt đơn thôi nào 🎉

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{}...`

---

## 15. SET_GOAL - ✅ PASS
**Câu lệnh:** "Tạo mục tiêu mua laptop 30 triệu"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_GOAL`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `30000000`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"amount":30000000,"category":null,"contact_name":null,"due_date":null,"enabled":true,"goal_name":"mua laptop","item":"laptop","loan_type":null,"target":null,"target_type":null,"theme":null,"time_range":null,"tool_type":"saving_personal","unit":null,"value":null,"verb":"SET","verbal_style":null}`
- **NLG Response (Câu thoại của AI):** Thành Khang ơi, mục tiêu mua laptop 30 củ đã được tạo rồi đó! Đêm khuya mà vẫn quyết tâm mua laptop mới, vibe cực 🔥 luôn á. Chốt đơn thôi nào, chỉ còn 3 ngày nữa là tới kỳ lương rồi, cố gắng tiết kiệm lên nhé! 💪

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{}...`

---

## 16. SET_GOAL - ✅ PASS
**Câu lệnh:** "Tiết kiệm lấy vợ 100 triệu vào cuối năm sau"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_GOAL`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `100000000`
  - **Category:** `Savings`
  - **Time Range:** `"cuối năm sau"`
  - **Raw Slots:** `{"amount":100000000,"category":"Savings","goal_name":"Tiết kiệm lấy vợ","item":"Tiết kiệm lấy vợ","target":null,"target_type":null,"time_range":"cuối năm sau","tool_type":"saving_personal","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Thành Khang ơi, vibe phát cẩu lương quá nha! Mục tiêu tiết kiệm 100 triệu cho việc lấy vợ cuối năm sau đã được tạo thành công rồi đó. Chiều bồ số 2 không ai số 1 nhé, nhớ giữ vững tay lái và tiết kiệm đều đặn nha! 💍✨

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{}...`

---

## 17. SET_TONE - ✅ PASS
**Câu lệnh:** "Từ nay hãy nói chuyện nghiêm khắc với tôi nhé."

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_TONE`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"target":null,"target_type":null,"unit":null,"value":null,"verb":null,"verbal_style":"kho_tinh"}`
- **NLG Response (Câu thoại của AI):** Được rồi Thành Khang, từ giờ Mimo sẽ nghiêm khắc hơn với bạn nha! Mình sẽ giúp bạn quản lý chi tiêu chặt chẽ hơn, đảm bảo không tiêu xài lung tung nữa nhé. Đêm khuya mà còn lo chuyện tiền bạc thì mới thành công được đó! 💪

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{}...`

---

## 18. SET_TONE - ❌ FAIL
**Câu lệnh:** "Đổi sang giọng điệu dận dỗi đi"

- **Intent:** `Chitchat`
- **Action Type (Thực tế):** `NONE`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"target":null,"target_type":null,"unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Ui trời, thành Khang muốn Mimo dạn dỗi vậy à? Được rồi, nhưng mà đêm khuya rồi đó, đừng thức khuya quá kẻo mai mặt mày sưng lên nhé 😒

### Mô phỏng Mobile UI hiển thị:
> 📱 Lỗi luồng, hiển thị text message thông thường.

---

## 19. SET_TONE - ✅ PASS
**Câu lệnh:** "Hãy đổi sang giọng ngọt ngào nhé"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_TONE`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"target":null,"target_type":null,"unit":null,"value":null,"verb":null,"verbal_style":"ngot_ngao"}`
- **NLG Response (Câu thoại của AI):** Được rồi Thành Khang ơi, từ giờ Mimo sẽ nói chuyện ngọt ngào hơn nha! 🌹 Đêm khuya mà còn online, chắc Thành Khang đang lên kế hoạch gì đó thú vị phải không? 💫

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{}...`

---

## 20. SEARCH_RECORD - ✅ PASS
**Câu lệnh:** "Hôm qua có mua ly trà sữa nào không?"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SEARCH_RECORD`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `Food`
  - **Time Range:** `"hôm qua"`
  - **Raw Slots:** `{"category":"Food","item":"trà sữa","target":null,"target_type":null,"time_range":"hôm qua","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** 🔍 Tìm thấy 1 giao dịch phù hợp.

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **SearchRecordWidget** (Danh sách các giao dịch tìm thấy).
> Số lượng tìm thấy: 0 giao dịch.

---

## 21. SEARCH_RECORD - ✅ PASS
**Câu lệnh:** "Tìm cho tôi các khoản chi trên 500k trong tuần trước."

- **Intent:** `Action`
- **Action Type (Thực tế):** `SEARCH_RECORD`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `500000`
  - **Category:** `N/A`
  - **Time Range:** `"tuần trước"`
  - **Raw Slots:** `{"amount":500000,"category":null,"contact_name":null,"due_date":null,"enabled":null,"goal_name":null,"item":null,"loan_type":null,"query":"chi","target":null,"target_type":null,"theme":null,"time_range":"tuần trước","tool_type":null,"unit":null,"value":null,"verb":null,"verbal_style":null}`
- **NLG Response (Câu thoại của AI):** 🔍 Không tìm thấy giao dịch nào phù hợp.

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **SearchRecordWidget** (Danh sách các giao dịch tìm thấy).
> Số lượng tìm thấy: 0 giao dịch.

---

## 22. SEARCH_RECORD - ✅ PASS
**Câu lệnh:** "Các khoản chi vào ngày 15/5 vừa rồi"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SEARCH_RECORD`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `"ngày 15/5 vừa rồi"`
  - **Raw Slots:** `{"target":null,"target_type":null,"time_range":"ngày 15/5 vừa rồi","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** 🔍 Không tìm thấy giao dịch nào phù hợp.

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **SearchRecordWidget** (Danh sách các giao dịch tìm thấy).
> Số lượng tìm thấy: 0 giao dịch.

---

## 23. SEARCH_RECORD - ✅ PASS
**Câu lệnh:** "Tìm mua sắm trên 1 triệu trong tháng trước"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SEARCH_RECORD`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `1000000`
  - **Category:** `Shopping`
  - **Time Range:** `"tháng trước"`
  - **Raw Slots:** `{"amount":1000000,"category":"Shopping","item":"mua sắm","target":null,"target_type":null,"time_range":"tháng trước","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** 🔍 Không tìm thấy giao dịch nào phù hợp.

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **SearchRecordWidget** (Danh sách các giao dịch tìm thấy).
> Số lượng tìm thấy: 0 giao dịch.

---

## 24. SUGGEST_BUDGET - ✅ PASS
**Câu lệnh:** "Gợi ý cách lập ngân sách giúp tôi."

- **Intent:** `Action`
- **Action Type (Thực tế):** `SUGGEST_BUDGET`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"target":null,"target_type":null,"time_range":null,"unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Chưa có đủ dữ liệu để gợi ý hạn mức cho tháng tới. Hãy tiếp tục ghi chép chi tiêu nhé!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **SuggestBudgetWidget** (Các thẻ mẹo tiết kiệm và phân bổ).
> Số lượng gợi ý: 0 mẹo.

---

## 25. SUGGEST_BUDGET - ✅ PASS
**Câu lệnh:** "Gợi ý cho tôi cách lập ngân sách để tiết kiệm 3 triệu mỗi tháng"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SUGGEST_BUDGET`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"target":null,"target_type":null,"time_range":null,"unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Chưa có đủ dữ liệu để gợi ý hạn mức cho tháng tới. Hãy tiếp tục ghi chép chi tiêu nhé!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị Widget **SuggestBudgetWidget** (Các thẻ mẹo tiết kiệm và phân bổ).
> Số lượng gợi ý: 0 mẹo.

---

## 26. SYSTEM_SETTING - ✅ PASS
**Câu lệnh:** "Chuyển ứng dụng sang chế độ tối (dark mode)."

- **Intent:** `Action`
- **Action Type (Thực tế):** `SYSTEM_SETTING`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"target":null,"target_type":null,"theme":"dark","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** ✅ Đã chuyển sang giao diện tối!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{"kind":"theme","message":"✅ Đã chuyển sang giao diện tối!","themeMode":true}...`

---

## 27. SET_USERNAME - ✅ PASS
**Câu lệnh:** "Hãy đổi tên tôi thành Sếp."

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_USERNAME`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"contact_name":null,"due_date":null,"enabled":null,"item":"Sếp","loan_type":null,"query":null,"target":null,"target_type":null,"theme":null,"time_range":null,"tool_type":null,"unit":null,"value":null,"verb":null,"verbal_style":null}`
- **NLG Response (Câu thoại của AI):** ✅ Mimo sẽ gọi bạn là "thành Sếp" nhé!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{"kind":"set_username","message":"✅ Mimo sẽ gọi bạn là \"thành Sếp\" nhé!","username":"thành Sếp"}...`

---

## 28. SET_USERNAME - ✅ PASS
**Câu lệnh:** "Gọi tên tôi là Khang"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_USERNAME`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"amount":null,"category":null,"contact_name":null,"due_date":null,"enabled":null,"goal_name":null,"item":"Khang","loan_type":null,"query":null,"target":null,"target_type":null,"theme":null,"time_range":null,"tool_type":null,"unit":null,"value":null,"verb":null,"verbal_style":null}`
- **NLG Response (Câu thoại của AI):** ✅ Mimo sẽ gọi bạn là "là Khang" nhé!

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{"kind":"set_username","message":"✅ Mimo sẽ gọi bạn là \"là Khang\" nhé!","username":"là Khang"}...`

---

## 29. SET_ALERT - ❌ FAIL
**Câu lệnh:** "Cài đặt cảnh báo chi tiêu 80% ngân sách tháng."

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_LIMIT`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `80`
  - **Category:** `N/A`
  - **Time Range:** `"tháng này"`
  - **Raw Slots:** `{"amount":80,"target":null,"target_type":null,"time_range":"tháng này","unit":null,"value":null,"verb":"SET"}`
- **NLG Response (Câu thoại của AI):** Được rồi Khang ơi, Mimo đã cài đặt cảnh báo khi bạn chi đến 80% ngân sách tháng này nè. Đêm khuya mà vẫn chăm chỉ quản lý tiền bạc, thật là đỉnh 😴 эконgười

### Mô phỏng Mobile UI hiển thị:
> 📱 Lỗi luồng, hiển thị text message thông thường.

---

## 30. SET_ALERT - ✅ PASS
**Câu lệnh:** "Nhắc tôi ghi chép chi tiêu vào lúc 8h tối mỗi ngày."

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_ALERT`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `"8h tối"`
  - **Raw Slots:** `{"item":"ghi chép chi tiêu","query":null,"target":null,"target_type":null,"time_range":"8h tối","unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** ✅ Đã bật thông báo cảnh báo chi tiêu.

### Mô phỏng Mobile UI hiển thị:
> 📱 Hiển thị thông báo Toast xác nhận cài đặt thành công, cập nhật State trong App.
> Dữ liệu RAG trả về: `{"enabled":true,"kind":"set_alert","message":"✅ Đã bật thông báo cảnh báo chi tiêu."}...`

---

## 31. SET_ALERT - ❌ FAIL
**Câu lệnh:** "Tắt cảnh báo chi tiêu đi"

- **Intent:** `Action`
- **Action Type (Thực tế):** `SET_LIMIT`
- **Slots (Bóc tách dữ liệu):**
  - **Amount:** `N/A`
  - **Category:** `N/A`
  - **Time Range:** `N/A`
  - **Raw Slots:** `{"enabled":false,"target":null,"target_type":null,"unit":null,"value":null,"verb":null}`
- **NLG Response (Câu thoại của AI):** Được rồi Khang, Mimo sẽ tắt cảnh báo chi tiêu cho bạn nè. Đêm khuya rồi, ngủ ngon nhé! 🌃😴

### Mô phỏng Mobile UI hiển thị:
> 📱 Lỗi luồng, hiển thị text message thông thường.

---

