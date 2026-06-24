# Tài liệu Đặc tả các Hành động (INTENT_ACTION) trong Mimo Chat

Dưới đây là danh sách tất cả các hành động hệ thống (`INTENT_ACTION`) được hỗ trợ xử lý khi người dùng tương tác bằng giọng nói hoặc văn bản thông qua Chat Bot Mimo.

---

## 1. Báo cáo Chi tiêu (REPORT_GENERAL)
* **Loại lệnh:** `REPORT_GENERAL`
* **Tham số:** 
  - `time_range`: Khoảng thời gian (tuần này, tháng này, hôm nay, 7 ngày qua...)
  - `categoryCode`: Mã danh mục chi tiêu (nếu muốn xem riêng một danh mục)
* **Ví dụ câu lệnh:**
  - *"Cho mình xem báo cáo tuần này"*
  - *"Thống kê chi tiêu ăn uống tháng này"*
  - *"So sánh chi tiêu của mình với sinh viên khác"*

## 2. Thiết lập Giới hạn Chi tiêu (SET_LIMIT)
* **Loại lệnh:** `SET_LIMIT`
* **Tham số:**
  - `value`: Số tiền hạn mức mong muốn
  - `categoryCode`: Mã danh mục áp dụng hạn mức (nếu không có sẽ áp dụng cho tổng chi tiêu)
  - `verb`: Hành động cụ thể (`SET` - đặt mới, `ADD` - cộng thêm, `SUB` - giảm bớt)
* **Ví dụ câu lệnh:**
  - *"Đặt hạn mức ăn uống 2 triệu một tháng"*
  - *"Cộng thêm 500k vào giới hạn đi lại"*
  - *"Giảm bớt 200k từ hạn mức mua sắm"*

## 3. Tạo Mục tiêu Tiết kiệm (SET_GOAL / ADD_GOAL)
* **Loại lệnh:** `SET_GOAL`, `ADD_GOAL`
* **Tham số:**
  - `value`: Số tiền mục tiêu
  - `goalName`: Tên mục tiêu tiết kiệm
* **Ví dụ câu lệnh:**
  - *"Tạo mục tiêu mua laptop mới 15 triệu"*
  - *"Mình muốn tiết kiệm 5 triệu để đi du lịch"*
  - *"Tăng mục tiêu tiết kiệm đi lại thêm 500k"*

## 4. Xóa Giao dịch Gần nhất (DELETE_RECORD)
* **Loại lệnh:** `DELETE_RECORD`
* **Tham số:** Không có
* **Ví dụ câu lệnh:**
  - *"Xóa giao dịch vừa nhập"*
  - *"Hủy hóa đơn cuối cùng giúp mình"*

## 5. Thay đổi Giọng nói Mascot (SET_TONE)
* **Loại lệnh:** `SET_TONE`
* **Tham số:**
  - `verbalStyle`: Giọng nói mong muốn (`funny` - hài hước, `gentle` - dễ thương, `serious` - nghiêm túc, `sarcastic` - châm chọc, `strict` - dặn dỗi)
* **Ví dụ câu lệnh:**
  - *"Đổi sang giọng nói châm chọc nhé"*
  - *"Mimo hãy nói chuyện dễ thương hơn đi"*

## 6. Tìm kiếm Giao dịch (SEARCH_RECORD)
* **Loại lệnh:** `SEARCH_RECORD`
* **Tham số:**
  - `query`: Từ khóa tìm kiếm
  - `categoryCode`: Mã danh mục cần tìm
  - `minAmount`: Số tiền tối thiểu
* **Ví dụ câu lệnh:**
  - *"Tìm các giao dịch mua sắm"*
  - *"Kiếm cho mình hóa đơn nào trên 500k"*
  - *"Tìm kiếm từ khóa trà sữa"*

## 7. Gợi ý Ngân sách (SUGGEST_BUDGET)
* **Loại lệnh:** `SUGGEST_BUDGET`
* **Tham số:**
  - `targetMonth`: Tháng cần gợi ý (định dạng `YYYY-MM`)
* **Ví dụ câu lệnh:**
  - *"Gợi ý ngân sách chi tiêu cho tháng sau"*
  - *"Đề xuất hạn mức chi tiêu hợp lý"*

## 8. Mở Cài đặt / Đổi giao diện (SYSTEM_SETTING)
* **Loại lệnh:** `SYSTEM_SETTING`
* **Tham số:**
  - `theme`: Chế độ sáng/tối (dark mode / light mode)
* **Ví dụ câu lệnh:**
  - *"Mở màn hình cài đặt"*
  - *"Chuyển sang giao diện tối"*
  - *"Tắt chế độ ban đêm"*

## 9. Đổi tên gọi người dùng (SET_USERNAME)
* **Loại lệnh:** `SET_USERNAME`
* **Tham số:**
  - `value`: Tên mới người dùng muốn gọi
* **Ví dụ câu lệnh:**
  - *"Gọi mình là Khang nhé"*
  - *"Đổi tên của tớ thành Mimo Master"*

## 10. Thiết lập Thu nhập hàng tháng (SET_INCOME)
* **Loại lệnh:** `SET_INCOME`
* **Tham số:**
  - `value`: Số tiền thu nhập
* **Ví dụ câu lệnh:**
  - *"Thu nhập hàng tháng của mình là 10 triệu"*
  - *"Cài đặt lương tháng này 15 củ"*

## 11. Chỉnh sửa Giao dịch Gần nhất (UPDATE_RECORD)
* **Loại lệnh:** `UPDATE_RECORD`
* **Tham số:**
  - `value`: Số tiền mới
  - `categoryCode`: Danh mục mới
  - `note`: Ghi chú mới
* **Ví dụ câu lệnh:**
  - *"Sửa số tiền giao dịch vừa rồi thành 50k"*
  - *"Đổi danh mục giao dịch cuối sang Ăn uống"*

## 12. Cài đặt Cảnh báo Hạn mức (SET_ALERT)
* **Loại lệnh:** `SET_ALERT`
* **Tham số:**
  - `categoryCode`: Danh mục muốn bật/tắt cảnh báo
  - `enabled`: Trạng thái bật/tắt (true/false)
* **Ví dụ câu lệnh:**
  - *"Bật cảnh báo vượt hạn mức cho ăn uống"*
  - *"Tắt thông báo chi tiêu"*
