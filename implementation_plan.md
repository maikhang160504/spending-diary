# Smart Budgeting Recommendation — Kế hoạch triển khai

## Phân tích câu hỏi của bạn

### Q1: Phương án thiết kế đã giải quyết trọn vẹn bài toán tối ưu thao tác chưa?

**Đã giải quyết 90% — nhưng cần bổ sung 3 điểm quan trọng:**

| Kịch bản | Tài liệu hiện tại | Cần bổ sung |
|---|---|---|
| User mới (< 1 tháng dữ liệu) | ❌ Chưa đề cập | Fallback dùng **peer benchmark** (`group_spending_benchmarks`) thay vì tính Moving Average |
| User từ chối gợi ý | ❌ Chưa rõ luồng | Nếu bấm "Để mình tự chỉnh lại" → mở form pre-filled số AI đã tính, user chỉ chỉnh sửa thay vì điền từ đầu |
| User bỏ lỡ ngày mùng 1 | ❌ Chưa xử lý | Suggestion vẫn hiển thị nếu user chưa có budget active cho tháng hiện tại, không chỉ show đúng ngày 1 |

### Q2: Bổ sung quy tắc xử lý tháng lễ lớn — CÓ, rất cần thiết

Nếu không xử lý tính mùa vụ, thuật toán sẽ gợi ý sai nghiêm trọng trong 2 kịch bản:

| Kịch bản sai | Ví dụ | Lỗi thuật toán |
|---|---|---|
| **Tháng sau Tết** (tháng 3) | Moving Avg 3 tháng = T12 + T1 + T2 → bao gồm Tết → gợi ý quá cao | Hạn mức bị inflated ~40-60% |
| **Tháng Tết** (tháng 2) | Moving Avg 3 tháng = T11 + T12 + T1 → toàn tháng thường → gợi ý quá thấp | Hạn mức quá khắt khe, user bực bội |

**Giải pháp: Seasonal Adjustment Factor (H)**

```
Hạn mức gợi ý = B × I × (1 - S) × H
```

Trong đó `H` (Holiday Factor) là hệ số mùa vụ:

| Tháng đích (tháng tiếp theo) | H | Lý do |
|---|---|---|
| Tháng 1 (trước Tết) | 1.20 | Mua sắm Tết bắt đầu |
| Tháng 2 (Tết Nguyên Đán) | 1.50 | Quà cáp, du lịch, lì xì, ăn uống |
| Tháng 3 (sau Tết) | 0.85 | Thắt lưng buộc bụng sau Tết |
| Tháng 9 (khai giảng) | 1.15 | Sinh viên: học phí, sách vở, đồ dùng |
| Tháng 12 (Giáng sinh + Tết Dương) | 1.25 | Quà tặng, tiệc, du lịch |
| Các tháng còn lại | 1.00 | Không điều chỉnh |

> [!IMPORTANT]
> Bộ lọc Denoising (Bước 1) cũng cần nhận biết tháng lễ: Trong tháng Tết, **không** flag các khoản Shopping/Social cao bất thường vì chúng là chi tiêu hợp lệ theo mùa.

---

## Proposed Changes

### Database Migration

#### [NEW] [011_budget_suggestions.sql](file:///d:/Luan-Van/Project/app/backend/src/db/migrations/011_budget_suggestions.sql)

Bảng lưu kết quả tính toán batch job — API chỉ cần SELECT tĩnh:

```sql
CREATE TABLE IF NOT EXISTS user_budget_suggestions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_month VARCHAR(7) NOT NULL,          -- '2026-07'
    category_code VARCHAR(50) NOT NULL,
    suggested_amount DECIMAL(15,2) NOT NULL,
    base_spending DECIMAL(15,2),               -- B value
    income_factor DECIMAL(5,3) DEFAULT 1.000,  -- I value
    saving_rate DECIMAL(5,3) DEFAULT 0.000,    -- S value
    holiday_factor DECIMAL(5,3) DEFAULT 1.000, -- H value
    reason TEXT,                                -- Giải thích cho user
    status VARCHAR(20) DEFAULT 'pending',      -- pending | applied | dismissed
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, target_month, category_code)
);
```

---

### Backend — Suggestion Service

#### [NEW] [suggestion.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/budgets/suggestion.service.js)

Service chứa toàn bộ logic tính toán gợi ý, bao gồm:

