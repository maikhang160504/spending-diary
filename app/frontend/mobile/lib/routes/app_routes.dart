import 'package:flutter/material.dart';

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

class AppRoutes {
  static const onboarding = '/';
  static const onboardingStep2 = '/onboarding/step-2';
  static const onboardingStep3 = '/onboarding/step-3';
  static const onboardingStep4 = '/onboarding/step-4';
  static const onboardingStep5 = '/onboarding/step-5';
  static const login = '/login';
  static const register = '/register';
  static const shell = '/app';

  static const home = '/home';
  static const homeCalendar = '/home/calendar';
  static const homeGallery = '/home/gallery';
  static const camera = '/camera';
  static const cameraInput = '/camera/input';
  static const cameraConfirm = '/camera/confirm';
  static const chat = '/chat';
  static const chatHistory = '/chat/history';
  static const goals = '/goals';
  static const shareWallet = '/wallet/share';
  static const streak = '/streak';
  static const settings = '/settings';
  static const report = '/report';
  static const storyDetail = '/story/detail';

  static final Map<String, WidgetBuilder> routes = {
    onboarding: (context) => const OnboardingStep1(),
    onboardingStep2: (context) => const OnboardingStep2(),
    onboardingStep3: (context) => const OnboardingStep3(),
    onboardingStep4: (context) => const OnboardingStep4(),
    onboardingStep5: (context) => const OnboardingStep5(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    shell: (context) => const AppShell(),
    home: (context) => const HomeScreen(),
    homeCalendar: (context) => const HomeCalendarScreen(),
    homeGallery: (context) => const HomeGalleryScreen(),
    camera: (context) => const CameraScreen(),
    cameraInput: (context) => const CameraInputScreen(),
    cameraConfirm: (context) => const CameraConfirmScreen(),
    chat: (context) => const ChatScreen(),
    chatHistory: (context) => const ChatHistoryScreen(),
    goals: (context) => const GoalScreen(),
    shareWallet: (context) => const ShareWalletScreen(),
    streak: (context) => const StreakScreen(),
    settings: (context) => const SettingsScreen(),
    report: (context) => const ReportScreen(),
    storyDetail: (context) => const DetailStoryScreen(),
  };
}
