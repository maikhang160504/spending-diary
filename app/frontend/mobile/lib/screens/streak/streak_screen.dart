import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StreakHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _StreakSummary(),
                    const SizedBox(height: 20),
                    Text('Thanh tich', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    ...MockData.streakAchievements.map((item) => _AchievementCard(item: item)),
                    const SizedBox(height: 24),
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

class _StreakHeader extends StatelessWidget {
  const _StreakHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chuoi ghi chep', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text('Duy tri thoi quen tot moi ngay', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _StreakSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Center(child: Text('🔥', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('7 ngay lien tuc', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text('Muc tieu: 10 ngay', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              FilledButton(onPressed: () {}, child: const Text('Tiep tuc')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              MockData.streakDays.length,
              (index) => _DayDot(isActive: MockData.streakDays[index], label: 'T${index + 2}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final bool isActive;
  final String label;

  const _DayDot({required this.isActive, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive ? AppColors.teal : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              isActive ? Icons.check : Icons.close,
              size: 16,
              color: isActive ? Colors.white : AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final StreakAchievement item;

  const _AchievementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.achieved ? AppColors.teal.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                if (item.date.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.tealDark)),
                ],
              ],
            ),
          ),
          Icon(item.achieved ? Icons.check_circle : Icons.lock_outline, color: item.achieved ? AppColors.teal : AppColors.muted),
        ],
      ),
    );
  }
}