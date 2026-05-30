import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

/// O-01: Shared progress header used by onboarding steps 2-4.
///
/// Shows step label (e.g. "Bước 2/5"), a linear progress bar, and an
/// optional "Bỏ qua" skip link.
class OnboardingProgressHeader extends StatelessWidget {
  final String label;
  final String percent;
  final double value;
  final VoidCallback? onSkip;

  const OnboardingProgressHeader({
    super.key,
    required this.label,
    required this.percent,
    required this.value,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onSkip != null)
                GestureDetector(
                  onTap: onSkip,
                  child: const Text(
                    'Bỏ qua',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
                    ),
                  ),
                )
              else
                Text(
                  percent,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

/// O-01: White rounded card used as content container in onboarding steps.
class OnboardingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const OnboardingCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// O-01: Full-screen gradient scaffold for onboarding steps.
///
/// Wraps [child] in a teal gradient background with [SafeArea].
class OnboardingScaffold extends StatelessWidget {
  final Widget child;

  const OnboardingScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(child: child),
      ),
    );
  }
}

/// O-01: Teal "continue" button used at the bottom of each onboarding step.
class OnboardingContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const OnboardingContinueButton({
    super.key,
    this.label = 'Tiếp tục',
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
