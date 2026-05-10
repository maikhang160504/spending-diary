import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class OnboardingStep1 extends StatelessWidget {
  const OnboardingStep1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(
          child: Column(
            children: [
              const _ProgressHeader(label: 'Buoc 1/5', percent: '20%', value: 0.2),
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 30,
                          offset: Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                          ),
                          child: const Center(child: Text('👋', style: TextStyle(fontSize: 28))),
                        ),
                        const SizedBox(height: 16),
                        Text('Xin chao! Minh la Mimo 😊', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(
                          'Con ban ten gi nhi? Cho minh xin ten de de goi nha~',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Ten cua ban', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        const TextField(
                          decoration: InputDecoration(
                            hintText: 'Nguyen Van A, hoac goi ban la gi cung duoc',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.onboardingStep2),
                    child: const Text('Tiep nao! ✨'),
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

class _ProgressHeader extends StatelessWidget {
  final String label;
  final String percent;
  final double value;

  const _ProgressHeader({
    required this.label,
    required this.percent,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text(percent, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
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