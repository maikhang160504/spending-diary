# Task Tracker — Master Implementation

## Phase 0 — Docker Test Plan ✅ ALL PASS
- [x] Task 0: Docker up + migrate + seed — ✅ "migration done", "demo user already exists"
- [x] Task 1: Health probes — ✅ Backend 200 OK, AI 200 OK
- [x] Task 2: Swagger UI — ✅ 37 paths (28 original + 9 new module endpoints)
- [x] Task 3: Auth flow — ✅ login/me/refresh/logout all 200
- [x] Task 4: Categories + Wallets — ✅ 15 categories, 1 wallet
- [x] Task 5: Transactions CRUD — ✅ Create/Patch/Delete all work
- [x] Task 6: Budgets + Stats — ✅ Budget created, summary OK, dashboard OK
- [x] Task 7: AI service direct — ✅ NLU mock: intent=Record, amount=45000, category=Food
- [x] Task 8: AI via backend proxy — ✅ NLU proxy + expense-from-text auto-save transaction
- [x] Task 9: DB rows — ✅ 2 ai_logs rows verified
- [x] Task 10: Security — ✅ No auth=401, Bad token=401, Bad body=422
- [x] Task 11: Test suites — ⚠️ Jest/Pytest not in prod containers (expected)
- [x] New Modules — ✅ Settings (GET/PATCH), Goals (CRUD+contribute), Chat (sessions+messages), Stories (list)

## Phase 1 — Asset & Bug Fixes ✅
- [x] A-01..A-05, B-01..B-05, B-08 — All done (see walkthrough)
- [x] B-07: CachedNetworkImage — all Image.network replaced ✅

## Phase 2 — Backend Modules ✅
- [x] B1-B5: Settings, Goals, Stories, Chat + routes registered

## Phase 3 — Widget Extraction ✅
- [x] X-01/X-04: home_header.dart, X-05: gallery_card.dart
- [x] X-09: categories.dart, X-11: skeleton.dart, X-12: error_banner.dart

## Phase 4 — Auth Flow ✅
- [x] M1: ApiClient + JWT auto-refresh
- [x] L-01..L-05: Login screen real API

## Phase 5 — AI Service Integration ✅
- [x] AI-01: Retry with exponential backoff
- [x] AI-02: aiChat endpoint + orchestration

## Phase 6 — Database ✅
- [x] Migration 002 verified + applied

## Phase 7 — expense-ocr-nlu ✅
- [x] N1: Refactored run_nlu to accept run_llm + user_id as parameters
- [x] N2: Created train_user_model.py

---

## Phase 8 — Mobile: Replace Mock Data with Real API ✅

### 8.1 Home Screen API Wiring ✅
- [x] H-01: home_screen.dart — Load wallets from `GET /wallets`, stats from `GET /stats/dashboard`
- [x] H-02: Replace hardcoded balance/income/expense with API data
- [x] H-03: Replace hardcoded wallet chips with dynamic `wallets[]`
- [x] H-04: Tab Story → `GET /transactions?walletId=&type=expense`, with _TransactionStoryCard
- [x] H-05: Dynamic date formatting from DateTime.now()
- [x] H-06: Add `RefreshIndicator` around `CustomScrollView`
- [x] H-07: Shimmer loading cards (SkeletonCard) while fetching data

### 8.2 Gallery & Calendar API ✅
- [x] HG-01: Gallery stories from `GET /stories?walletId=` ✅
- [x] HC-01: Calendar entries from `GET /stats/dashboard` byDay ✅
- [x] HC-02: CalendarEntry tap → real storyId from transactions ✅

### 8.3 Register Screen Real API ✅
- [x] R-01: TextEditingControllers for email, password, confirm
- [x] R-02: Validate email format, ≥ 8 chars, confirm match
- [x] R-03: Call `ApiClient.register()` → go to onboarding
- [x] R-04: Inline field-level errors + general error banner

### 8.4 Settings Screen ✅
- [x] S-01: Load `GET /auth/me` + `GET /users/me/settings`
- [x] S-02: Sync AI personality with Dui Dẻ / Dận Dữ
- [x] S-03: Toggle notifications/dark mode → `PATCH /users/me/settings`
- [x] S-04: "Đổi mật khẩu" dialog (placeholder until backend endpoint)
- [x] S-05: "Đăng xuất" → clear tokens + `context.go(login)`

