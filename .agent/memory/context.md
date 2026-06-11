# Current Context

> **Last updated**: 2026-06-11

## Current Focus

Discussing and implementing the proposed 4-phase Data Loading & Synchronization optimizations.

## Recent Changes

- Fixed PostgreSQL query syntax for `DISTINCT ON` in [ai.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/ai/ai.service.js) via a clean subquery structure.
- Resolved group wallet story details permission check in [stories.service.js](file:///d:/Luan-Van/Project/app/backend/src/modules/stories/stories.service.js).
- Added in-app notification dismissal and system status bar tray clearing in [share_wallet_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/wallet/share_wallet_screen.dart) using the updated `cancelAll` method in [push_notification_service.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/services/push_notification_service.dart).
- Restricted the group crown icon display exclusively to wallet creators.
- Bypassed manual photo/gallery permission checks in [settings_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/settings/settings_screen.dart) and [camera_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/camera/camera_screen.dart) in favor of native picking.
- Restored home screen wallet context dynamically when returning from group wallet screens and added a **Ví lưu** selector dropdown in [camera_confirm_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/camera/camera_confirm_screen.dart).
- Avoided layout shifts on chat transaction card updates by disabling the Save action button and updating its text instead of hiding it.
- Drafted a 4-phase data loading optimization and local database syncing architecture proposal in [implementation_plan.md](file:///C:/Users/LENOVO/.gemini/antigravity-ide/brain/8d091fd1-8aa9-488a-ba5e-44b3c160a6fa/implementation_plan.md).

## Next Steps

1. Initiate implementation of Phase 1 (Query Caching in Group/Shared Wallets using `cached_query`) and Phase 2 (WebSocket update signals).
2. Gather user feedback on pagination and local database sync designs (Drift/SQLite vs Hive).

## Active Work

- **Branch**: `main` (active local environment)
- **Features in progress**: None.
- **Blockers**: None.
