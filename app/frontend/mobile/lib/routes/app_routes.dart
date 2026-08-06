import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'lottie_transition_page.dart';
import '../services/api_client.dart';
import '../services/bill_processing_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/verify_otp_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/banned_screen.dart';
import '../screens/camera/camera_confirm_screen.dart';
import '../screens/camera/camera_input_screen.dart';
import '../screens/camera/camera_screen.dart';
import '../screens/chat/chat_history_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/goals/goal_detail_screen.dart';
import '../screens/financial_tools/financial_tools_screen.dart';
import '../screens/home/home_calendar_screen.dart';
import '../screens/home/home_gallery_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/limits/limits_screen.dart';
import '../screens/onboarding/onboarding_screen_1.dart';
import '../screens/onboarding/onboarding_screen_2.dart';
import '../screens/onboarding/onboarding_screen_3.dart';
import '../screens/onboarding/onboarding_screen_4.dart';
import '../screens/report/report_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/recurring_rules_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/story/detail_story_screen.dart';
import '../screens/streak/streak_screen.dart';
import '../screens/wallet/share_wallet_screen.dart';
import '../screens/group/group_analytics_screen.dart';
import '../screens/premium/premium_payment_screen.dart';

/// Tất cả tên route tập trung tại đây
class AppRoutes {
  // Auth / Onboarding
  static const splash = '/splash';
  static const onboarding = '/';
  static const onboardingStep2 = '/onboarding/step-2';
  static const onboardingStep3 = '/onboarding/step-3';
  static const onboardingStep4 = '/onboarding/step-4';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const banned = '/banned';
  static const verifyOtp = '/verify-otp';
  static const resetPassword = '/reset-password';

  // Shell tabs
  static const home = '/app/home';
  static const report = '/app/report';
  static const goals = '/app/goals';
  static const settings = '/app/settings';

  // Home sub-views
  static const homeGallery = '/app/home/gallery';
  static const homeCalendar = '/app/home/calendar';

  // Camera
  static const camera = '/camera';
  static const cameraInput = '/camera/input';
  static const cameraConfirm = '/camera/confirm';

  // Chat
  static const chat = '/chat';
  static const chatHistory = '/chat/history';

  // Full-screen overlays
  static const limits = '/limits';
  static const shareWallet = '/wallet/share';
  static const streak = '/streak';
  static const storyDetail = '/story/:storyId';
  static const goalDetail = '/app/goals/:goalId';
  static const recurring = '/recurring';
  static const groupAnalytics = '/group-analytics/:walletId';

  // Premium
  static const premiumPayment = '/premium/payment';

  /// Build the story detail path with a real [storyId]
  static String storyDetailOf(String storyId) => '/story/$storyId';

  /// Build the goal detail path with a real [goalId]
  static String goalDetailOf(String goalId) => '/app/goals/$goalId';

  /// Build the group analytics path with a real [walletId]
  static String groupAnalyticsOf(String walletId) =>
      '/group-analytics/$walletId';
}

/// Helper function to build a page with a Lottie transition
Page<dynamic> _lottiePage(
  GoRouterState state,
  String lottiePath,
  Widget child,
) {
  return LottieTransitionPage(
    key: state.pageKey,
    lottiePath: lottiePath,
    child: child,
  );
}

/// Helper function to build a page with a slide transition
Page<dynamic> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
  );
}