**1. `computeSuggestionsForUser(userId, targetMonth)`** — Core algorithm:
- Lấy lịch sử giao dịch 3 tháng gần nhất theo `category_code`
- **Denoising**: Loại bỏ giao dịch outlier (> 3σ) + whitelist category mùa lễ
- **Base Spending (B)**: Weighted Moving Average (tháng gần nhất × 0.5, tháng trước × 0.3, tháng trước nữa × 0.2)
- **Income Factor (I)**: So sánh thu nhập 3 tháng, nếu giảm → `I = avg_recent_income / avg_older_income` (capped 0.7-1.0)
- **Saving Rate (S)**: 0.05-0.10 cho danh mục "lãng phí" (Entertainment, Shopping, Social, Beauty), 0.00 cho danh mục thiết yếu (Food, Housing, Transport, Essentials)
- **Holiday Factor (H)**: Tra bảng hệ số mùa vụ theo `targetMonth`
- **Fallback cho user mới**: Nếu < 1 tháng dữ liệu → dùng `group_spending_benchmarks` theo `age_group` + `job_type`

**2. `generateBatchSuggestions()`** — Batch job cho tất cả users:
- Quét toàn bộ active users
- Gọi `computeSuggestionsForUser()` cho từng user
- Upsert vào `user_budget_suggestions`

**3. `getSuggestions(userId, targetMonth)`** — API read:
- SELECT từ bảng `user_budget_suggestions`
- Format thành payload gồm danh sách category + số tiền + lý do

**4. `applySuggestions(userId, targetMonth, overrides?)`** — 1-Click Apply:
- Đọc suggestions → tạo/update budgets qua `budgetsService.create()`
- Cập nhật `status = 'applied'`
- Trả message xác nhận kiểu MiMo

**5. `dismissSuggestion(userId, targetMonth)`** — Từ chối:
- Cập nhật `status = 'dismissed'`

---

### Backend — API Routes

#### [MODIFY] [budgets.routes.js](file:///d:/Luan-Van/Project/app/backend/src/modules/budgets/budgets.routes.js)

Thêm 3 endpoints:
- `GET /api/v1/budgets/suggestions?month=2026-07` — lấy gợi ý tháng
- `POST /api/v1/budgets/suggestions/apply` — áp dụng 1-Click
- `POST /api/v1/budgets/suggestions/dismiss` — từ chối

---

### Backend — AI Action Integration

#### [MODIFY] [action.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/ai/action.service.js)

- Thêm handler cho action type `SUGGEST_BUDGET` trong `executeAction()`
- Thêm function `executeSuggestBudget(userId, payload)`:
  - Gọi `suggestionService.getSuggestions()`
  - Format thành Vietnamese emotional story kiểu MiMo
  - Trả `kind: 'budget_suggestion'` với danh sách categories + `apply_action`

---

### Backend — Unit Tests

#### [MODIFY] [action.service.test.js](file:///d:/Luan-Van/Project/app/backend/tests/unit/action.service.test.js)

Thêm test cases:
- Holiday factor lookup cho các tháng Tết (1, 2), sau Tết (3), Giáng sinh (12)
- Denoising filter loại bỏ outlier > 3σ
- Fallback peer benchmark cho user mới
- `buildReportStory` cho `kind: 'budget_suggestion'`

#### [NEW] [suggestion.service.test.js](file:///d:/Luan-Van/Project/app/backend/tests/unit/suggestion.service.test.js)

Unit tests cho core logic:
- `computeSuggestionsForUser` with mock transaction data
- Weighted Moving Average calculation
- Income factor capping
- Holiday adjustment
- Edge case: user với 0 giao dịch → fallback peer benchmark

---

## Open Questions

> [!IMPORTANT]
> **1. Batch Job Scheduling**: Tài liệu đề cập chạy batch job lúc 12h00 đêm ngày cuối tháng. Trong giai đoạn MVP, bạn muốn:
> - **(A)** Dùng API endpoint thủ công để trigger (admin hoặc cron bên ngoài gọi)?
> - **(B)** Implement cron job trực tiếp trong Node.js server (dùng `node-cron`)?
>
> **2. UI/UX Morning Story**: Frontend mobile hiện có sẵn cơ chế hiển thị "Morning Story" / proactive notification không, hay cần xây mới? Trong plan này tôi sẽ triển khai phần backend API trước, frontend sẽ consume API này.

---

## Verification Plan

### Automated Tests
- `npm test` trong `d:\Luan-Van\Project\app\backend` — tất cả tests phải pass (bao gồm cả tests mới)

### Manual Verification
- Seed user có 3+ tháng giao dịch → gọi API suggestion → verify số liệu hợp lý
- Test edge case tháng Tết (tháng 2) → verify holiday factor = 1.50
- Test user mới (0 tháng) → verify fallback dùng peer benchmark
