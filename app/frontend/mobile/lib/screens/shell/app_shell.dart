import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/bill_processing_service.dart';
import '../../services/chat_llm_notifier.dart';
import '../../services/transaction_notifier.dart';
import '../../services/push_notification_service.dart';
import '../../services/fcm_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../widgets/mimo_overlay.dart';
import '../../widgets/notification_overlay.dart';
import '../../widgets/bill_processing_banner.dart';
import '../../widgets/ai_popup_menu.dart';
import '../../widgets/premium_upsell_bottom_sheet.dart';
import '../../services/ads_service.dart';

/// AppShell wraps the 4 ShellRoute tabs + persistent bottom nav + MiMo overlay + Notification banner
class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  final _api = ApiClient();
  bool _showAiPopup = false;
  final GlobalKey<AiAssistantPopupMenuState> _aiPopupKey = GlobalKey<AiAssistantPopupMenuState>();

  @override
  void initState() {
    super.initState();
    AdsService.instance.initialize();
    AdsService.instance.onAdTriggered.listen((_) {
      if (mounted) {
        showPremiumUpsellSheet(context);
        AdsService.instance.resetTime();
      }
    });
    mimoController.addListener(_onMiMoChanged);
    inAppNotificationController.addListener(_onNotificationChanged);
    BillProcessingService.instance.addListener(_onBillJobsChanged);
    BillProcessingService.instance.onNavigate = (route, [extra]) {
      if (!mounted) return;
      try {
        if (extra != null) {
          context.push(route, extra: extra);
        } else {
          context.push(route);
        }
      } catch (e) {
        debugPrint('[BillProcessing] Navigation failed: $e');
      }
    };
    _connectWebSocket();
    _requestPermissions();
    PushNotificationService.instance.initialize(
      onNotificationTap: (payload) {
        if (mounted && payload != null && payload.isNotEmpty) {
          try {
            context.push(payload);
          } catch (e) {
            debugPrint('[Notification] Navigation failed: $e');
          }
        }
      },
    );
    _initFcm();
  }

  Future<void> _initFcm() async {
    await FcmService.instance.initialize(
      registerToken: (token, platform) =>
          _api.registerFcmToken(token, platform),
      removeToken: (token) => _api.removeFcmToken(token),
      onDeepLink: (deepLink) {
        if (mounted && deepLink.isNotEmpty) {
          try {
            context.push(deepLink);
          } catch (e) {
            debugPrint('[FCM] Navigation failed: $e');
          }
        }
      },
    );
  }

  @override
  void dispose() {
    mimoController.removeListener(_onMiMoChanged);
    inAppNotificationController.removeListener(_onNotificationChanged);
    BillProcessingService.instance.removeListener(_onBillJobsChanged);
    BillProcessingService.instance.onNavigate = null;
    _wsSub?.cancel();
    _reconnectTimer?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  void _onMiMoChanged() => setState(() {});
  void _onNotificationChanged() => setState(() {});
  void _onBillJobsChanged() => setState(() {});

  bool _isAndroid13OrHigher() {
    if (!Platform.isAndroid) return false;
    try {
      final versionString = Platform.operatingSystemVersion.toLowerCase();
      final apiMatch = RegExp(r'api\s+(\d+)').firstMatch(versionString);
      if (apiMatch != null) {
        final apiLevel = int.parse(apiMatch.group(1)!);
        return apiLevel >= 33;
      }
      final androidMatch = RegExp(r'android\s+(\d+)').firstMatch(versionString);
      if (androidMatch != null) {
        final androidVersion = int.parse(androidMatch.group(1)!);
        return androidVersion >= 13;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _requestPermissions() async {
    try {
      final List<Permission> permissions = [
        Permission.camera,
        Permission.microphone,
        Permission.notification,
      ];

      if (Platform.isAndroid) {
        if (_isAndroid13OrHigher()) {
          permissions.add(Permission.photos);
        } else {
          permissions.add(Permission.storage);
        }
      } else {
        permissions.add(Permission.photos);
      }

      await permissions.request();
    } catch (e) {
      debugPrint('[Permission] Error requesting permissions: $e');
    }
  }

  Future<void> _connectWebSocket() async {
    _wsSub?.cancel();
    _reconnectTimer?.cancel();
    try {
      final token = await _api.accessToken;
      if (token == null) {
        _scheduleReconnect();
        return;
      }
      final wsUrl = Uri.parse(
        '${_api.baseUrl.replaceFirst(RegExp(r'^http'), 'ws').replaceFirst('/api/v1', '')}/ws?token=$token',
      );
      _wsChannel = WebSocketChannel.connect(wsUrl);
      _reconnectAttempt = 0; // Reset on successful connection
      debugPrint('[WebSocket] Connected successfully');
      // Request any missed events since last disconnect
      _wsChannel!.sink.add(jsonEncode({'type': 'SYNC_STATUS'}));
      _wsSub = _wsChannel!.stream.listen(
        (msg) {
          try {
            final json = jsonDecode(msg as String) as Map<String, dynamic>;
            if (json['type'] == 'BUDGET_ALERT') {
              final payload = json['payload'] as Map<String, dynamic>? ?? {};
              final title = payload['title'] as String? ?? 'Cảnh báo ngân sách';
              final message = payload['message'] as String? ?? '';
              final deepLink = payload['deepLink'] as String? ?? '/chat';
              inAppNotificationController.show(
                InAppNotification(
                  title: title,
                  message: message,
                  deepLink: deepLink,
                  actionLabel: '💬 Chat AI tư vấn',
                  onAction: () {
                    context.push(deepLink);
                  },
                ),
              );
              PushNotificationService.instance.showNotification(
                id: 1,
                title: title,
                body: message,
                payload: deepLink,
              );
            } else if (json['type'] == 'transaction_done') {
              final txId = json['transactionId'] as String?;
              final data = json['data'] as Map<String, dynamic>? ?? {};
              if (txId != null) {
                BillProcessingService.instance.handleWsTransactionDone(txId, data);
              }
            } else if (json['type'] == 'transaction_failed') {
              final txId = json['transactionId'] as String?;
              final error = json['error']?.toString();
              if (txId != null) {
                BillProcessingService.instance.handleWsTransactionFailed(txId, error);
              }
            } else if (json['type'] == 'chat_llm_update') {
              final sessionId = json['sessionId'] as String?;
              final messageId = json['messageId'] as String?;
              if (sessionId != null && messageId != null) {
                notifyChatLlmUpdate(
                  ChatLlmUpdate(
                    sessionId: sessionId,
                    messageId: messageId,
                    content: json['content'] as String?,
                    mood: json['mood'] as String?,
                    failed: json['failed'] == true,
                    intentAction: json['intentAction'] as Map<String, dynamic>?,
                  ),
                );
              }
            } else if (json['type'] == 'RECURRING_ALERT') {
              final payload = json['payload'] as Map<String, dynamic>? ?? {};
              final title = payload['title'] as String? ?? 'Giao dịch định kỳ';
              final message = payload['message'] as String? ?? '';
              final deepLink = payload['deepLink'] as String? ?? '/';
              
              // Cập nhật UI ngay lập tức
              notifyTransactionChanged();
              
              inAppNotificationController.show(
                InAppNotification(
                  title: title,
                  message: message,
                  deepLink: deepLink,
                  actionLabel: 'Xem ví',
                  onAction: () {
                    context.push(deepLink);
                  },
                ),
              );
              PushNotificationService.instance.showNotification(
                id: DateTime.now().millisecondsSinceEpoch % 100000,
                title: title,
                body: message,
                payload: deepLink,
              );
            }
          } catch (e) {
            debugPrint('[WebSocket] Error parsing message: $e');
          }
        },
        onError: (err) {
          debugPrint('[WebSocket] Error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[WebSocket] Closed');
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[WebSocket] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!mounted) return;
    // Exponential backoff: 2^attempt * 1000ms + random jitter (0..1000ms), capped at 60s
    final baseDelay = math.min(math.pow(2, _reconnectAttempt).toInt() * 1000, 60000);
    final jitter = math.Random().nextInt(1000);
    final delay = Duration(milliseconds: baseDelay + jitter);
    debugPrint('[WebSocket] Reconnect attempt ${_reconnectAttempt + 1} in ${delay.inMilliseconds}ms');
    _reconnectAttempt++;
    _reconnectTimer = Timer(delay, _connectWebSocket);
  }

  static int _tabIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith(AppRoutes.report))   return 1;
    if (loc.startsWith(AppRoutes.goals))    return 2;
    if (loc.startsWith(AppRoutes.settings)) return 3;
    return 0;
  }

  void _onTabTap(BuildContext context, int index) {
    shellNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    const routes = [AppRoutes.home, AppRoutes.report, AppRoutes.goals, AppRoutes.settings];
    context.go(routes[index]);
  }

  void _onFabTap(BuildContext context) {
    if (_showAiPopup) {
      if (_aiPopupKey.currentState != null) {
        _aiPopupKey.currentState!.closePopup();
      } else {
        setState(() => _showAiPopup = false);
      }
    } else {
      setState(() => _showAiPopup = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _tabIndex(context);
    final billJobs = BillProcessingService.instance.activeJobs;
    final topInset = MediaQuery.of(context).padding.top;
    final hasInAppNotification = inAppNotificationController.current != null;
    final billBannerTop = topInset + 12 + (hasInAppNotification ? 92 : 0);

    final mainContent = Stack(
      children: [
        widget.child,
        if (billJobs.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            top: billBannerTop,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: billJobs.map((job) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BillProcessingBanner(
                    job: job,
                    onDismiss: job.phase == BillJobPhase.failed
                        ? () => BillProcessingService.instance.dismissJob(job.transactionId)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        // MiMo overlay — góc phải dưới, ngay trên nav bar
        if (mimoController.current != null)
          Positioned(
            right: 12,
            bottom: 88,
            child: MiMoOverlay(
              response: mimoController.current!,
              onDismiss: mimoController.dismiss,
            ),
          ),
        // In-App Floating Notification Banner — Top center of the screen
        if (inAppNotificationController.current != null)
          Positioned(
            top: topInset + 12,
            left: 16,
            right: 16,
            child: InAppNotificationBanner(
              notification: inAppNotificationController.current!,
              onDismiss: inAppNotificationController.dismiss,
            ),
          ),
        // AI Assistant Speed Dial Popup overlay
        if (_showAiPopup)
          Positioned.fill(
            child: AiAssistantPopupMenu(
              key: _aiPopupKey,
              onClose: () {
                setState(() {
                  _showAiPopup = false;
                });
              },
              onSelectBill: () {
                context.push(
                  AppRoutes.camera,
                  extra: {
                    'walletId': ApiClient.lastSelectedWalletId,
                    'initialMode': 'Bill',
                  },
                );
              },
              onSelectPhotoText: () {
                context.push(
                  AppRoutes.camera,
                  extra: {
                    'walletId': ApiClient.lastSelectedWalletId,
                    'initialMode': 'Ảnh',
                  },
                );
              },
              onSelectChat: () {
                context.push(
                  AppRoutes.chat,
                  extra: {'walletId': ApiClient.lastSelectedWalletId},
                );
              },
            ),
          ),
      ],
    );

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 600;

      if (isWide) {
        return Scaffold(
          backgroundColor: context.palette.bg,
          body: Row(
            children: [
              NavigationRail(
                backgroundColor: context.palette.card,
                selectedIndex: currentIndex,
                onDestinationSelected: (idx) => _onTabTap(context, idx),
                labelType: NavigationRailLabelType.all,
                selectedLabelTextStyle: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                unselectedLabelTextStyle: TextStyle(color: context.palette.muted, fontSize: 12),
                selectedIconTheme: IconThemeData(color: AppColors.teal),
                unselectedIconTheme: IconThemeData(color: context.palette.muted),
                leading: Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 16),
                  child: FloatingActionButton(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    onPressed: () => _onFabTap(context),
                    child: const Icon(Icons.add),
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Trang chủ')),
                  NavigationRailDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: Text('Báo cáo')),
                  NavigationRailDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings_rounded), label: Text('Công cụ')),
                  NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: Text('Cài đặt')),
                ],
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: mainContent),
            ],
          ),
        );
      }

      return Scaffold(
        backgroundColor: context.palette.bg,
        body: mainContent,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.palette.card,
            border: Border(top: BorderSide(color: context.palette.border, width: 1)),
            boxShadow: [BoxShadow(color: context.palette.shadow, blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 72,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    children: [
                      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Trang chủ', isActive: currentIndex == 0, onTap: () => _onTabTap(context, 0)),
                      _NavItem(icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, label: 'Báo cáo', isActive: currentIndex == 1, onTap: () => _onTabTap(context, 1)),
                      const Expanded(child: SizedBox()), // gap for FAB
                      _NavItem(icon: Icons.savings_outlined, activeIcon: Icons.savings_rounded, label: 'Công cụ', isActive: currentIndex == 2, onTap: () => _onTabTap(context, 2)),
                      _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Cài đặt', isActive: currentIndex == 3, onTap: () => _onTabTap(context, 3)),
                    ],
                  ),
                  Positioned(
                    top: -22,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _AnimatedFab(onTap: () => _onFabTap(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ── Nav Item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.teal : context.palette.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(isActive ? activeIcon : icon, color: color, size: 26, key: ValueKey(isActive)),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: color),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}

// ── Animated FAB (SH-02) ─────────────────────────────────────────────────────

class _AnimatedFab extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedFab({required this.onTap});

  @override
  State<_AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<_AnimatedFab> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _rotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: context.palette.card,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            )
          ],
        ),
        child: Center(
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: AnimatedBuilder(
              animation: _rotation,
              builder: (_, child) => Transform.rotate(
                angle: _rotation.value * 0.785398, // 45 degrees
                child: child,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

