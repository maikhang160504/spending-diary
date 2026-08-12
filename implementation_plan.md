# Kế hoạch sửa lỗi [code] — Spending Diary

Tài liệu này mô tả chi tiết kế hoạch sửa toàn bộ các mục đánh dấu `[code]` trong [fix.md](file:///d:/Luan-Van/Project/fix.md). Phần test và kịch bản demo được xử lý riêng.

---

## Tổng quan các lỗi cần sửa

| # | Mô tả lỗi | Layer | File chính |
|---|-----------|-------|-----------|
| 1 | Chi tiết giao dịch bị sai — dưới tiền phải là text người dùng | Flutter (UI) | `home_screen.dart` |
| 2 | Thêm người dùng mới ở chia bill (chủ nhóm) | Flutter + Backend | `group_detail_screen.dart`, `expense_groups` module |
| 3 | Giới hạn response ≤ 25 từ | Python (NLU) | `llm_prompts.py` |
| 4 | Nút phân tích AI bị bấm nhiều lần (camera) | Flutter (UI) | `camera_screen.dart` |
| 5 | Gợi ý chi tiêu dùng bản mẫu khi không có dữ liệu | Backend (JS) | `ai.service.js` |
| 6 | Sai emotion ở action stage 2 | Python (NLU) | `llm_prompts.py`, `action_slots.py` |
| 7 | Sửa quy tắc ngưỡng (10k record / 1k ảnh) ở dashboard | Web Admin (JSX) | `DashboardPage.jsx`, backend API |
| 8 | Không hiển thị dữ liệu ở "Test Prompt" web admin | Web Admin (JSX) | `BotPromptsPage.jsx` |
| 9 | Chuyển hướng khi nhấn thông báo chưa đúng trang | Flutter (service) | `app_shell.dart`, FCM deep link |

---

## Phân tích chi tiết & Hướng xử lý

---

### Bug 1 — Chi tiết giao dịch bị sai (dưới tiền phải là text người dùng)

**Vị trí:** [home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart) (logic hiển thị card giao dịch)

**Phân tích:** Mỗi giao dịch có 2 trường văn bản: `note` (do AI sinh ra) và `original_text` (câu gốc người dùng gõ). Hiện tại dòng caption dưới số tiền đang ưu tiên `note` thay vì `original_text`. Dòng ở line 932:

```dart
final caption = originalText.isNotEmpty ? originalText : note;
```

Logic này **đúng**, nhưng cần xác minh trường `originalText` được lấy từ field nào của API response và đảm bảo nó được binding đúng.

**Hướng sửa:**
- Tìm chính xác vị trí render caption của transaction card trong `home_screen.dart`.
- Đảm bảo `original_text` (hoặc field tương đương từ backend) được hiển thị làm subtitle — không phải AI-generated `note`.
- Nếu backend chưa trả `original_text` trong list API, thêm field vào query SQL ở `transactions.service.js`.

#### [MODIFY] [home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart)
#### [MODIFY] [transactions.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/transactions/transactions.service.js)

---

### Bug 2 — Thêm người dùng mới ở chia bill (chủ nhóm)

**Vị trí:** [group_detail_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/financial_tools/group_detail_screen.dart) (line ~406, 711, 729)

**Phân tích:** Chức năng thêm thành viên mới (invite) vào ví nhóm chia bill hiện đã có `addMember` widget, nhưng chỉ chủ nhóm mới được phép thêm. Cần kiểm tra:
1. Điều kiện `isOwner` trước khi hiển thị nút thêm thành viên.
2. API endpoint `addMember` trong backend có kiểm tra quyền chủ nhóm hay không.

**Hướng sửa:**
- Trong `group_detail_screen.dart`: kiểm tra field `role == 'owner'` (hoặc `is_owner`) từ dữ liệu API trước khi render nút "Thêm thành viên".
- Trong backend module `expense_groups`: bổ sung middleware guard kiểm tra `user_id` phải là `owner_id` của group trước khi cho phép `POST /groups/:id/members`.

#### [MODIFY] [group_detail_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/financial_tools/group_detail_screen.dart)
#### [MODIFY] expense_groups route/controller (backend)

---

### Bug 3 — Giới hạn response ≤ 25 từ

**Vị trí:** [llm_prompts.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/prompts/llm_prompts.py) — `UNIFIED_NLU_PROMPT` và `ACTION_SLOT_EXTRACTION_PROMPT`

**Phân tích:** Hiện prompt yêu cầu "Chỉ viết tối đa 2-3 câu ngắn gọn" (line 82) nhưng không có ràng buộc số từ cụ thể. Hệ thống sinh ra phản hồi quá dài (ví dụ ở fix.md: response dài 2 câu phức tạp).

**Hướng sửa:**
- Thêm vào `UNIFIED_NLU_PROMPT` rule: `- TUYỆT ĐỐI KHÔNG viết response quá 25 từ tiếng Việt. Đếm từ và cắt ngắn nếu cần.`
- Thêm post-processing truncation ở `llm_intent_handler.py`: sau khi parse JSON, kiểm tra `len(response.split()) > 25` → cắt ở từ thứ 25 và thêm "..." nếu cần.

#### [MODIFY] [llm_prompts.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/prompts/llm_prompts.py)
#### [MODIFY] [llm_intent_handler.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/nlu/llm_intent_handler.py)

---

### Bug 4 — Nút phân tích AI bị bấm nhiều lần (camera)

**Vị trí:** [camera_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/camera/camera_screen.dart) — nút chụp ảnh và phân tích bill

**Phân tích:** File có biến `_isTakingPhoto = false` (line 42) nhưng không được toggle trước khi chuyển màn hình. Sau khi gọi API và navigate về home, có độ trễ từ việc dispose controller. Trong thời gian delay đó, người dùng vẫn bấm được nút thêm lần nữa → tạo thêm 1 giao dịch.

**Hướng sửa:**
- Set `_isTakingPhoto = true` ngay khi bắt đầu xử lý.
- Kiểm tra `if (_isTakingPhoto) return;` ở đầu hàm xử lý chụp ảnh/phân tích.
- Vô hiệu hóa hoặc thay đổi style nút khi `_isTakingPhoto == true`.
- **Áp dụng tương tự** cho `camera_input_screen.dart` nút "Phân tích ✨" (hiện đã có `_isLoading` nhưng button dùng `ListenableBuilder` — cần đảm bảo state được rebuild đúng).

#### [MODIFY] [camera_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/camera/camera_screen.dart)

---

### Bug 5 — Gợi ý chi tiêu dùng bản mẫu khi không có dữ liệu

**Vị trí:** [ai.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/ai/ai.service.js) — logic `SUGGEST_BUDGET` action

**Phân tích:** Khi người dùng mới đăng ký chưa có giao dịch, hệ thống gọi `SUGGEST_BUDGET` nhưng không có dữ liệu chi tiêu thực tế → query trả về rỗng → AI nhận context trống → response vô nghĩa hoặc lỗi.

**Hướng sửa:**
- Trong handler của `SUGGEST_BUDGET` action trong `action.service.js`: Kiểm tra nếu `transactions.length === 0` (hoặc tổng chi tiêu = 0), trả về **template ngân sách mẫu** (sample budget) thay vì gọi AI phân tích.
- Template mẫu: phân bổ theo tỉ lệ tiêu chuẩn (50% Ăn uống + đi lại, 20% Mua sắm, 10% Giải trí, 10% Sức khỏe, 10% Tiết kiệm) dựa trên income của user hoặc mức trung bình mặc định 5,000,000đ/tháng.
- Thêm flag `is_template: true` trong response để frontend hiển thị thông báo "Đây là gợi ý mẫu — chưa có đủ dữ liệu chi tiêu của bạn".

#### [MODIFY] [action.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/ai/action.service.js)

---

### Bug 6 — Sai emotion ở action stage 2

**Vị trí:** [llm_prompts.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/prompts/llm_prompts.py) — `ACTION_SLOT_EXTRACTION_PROMPT`

**Phân tích:** Stage 1 (intent classification) không sinh emotion. Stage 2 (action slot extraction) có trường `action_type` nhưng không có trường `emotion` trong JSON schema của `ACTION_SLOT_EXTRACTION_PROMPT` (line 117-161). Khi backend nhận response từ stage 2, `pickMimoEmotionFromNlu()` tìm trong `nlu.gemini_json.emotion` nhưng field này không tồn tại → fallback về `Approved` cho mọi action, không phân biệt.

**Hướng sửa:**
- Bổ sung field `"mimo_emotion"` vào JSON schema của `ACTION_SLOT_EXTRACTION_PROMPT`.
- Thêm hướng dẫn mapping action_type → emotion phù hợp:
  - `SET_GOAL`, `ADD_GOAL` → `Proud` hoặc `Celebrate`
  - `SET_LIMIT` → `Determined`
  - `SET_TONE` → `Cool`
  - `SUGGEST_BUDGET` → `Thinking`
  - `REPORT_GENERAL`, `REPORT_COMPARE` → `Working`
  - `SEARCH_RECORD` → `Thinking`
  - `SET_ALERT` → `Alert`
  - `SYSTEM_SETTING` → `Chill`

#### [MODIFY] [llm_prompts.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/prompts/llm_prompts.py)

---

### Bug 7 — Sửa quy tắc ngưỡng (10k record / 1k ảnh) ở dashboard

**Vị trí:** [DashboardPage.jsx](file:///d:/Luan-Van/Project/app/frontend/web-admin/src/pages/DashboardPage.jsx) + backend API `getRetrainReadiness`

**Phân tích:** Dashboard hiện hiển thị ngưỡng kích hoạt retrain dựa theo số "sửa lỗi từ người dùng" và "hóa đơn được duyệt". Theo yêu cầu mới: ngưỡng phải là **CSDL có 10,000 record** và **đã quét được 1,000 ảnh hóa đơn**.

**Hướng sửa:**
- Backend (`admin` routes hoặc `stats.service.js`): Cập nhật `getRetrainReadiness()` để trả về:
  - `nlu.current` = tổng số giao dịch trong CSDL
  - `nlu.threshold` = 10000
  - `ocr.current` = tổng số ảnh hóa đơn đã quét (approved + pending)
  - `ocr.threshold` = 1000
- Frontend: Cập nhật text giải thích ở line 969: `"Ngưỡng kích hoạt: NLU ≥ 10,000 giao dịch · OCR ≥ 1,000 ảnh hóa đơn đã quét"`.

#### [MODIFY] [DashboardPage.jsx](file:///d:/Luan-Van/Project/app/frontend/web-admin/src/pages/DashboardPage.jsx)
#### [MODIFY] backend admin/stats service (`getRetrainReadiness`)

---

### Bug 8 — Không hiển thị dữ liệu ở Test Prompt web admin

**Vị trí:** [BotPromptsPage.jsx](file:///d:/Luan-Van/Project/app/frontend/web-admin/src/pages/BotPromptsPage.jsx) — component hiển thị `testResult`

**Phân tích:** Từ log trong `fix.md`, backend trả kết quả debug bao gồm:
- Raw debug prompt text (không phải JSON)
- JSON `WARNING: Failed to parse LLM JSON response`

Điều này chứng tỏ `testSystemPrompt` API trả về **text debug thô** thay vì structured JSON `{ result: {...}, latency_ms: ... }`. Frontend tại line 600 render `testResult.result?.response` nhưng trường này null → không hiển thị gì.

**Hướng sửa 2 phía:**
1. **Backend** (`ai.controller.js` → `testSystemPrompt` handler): Đảm bảo response luôn trả về JSON có cấu trúc `{ success, result: { intent, response, ... }, latency_ms }`. Không để debug log lẫn vào response body.
2. **Frontend** (`BotPromptsPage.jsx`): Thêm fallback hiển thị toàn bộ `testResult` dạng `JSON.stringify` khi `testResult.result` không có `response` field, để debug được dù backend chưa chuẩn.

#### [MODIFY] [BotPromptsPage.jsx](file:///d:/Luan-Van/Project/app/frontend/web-admin/src/pages/BotPromptsPage.jsx)
#### [MODIFY] [ai.controller.js](file:///d:/Luan-Van/Project/app/backend/src/modules/ai/ai.controller.js)

---

### Bug 9 — Chuyển hướng khi nhấn thông báo chưa đúng trang

**Vị trí:** [app_shell.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/shell/app_shell.dart) — `onDeepLink` handler (line 93-101)

**Phân tích:** Hiện tại `onDeepLink` chỉ gọi `context.push(deepLink)` không phân loại. Một số deepLink có thể:
- Không khớp route đã đăng ký → exception im lặng
- Dẫn đến màn hình sai (ví dụ: thông báo "giao dịch mới" → push vào home thay vì transaction detail)

Backend (FCM templates trong `notification_templates.json`) gán `deepLink` như `/wallet/:id`, `/chat`, `/goals/:id`... nhưng router Go chưa xử lý một số pattern.

**Hướng sửa:**
- Xem lại `notification_templates.json` để biết toàn bộ `deepLink` patterns.
- Trong `app_shell.dart`: thêm switch/case mapping deepLink → route tương ứng, dùng `context.go()` thay vì `push` cho các route top-level.
- Thêm try-catch riêng và fallback về `/home` nếu route không tìm thấy.
- Kiểm tra `app_routes.dart` để đảm bảo mọi deepLink pattern đều có route được khai báo.

#### [MODIFY] [app_shell.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/shell/app_shell.dart)

---

## Thứ tự thực hiện (ưu tiên)

1. **Bug 4** — Camera double-tap (rủi ro cao nhất, tạo dữ liệu rác)
2. **Bug 8** — Test prompt web admin (ảnh hưởng workflow admin)
3. **Bug 3** — Giới hạn response (cải thiện chất lượng AI)
4. **Bug 6** — Sai emotion stage 2 (liên quan đến NLU)
5. **Bug 5** — Gợi ý mẫu khi chưa có dữ liệu (UX người dùng mới)
6. **Bug 1** — Chi tiết giao dịch hiển thị sai
7. **Bug 2** — Thêm member chia bill (check quyền)
8. **Bug 7** — Sửa ngưỡng dashboard
9. **Bug 9** — Điều hướng thông báo

---

## Kế hoạch xác minh

### Sau mỗi bug fix:
- Build Flutter (mobile) và reload để kiểm tra UI
- Chạy backend `npm run dev` kiểm tra API response
- Chạy Python NLU server kiểm tra prompt output

### Automated check:
- Không có unit test tự động (theo yêu cầu, test do người dùng tự thực hiện)

### Manual check (người dùng tự test):
- Bug 4: Bấm liên tục nút "Phân tích ✨" và nút chụp ảnh → chỉ tạo 1 giao dịch
- Bug 8: Nhập text trong BotPromptsPage → bấm "Test Live Prompt" → kết quả hiển thị rõ
- Bug 3: Chat "ăn sáng hết 45k" → phản hồi ≤ 25 từ
- Bug 5: Đăng nhập tài khoản mới → yêu cầu gợi ý chi tiêu → có hiển thị bản mẫu
