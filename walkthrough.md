# Walkthrough — Phase 8: Mobile API Wiring

## Summary

Phase 8 replaced mock data with real API calls across **7 mobile screens**. The app now communicates with the backend for all core flows: auth, wallets, transactions, budgets, goals, settings, chat, and stats.

## Screens Modified

### 1. Home Screen ([home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart))

| Feature | Before | After |
|---------|--------|-------|
| Username | Hardcoded "bạn" | `GET /auth/me` → user.username |
| Balance | Static 4.500.000 đ | `GET /stats/dashboard` → totalIncome - totalExpense |
| Wallets | 3 hardcoded chips | `GET /wallets` → dynamic list |
| Story tab | MockData.storyCards | `GET /transactions` → `_TransactionStoryCard` |
| Loading | None | `SkeletonCard` shimmer placeholders |
| Error | None | `ErrorBanner` with retry |
| Refresh | None | `RefreshIndicator` pull-to-refresh |

### 2. Register Screen ([register_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/auth/register_screen.dart))

- Added `TextEditingController` for email, password, confirm
- Field-level validation: email format, ≥8 chars, confirm match
- Calls `ApiClient.register()` with loading spinner
- Error banner for API failures (e.g., EMAIL_EXISTS)

### 3. Settings Screen ([settings_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/settings/settings_screen.dart))

- Loads profile from `GET /auth/me` + preferences from `GET /users/me/settings`
- Avatar shows first letter with deterministic color
- AI personality synced: "Dui Dẻ" ↔ funny, "Dận Dữ" ↔ strict
- Toggle notifications/dark mode → `PATCH /users/me/settings`
- Logout calls `ApiClient.logout()` then navigates to login

### 4. Goals Screen ([goal_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/goals/goal_screen.dart))

- Loads goals from `GET /goals` with loading/empty states
- Create goal bottom sheet → `POST /goals`
- Contribute money bottom sheet → `POST /goals/:id/contribute`
- Completed goals show 🎉 badge + green progress bar

### 5. Limits/Budgets Screen ([limits_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/limits/limits_screen.dart))

- Loads budgets from `GET /budgets` with `CategoryTheme` styling
- Dynamic warning banner for first category ≥85% spent
- Add budget with category dropdown → `POST /budgets`
- Summary chips show total budget / total spent from real data

### 6. Chat Screen ([chat_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/chat/chat_screen.dart))

- Full StatefulWidget rewrite with real-time messaging
- Creates session via `POST /chat/sessions`
- Sends user text to `POST /ai/nlu` for AI response
- **Record intent** → transaction preview card with "💾 Lưu giao dịch" button
- Typing indicator with animated dots while AI processes
- Quick chips are now tappable (Phở 50k, Cafe 35k, etc.)

### 7. Report Screen ([report_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/report/report_screen.dart))

- Total card shows real `totalExpense`/`totalIncome` from `GET /stats/dashboard`
- Dynamic % of income calculation with colored arrow indicator
- RefreshIndicator for pull-to-refresh
- Charts still use MockData (pending per-category breakdown API)

## Dependency Fix

Fixed `google_fonts: ^9.1.0` (not published) → `^6.3.3` in [pubspec.yaml](file:///d:/Luan-Van/Project/app/frontend/mobile/pubspec.yaml).

## Analyzer Results

```
flutter analyze → 0 errors, ~5 warnings (all pre-existing unused imports in widget files), 8 infos
```

## What Remains Mock

| Component | Why Mock | Needs |
|-----------|----------|-------|
| Gallery tab | No image URLs from API | Stories API with image attachments |
| Calendar tab | Grouped by day view | Transaction-by-day aggregation API |
| Bar/Donut/Trend charts | No per-category/per-day breakdown | `GET /stats/by-category`, `GET /stats/by-day` |
| TopCategoryCard | Hardcoded | Sorted category breakdown from API |

## Next Steps

The highest-impact remaining work is:
1. **Phase 9**: Camera + AI OCR flow (real hardware capture → bill parsing)
2. **Phase 10**: Chat history + mascot polish
3. **Phase 11**: Add Transaction screen, Detail Story, Streak, Onboarding persist