/// go_router instance — được dùng trong MaterialApp.router
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  redirect: (context, state) async {
    final protectedPrefixes = [
      '/app/',
      '/camera',
      '/chat',
      '/limits',
      '/wallet',
      '/streak',
      '/story',
      '/recurring',
      '/premium',
    ];

    final isOnboarding =
        state.matchedLocation == AppRoutes.onboarding ||
        state.matchedLocation == AppRoutes.onboardingStep2 ||
        state.matchedLocation == AppRoutes.onboardingStep3 ||
        state.matchedLocation == AppRoutes.onboardingStep4;

    final api = ApiClient();
    bool loggedIn = await api.isLoggedIn;

    if (isOnboarding && loggedIn) {
      final bypassed = await api.checkOnboardingBypassed();
      if (bypassed) {
        return AppRoutes.home;
      }
      // Re-evaluate loggedIn in case checkOnboardingBypassed cleared tokens due to 401
      loggedIn = await api.isLoggedIn;
    }

    final isProtected =
        isOnboarding ||
        protectedPrefixes.any((p) => state.matchedLocation.startsWith(p));

    if (!isProtected) return null;
    if (!loggedIn) return AppRoutes.login;
    return null;
  },
  routes: [
    // ── Splash ──────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.splash,
      pageBuilder: (context, state) => _lottiePage(
        state,
        'assets/animations/Loading.json',
        const SplashScreen(),
      ),
    ),

    // ── Auth / Onboarding ────────────────────────────────────
    GoRoute(
      path: AppRoutes.onboarding,
      pageBuilder: (context, state) => _lottiePage(
        state,
        'assets/animations/Loading.json',
        const OnboardingStep1(),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboardingStep2,
      pageBuilder: (context, state) =>
          _slidePage(state, const OnboardingStep2()),
    ),
    GoRoute(
      path: AppRoutes.onboardingStep3,
      pageBuilder: (context, state) =>
          _slidePage(state, const OnboardingStep3()),
    ),
    GoRoute(
      path: AppRoutes.onboardingStep4,
      pageBuilder: (context, state) =>
          _slidePage(state, const OnboardingStep4()),
    ),
    GoRoute(
      path: AppRoutes.login,
      pageBuilder: (context, state) => _lottiePage(
        state,
        'assets/animations/Loading.json',
        const LoginScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.register,
      pageBuilder: (context, state) => _lottiePage(
        state,
        'assets/animations/Loading.json',
        const RegisterScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.verifyOtp,
      pageBuilder: (context, state) => LottieTransitionPage(
        key: state.pageKey,
        lottiePath: 'assets/animations/Loading.json',
        child: VerifyOtpScreen(email: (state.extra as String?) ?? ''),
      ),
    ),
    GoRoute(
      path: AppRoutes.banned,
      pageBuilder: (context, state) {
        String? banReason;
        Map<String, dynamic>? initialAppeal;
        if (state.extra is String) {
          banReason = state.extra as String;
        } else if (state.extra is Map) {
          final map = state.extra as Map;
          banReason = map['banReason'] as String?;
          if (map['appeal'] is Map<String, dynamic>) {
            initialAppeal = map['appeal'] as Map<String, dynamic>;
          }
        }
        return LottieTransitionPage(
          key: state.pageKey,
          lottiePath: 'assets/animations/Loading.json',
          child: BannedScreen(
            banReason: banReason,
            initialAppeal: initialAppeal,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.resetPassword,
      builder: (context, state) {
        final resetToken = state.extra as String? ?? '';
        return ResetPasswordScreen(resetToken: resetToken);
      },
    ),

    // ── Shell (bottom nav) ───────────────────────────────────
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: AppRoutes.report,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ReportScreen()),
        ),
        GoRoute(
          path: AppRoutes.goals,
          pageBuilder: (context, state) {
            final tabParam = state.uri.queryParameters['tab'];
            int initialTab = 0;
            if (tabParam == 'challenge' ||
                tabParam == '1' ||
                tabParam == 'thuthach') {
              initialTab = 1;
            } else if (tabParam == 'loans' ||
                tabParam == '2' ||
                tabParam == 'vaymuon') {
              initialTab = 2;
            }
            final joinCode = state.uri.queryParameters['code'];
            return NoTransitionPage(
              child: FinancialToolsScreen(
                initialTabIndex: initialTab,
                initialJoinCode: joinCode,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),

    // Deep link routes for challenge and loans
    GoRoute(
      path: '/challenge',
      redirect: (context, state) {
        final code = state.uri.queryParameters['code'];
        return '${AppRoutes.goals}?tab=challenge${code != null ? '&code=$code' : ''}';
      },
    ),
    GoRoute(
      path: '/loans',
      redirect: (context, state) => '${AppRoutes.goals}?tab=loans',
    ),

    // ── Home sub-views ───────────────────────────────────────
    GoRoute(
      path: AppRoutes.homeGallery,
      builder: (context, state) => const HomeGalleryScreen(),
    ),
    GoRoute(
      path: AppRoutes.homeCalendar,
      builder: (context, state) => const HomeCalendarScreen(),
    ),

    // ── Camera ──────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.camera,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CameraScreen(
          returnOnlyImagePath: extra?['returnOnlyImagePath'] as bool? ?? false,
          walletId: extra?['walletId'] as String?,
          initialMode: extra?['initialMode'] as String?,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.cameraInput,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CameraInputScreen(
          imagePath: extra?['imagePath'] as String?,
          isBill: extra?['isBill'] as bool? ?? false,
          walletId: extra?['walletId'] as String?,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.cameraConfirm,
      builder: (context, state) {
        final extra =
            state.extra as Map<String, dynamic>? ??
            BillProcessingService.instance.takePendingReviewExtra();
        return CameraConfirmScreen(extractedData: extra);
      },
    ),

    // ── Chat ────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.chat,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _slidePage(
          state,
          ChatScreen(
            sessionId: extra?['sessionId'] as String?,
            walletId: extra?['walletId'] as String?,
            forceNew: extra?['forceNew'] as bool? ?? false,
            initialMessage: extra?['initialMessage'] as String?,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.chatHistory,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _slidePage(
          state,
          ChatHistoryScreen(walletId: extra?['walletId'] as String?),
        );
      },
    ),

    // ── Overlays / Full-screen ───────────────────────────────
    GoRoute(
      path: AppRoutes.limits,
      builder: (context, state) {
        final catCode = state.uri.queryParameters['categoryCode'];
        return LimitsScreen(initialCategoryCode: catCode);
      },
    ),
    GoRoute(
      path: AppRoutes.recurring,
      builder: (context, state) => const RecurringRulesScreen(),
    ),
    GoRoute(
      path: AppRoutes.shareWallet,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ShareWalletScreen(walletId: extra?['walletId'] as String?);
      },
    ),
    GoRoute(
      path: AppRoutes.groupAnalytics,
      builder: (context, state) {
        return GroupAnalyticsScreen(
          walletId: state.pathParameters['walletId'] ?? '',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.streak,
      pageBuilder: (context, state) => _lottiePage(
        state,
        'assets/animations/Fire.json',
        const StreakScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.storyDetail,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return DetailStoryScreen(
          storyId: state.pathParameters['storyId'] ?? '',
          storyIds: (extra?['storyIds'] as List?)?.cast<String>(),
          initialIndex: extra?['initialIndex'] as int? ?? 0,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.goalDetail,
      pageBuilder: (context, state) => _lottiePage(
        state,
        'assets/animations/Success_goal.json',
        GoalDetailScreen(goalId: state.pathParameters['goalId'] ?? ''),
      ),
    ),
    GoRoute(
      path: AppRoutes.premiumPayment,
      builder: (context, state) => const PremiumPaymentScreen(),
    ),
  ],
);