### 8.5 Goals Screen ✅
- [x] G-01: Load from `GET /goals` with loading/error states
- [x] G-02: "+" button → BottomSheet create goal → `POST /goals`
- [x] G-03: "Thêm tiền" → `POST /goals/:id/contribute`
- [x] G-04: Completed goal highlighting with badge

### 8.6 Limits/Budgets Screen ✅
- [x] LM-01: Load from `GET /budgets` with CategoryTheme styling
- [x] LM-02: Dynamic warning banner (first category ≥ 85% spent)
- [x] LM-03: "Tháng X/YYYY" dynamic from DateTime.now()
- [x] LM-04: "Thêm giới hạn" → BottomSheet with category picker → `POST /budgets`
- [x] LM-05: Edit budget dialog (PATCH deferred until endpoint ready)

### 8.7 Report Screen (Partial)
- [x] RP-01: Total card shows real totalExpense/totalIncome from `GET /stats/dashboard`
- [x] RP-02: RefreshIndicator + dynamic % of income calculation
- [x] RP-03: GET /stats/by-category backend + Flutter wire to donut chart ✅
- [x] RP-04: TopCategoryCard now uses real top category from API ✅
- [x] RP-05: Range tabs reload chart data ✅
- [x] RP-06: Bar chart from real `byDay` dashboard data ✅
- [x] RP-07: Trend chart from real `GET /stats/by-month` data ✅

### 8.8 Chat Screen ✅
- [x] CH-01: Converted to StatefulWidget with messages list + controllers
- [x] CH-02: Creates chat session via `POST /chat/sessions`
- [x] CH-03: Send → `POST /ai/nlu` → Record intent shows tx preview card with save button
- [x] CH-04: QuickChip → GestureDetector sends message
- [x] CH-05: Auto-scroll to bottom after new message
- [x] CH-06: "Mimo đang nghĩ…" typing indicator with dot animation

### 8.9 Share Wallet Screen ✅
- [x] SW-01: Route receives walletId, load `GET /wallets/:id/members` ✅
- [x] SW-02: `POST /wallets/:id/invite` invite by email + dialog ✅
- [x] SW-03: `DELETE /wallets/:id/members/:userId` remove member ✅

---

## Phase 9 — Mobile: Camera + AI Flow (Priority: HIGH)

### 9.1 Camera Screen (Real Hardware) ✅
- [x] CAM-01: Added `camera: ^0.11.1` + `permission_handler: ^11.3.1` to pubspec ✅
- [x] CAM-02: Real `CameraPreview` with `CameraController` ✅
- [x] CAM-03: Zoom via `setZoomLevel` + tap-to-focus via `setFocusPoint` ✅
- [x] CAM-04: Shutter → `takePicture()` → push cameraInput with XFile path ✅
- [x] CAM-05: Mode 'Bill' flag propagated to cameraInput ✅
- [x] CAM-06: "Thư viện" → `image_picker` gallery ✅
- [x] CAM-07: Flash toggle button, permission-denied fallback screen ✅

### 9.2 Camera Input Screen ✅
- [x] CI-01: Receive imagePath from camera, replace background
- [x] CI-02: `_submit()` → `POST /ai/expense/from-text` → push confirm with data
- [x] CI-03: Error snackbar on API failure

### 9.3 Camera Confirm Screen ✅
- [x] CC-01: Convert to StatefulWidget, receive ExtractedExpense via route
- [x] CC-02: Render dynamic data (amount, category, confidence)
- [x] CC-03: "Chỉnh sửa" → BottomSheet to edit amount/category/note
- [x] CC-04: "Xác nhận" → `POST /transactions` + mascot emotion from response
- [x] CC-05: Confidence badge dynamic + warning if < 60%

## Phase 10 — Mobile: Chat + Mascot Polish (Priority: MEDIUM)

### 10.1 Chat History ✅
- [x] CHH-01: Load from `GET /chat/sessions` instead of mock
- [x] CHH-02: Tap thread → push to chat with sessionId
- [x] CHH-03: Search delegate for client-side filtering

