import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class OnboardingStep3 extends StatefulWidget {
  const OnboardingStep3({super.key});

  @override
  State<OnboardingStep3> createState() => _OnboardingStep3State();
}

class _OnboardingStep3State extends State<OnboardingStep3> {
  String _selected = 'Dui Dẻ';

  static const _styles = [
    _Style(
      '😎',
      'Dui Dẻ',
      'Vui vẻ, hài hước, thoải mái',
      '"Tiêu kiểu này là cuối tháng ăn mì nha bro! 😂"',
    ),
    _Style(
      '🔥',
      'Dận Dữ',
      'Nghiêm túc, sắc sảo, thẳng thắn',
      '"Chi nhiều vậy là vượt ngân sách rồi đó! 🧐"',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(
          child: Column(
            children: [
              const _ProgressHeader(
                label: 'Bước 3/5',
                percent: '60%',
                value: 0.6,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎭', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: 12),
                        Text(
                          'Bạn thích mình nói chuyện kiểu nào?',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chọn phong cách mà bạn thấy "vibe" nhất nha!',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ..._styles.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _StyleCard(
                              style: s,
                              isSelected: _selected == s.title,
                              onTap: () => setState(() => _selected = s.title),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _NavButtons(
                onBack: () => context.pop(),
                onNext: () => context.push(AppRoutes.onboardingStep4),
                nextLabel: 'Tiếp nào! ✨',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Style {
  final String emoji, title, subtitle, sample;
  const _Style(this.emoji, this.title, this.subtitle, this.sample);
}

class _StyleCard extends StatelessWidget {
  final _Style style;
  final bool isSelected;
  final VoidCallback onTap;
  const _StyleCard({
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.teal.withValues(alpha: 0.06)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(style.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        style.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    style.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.teal.withValues(alpha: 0.08)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Text(
                      style.sample,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButtons extends StatelessWidget {
  final VoidCallback onBack, onNext;
  final String nextLabel;
  const _NavButtons({
    required this.onBack,
    required this.onNext,
    this.nextLabel = 'Tiếp tục',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              label: const Text(
                'Quay lại',
                style: TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                nextLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final String label, percent;
  final double value;
  const _ProgressHeader({
    required this.label,
    required this.percent,
    required this.value,
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
