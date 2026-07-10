# Hướng Dẫn Prompt, NLU & Luồng Chat Cho Công Cụ Tiền Tệ (Tiết Kiệm - Thử Thách - Vay Mượn)

Tài liệu này mô tả chi tiết logic NLU mới, các thuộc tính (slots) mở rộng trong Prompt và luồng hiển thị thành công trong AI Chat cho 3 Công cụ tiền tệ của Spending Diary.

---

## I. Cấu Trúc Slot Mở Rộng Cho Công Cụ Tiền Tệ (`SET_GOAL` / `ADD_GOAL`)

Trong kiến trúc NLU hợp nhất (`expense-ocr-nlu`), khi người dùng đưa ra câu lệnh liên quan đến tài chính (`intent = "Action"` với `action_type = "SET_GOAL"` hoặc `"ADD_GOAL"`), LLM sẽ trích xuất các thuộc tính phân biệt vào `slots`:

```json
{
  "intent": "Action",
  "action_type": "SET_GOAL",
  "slots": {
    "goal_name": "Tên mục tiêu / Nội dung nhắc hẹn vay mượn",
    "amount": 5000000,
    "tool_type": "saving_personal | saving_group | challenge | loan",
    "loan_type": "lend | borrow",
    "contact_name": "Tên người vay / cho vay (nếu tool_type=loan)",
    "due_date": "2026-08-15"
  }
}
```

### Phân loại `tool_type`:
1. **`saving_personal` (Tiết kiệm cá nhân):**
   - Người dùng tạo mục tiêu tích lũy riêng cho bản thân.
   - *Ví dụ:* `"Tạo mục tiêu tiết kiệm 10 triệu mua laptop"` -> `tool_type = "saving_personal"`.
2. **`saving_group` (Tiết kiệm tập thể / Quỹ nhóm):**
   - Người dùng rủ thêm bạn bè hoặc gia đình cùng góp chung vào 1 quỹ tiết kiệm.
   - *Ví dụ:* `"Tạo quỹ nhóm tiết kiệm 50 triệu đi du lịch Đà Lạt"` -> `tool_type = "saving_group"`.
3. **`challenge` (Thử thách tiết kiệm):**
   - Các thành viên cùng tham gia một thử thách với tiến độ riêng từng người để đua hạng.
   - *Ví dụ:* `"Tạo thử thách tiết kiệm 3 triệu trong tháng 8"` -> `tool_type = "challenge"`.
4. **`loan` (Vay mượn / Nhắc hẹn):**
   - Người dùng tạo nhắc hẹn cho vay hoặc đi vay.
   - *Ví dụ:* `"Tạo nhắc hẹn cho Minh vay 2 triệu hạn 15/08"` -> `tool_type = "loan"`, `loan_type = "lend"`, `contact_name = "Minh"`, `due_date = "2026-08-15"`.

---

## II. Luồng Xử Lý Tại Backend (`action.service.js`)

Khi người dùng nhấn **Xác nhận** trên thẻ hành động trong Chat, Backend nhận payload và định tuyến tới `executeSetGoal`:

### 1. Phân nhánh Vay mượn (`tool_type === 'loan'`):
- Backend gọi `loansService.create(userId, { contact_name, type: loan_type, amount, due_date, reminder_date, note })`.
- Trả về `kind: 'loan'` với lời nhắn Mimo xác nhận lịch nhắc hẹn.

### 2. Phân nhánh Tiết kiệm & Thử thách (`saving_personal` / `saving_group` / `challenge`):
- Nếu người dùng nộp tiền vào mục tiêu có sẵn (`contribute`):
  - Phản hồi tiến độ theo loại (`% hoàn thành` của cá nhân hoặc quỹ nhóm).
- Nếu tạo mục tiêu mới (`create`):
  - Với `saving_group`: Tạo mục tiêu kèm mã mời tham gia (`invite_code`), thông báo lời mời rủ thành viên cùng đóng góp.
  - Với `challenge`: Tạo thử thách kèm mã mời (`invite_code`), lời mời đua tiến độ riêng.
  - Với `saving_personal`: Tạo mục tiêu cá nhân chuẩn.

---

## III. Hiển Thị Thành Công Tại Chat Mobile (`chat_screen.dart`)

1. **Thẻ xác nhận trước khi thực hiện (`_ActionPreview`):**
   - Tiêu đề thẻ tự động thay đổi theo `toolType`:
     - `"Tạo thử thách tiết kiệm: 5.000.000 đ"`
     - `"Tạo nhóm tiết kiệm: 50.000.000 đ"`
     - `"Tạo nhắc hẹn vay mượn: 2.000.000 đ"`
     - `"Đặt mục tiêu: 10.000.000 đ"`

2. **Tin nhắn phản hồi của Mimo sau khi thực hiện thành công (`message`):**
   - Tin nhắn kết quả được lưu vĩnh viễn trong phiên chat (`_persistActionResultMessage`).
   - Mimo hiển thị thông báo với giọng điệu Gen Z khích lệ và hiển thị mã mời `[invite_code]` nếu là Nhóm / Thử thách.