### 10.2 Mascot Feedback
- [x] M4-01: AI correction button (long-press) on transaction cards → `POST /ai/corrections` ✅
- [x] M4-02: Show mascot emotion based on `mascot_mood` from API response ✅
- [x] M4-03: Action popup confirm flow → `/ai/actions/confirm` or `/reject` ✅

## Phase 11 — Mobile: Navigation + Polish (Priority: MEDIUM)

### 11.1 Add Transaction Screen ✅
- [x] AT-01: Register route `AppRoutes.addTransaction = '/add'` in GoRoute
- [x] AT-02: FAB → BottomSheet with "Nhập tay" and "Chụp bill" options
- [x] AT-03: Load categories from `GET /categories` instead of const
- [x] AT-04: "Lưu giao dịch" → `POST /transactions`
- [x] AT-05: Date/Time picker on tap
- [x] AT-06: Comma format on amount display

### 11.2 Detail Story ✅
- [x] DS-01: Route receives storyId from path params ✅
- [x] DS-02: Load `GET /stories/:id` with transactions ✅
- [x] DS-03: "Chỉnh sửa" → push AddTransactionScreen with prefilled data ✅
- [x] DS-04: "AI nhận nhầm" correction button → `/ai/corrections` ✅

### 11.3 Streak Screen ✅
- [x] ST-01: Load streak data from `GET /users/me/streak`
- [x] ST-02: Render `_StreakGrid` from actual streak data
- [x] ST-03: "Hôm nay" pill dynamic
- [x] ST-04: Achievements computed from streak data

### 11.4 Onboarding Persist
- [x] O-01: Extract shared widgets to `widgets/onboarding_widgets.dart` ✅
- [x] O-02: Create `state/onboarding_state.dart` (ChangeNotifier + InheritedNotifier) ✅
- [x] O-03: Step 5 "Hoàn thành" → PATCH /users/me/settings before go(home) ✅
- [x] O-04: "Bỏ qua" skip button on optional steps 2-4 → go to step 5 ✅

### 11.5 Global Polish
- [x] B-07: Replace all `Image.network` → `CachedNetworkImage` ✅
- [x] X-10: Replace `Navigator.pop` → `context.pop()` consistently ✅
- [x] SH-01: FAB → BottomSheet with 2 options
- [x] SH-02: Animate FAB icon rotation when sheet open
- [x] A-10: CategoryTheme.iconOf() — all category emoji → MiMo/category PNG assets ✅
- [x] A-11: MiMo status PNGs wired in mimo_overlay + onboarding step 1/3 ✅
- [x] A-12: Logo.png + Title.png used in login + register screens ✅
- [x] A-13: flutter analyze → No issues found ✅

## Phase 12 — expense-ocr-nlu Refinements (Priority: LOW)

### 12.1 Pipeline Improvements
- [x] N3: Pin versions in requirements-real.txt (paddleocr, vietocr, torch, etc.) ✅
- [x] N4: Add `/api/v1/chat` endpoint to ai-service for chat proxy ✅
- [x] N5: Add `POST /api/v1/ocr/review` endpoint (text + lines) before save ✅
- [x] N6: Add `GET /api/v1/internal/status` returning model_version + uptime ✅

### 12.2 Training & Deployment
- [ ] N7: Dockerfile multi-stage (mock vs real image)
- [ ] N8: GitHub Actions CI for running pytest + building images
- [ ] N9: Load per-user model in adapter when user_id provided

### 12.3 Backend Enhancements
- [x] BE-01: `POST /auth/change-password` endpoint
- [x] BE-02: `GET /users/me/streak` endpoint with streak calculation
- [x] BE-03: `ai_processing_logs` detailed logging for from-bill pipeline ✅
- [x] BE-04: Wallet member permission checks — `assertMember(['owner'])` on all mutating ops ✅
- [ ] BE-05: Install jest as devDependency in Docker + run tests in CI

---

## Phase 13 — New Tasks (Proposed)

### 13.1 Gallery & Calendar Real Data ✅
- [x] HG-01..HC-02: Completed ✅

### 13.2 Share Wallet Real Flow ✅
- [x] SW-01..SW-03: Completed ✅

