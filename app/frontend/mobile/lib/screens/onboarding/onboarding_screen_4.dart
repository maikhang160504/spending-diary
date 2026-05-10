import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class OnboardingStep4 extends StatelessWidget {
  const OnboardingStep4({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = const [
      _LimitItem('🍔', 'An uong'),
      _LimitItem('🛍️', 'Mua sam'),
      _LimitItem('🚗', 'Di chuyen'),
      _LimitItem('🎬', 'Giai tri'),
      _LimitItem('🧾', 'Khac'),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(
          child: Column(
            children: [
              const _ProgressHeader(label: 'Buoc 4/5', percent: '80%', value: 0.8),
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
                        Text('Gioi han chi tieu', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Dat gioi han cho tung danh muc (co the bo qua)',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ...categories.map((item) => _LimitRow(item: item)),
                        const SizedBox(height: 8),
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
                                  'Ban co the thay doi gioi han nay bat cu luc nao trong Cai dat',
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
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.onboardingStep5),
                        icon: const Text(''),
                        label: const Text('Tiep tuc'),
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

class _LimitItem {
  final String emoji;
  final String label;

  const _LimitItem(this.emoji, this.label);
}

class _LimitRow extends StatelessWidget {
  final _LimitItem item;

  const _LimitRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(item.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          const TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: '2,000,000'),
          ),
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