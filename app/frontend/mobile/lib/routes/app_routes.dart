import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/camera/camera_confirm_screen.dart';
import '../screens/camera/camera_input_screen.dart';
import '../screens/camera/camera_screen.dart';
import '../screens/chat/chat_history_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/goals/goal_screen.dart';
import '../screens/home/home_calendar_screen.dart';
import '../screens/home/home_gallery_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/limits/limits_screen.dart';
import '../screens/onboarding/onboarding_screen_1.dart';
import '../screens/onboarding/onboarding_screen_2.dart';
import '../screens/onboarding/onboarding_screen_3.dart';
import '../screens/onboarding/onboarding_screen_4.dart';
import '../screens/onboarding/onboarding_screen_5.dart';
import '../screens/report/report_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/story/detail_story_screen.dart';
import '../screens/streak/streak_screen.dart';
import '../screens/wallet/share_wallet_screen.dart';
import '../screens/add/add_transaction_screen.dart';

/// Tất cả tên route tập trung tại đây
class AppRoutes {
  // Auth / Onboarding
  static const onboarding      = '/';
  static const onboardingStep2 = '/onboarding/step-2';
  static const onboardingStep3 = '/onboarding/step-3';
  static const onboardingStep4 = '/onboarding/step-4';
  static const onboardingStep5 = '/onboarding/step-5';
  static const login           = '/login';
  static const register        = '/register';

  // Shell tabs
  static const home     = '/app/home';
  static const report   = '/app/report';
  static const goals    = '/app/goals';
  static const settings = '/app/settings';

  // Home sub-views
  static const homeGallery  = '/app/home/gallery';
  static const homeCalendar = '/app/home/calendar';

  // Camera
  static const camera        = '/camera';
  static const cameraInput   = '/camera/input';
  static const cameraConfirm = '/camera/confirm';

  // Chat
  static const chat        = '/chat';
  static const chatHistory = '/chat/history';

  // Full-screen overlays
  static const limits         = '/limits';
  static const shareWallet    = '/wallet/share';
  static const streak         = '/streak';
  static const storyDetail    = '/story/:storyId';
  static const addTransaction = '/add';

  /// Build the story detail path with a real [storyId]
  static String storyDetailOf(String storyId) => '/story/$storyId';
}

/// go_router instance — được dùng trong MaterialApp.router
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.onboarding,
  routes: [
    // ── Auth / Onboarding ────────────────────────────────────
    GoRoute(path: AppRoutes.onboarding,      builder: (context, state) => const OnboardingStep1()),
    GoRoute(path: AppRoutes.onboardingStep2, builder: (context, state) => const OnboardingStep2()),
    GoRoute(path: AppRoutes.onboardingStep3, builder: (context, state) => const OnboardingStep3()),
    GoRoute(path: AppRoutes.onboardingStep4, builder: (context, state) => const OnboardingStep4()),
    GoRoute(path: AppRoutes.onboardingStep5, builder: (context, state) => const OnboardingStep5()),
    GoRoute(path: AppRoutes.login,           builder: (context, state) => const LoginScreen()),
    GoRoute(path: AppRoutes.register,        builder: (context, state) => const RegisterScreen()),

    // ── Shell (bottom nav) ───────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: AppRoutes.home,     builder: (context, state) => const HomeScreen()),
        GoRoute(path: AppRoutes.report,   builder: (context, state) => const ReportScreen()),
        GoRoute(path: AppRoutes.goals,    builder: (context, state) => const GoalScreen()),
        GoRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsScreen()),
      ],
    ),

    // ── Home sub-views ───────────────────────────────────────
    GoRoute(path: AppRoutes.homeGallery,  builder: (context, state) => const HomeGalleryScreen()),
    GoRoute(path: AppRoutes.homeCalendar, builder: (context, state) => const HomeCalendarScreen()),

    // ── Camera ──────────────────────────────────────────────
    GoRoute(path: AppRoutes.camera,        builder: (context, state) => const CameraScreen()),
    GoRoute(path: AppRoutes.cameraInput,   builder: (context, state) => const CameraInputScreen()),
    GoRoute(
      path: AppRoutes.cameraConfirm,
      builder: (context, state) => CameraConfirmScreen(
        extractedData: state.extra as Map<String, dynamic>?,
      ),
    ),

    // ── Chat ────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.chat,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ChatScreen(sessionId: extra?['sessionId'] as String?);
      },
    ),
    GoRoute(path: AppRoutes.chatHistory, builder: (context, state) => const ChatHistoryScreen()),

    // ── Overlays / Full-screen ───────────────────────────────
    GoRoute(path: AppRoutes.limits,         builder: (context, state) => const LimitsScreen()),
    GoRoute(path: AppRoutes.shareWallet,    builder: (context, state) => const ShareWalletScreen()),
    GoRoute(path: AppRoutes.streak,         builder: (context, state) => const StreakScreen()),
    GoRoute(
      path: AppRoutes.storyDetail,
      builder: (context, state) => DetailStoryScreen(
        storyId: state.pathParameters['storyId'] ?? '',
      ),
    ),
    GoRoute(path: AppRoutes.addTransaction, builder: (context, state) => const AddTransactionScreen()),
  ],
);