### 13.3 Camera Real Hardware ✅
- [x] CAM-01..CAM-07: Completed ✅

### 13.4 Report Screen Polish ✅
- [x] RP-05..RP-07: Completed ✅

### 13.5 AI Corrections & Actions ✅
- [x] M4-01: Per-transaction "AI nhận nhầm" long-press → `POST /ai/corrections` ✅
- [x] M4-03: Action confirm/reject popup → `POST /ai/actions/confirm` or `/reject` ✅
- [x] N4: `/api/v1/chat` endpoint in ai-service (mock rule-based Mimo) ✅

### 13.6 Onboarding Persist Full Flow ✅
- [x] O-01: Extract shared onboarding widgets to `widgets/onboarding_widgets.dart` ✅
- [x] O-02: `state/onboarding_state.dart` ChangeNotifier + InheritedNotifier ✅
- [x] O-04: "Bỏ qua" skip button on optional steps 2-4 ✅

### 13.7 Performance & Quality ✅
- [ ] P-01: Replace `dynamic` maps in home_screen with typed models (deferred — analyze clean)
- [x] P-02: `use_build_context_synchronously` — no issues found in `flutter analyze` ✅
- [x] P-03: `unnecessary_underscores` — no issues found in `flutter analyze` ✅
- [x] P-04: flutter_test widget tests for login, home, chat screens ✅
- [x] P-05: `go_router` redirect guard for expired JWT → auto-navigate to login ✅

---

## Phase 14 — expense-ocr-nlu Prompt Rewrite & Module Alignment (Priority: HIGH)

**Phân tích vấn đề hiện tại:**
- `prompts.json`: emotions chỉ có 1-2 câu chung chung, không có slang GenZ đa dạng, không có quy tắc CONTEXT_META diversity, không có relationship_tag override
- `context_meta.py`: thiếu các trường `time_of_day`, `weather`, `day_of_month`, `wallet_health`, `historical_fact` mà prompt mẫu yêu cầu để tạo lời thoại độc bản
- `prompt.py`: không khai thác các trường context để ra lệnh LLM phối hợp ≥2 yếu tố môi trường

### 14.1 Rewrite prompts.json
- [x] PR-01: Bổ sung slang vocabulary cho từng emotion (vui/dan_doi/cham_choc/dong_cam/nghiem_tuc/hai_huoc) — mỗi emotion có ≥3 ví dụ slang riêng biệt
- [x] PR-02: Thêm `context_diversity_rule` vào `common` — yêu cầu LLM phối hợp ≥2 yếu tố từ CONTEXT_META (thời tiết, giờ, ngân sách, lịch sử chi tiêu)
- [x] PR-03: Thêm `relationship_override` block — rules cho tag `CHA_ME` (không khịa, ấm áp) và `NGUOI_YEU` (trêu ngọt/ghen đáng yêu)
- [x] PR-04: Thêm `mood_personas` cho 2 nhóm lớn: VUI_VE (slang: vibe, hết nước chấm, chốt đơn) và DAN_DOI (slang: ét ô ét, rớt nước mắt, nhức nhức cái đầu)

### 14.2 Enhance context_meta.py
- [x] CM-01: Thêm `time_of_day` (sáng_sớm/buổi_trưa/chiều_tối/đêm_muộn) dựa theo `datetime.now().hour`
- [x] CM-02: Thêm `day_of_month` và `days_to_payday` (tính từ ngày 15 hoặc 30)
- [x] CM-03: Thêm `wallet_health` label: `an_toan` / `can_than` / `bao_dong` dựa trên `budget_remain/budget_total` ratio
- [x] CM-04: Thêm `historical_fact` string — câu gợi ý ngữ cảnh ngẫu nhiên (tuần này +12%, ăn uống >35%, còn 5 ngày cuối tháng...)
- [x] CM-05: Cập nhật `build_mock_context_metadata` để populate đầy đủ các trường mới

### 14.3 Update prompt.py
- [x] PY-01: Inject CONTEXT_META mới (time_of_day, weather, wallet_health, historical_fact) vào user_prompt dưới dạng text có cấu trúc thay vì JSON thuần
- [x] PY-02: Thêm chỉ thị "phối hợp ≥2 yếu tố từ CONTEXT_META" vào system_prompt cho intent Record
- [x] PY-03: Inject `relationship_tag` từ `nlu_result` vào prompt nếu có — trigger override rules

