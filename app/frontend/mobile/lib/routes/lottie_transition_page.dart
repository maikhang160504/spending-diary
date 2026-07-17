import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

/// A custom GoRouter page transition that plays a thematic Lottie animation
/// during the entrance transition, and performs a clean fade-out on pop.
class LottieTransitionPage<T> extends CustomTransitionPage<T> {
  LottieTransitionPage({
    required String lottiePath,
    required super.child,
    super.key,
    Duration duration = const Duration(milliseconds: 900),
    Duration reverseDuration = const Duration(milliseconds: 300),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _LottieTransitionBuilder(
              animation: animation,
              lottiePath: lottiePath,
              child: child,
            );
          },
        );
}

class _LottieTransitionBuilder extends StatelessWidget {
  final Animation<double> animation;
  final String lottiePath;
  final Widget child;

  const _LottieTransitionBuilder({
    required this.animation,
    required this.lottiePath,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = animation.value;
        final status = animation.status;
        final isReversing = status == AnimationStatus.reverse;

        if (isReversing) {
          // snappy fade-out when popping
          return Opacity(
            opacity: value,
            child: child,
          );
        }

        // Forward transition color matching theme
        final bgColor = Theme.of(context).scaffoldBackgroundColor;

        // Background covers old page completely until transition finishes
        final bgOpacity = (value < 0.1) ? (value / 0.1) : 1.0;

        // Lottie fades out in the second half of transition
        final lottieOpacity = (value < 0.1)
            ? (value / 0.1)
            : (value > 0.65 ? ((1.0 - value) / 0.35).clamp(0.0, 1.0) : 1.0);

        // Target screen fades in after 50% transition progress
        final childOpacity = (value > 0.5)
            ? ((value - 0.5) / 0.5).clamp(0.0, 1.0)
            : 0.0;

        final childScale = 0.95 + (0.05 * childOpacity);

        return Stack(
          children: [
            // Theme background overlay
            Opacity(
              opacity: bgOpacity,
              child: Container(
                color: bgColor,
              ),
            ),

            // The target page fading & scaling in
            Opacity(
              opacity: childOpacity,
              child: Transform.scale(
                scale: childScale,
                child: child,
              ),
            ),

            // The thematic Lottie animation in the center
            if (!kIsWeb && value < 0.9)
              IgnorePointer(
                child: Opacity(
                  opacity: lottieOpacity,
                  child: Center(
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: Lottie.asset(
                        lottiePath,
                        controller: animation,
                        animate: false, // Drive animation using the transition value
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
