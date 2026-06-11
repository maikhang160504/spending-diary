# Task list — fix_app.json

Nguồn: `fix_app.json`, chi tiết triển khai: `implementation_plan.md`.

Chú thích trạng thái: `[x]` xong · `[/]` đang làm / một phần · `[ ]` chưa làm

---

## 1. Chat (backend + luồng session)

| # | Task | Trạng thái | File / ghi chú |
|---|------|------------|----------------|
| 1.1 | Sửa `recentMessages.map is not a function` — unwrap `getMessages` trả về `{ messages: [] }` | [x] | `app/backend/src/modules/ai/ai.service.js` |
| 1.2 | Vào Chat từ Home/Wallet **không** tạo session mới — tái sử dụng session active theo ví | [x] | `chat_screen.dart`, `app_routes.dart` |
| 1.3 | Thêm `forceNew: true` chỉ khi tạo chat mới từ **Chat History** | [x] | `chat_history_screen.dart` |
| 1.4 | Lần đầu vào Chat (chưa có session) → tạo session mới + hiển thị câu chào Mimo | [x] | `chat.service.js` (greeting theo `preferred_vibe`) |
| 1.5 | **Verify thủ công**: mở Chat lần 2 cùng ví → thấy lịch sử + không duplicate session | [ ] | QA |

---

## 2. Chat Screen (UI + NLU + ví)

| # | Task | Trạng thái | File / ghi chú |
|---|------|------------|----------------|
| 2.1 | Hiển thị response LLM text trong chat (bypass `should_run_llm` khi client gửi `run_llm`) | [x] | `llm_runner.py`, `app.py`, `expense_ocr_nlu.py`, `ai.service.js` |
| 2.2 | **Verify thủ công**: gửi câu chitchat / hỏi tư vấn → bubble assistant có text NLG, không trống | [ ] | QA |
| 2.3 | Voice input **chỉ** xuất hiện ở màn Chat | [x] | `VoiceInputService` chỉ dùng trong `chat_screen.dart` |
| 2.4 | Ẩn nút xác nhận / lưu sau khi `message.isSaved == true` (single + multi tx) | [x] | `chat_screen.dart` |
| 2.5 | Story / transaction từ chat & add_story lưu đúng ví đang chọn (cá nhân vs ví chung) | [x] | `share_wallet_screen.dart` set `ApiClient.lastSelectedWalletId`; kiểm tra thêm `chat_screen` gửi `walletId` |
| 2.6 | **Verify thủ công**: ở ví nhóm → chat + chụp bill → giao dịch thuộc đúng `wallet_id` | [ ] | QA |
| 2.7 | Home: draft card hiển thị đúng icon/title theo `source` (`voice` / `bill` / khác) | [x] | `home_screen.dart` |

---

## 3. App Icon

| # | Task | Trạng thái | File / ghi chú |
|---|------|------------|----------------|
| 3.1 | Script pad logo ~63% → `Logo_padded.png` | [x] | `pad_logo.py`, `assets/logo/Logo_padded.png` |
| 3.2 | Cập nhật `pubspec.yaml` + `adaptive_icon_foreground` | [x] | `pubspec.yaml` |
| 3.3 | Chạy `dart run flutter_launcher_icons` và build lại app | [x] | `Logo_padded.png` + icons Android/iOS đã generate |
| 3.4 | **Verify thủ công**: icon launcher hiển thị đủ logo, không bị crop/phóng to | [ ] | QA |

---

## 4. Notification (local + push)

| # | Task | Trạng thái | File / ghi chú |
|---|------|------------|----------------|
| 4.1 | Sửa crash Android: dùng `@mipmap/launcher_icon` | [x] | `push_notification_service.dart` |
| 4.2 | Tap notification → deep link (`onNotificationTap` → `context.push`) | [x] | `app_shell.dart` |
| 4.3 | Hiển thị trên **thanh thông báo hệ thống** (Android 13+ permission, iOS alert) | [x] | Channel + icon + iOS permission trong `push_notification_service.dart` |
| 4.4 | Tích hợp **FCM / push remote** — backend token API + Firebase Messaging | [x] | `fcm/*`, `fcm_service.dart`, `notificationDispatch.js`; cần `.env` Firebase + `google-services.json` hợp lệ |
| 4.5 | **Verify thủ công**: budget alert / recurring → notification xuất hiện ngoài app + tap mở đúng màn | [ ] | QA |

---

## 5. Google Sign-In

