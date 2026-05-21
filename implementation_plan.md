# Master Implementation Plan — TEST_PLAN + NEXT_STEPS

Kế hoạch tổng thể thực hiện tất cả task từ [TEST_PLAN.md](file:///d:/Luan-Van/Project/app/TEST_PLAN.md) và [NEXT_STEPS.md](file:///d:/Luan-Van/Project/app/NEXT_STEPS.md).

> [!IMPORTANT]
> Đây là kế hoạch rất lớn, bao gồm **~100+ task** trải dài qua backend, AI service, Flutter mobile, database, và testing. Ước lượng tổng thời gian triển khai: **rất dài**. Cần xác nhận trước khi bắt đầu.

---

## User Review Required

> [!WARNING]
> **Các quyết định kiến trúc cần chốt** (từ NEXT_STEPS Section 6):
> 1. **Personal data trong `users` vs `user_profiles`?** — Plan giữ trong `users` (không JOIN thêm).
> 2. **Stories bắt buộc với mỗi transaction?** — Plan: optional (`story_item_id` NULL allowed).
> 3. **Personal vs Group wallet permission** — Plan thêm middleware check role trước edit budget/goal.
> 4. **USE_REAL_NLU production** — Plan giữ mock cho dev, không build image real trong scope này.

> [!IMPORTANT]
> **Docker phải đang chạy** để thực hiện TEST_PLAN (Task 0-11). Nếu Docker chưa chạy, các task test sẽ bị skip và chỉ làm code changes.

---

## Open Questions

1. **Docker đang chạy chưa?** — Cần `docker compose up -d` để chạy TEST_PLAN Task 0-11.
2. **Flutter SDK có sẵn trên máy?** — Cần để validate build Flutter sau khi sửa code.
3. **Có muốn skip phần camera plugin thật (CAM-01..CAM-07)?** — Cần `camera` plugin + thiết bị thật/emulator. Nếu chỉ cần code changes thì vẫn tạo được nhưng không test được.
4. **expense-ocr-nlu tasks (N1-N3) có trong scope?** — Đây là repo riêng, plan sẽ include nhưng tách phase cuối.

---

## Proposed Changes

Chia thành **8 Phase**, thực hiện tuần tự (dependencies đi trước).

---

### Phase 0 — Docker Test Plan (TEST_PLAN Task 0-11)

> Chạy smoke + integration test trên Docker containers đang chạy. Ghi kết quả pass/fail.

#### Task 0: Khởi tạo môi trường
- `docker compose ps` — verify 3 container
- `docker compose exec backend npm run migrate`
- `docker compose exec backend npm run seed`

#### Task 1: Health probes
- `GET http://localhost:4000/api/v1/health`
- `GET http://localhost:8000/health`

#### Task 2: Swagger UI
- Verify `http://localhost:4000/docs`, `/openapi.json`
- Verify `http://localhost:8000/docs`

#### Task 3: Auth flow (register → login → /me → refresh → logout)

#### Task 4: Categories + Wallets

#### Task 5: Transactions CRUD

#### Task 6: Budgets + Stats

#### Task 7: AI service direct (4 endpoints)

#### Task 8: AI qua Backend proxy (5 endpoints)

#### Task 9: Verify DB rows

#### Task 10: Negative/security tests (401, 422)

#### Task 11: Jest + Pytest suite

---

### Phase 1 — Asset & Bug Fixes (nhanh, không vỡ gì)

> **Ước lượng: ~30 phút.** Fix trước để build không lỗi.

#### [MODIFY] [pubspec.yaml](file:///d:/Luan-Van/Project/app/frontend/mobile/pubspec.yaml)
- **A-01**: Sửa `assets/Logo/` → `assets/logo/` (case-sensitive)
- **A-02**: Thêm `- assets/MiMo/background/`
- **A-03**: Thêm `- assets/category/` (nếu folder tồn tại)
- **A-05**: Thêm dependencies cần thiết: `intl`, `flutter_secure_storage`, `dio`, `shimmer`, `image_picker`

#### [MODIFY] [home_calendar_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_calendar_screen.dart)
- **B-01**: Fix `'0$_currentMonth'` → `padLeft(2,'0')`
- **B-02**: Fix `_currentMonth = 3` → `DateTime.now().month`

#### [MODIFY] [register_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/auth/register_screen.dart)
- **B-04**: Xoá `StatefulBuilder` lồng, dùng `setState` outer

#### [MODIFY] [chat_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/chat/chat_screen.dart)
- **B-05**: Xoá field `context` dư thừa trong `_ChatHeader`

#### [MODIFY] [camera_input_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/camera/camera_input_screen.dart)
- **B-08**: Fix `errorBuilder` trả `Icon` thay vì `SizedBox` rỗng

#### [MODIFY] [share_wallet_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/wallet/share_wallet_screen.dart)
- **B-03**: Fix avatar 👑 + chữ cái → `Stack` layout

---

### Phase 2 — Backend New Modules (B1-B5)

> **Ước lượng: ~2-3 giờ.** Tạo 4 module backend mới cần cho mobile.

#### [NEW] User Settings Module (B1)
- `src/modules/settings/settings.controller.js`
- `src/modules/settings/settings.service.js`
- `src/modules/settings/settings.routes.js`
- `src/modules/settings/settings.schema.js`
- Endpoints: `GET/PATCH /api/v1/users/me/settings`

#### [NEW] Goals Module (B2)
- `src/modules/goals/goals.controller.js`
- `src/modules/goals/goals.service.js`
- `src/modules/goals/goals.routes.js`
- `src/modules/goals/goals.schema.js`
- Endpoints: `GET/POST /api/v1/goals`, `GET/PATCH/DELETE /api/v1/goals/:id`, `POST /api/v1/goals/:id/contribute`

#### [NEW] Stories Module (B3)
- `src/modules/stories/stories.controller.js`
- `src/modules/stories/stories.service.js`
- `src/modules/stories/stories.routes.js`
- `src/modules/stories/stories.schema.js`
- Endpoints: `GET/POST /api/v1/stories`, `GET/PATCH /api/v1/stories/:id`

#### [NEW] Chat Module (B4)
- `src/modules/chat/chat.controller.js`
- `src/modules/chat/chat.service.js`
- `src/modules/chat/chat.routes.js`
- `src/modules/chat/chat.schema.js`
- Endpoints: `GET/POST /api/v1/chat/sessions`, `GET /api/v1/chat/sessions/:id/messages`, `POST /api/v1/chat/sessions/:id/messages`

#### [MODIFY] [index.js](file:///d:/Luan-Van/Project/app/backend/src/routes/index.js)
- Register 4 module routes mới

#### [MODIFY] AI Service (B5)
- Ghi vào `ai_processing_logs` khi gọi `from-bill`

---

### Phase 3 — Cross-Screen Widget Extraction (X-01..X-12)

> **Ước lượng: ~2-3 giờ.** Extract widgets chung, giảm ~40% LOC. Không đổi UI.

#### [NEW] `widgets/home_header.dart` (X-01, X-04)
- Extract `_HeaderSection` (gradient + date + streak + wallet chips + balance card)
- Params: `userName, streakDays, wallets, selectedWalletId, balance, income, expense, onWalletTap`

#### [MODIFY] `widgets/segment_tabs.dart` (X-02)
- Đã có file — gắn nội dung `_SegmentTabs` + `_SegmentItem` vào

#### [MODIFY] `widgets/wallet_chips.dart` (X-03)
- Đã có file — wire-up `_WalletChip`

#### [NEW] `widgets/gallery_card.dart` (X-05)
- Extract `_GalleryCard` chung

#### [NEW] `widgets/story_card.dart` (X-06)
- Extract `_StoryCard`, prop `showOwnerBadge: bool`

#### [NEW] `widgets/inline_calendar.dart` (X-07)
- Extract `_InlineCalendarView` + `_StackedPhotoCell`

#### [NEW] `widgets/onboarding_widgets.dart` (X-08)
- Extract `_ProgressHeader` + `_NavButtons`

#### [NEW] `theme/categories.dart` (X-09)
- Gom category color/emoji vào `Map<String, CategoryStyle>`

#### Remaining (X-10..X-12)
- **X-10**: Replace `Navigator.pop` → `context.pop()` (go_router)
- **X-11**: Tạo `widgets/skeleton.dart` (shimmer placeholder)
- **X-12**: Tạo `widgets/error_banner.dart` + `widgets/empty_state.dart`

---

### Phase 4 — Auth Flow (L, R, O tasks)

> **Ước lượng: ~2-3 giờ.** Auth flow + onboarding — blocks hầu hết screen khác.

#### [NEW] `lib/services/api_client.dart` (M1)
- Tạo `ApiClient` class dùng `dio` hoặc `http`
- Base URL configurable (`--dart-define=API_BASE_URL`)
- Tất cả endpoints: auth, wallets, transactions, budgets, stats, AI, categories

#### [NEW] `lib/services/auth_interceptor.dart` (M1)
- Attach `Authorization: Bearer <access>` mọi request trừ `/auth/*`
- Khi 401 → gọi `/auth/refresh` → retry

#### [NEW] `lib/services/auth_provider.dart`
- State management cho auth (token storage, login/logout state)

#### [MODIFY] `login_screen.dart` (L-01..L-05)
- Chuyển `StatefulWidget`, thêm controllers
- Gọi `ApiClient.login()` → lưu token → navigate
- Error handling, loading state

#### [MODIFY] `register_screen.dart` (R-01..R-04)
- Fix `StatefulBuilder`, thêm controllers
- Validate ≥ 8 ký tự, match confirm password
- Gọi `ApiClient.register()`

#### [MODIFY] Onboarding 1-5 (O-01..O-04)
- Extract `_ProgressHeader` + `_NavButtons` (đã làm ở X-08)
- Tạo `OnboardingState` (ChangeNotifier)
- Step 5 → gọi API persist data

---

### Phase 5 — Main Screens API Integration (H, HG, HC, AT, SH)

> **Ước lượng: ~3-4 giờ.** Nối API cho các screen chính.

#### [MODIFY] `home_screen.dart` (H-01..H-07)
- Import `home_header.dart` chung
- Load stats từ API
- Wallet chips dynamic
- `intl` format date Việt
- `RefreshIndicator` + shimmer

#### [MODIFY] `home_gallery_screen.dart` (HG-01, HG-02)
- Reuse `home_header.dart` + `gallery_card.dart`

#### [MODIFY] `home_calendar_screen.dart` (HC-01..HC-05)
- Fix bugs + dynamic data + reuse header

#### [MODIFY] `app_routes.dart` (AT-01)
- Thêm route `/add` cho `AddTransactionScreen`

#### [MODIFY] `add_transaction_screen.dart` (AT-01..AT-06)
- Register route, nối API categories + POST transactions
- DatePicker/TimePicker

#### [MODIFY] `app_shell.dart` (SH-01, SH-02)
- FAB → BottomSheet 2 lựa chọn (nhập tay / chụp bill)

---

### Phase 6 — Feature Screens (CAM, CI, CC, CH, CHH, DS, G, S, ST, LM, RP, SW)

> **Ước lượng: ~4-6 giờ.** Fan-out screens.

#### Camera Flow (CAM, CI, CC)
- `camera_screen.dart`: Thêm `image_picker` để chọn ảnh gallery
- `camera_input_screen.dart`: Nhận file path + gọi API
- `camera_confirm_screen.dart`: Dynamic data + edit sheet + POST transaction

#### Chat (CH, CHH)
- `chat_screen.dart`: StatefulWidget + API NLU + quick chip clickable
- `chat_history_screen.dart`: Bỏ trùng MockData + tap mở session

#### Other Screens
- `detail_story_screen.dart` (DS-01..DS-04): Route param + edit + AI correction
- `goal_screen.dart` (G-01..G-05): CRUD + contribute money sheet
- `settings_screen.dart` (S-01..S-06): Load /me + personality sync + logout
- `streak_screen.dart` (ST-01..ST-05): API streak + animate
- `limits_screen.dart` (LM-01..LM-06): API budgets + create sheet
- `report_screen.dart` (RP-01..RP-05): Range query + stats API
- `share_wallet_screen.dart` (SW-01..SW-05): API + invite member

---

### Phase 7 — expense-ocr-nlu & Polish (N1-N3, X-10..X-12)

> **Ước lượng: ~1-2 giờ.**

#### [MODIFY] `expense-ocr-nlu/src/nlu/pipeline.py` (N1)
- Refactor `run_nlu` nhận `run_llm` & `user_id` qua param thay vì `os.environ`

#### [NEW] `expense-ocr-nlu/train_user_model.py` (N2)
- Script đọc corrections từ DB → train per-user model

#### [MODIFY] `expense-ocr-nlu/requirements-real.txt` (N3)
- Pin versions chính xác

#### Polish (X-10..X-12)
- Replace `Navigator.pop` → `context.pop()`
- Skeleton/shimmer widgets
- Error banner + empty state widgets
- Thay `Image.network` → `CachedNetworkImage` (A-06)

---

## Verification Plan

### Automated Tests
```powershell
# Backend Jest
cd D:\Luan-Van\Project\app\backend
npm test   # expect: ≥ 9 passed

# AI-service pytest
cd D:\Luan-Van\Project\app\ai-service
pytest -q  # expect: 6 passed

# Flutter analyze
cd D:\Luan-Van\Project\app\frontend\mobile
flutter analyze  # 0 errors
```

### Docker Integration Tests (TEST_PLAN Task 0-11)
- Chạy lần lượt từng task, ghi kết quả vào bảng tổng kết

### Manual Verification
- Verify Swagger UI tại `http://localhost:4000/docs` có thêm routes mới (settings, goals, stories, chat)
- Verify Flutter app build thành công (`flutter build apk --debug`)