---

## Phase 15 — Đồng bộ Mascot Emotion: API status ↔ Flutter MiMo Assets (Priority: HIGH)

**Phân tích vấn đề hiện tại:**
- API (`response.py`) trả `status` ∈ {`vui`, `buon`, `canh_bao`, `trung_lap`}
- Flutter `MiMoOverlay` load file `assets/MiMo/status/${status}.png` — asset names: `Happy`, `Sad`, `Chill`, `Sassy`, `Success`, `Thinking`, `Taunting`
- **Mismatch hoàn toàn**: `vui` ≠ `Happy`, `buon` ≠ `Sad` → `errorBuilder` luôn fallback về `Happy.png`
- `chat_screen.dart` đọc field `nlu['mascot_mood']` — field này **không tồn tại** trong `NLUResponse` schema
- `camera_confirm_screen.dart` hardcode `status: 'Happy'` không dùng API response

### 15.1 AI-Service: Thêm mascot_mood field
- [x] EM-01: Thêm field `mascot_mood: str | None` vào `NLUResponse` schema (`app/ai-service/app/schemas/nlu.py`)
- [x] EM-02: Trong `nlu_service.py`, sau khi có `gemini_json.status`, map sang Flutter asset name và gán vào `result.mascot_mood`:
  - `vui` → `Happy`, `buon` → `Sad`, `canh_bao` → `Thinking`, `trung_lap` → `Chill`
  - Emotion `hai_huoc`/`cham_choc` + status `vui` → `Sassy`; intent Record thành công → `Success`

### 15.2 Mobile: Consume mascot_mood đúng cách
- [x] EM-03: `chat_screen.dart` — đọc `nlu['mascot_mood']` (đã có field từ EM-01), xóa hardcode fallback `'Happy'`/`'Chill'`; fallback về `'Chill'` nếu null
- [x] EM-04: `camera_confirm_screen.dart` — sau khi `POST /transactions` thành công, dùng `mascot_mood` từ NLU response (truyền qua route extra) thay vì hardcode `'Happy'`
- [x] EM-05: Thêm helper `String mapApiStatusToAsset(String? apiStatus)` vào `mock_data.dart` hoặc utils — centralise mapping để tái sử dụng

---

## Phase 16 — Đăng nhập bằng Google (Priority: MEDIUM)

**Phân tích hiện trạng:**
- Backend chỉ có email/password login; không có OAuth flow
- Flutter login_screen đã có nút "Đăng nhập với Google" nhưng `onPressed: () {}` — chưa implement
- DB `users` table chưa có `google_id` column; `password_hash` NOT NULL sẽ cản user Google

### 16.1 Database Migration
- [x] GL-01: Tạo migration `003_google_auth.sql` — thêm `google_id VARCHAR(255) UNIQUE` vào `users`; ALTER `password_hash` thành nullable
  > ⚠️ Chạy `npm run migrate` khi DB khả dụng (CockroachDB cloud)

### 16.2 Backend
- [x] GL-02: Cài `google-auth-library` vào `package.json` backend
- [x] GL-03: Thêm `GOOGLE_CLIENT_ID` vào `env.js` và README
- [x] GL-04: Tạo `POST /api/v1/auth/google` — nhận `{ idToken }`, verify với Google, find-or-create user (upsert by `google_id` hoặc email), gọi `issueTokens()` → trả về access/refresh token
- [x] GL-05: Đăng ký route trong `auth.routes.js` + thêm OpenAPI doc

### 16.3 Flutter Mobile
- [x] GL-06: Thêm `google_sign_in: ^6.2.1` vào `pubspec.yaml`
- [ ] GL-07: ⚠️ **MANUAL** — Thêm `google-services.json` (Android) và `GoogleService-Info.plist` (iOS) từ Firebase Console; thêm `GOOGLE_CLIENT_ID` vào `.env`
- [x] GL-08: `login_screen.dart` — implement `_loginWithGoogle()`: gọi `GoogleSignIn().signIn()` → lấy `idToken` → `POST /auth/google` → lưu token → `context.go(home)`
- [x] GL-09: Xử lý cancel/error + hiện error banner inline (cùng pattern với email login)

