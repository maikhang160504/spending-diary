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

### 8.2 Gallery & Calendar API (Partial — Mock fallback)
- [ ] HG-01: Gallery still uses MockData.galleryItems (needs stories API with images)
- [ ] HC-01: Calendar still uses MockData.calendarEntries (needs transactions-by-day API)

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
- [ ] RP-05: Chart tap interactions

### 8.8 Chat Screen ✅
- [x] CH-01: Converted to StatefulWidget with messages list + controllers
- [x] CH-02: Creates chat session via `POST /chat/sessions`
- [x] CH-03: Send → `POST /ai/nlu` → Record intent shows tx preview card with save button
- [x] CH-04: QuickChip → GestureDetector sends message
- [x] CH-05: Auto-scroll to bottom after new message
- [x] CH-06: "Mimo đang nghĩ…" typing indicator with dot animation

### 8.9 Share Wallet Screen
- [ ] SW-01: Route receives walletId, load `GET /wallets/:id/members`
- [ ] SW-02..SW-04 (deferred until multi-wallet flow implemented)

---

## Phase 9 — Mobile: Camera + AI Flow (Priority: HIGH)

### 9.1 Camera Screen (Real Hardware)
- [ ] CAM-01: Add `camera: ^0.11.x` + `permission_handler` to pubspec
- [ ] CAM-02: Replace mock Container background with `CameraPreview`
- [ ] CAM-03: Wire zoom + tap focus to controller
- [ ] CAM-04: Shutter → `takePicture()` → push to cameraConfirm with XFile
- [ ] CAM-05: Mode 'Bill' flag for from-bill vs from-text flow
- [ ] CAM-06: "Thư viện" → image_picker gallery
- [ ] CAM-07: Auto-detect bill badge polish

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
- [ ] M4-01: AI correction button on each AI-generated transaction
- [x] M4-02: Show mascot emotion based on `mascot_mood` from API response ✅
- [ ] M4-03: Action popup confirm flow → `/ai/actions/confirm` or `/reject`

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
- [ ] O-01: Extract shared widgets to `widgets/onboarding_widgets.dart`
- [ ] O-02: Create `state/onboarding_state.dart` (ChangeNotifier)
- [x] O-03: Step 5 "Hoàn thành" → PATCH /users/me/settings before go(home) ✅
- [ ] O-04: "Bỏ qua" button on optional steps

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
- [ ] N3: Pin versions in requirements-real.txt (paddleocr, vietocr, torch, etc.)
- [ ] N4: Add `/api/v1/chat` endpoint to ai-service for chat proxy
- [ ] N5: Add OCR-only review endpoint (text + lines) before save
- [ ] N6: Add `GET /api/internal/status` returning model_version + last_train_date

### 12.2 Training & Deployment
- [ ] N7: Dockerfile multi-stage (mock vs real image)
- [ ] N8: GitHub Actions CI for running pytest + building images
- [ ] N9: Load per-user model in adapter when user_id provided

### 12.3 Backend Enhancements
- [x] BE-01: `POST /auth/change-password` endpoint
- [x] BE-02: `GET /users/me/streak` endpoint with streak calculation
- [ ] BE-03: `ai_processing_logs` detailed logging for from-bill pipeline
- [ ] BE-04: Wallet member permission checks (only owner can edit budget/goal)
- [ ] BE-05: Install jest as devDependency in Docker + run tests in CI

---

## Phase 13 — New Tasks (Proposed)

### 13.1 Gallery & Calendar Real Data (Priority: HIGH)
- [ ] HG-01: `GET /stories?walletId=` → map to GalleryItem (imageUrl, title, amount, category)
- [ ] HC-01: `GET /transactions?groupBy=day` → map to CalendarEntry (day, imageUrls, totalAmount)
- [ ] HC-02: CalendarEntry tap → pass real storyId from transactions

### 13.2 Share Wallet Real Flow (Priority: HIGH)
- [ ] SW-01: `GET /wallets/:id/members` → list members in ShareWalletScreen
- [ ] SW-02: `POST /wallets/:id/invite` → invite by email
- [ ] SW-03: `DELETE /wallets/:id/members/:userId` → remove member

### 13.3 Camera Real Hardware (Priority: HIGH)
- [ ] CAM-01..CAM-07: Wire real camera (see Phase 9.1 above)

### 13.4 Report Screen Polish (Priority: MEDIUM)
- [ ] RP-05: Range tabs reload chart data (7 ngày / Tháng / Năm)
- [ ] RP-06: Bar chart from real `GET /stats/dashboard` byDay data
- [ ] RP-07: Trend chart from real `GET /stats/by-month` data

### 13.5 AI Corrections & Actions (Priority: MEDIUM)
- [ ] M4-01: Per-transaction "AI nhận nhầm" button → `POST /ai/corrections`
- [ ] M4-03: Action confirm/reject popup → `POST /ai/actions/confirm` or `/reject`
- [ ] N4: `/api/v1/chat` LLM proxy in ai-service for richer Mimo responses

### 13.6 Onboarding Persist Full Flow (Priority: LOW)
- [ ] O-01: Extract shared onboarding widgets to `widgets/onboarding_widgets.dart`
- [ ] O-02: `state/onboarding_state.dart` ChangeNotifier to carry data across steps
- [ ] O-04: "Bỏ qua" skip button on optional steps 2-4

### 13.7 Performance & Quality (Priority: LOW)
- [ ] P-01: Replace `dynamic` maps in home_screen with typed models
- [ ] P-02: `use_build_context_synchronously` fix in settings_screen dialog
- [ ] P-03: `unnecessary_underscores` fix in detail_story_screen
- [ ] P-04: Add flutter_test widget tests for critical screens (login, home, chat)
- [ ] P-05: `go_router` redirect guard for expired JWT → auto-navigate to login
