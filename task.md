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
- [ ] B-07: CachedNetworkImage (deferred to Phase 11)

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
- [ ] RP-03: Charts still use MockData (needs per-category breakdown API)
- [ ] RP-04: TopCategoryCard from sorted API data
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

### 9.2 Camera Input Screen
- [ ] CI-01: Receive imagePath from camera, replace background
- [ ] CI-02: `_submit()` → `POST /ai/expense/from-text` → push confirm with data
- [ ] CI-03: Error snackbar on API failure

### 9.3 Camera Confirm Screen
- [ ] CC-01: Convert to StatefulWidget, receive ExtractedExpense via route
- [ ] CC-02: Render dynamic data (amount, category, confidence)
- [ ] CC-03: "Chỉnh sửa" → BottomSheet to edit amount/category/note
- [ ] CC-04: "Xác nhận" → `POST /transactions` + mascot emotion from response
- [ ] CC-05: Confidence badge dynamic + warning if < 60%

## Phase 10 — Mobile: Chat + Mascot Polish (Priority: MEDIUM)

### 10.1 Chat History
- [ ] CHH-01: Load from `GET /chat/sessions` instead of mock
- [ ] CHH-02: Tap thread → push to chat with sessionId
- [ ] CHH-03: Search delegate for client-side filtering

### 10.2 Mascot Feedback
- [ ] M4-01: AI correction button on each AI-generated transaction
- [ ] M4-02: Show mascot emotion based on `mascot_mood` from API response
- [ ] M4-03: Action popup confirm flow → `/ai/actions/confirm` or `/reject`

## Phase 11 — Mobile: Navigation + Polish (Priority: MEDIUM)

### 11.1 Add Transaction Screen
- [ ] AT-01: Register route `AppRoutes.addTransaction = '/add'` in GoRoute
- [ ] AT-02: FAB → BottomSheet with "Nhập tay" and "Chụp bill" options
- [ ] AT-03: Load categories from `GET /categories` instead of const
- [ ] AT-04: "Lưu giao dịch" → `POST /transactions`
- [ ] AT-05: Date/Time picker on tap
- [ ] AT-06: Comma format on amount display

### 11.2 Detail Story
- [ ] DS-01: Route receives storyId from path params
- [ ] DS-02: Load `GET /stories/:id` with transactions
- [ ] DS-03: "Chỉnh sửa" → push AddTransactionScreen with prefilled data
- [ ] DS-04: "AI nhận nhầm" correction button → `/ai/corrections`

### 11.3 Streak Screen
- [ ] ST-01: Load streak data (placeholder until backend endpoint)
- [ ] ST-02: Render `_StreakGrid` from actual streak data
- [ ] ST-03: "Hôm nay" pill dynamic
- [ ] ST-04: Achievements computed from streak data

### 11.4 Onboarding Persist
- [ ] O-01: Extract shared widgets to `widgets/onboarding_widgets.dart`
- [ ] O-02: Create `state/onboarding_state.dart` (ChangeNotifier)
- [ ] O-03: Step 5 "Hoàn thành" → `PATCH /auth/me` + `POST /budgets`
- [ ] O-04: "Bỏ qua" button on optional steps

### 11.5 Global Polish
- [ ] B-07: Replace all `Image.network` → `CachedNetworkImage`
- [ ] X-10: Replace `Navigator.pop` → `context.pop()` consistently
- [ ] SH-01: FAB → BottomSheet with 2 options
- [ ] SH-02: Animate FAB icon rotation when sheet open

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
- [ ] BE-01: `POST /auth/change-password` endpoint
- [ ] BE-02: `GET /users/me/streak` endpoint with streak calculation
- [ ] BE-03: `ai_processing_logs` detailed logging for from-bill pipeline
- [ ] BE-04: Wallet member permission checks (only owner can edit budget/goal)
- [ ] BE-05: Install jest as devDependency in Docker + run tests in CI