---

## Phase 17A — Fix Luồng 1 (Text): Gap thực thi vs flow (Priority: HIGH)

**Gap phân tích — Luồng 1 (Text):**
| Bước Flow | Hiện trạng | Vấn đề |
|---|---|---|
| Bước 4: Quét Prompt Ẩn | `pipeline.py` KHÔNG có logic nào | `prompt.py` đọc `nlu_result.get("relationship_tag")` → luôn `None` → override không bao giờ kích hoạt |
| Bước 6-7: LLM call | `ai.service.js expenseFromText` đặt `run_llm: false` | Story & mascot_mood KHÔNG được tạo ra khi nhập text |
| Bước 5: Truy vấn Wallet | `profile: null` gửi vào AI | `context_meta` chạy với mock fallback, không dùng số liệu thật từ PostgreSQL |

**Quyết định relationship_tag:** KHÔNG train model mới, KHÔNG gửi thêm LLM call.
→ **Keyword/regex scanner** trong `pipeline.py` — 0ms, 0 cost, đủ chính xác cho 2-3 tags.
→ Bill scan: KHÔNG cần tag ẩn (không có câu text chủ quan của user).

### 17A.1 relationship_tag keyword scanner
- [x] FT-01: Thêm hàm `detect_relationship_tag(text)` vào `pipeline.py` với keyword list:
  - `CHA_ME`: mẹ, ba, cha, bố, mẹ ruột, bố ruột, ba ruột, báo hiếu, cho mẹ, cho ba, tặng mẹ, tiền mẹ, mẹ ơi...
  - `NGUOI_YEU`: bồ, người yêu, crush, bạn gái, bạn trai, bạn ghệ, ghệ, em yêu, anh yêu, hẹn hò, date, kỷ niệm
- [x] FT-02: Gọi `detect_relationship_tag` trong `run_nlu()` và gán vào `result["relationship_tag"]`

### 17A.2 Enable LLM cho Luồng 1
- [x] FT-03: `ai.service.js expenseFromText` — đổi `run_llm: false` → `run_llm: true`
- [x] FT-04: Pass `profile` thực từ PostgreSQL (budget của wallet) vào AI call thay vì `null`

---

## Phase 17B — Fix Luồng 2 (Ảnh/Bill): Async Queue + WebSocket (Priority: HIGH)

**Gap phân tích — Luồng 2 (Ảnh):**
| Bước Flow | Hiện trạng | Vấn đề |
|---|---|---|
| Bước 2-3: Tạo bản ghi NHÁP + trả story_id ngay | `expenseFromBill` đang SYNCHRONOUS | Mobile phải chờ 2-3s OCR mới nhận được response |
| Bước 4-5: Message Queue | Không tồn tại | OCR chạy thẳng, blocking |
| Bước 12: WebSocket bắn kết quả | Không tồn tại | Mobile không có cách nhận update async |

### 17B.1 Pending Transaction + Immediate Response
- [x] BL-01: Migration `004_bill_processing_status.sql` — thêm `processing_status` (`pending`/`done`/`failed`) vào `transactions`
- [x] BL-02: `expenseFromBill` tạo tx PENDING ngay → trả `{ transactionId, status: 'pending' }` cho Mobile (HTTP 202)
- [x] BL-03: `setImmediate` → `_processBillBackground()` — OCR → UPDATE tx → sendToUser WebSocket

### 17B.2 WebSocket
- [x] WS-01: Cài `ws` package; tạo `src/services/wsHub.js`; attach WebSocket server tại `/ws` sau khi HTTP server start
- [x] WS-02: Auth qua `?token=<accessToken>` trong URL khi connect; map userId → WebSocket connections
- [x] WS-03: `sendToUser(userId, { type: 'transaction_done', transactionId, data })` sau khi job xong
- [x] WS-04: Flutter — thêm `web_socket_channel` package; `camera_confirm_screen.dart` lắng nghe WS:
  - Hiển thị loading khi `status=pending`
  - Khi nhận `transaction_done` → cập nhật UI với extracted data + MiMo story
  - Khi nhận `transaction_failed` → hiển thị error screen
  - `dispose()` đóng WS channel

