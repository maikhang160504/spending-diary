# Implementation Plan - App Bug Fixes

This implementation plan details the fixes for the issues reported across the chat, chat screen, app icon, notification system, Google Sign-In, wallet onboarding, avatar changing, and metadata context.

## User Review Required

> [!IMPORTANT]
> **Google Sign-In Fallback Notification**: We will display a warning `SnackBar` to the user when Google Sign-In fails and falls back to the developer mock account, making it transparent that the mock user is logged in.
> **App Icon Re-generation**: We will run a python script to pad `Logo.png` to `Logo_padded.png` and run the `flutter_launcher_icons` package to generate the icons.
> **Onboarding Wallet Update**: Instead of creating a duplicate personal wallet, onboarding step 4 will query existing wallets, update the name of the default personal wallet, and post an income transaction to set the initial balance.

---

## Proposed Changes

### 1. Chat Modules (Backend & Frontend)

#### [MODIFY] [ai.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/ai/ai.service.js)
Fix `recentMessages.map is not a function` error by correctly handling the object returned from `chatService.getMessages`.
- Change the call to `chatService.getMessages(userId, sessionId, { limit: 20 })` (wrapped in options object).
- Extract `recentMessages = recentMessagesRes.messages || []` array from the result object before mapping.

#### [MODIFY] [chat_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/chat/chat_screen.dart)
Modify session initialization logic to reuse existing active sessions for a wallet and show the welcome greeting message.
- Add `forceNew` parameter (default `false`) to `ChatScreen` constructor and register it in `app_routes.dart`.
- In `_initSession()`:
  - If `forceNew` is `false` and `widget.sessionId` is null:
    - Query `getChatSessions()`.
    - Find the most recent active chat session matching the wallet (either `widget.walletId` if not null, or the default wallet).
    - If found, set `_sessionId` and `_walletId` and load its messages.
    - If not found (or if `forceNew` is `true`), create a new session, set `_sessionId`, and call `_loadMessagesPage()` immediately to show the mascot's welcome greeting inserted by the backend.

---

### 2. Chat Screen UI and Voice Input

#### [MODIFY] [llm_runner.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/nlg/llm_runner.py)
Allow the dynamic override of `should_run_llm` check via a parameter in `attach_nlg_and_llm`.
- Modify `attach_nlg_and_llm` signature to accept `run_llm: bool | None = None`.
- Evaluate `should_run = run_llm if run_llm is not None else should_run_llm(...)` and return early if false.

#### [MODIFY] [expense_ocr_nlu.py](file:///d:/Luan-Van/Project/app/ai-service/app/adapters/expense_ocr_nlu.py)
- Pass `run_llm=run_llm` parameter down to `llm_runner.attach_nlg_and_llm`.

#### [MODIFY] [app.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/api/app.py)
- Pass `run_llm=run_llm_flag` to `attach_nlg_and_llm`.

#### [MODIFY] [chat_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/chat/chat_screen.dart)
Hide the action buttons once a transaction is successfully saved to improve UI clarity.
- For both `_TxPreviewCard` and the multi-transaction card, if `message.isSaved` is true:
  - Hide the edit/save buttons.
  - Display a teal checkmark badge or banner stating `✓ Đã lưu giao dịch thành công` / `✓ Đã lưu tất cả giao dịch thành công`.

#### [MODIFY] [home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart)
Adjust draft transactions to display the correct title and icon depending on their source.
- Check `tx['source']` for draft card rendering:
  - If `source == 'voice'`, display `'Nhập liệu giọng nói'` and `Icons.mic_none_rounded`.
  - If `source == 'bill'`, display `'Nhập hóa đơn'` and `Icons.receipt_long_rounded`.
  - Else, display `'Giao dịch nháp'` and `Icons.edit_note_rounded`.

#### [MODIFY] [share_wallet_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/wallet/share_wallet_screen.dart)
Store transaction in the correct wallet when taking photos/adding stories from a group wallet screen.
- Set `ApiClient.lastSelectedWalletId = widget.walletId` inside `initState` of `ShareWalletScreen` so any camera/bill input defaults to the current active group wallet.

