# Phân Tích Hiện Trạng & Kế Hoạch Cải Tiến 3 Chức Năng Công Cụ Tiền Tệ (Tiết Kiệm - Thử Thách - Vay Mượn)

Tài liệu này tổng hợp **luồng hiện tại đã triển khai (DB, Backend, Frontend)** và **chi tiết các điểm cần cải tiến** để đạt đúng nghiệp vụ yêu cầu cho 3 chức năng thuộc Công cụ tiền tệ trong ứng dụng Spending Diary.

---

## I. HIỆN TRẠNG TRIỂN KHAI (FULL-STACK FLOW)

### 1. Tiết kiệm (Savings) & Thử thách (Challenge) hiện tại
* **Database ([002_extend_csdl.sql](file:///d:/Luan-Van/Project/app/backend/src/db/migrations/002_extend_csdl.sql), [020_financial_tools.sql](file:///d:/Luan-Van/Project/app/backend/src/db/migrations/020_financial_tools.sql), [021_goal_members_and_invite.sql](file:///d:/Luan-Van/Project/app/backend/src/db/migrations/021_goal_members_and_invite.sql)):**
  - Bảng `goals`: Chứa các cột `name`, `target_amount`, `current_amount`, `deadline`, `type` (`'personal'` hoặc `'challenge'`), `invite_code`.
  - Bảng `goal_contributions`: Chứa lịch sử đóng góp (`goal_id`, `user_id`, `amount`, `created_at`).
  - Bảng `goal_members`: Chứa danh sách thành viên (`goal_id`, `user_id`, `role`).
* **Backend ([goals.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/goals/goals.service.js)):**
  - Hàm `list(userId, type)` lọc theo `type = 'challenge'` hoặc `type != 'challenge'`.
  - Hàm `create`: Nếu `type === 'challenge'` mới tự động sinh `invite_code`.
  - Hàm `contribute(userId, goalId, amount)`: Luôn cộng `amount` vào **`goals.current_amount` (quỹ chung)**, bất kể là Tiết kiệm hay Thử thách.
  - Hàm `getById`: Trả về `contributions` và `topContributors` (chỉ LIMIT 3 theo `SUM(amount)`).
* **Frontend ([goal_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/goals/goal_screen.dart), [goal_detail_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/goals/goal_detail_screen.dart)):**
  - Màn hình `GoalScreen` dùng cờ `isChallenge` để hiển thị 2 tab riêng: "Tiết kiệm" và "Thử thách".
  - Chỉ khi `isChallenge == true` mới hiện nút **Mời tham gia (`onInvite`)**.
  - Màn hình chi tiết `GoalDetailScreen` hiển thị tiêu đề chung chung `"Chi tiết mục tiêu"`, hiển thị `topContributors` dưới dạng top 3 đóng góp vào quỹ chung.

### 2. Vay mượn (Loans) hiện tại
* **Database ([020_financial_tools.sql](file:///d:/Luan-Van/Project/app/backend/src/db/migrations/020_financial_tools.sql)):**
  - Bảng `loans`: Lưu `user_id`, `wallet_id`, `contact_name`, `type` (`'lend'` | `'borrow'`), `amount`, `paid_amount`, `due_date`, `status`, `note`, `interest_rate`.
* **Backend ([loans.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/loans/loans.service.js), [loanReminder.cron.js](file:///d:/Luan-Van/Project/app/backend/src/cron/loanReminder.cron.js)):**
  - CRUD cơ bản cho khoản vay/mượn.
  - Có tùy chọn tự động tạo transaction (`create_transaction = true`) khi tạo khoản vay.
  - Cronjob `initLoanReminderCron` chạy lúc **08:00 sáng mỗi ngày**, query các khoản vay có `due_date = CURRENT_DATE` và bắn push notification qua FCM.
* **Frontend ([loans_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/financial_tools/loans_screen.dart), [loan_form_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/financial_tools/loan_form_screen.dart)):**
  - Danh sách khoản vay/mượn, form tạo khoản vay mới (chọn `due_date`, loại `lend`/`borrow`, tạo giao dịch).

---

## II. PHÂN TÍCH NHỮNG ĐIỂM CẦN CẢI TIẾN (GAP ANALYSIS)

### 1. TIẾT KIỆM (Cá nhân & Tập thể)
**Yêu cầu mong muốn:** *Có cá nhân và tập thể (tập thể có thể rủ thêm người tham gia) có đóng góp, xếp hạng đóng góp.*

#### Điểm cần cải tiến:
1. **Kiến trúc dữ liệu (`type` & `invite_code`):**
   - Hiện tại `type` chỉ phân biệt `'personal'` và `'challenge'`. Cần chuẩn hoá `type` thành:
     + `'saving_personal'`: Tiết kiệm cá nhân (1 người).
     + `'saving_group'`: Tiết kiệm tập thể (có mã mời, rủ thêm người cùng góp chung vào 1 quỹ).
     + `'challenge'`: Thử thách (tiến độ riêng từng người).
   - Cho phép **Tiết kiệm tập thể (`saving_group`)** cũng sinh `invite_code` và mời người tham gia qua QR/mã mời giống như Thử thách.
2. **Logic tính toán & Xếp hạng đóng góp (Leaderboard Quỹ Chung):**
   - Với `saving_group`: Quỹ chung `current_amount = SUM(tất cả contributions)`.
   - Cần bổ sung vào API `GET /api/v1/goals/:id`:
     + Trả về **Bảng xếp hạng đóng góp đầy đủ (`contributorLeaderboard`)** của tất cả thành viên trong nhóm kèm:
       - Số tiền đóng góp (`totalContributed`).
       - Tỷ lệ % đóng góp trên tổng quỹ (`percentage = totalContributed / targetAmount * 100`).
       - Xếp hạng thứ tự 1, 2, 3...
3. **Frontend (`GoalScreen` & `GoalDetailScreen`):**
   - Ở tab Tiết kiệm: Cho phép chọn tạo **Tiết kiệm cá nhân** hoặc **Tiết kiệm tập thể (nhóm)**.
   - Nếu là Tiết kiệm tập thể: Hiển thị nút **Mời thành viên** và hiển thị rõ **Xếp hạng đóng góp của nhóm** tại màn hình chi tiết.
   - Đổi tiêu đề màn hình chi tiết thành **"Chi tiết mục tiết kiệm"** (thay vì "Chi tiết mục tiêu" chung chung).

---

### 2. THỬ THÁCH (Challenge)
**Yêu cầu mong muốn:** *Có thể rủ nhiều người tham gia, cùng 1 thử thách nhưng có tiến độ riêng, xếp hạng tiến độ hoàn thành thử thách.*

#### Điểm cần cải tiến:
1. **Tách biệt cốt lõi: Đóng góp riêng thay vì Quỹ chung!**
   - Hiện tại `contribute()` đang cộng gộp tiền của mọi thành viên vào `goals.current_amount` -> Sai bản chất thử thách (biến thử thách thành hũ chung).
   - **Cải tiến DB (`goal_members`):**
     Bổ sung các cột theo dõi tiến độ cá nhân cho từng thành viên:
     ```sql
     ALTER TABLE goal_members 
       ADD COLUMN IF NOT EXISTS current_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
       ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'active', -- active | completed
       ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
     ```
2. **Cải tiến logic hàm `contribute()` trong `goals.service.js`:**
   - Khi `type === 'challenge'`:
     + Tiền đóng góp (`amount`) được cộng vào **tiến độ riêng của user đó (`goal_members.current_amount`)** (hoặc `SUM(amount)` từ `goal_contributions WHERE goal_id = $1 AND user_id = $2`).
     + Không cộng dồn sang của người khác.
     + Khi `user.current_amount >= target_amount` -> Cập nhật `status = 'completed'` và `completed_at = NOW()` cho thành viên đó.
3. **API & Bảng xếp hạng tiến độ Thử thách (`progressLeaderboard`):**
   - Trả về danh sách thành viên được sắp xếp theo:
     1. **Tỷ lệ % hoàn thành mục tiêu cá nhân (`current_amount / target_amount DESC`)**.
     2. **Thời gian hoàn thành sớm nhất (`completed_at ASC`)** nếu cùng đạt 100%.
   - Trả về thông tin `myProgress` (Tiến độ riêng của chính user đang gọi API).
4. **Frontend (`GoalDetailScreen` cho Challenge):**
   - Đổi tiêu đề màn hình thành **"Chi tiết thử thách"**.
   - Hiển thị widget **Tiến độ của tôi (My Progress)** riêng biệt so với mục tiêu đề bài.
   - Hiển thị **Bảng xếp hạng tiến độ thử thách** (hiện ai đạt bao nhiêu %, ai đã hoàn thành sớm nhất).

---

### 3. VAY MƯỢN (Loans)
**Yêu cầu mong muốn:** *Tạo nhắc hẹn vay / mượn.*

#### Điểm cần cải tiến:
1. **Cải tiến Database (`loans`):**
   - Hiện tại chỉ có `due_date`, chưa có cấu hình nhắc hẹn tùy chỉnh trước hạn chót.
   - Thêm các cột cho phép lập lịch nhắc hẹn:
     ```sql
     ALTER TABLE loans 
       ADD COLUMN IF NOT EXISTS reminder_date TIMESTAMPTZ, -- Ngày giờ cụ thể muốn nhắc
       ADD COLUMN IF NOT EXISTS reminder_days_before INT DEFAULT 0, -- Nhắc trước X ngày (0 = đúng ngày)
       ADD COLUMN IF NOT EXISTS is_reminded BOOLEAN NOT NULL DEFAULT FALSE;
     ```
2. **Cải tiến Backend & Cronjob (`loanReminder.cron.js`):**
   - Khi tạo/sửa khoản vay (`POST /loans`, `PATCH /loans/:id`), cho phép truyền `reminderDate` hoặc `reminderDaysBefore`.
   - Nâng cấp Cronjob:
     + Thay vì chỉ kiểm tra đúng `due_date = CURRENT_DATE`, query cả các khoản vay có `reminder_date <= NOW()` và `is_reminded = false`.
     + Gửi thông báo nhắc qua FCM & Notification log:
       - Vay (`borrow`): `"⏰ Nhắc hẹn trả nợ: Bạn có khoản vay [amount] đ từ [contact_name] cần thanh toán vào [due_date]."`
       - Cho vay (`lend`): `"⏰ Nhắc hẹn thu nợ: Khoản cho vay [amount] đ với [contact_name] sẽ đến hạn vào [due_date]."`
     + Cập nhật `is_reminded = true` sau khi gửi thành công.
3. **Cải tiến Frontend (`LoanFormScreen` & `LoansScreen`):**
   - Thêm tùy chọn **"Bật nhắc hẹn"** khi tạo/chỉnh sửa khoản vay (chọn ngày nhắc hoặc nhắc trước 1 ngày, 3 ngày, 1 tuần).
   - Hiển thị badge/icon **"Có nhắc hẹn" (⏰)** trên thẻ khoản vay trong danh sách `LoansScreen`.

---

## III. TỔNG KẾT BẢNG ĐỐI CHIẾU CẢI TIẾN

| Chức năng | Hiện trạng đang triển khai | Điểm cải tiến cần thực hiện |
| :--- | :--- | :--- |
| **1. Tiết kiệm** | Gộp chung `personal` và `challenge`. Chỉ `challenge` mới có `invite_code`. Chi tiết chỉ hiện Top 3 đóng góp. | Tách `saving_personal` và `saving_group`. Cho phép `saving_group` có `invite_code` mời người tham gia, tính **xếp hạng đóng góp toàn nhóm (%)**. Tiêu đề: *"Chi tiết mục tiết kiệm"*. |
| **2. Thử thách** | Đang cộng dồn tiền của mọi người vào 1 quỹ chung `current_amount`. | Tách **Tiến độ riêng** từng người (`goal_members.current_amount`). Xếp hạng theo **% hoàn thành cá nhân** & **thời gian đạt mục tiêu**. Tiêu đề: *"Chi tiết thử thách"*. |
| **3. Vay mượn** | Chỉ nhắc cố định vào đúng 8h sáng ngày `due_date`. | Thêm cấu hình **Nhắc hẹn tùy chỉnh (`reminder_date` / trước X ngày)**, bắn thông báo nhắc trả nợ/thu nợ tự động. |

---

## IV. CẢI TIẾN NLU PROMPT & LUỒNG AI CHAT
Xem tài liệu hướng dẫn chi tiết tại: [nlu_prompt_cong_cu_tien_te.md](file:///d:/Luan-Van/Project/docs/nlu_prompt_cong_cu_tien_te.md)
- **NLU Slots mở rộng:** Thêm `tool_type` (`saving_personal`, `saving_group`, `challenge`, `loan`), `loan_type`, `contact_name`, `due_date`.
- **Backend `action.service.js` (`executeSetGoal`):** Phân chia nhánh tạo mục tiêu / tạo nhắc hẹn vay mượn và trả về thông báo riêng biệt theo từng loại.
- **Frontend Chat (`chat_screen.dart`):** Cập nhật thẻ xác nhận trước khi thực hiện (`_ActionPreview`) và lưu kết quả lời nhắn của Mimo vào lịch sử chat.