---

## Phase 18 — Tối ưu Hiệu năng Mobile (Priority: HIGH)

**Rà soát màn phụ (đã xong):**
- Auth (login/register/splash) + Onboarding: nền gradient teal thương hiệu — *locked theme*, đúng ở cả light/dark, không cần đổi.
- Camera + preview (camera/input/confirm): nền đen viewfinder — cố ý tối, đúng ở cả 2 mode.
- ✅ Đã fix: bottom-sheet "Chỉnh sửa giao dịch" trong `camera_confirm_screen.dart` → `context.palette.card` (trước hardcode trắng).

**Phân tích hiệu năng (grounded từ codebase):**
| Vấn đề | Bằng chứng | Tác động |
|---|---|---|
| Ảnh giải mã full-res vào RAM | 0 chỗ dùng `memCacheWidth`/`cacheWidth` trên `CachedNetworkImage` | RAM cao, jank khi scroll lịch/gallery |
| Upload bill không nén | `camera_confirm` upload thẳng `imagePath` (ảnh Full HD từ `takePicture()`) | OCR/mạng chậm; avatar đã nén sẵn (q85, w1024) |
| Rebuild rộng | `setState` trên home/report dựng lại cả cây | Tốn frame khi đổi 1 field |
| Lottie Fire chạy nền | `repeat:true` streak | Ticker chạy cả khi off-screen |

### 18.1 Ảnh & bộ nhớ
- [x] PERF-01: ✅ Thêm `memCacheWidth` cho **toàn bộ 16 `CachedNetworkImage`** đúng kích thước hiển thị (ô lịch/avatar→200/300, lưới gallery→600, hero/story full-width→1080). Analyze sạch.
- [ ] PERF-09: `precacheImage` cho ảnh above-the-fold — *deferred*: lợi ích biên thấp sau khi đã có `memCacheWidth`; cân nhắc sau khi profiling PERF-10

### 18.2 Upload & mạng
- [x] PERF-02: ✅ Thêm `flutter_image_compress` + `path_provider`; util `utils/image_compressor.dart`; nén tập trung ở `ApiClient` — story 1280px/q80, bill OCR 1600px/q85 (giữ chữ rõ); fallback ảnh gốc nếu nén lỗi
- [x] PERF-06: ✅ `invalidateWalletData()` đã chạy sau mutation (qua `transactionNotifier`) + khi refresh home/calendar/report. **Fix**: `AppQueries.clearAll()` khi logout (trước đây cache user cũ sót sang phiên mới)

### 18.3 Render & rebuild
- [x] PERF-03: ✅ Verified — list cuộn chính dùng `SliverChildBuilderDelegate`/`GridView.builder` (Flutter tự bọc `RepaintBoundary` mỗi item). Không cần thêm thủ công
- [x] PERF-05: ✅ Verified — list dài đã virtualize (home Sliver builders, gallery `SliverGrid`/`GridView.builder`, chat `ListView.builder`). Các `.map()` còn lại đều bounded (categories, ≤31 bars, ≤12 tháng, members, tx 1 ngày/1 story)
- [ ] PERF-07: Thu hẹp `setState` ở home/report — *deferred*: cần tách widget con/`ValueListenableBuilder`, là refactor lớn dễ gây regression; nên làm sau khi có số liệu profiling

### 18.4 Animation & khởi động
- [x] PERF-04: ✅ Verified — Lottie chỉ ở màn route-level (streak Fire, loading), không nằm trong list cuộn; `Navigator` tự đặt `TickerMode=false` khi route bị che → tự pause. Loading indicator chỉ tồn tại lúc tải. Không cần đổi
- [x] PERF-08: ✅ WebSocket đã lazy-init (chỉ luồng bill) + `onError` + dispose. **Thêm**: `onDone` (server đóng sớm → báo lỗi) + `Timer` timeout 45s chống treo "đang xử lý"

### 18.5 Đo lường
- [ ] PERF-10: ⏸ **MANUAL** — Chạy `flutter run --profile` + DevTools timeline cho scroll Home & lưới Gallery; baseline `flutter build apk --analyze-size`. (Cần thiết bị/profiling thủ công)
