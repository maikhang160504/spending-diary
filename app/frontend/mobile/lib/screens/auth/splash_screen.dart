import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../widgets/spend_diary_wordmark.dart';

/// Splash: icon cuốn sổ + wordmark SpendDiary cùng xuất hiện trên 1 màn hình.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _master;

  // Logo 0–50% (xuất hiện nhanh, giữ nguyên)
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoShimmer;

  // Wordmark 15–70% (fade in ngay sau logo, cùng hiển thị)
  late final Animation<double> _wordOpacity;
  late final Animation<double> _wordScale;
  late final Animation<double> _wordBlur;
  late final Animation<double> _wordTextShimmer;
  late final Animation<double> _leafWiggle;
  late final Animation<double> _wordGlow;

  static const _bg = Color(0xFFF8FFFE);

  @override
  void initState() {
    super.initState();
    _master = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    // Logo: scale nhẹ từ 0.85 → 1.0, giữ nguyên không biến mất
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.05), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _master, curve: Curves.easeOutCubic));

    _logoOpacity = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
    );

    _logoShimmer = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.10, 0.35, curve: Curves.easeInOut),
    );

    // Wordmark: xuất hiện sớm hơn, cùng lúc với logo (không chờ logo biến mất)
    _wordOpacity = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
    );

    _wordScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _master, curve: const Interval(0.15, 0.50, curve: Curves.easeOutCubic)),
    );

    _wordBlur = Tween<double>(begin: 6, end: 0).animate(
      CurvedAnimation(parent: _master, curve: const Interval(0.15, 0.50, curve: Curves.easeOut)),
    );

    _wordTextShimmer = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.50, 0.75, curve: Curves.easeInOut),
    );

    _leafWiggle = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.65, 0.85, curve: Curves.elasticOut),
    );

    _wordGlow = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
    );

    _master.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // Start authentication and onboarding checks in parallel
    final api = ApiClient();
    final loggedInFuture = api.isLoggedIn;
    final bypassedFuture = api.checkOnboardingBypassed();

    // Minimum delay to let the logo animation play cleanly
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final loggedIn = await loggedInFuture;
    if (!mounted) return;

    if (loggedIn) {
      try {
        final bypassed = await bypassedFuture;
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
    _master.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FFFE);
    
    // Responsive sizing
    final double iconSize;
    final double baseWordScale;
    
    if (screenWidth < 360) {
      iconSize = 90.0;
      baseWordScale = 0.85;
    } else if (screenWidth > 600) {
      iconSize = 150.0;
      baseWordScale = 1.35;
    } else {
      iconSize = 110.0;
      baseWordScale = 1.0;
    }

    return Scaffold(
      backgroundColor: bg,
      body: AnimatedBuilder(
        animation: _master,
        builder: (context, _) {
          final glow = _wordGlow.value;

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo — luôn hiển thị, không biến mất
                Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: NotebookIconShimmer(
                      size: iconSize,
                      progress: _logoShimmer.value,
                    ),
                  ),
                ),
                SizedBox(height: screenWidth > 600 ? 30 : 20),
                // Wordmark — xuất hiện ngay sau logo
                if (glow > 0)
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF42C9A8).withValues(alpha: 0.18 * glow),
                          blurRadius: 40 * glow,
                          spreadRadius: 4 * glow,
                        ),
                      ],
                    ),
                    child: SpendDiaryWordmark(
                      scale: _wordScale.value * baseWordScale,
                      opacity: _wordOpacity.value,
                      blurSigma: _wordBlur.value,
                      textShimmer: _wordTextShimmer.value,
                      leafWiggle: _leafWiggle.value,
                    ),
                  )
                else
                  SpendDiaryWordmark(
                    scale: _wordScale.value * baseWordScale,
                    opacity: _wordOpacity.value,
                    blurSigma: _wordBlur.value,
                    textShimmer: _wordTextShimmer.value,
                    leafWiggle: _leafWiggle.value,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