---

### 3. App Icon Padding

#### [NEW] [pad_logo.py](file:///d:/Luan-Van/Project/pad_logo.py)
Create a helper python script using Pillow to center and scale the original `Logo.png` down to `63%` with a transparent background of the same size, saving it as `Logo_padded.png` in `assets/logo/`.

#### [MODIFY] [pubspec.yaml](file:///d:/Luan-Van/Project/app/frontend/mobile/pubspec.yaml)
- Add `assets/logo/Logo_padded.png` to assets list.
- Update `adaptive_icon_foreground` to `"assets/logo/Logo_padded.png"`.

---

### 4. Push and Local Notifications

#### [MODIFY] [push_notification_service.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/services/push_notification_service.dart)
Fix Android local notification crash and add tapping callback.
- Change `AndroidInitializationSettings` resource name from `'@mipmap/ic_launcher'` to `'@mipmap/launcher_icon'`.
- Accept an optional callback `void Function(String?)? onNotificationTap` in `initialize()`.
- Fire `onNotificationTap` inside `onDidReceiveNotificationResponse`.

#### [MODIFY] [app_shell.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/shell/app_shell.dart)
Enable navigation when tapping notifications.
- When initializing `PushNotificationService`, pass an `onNotificationTap` callback that calls `context.push(payload)` if mounted and valid.

---

### 5. Google Sign-in Fallback Diagnostics

#### [MODIFY] [login_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/auth/login_screen.dart)
Notify user when Google login falls back to mock user on emulators.
- Detect if the google sign-in fails or throws a platform exception.
- Display a warning snackbar notifying the user/developer that Google login failed (due to configuration/emulator) and they are being logged in with the developer mock account.

---

### 6. Onboarding Wallet Creation

#### [MODIFY] [api_client.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/services/api_client.dart)
- Implement `updateWallet(String id, Map<String, dynamic> body)` mapping to `PATCH /wallets/:id`.

#### [MODIFY] [onboarding_screen_4.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/onboarding/onboarding_screen_4.dart)
Update default wallet instead of creating duplicate.
- Call `_api.getWallets()` to fetch existing wallets.
- Find the personal wallet (`type == 'personal'`).
- If found:
  - Call `_api.updateWallet(walletId, {'name': config['name']})`.
  - If `config['balance'] > 0`, insert an initial balance income transaction on that wallet:
    ```dart
    await _api.createTransaction({
      'walletId': walletId,
      'amount': config['balance'],
      'type': 'income',
      'categoryCode': 'Others',
      'note': 'Số dư ban đầu',
      'source': 'manual',
    });
    ```
  - If not found (fallback), call `_api.createWallet(...)` as before.

---

### 7. iOS Photo & Camera Permissions

#### [MODIFY] [Info.plist](file:///d:/Luan-Van/Project/app/frontend/mobile/ios/Runner/Info.plist)
Add usage description keys to prevent iOS crashes on avatar changing.
- Add `NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription` keys.

---

### 8. Metadata Fallback Removal

#### [MODIFY] [context_meta.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/nlg/context_meta.py)
- Remove `profile.get("frequency_week")` fallback for category `frequency_week`, resolving to `cat.get("frequency_week") or 0`.

---

## Verification Plan

### Automated Tests
- Run `npm test` in backend to verify test suite passing.
- Run `pytest` or Python tests in `app/ai-service` and `expense-ocr-nlu` to verify NLU components.
- Run python script to verify logo padding generation.

### Manual Verification
- Launch local development server (`npm run dev`) and Python NLU backend.
- Run Flutter application on Android Emulator / iOS Simulator.
- Verify Google Sign-In fallback warning snackbar.
- Verify onboarding step 4 does not create a duplicate wallet and updates the default wallet with initial balance.
- Verify iOS photos and camera picking permissions don't crash.
- Verify chat welcome greeting appears upon new chat session creation.
- Verify chat screen hides confirm/save buttons when a transaction is saved.
- Verify chat screen reuses existing session when clicking Chat on Home/Wallet screens.
- Run the icon generation script and check if the generated launcher icon fits within the boundaries.