| # | Task | Trạng thái | File / ghi chú |
|---|------|------------|----------------|
| 5.1 | Snackbar cảnh báo khi fallback `mock-google-token` (emulator / lỗi config) | [x] | `login_screen.dart` |
| 5.2 | Hiển thị **đúng Gmail** sau đăng nhập Google thật (Settings / profile) | [x] | Không còn silent mock khi thiếu token; mock chỉ debug + snackbar |
| 5.3 | Không dùng mock token khi user cancel sign-in; chỉ fallback khi exception rõ ràng | [x] | `login_screen.dart` |
| 5.4 | **Verify thủ công**: device có Google Play → login → Settings hiện email thật | [ ] | QA |

---

## 6. Tạo ví / Onboarding

| # | Task | Trạng thái | File / ghi chú |
|---|------|------------|----------------|
| 6.1 | Thêm `updateWallet(id, body)` → `PATCH /wallets/:id` | [x] | `api_client.dart` |
| 6.2 | Onboarding bước 4: **không** `createWallet` mới — đổi tên ví personal mặc định + thêm giao dịch số dư ban đầu | [x] | `onboarding_screen_4.dart` |
| 6.3 | Copy UI onboarding: “Tạo ví” thực chất là đặt tên + số dư cho ví có sẵn | [x] | Nút đổi thành `Lưu & Bắt đầu` |
| 6.4 | **Verify thủ công**: user mới → Home chỉ **1** ví cá nhân | [ ] | QA |

---

## 7. Đổi avatar

| # | Task | Trạng thái | File / ghi chú |
|---|------|------------|----------------|
| 7.1 | Request quyền photos/camera khi bấm đổi ảnh | [x] | `settings_screen.dart` + `permission_handler` |
| 7.2 | Thêm `NSPhotoLibraryUsageDescription` + `NSCameraUsageDescription` (iOS) | [x] | `ios/Runner/Info.plist` |
| 7.3 | **Verify thủ công**: iOS Simulator/device — chọn ảnh không crash | [ ] | QA |

---

## 8. Metadata NLU (phản hồi sai do context dư)

| # | Task | Trạng thái | File / ghi chú |
|---|------|------------|----------------|
| 8.1 | Bỏ fallback `profile.get("frequency_week")` — chỉ dùng `cat.get("frequency_week")` | [x] | `expense-ocr-nlu/src/nlg/context_meta.py` |
| 8.2 | Rà soát payload `profile` từ backend — chỉ gửi field NLU cần (budget, category stats) | [x] | Bỏ `frequency_week`/`avg_amount` cấp ví khỏi `_fetchWalletProfile` |
| 8.3 | **Verify thủ công**: cùng câu hỏi trước/sau fix → phản hồi NLG nhất quán, không lẫn số liệu ví khác | [ ] | QA |

---

## Thứ tự ưu tiên đề xuất (P0 → P2)

### P0 — Blocker / data sai
1. **6.1 + 6.2** — Trùng ví cá nhân onboarding  
2. **5.2 + 5.1** — Email Google / mock fallback  
3. **8.1** — Metadata `frequency_week` sai  

### P1 — UX quan trọng
4. **7.2** — iOS avatar permissions  
5. **4.3 + 4.5** — Notification trên status bar  
6. **2.2 + 2.6** — QA chat LLM + đúng ví  

### P2 — Polish
7. **3.3 + 3.4** — Regenerate launcher icons  
8. ~~**4.4** — FCM push remote~~ ✅ (cần Firebase credentials + google-services.json để test thật)  
9. **1.5, 2.2, 6.4** — Regression QA tổng  

---

## Checklist nhanh (copy khi làm từng PR)

```text
[ ] Backend: ai.service.js recentMessages — đã merge
[ ] Chat: forceNew + reuse session — đã merge
[ ] NLU: run_llm override — đã merge
[ ] Chat UI: hide save when isSaved — đã merge
[ ] Wallet context: lastSelectedWalletId — đã merge
[ ] Icon: Logo_padded + pubspec — đã merge
[ ] Notifications: launcher_icon + tap — đã merge
[ ] Google: snackbar fallback + email đúng — đã merge
[ ] Onboarding: updateWallet + không duplicate ví — đã merge
[ ] iOS: Info.plist photo/camera keys — đã merge
[ ] Metadata: context_meta frequency_week — đã merge
[x] flutter_launcher_icons + Logo_padded — đã chạy
[x] Notification channel + status bar config — đã merge
[x] Profile metadata trim (ai.service.js) — đã merge
[x] FCM: backend token API + migration 016 + Flutter FcmService — đã merge
[ ] FCM QA: budget/recurring push khi app background (cần FIREBASE_* + google-services.json)
```
