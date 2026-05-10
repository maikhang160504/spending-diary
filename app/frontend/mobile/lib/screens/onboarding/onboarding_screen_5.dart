import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class OnboardingStep5 extends StatelessWidget {
  const OnboardingStep5({super.key});

  @override
  Widget build(BuildContext context) {
    final ageOptions = const [
      _OptionItem('🎓', '18-22 tuoi'),
      _OptionItem('💼', '23-30 tuoi'),
      _OptionItem('👔', '31-40 tuoi'),
      _OptionItem('🏢', '41-50 tuoi'),
      _OptionItem('✨', 'Tren 50'),
    ];

    final jobOptions = const [
      _OptionItem('📚', 'Sinh vien'),
      _OptionItem('💻', 'Van phong'),
      _OptionItem('✨', 'Freelancer'),
      _OptionItem('💼', 'Kinh doanh'),
      _OptionItem('🎯', 'Khac'),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(
          child: Column(
            children: [
              const _ProgressHeader(label: 'Buoc 5/5', percent: '100%', value: 1),
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
                          child: const Icon(Icons.auto_awesome, color: AppColors.teal),
                        ),
                        const SizedBox(height: 16),
                        Text('Thong tin ca nhan', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'De Mimo co the tu van phu hop voi ban nhat',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Do tuoi cua ban', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: ageOptions.map((option) => _OptionChip(option: option)).toList(),
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Nghe nghiep', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: jobOptions.map((option) => _OptionChip(option: option)).toList(),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F7F6),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Row(
                            children: [
                              const Text('💡'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Thong tin nay giup AI nhan xet chinh xac hon ve chi tieu cua ban',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.tealDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Quay lai'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.shell),
                        icon: const Text(''),
                        label: const Text('Hoan thanh'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionItem {
  final String emoji;
  final String label;

  const _OptionItem(this.emoji, this.label);
}

class _OptionChip extends StatelessWidget {
  final _OptionItem option;

  const _OptionChip({required this.option});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(option.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(option.label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
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