import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
              const _ProgressHeader(label: 'Bước 1/5', percent: '20%', value: 0.2),
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 20)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                          ),
                          child: const Center(child: Text('👋', style: TextStyle(fontSize: 32))),
                        ),
                        const SizedBox(height: 20),
                        Text('Xin chào! Mình là Mimo 😊', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        Text(
                          'Còn bạn tên gì nhỉ? Cho mình xin tên để dễ gọi nha~',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Tên của bạn', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        const TextField(
                          decoration: InputDecoration(
                            hintText: 'Nguyễn Văn A, hoặc gọi bạn là gì cũng được',
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
                    onPressed: () => context.push(AppRoutes.onboardingStep2),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('Tiếp nào! ✨', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios, size: 14),
                      ],
                    ),
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

  const _ProgressHeader({required this.label, required this.percent, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              Text(percent, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
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