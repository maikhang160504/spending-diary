import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';

/// Splash screen shown on app launch, then redirects to /login or /app/home
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoAnim;
  late final Animation<double> _titleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _logoAnim = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _titleAnim = CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // Wait minimum splash duration
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final api = ApiClient();
    final loggedIn = await api.isLoggedIn;
    if (!mounted) return;

    if (loggedIn) {
      try {
        final bypassed = await api.checkOnboardingBypassed();
        if (!mounted) return;
        if (bypassed) {
          context.go(AppRoutes.home);
          return;
        }
      } catch (_) {}
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with fade+scale
              FadeTransition(
                opacity: _logoAnim,
                child: ScaleTransition(
                  scale: _logoAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/logo/Logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => const Icon(Icons.savings_outlined, color: AppColors.teal, size: 64),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Title with fade+slide
              FadeTransition(
                opacity: _titleAnim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
                      .animate(_titleAnim),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo/Title.png',
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => const Text(
                        'Spending Diary',
                        style: TextStyle(color: AppColors.teal, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Loading dots
              FadeTransition(
                opacity: _titleAnim,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
