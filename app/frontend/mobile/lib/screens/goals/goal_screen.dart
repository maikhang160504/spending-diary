import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class GoalScreen extends StatelessWidget {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GoalHeader(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  children: [
                    ...MockData.goals.map((goal) => _GoalCard(goal: goal)),
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

class _GoalHeader extends StatelessWidget {
  const _GoalHeader();

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mục tiêu', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Đặt mục tiêu và theo dõi tiến độ tiết kiệm', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final GoalItem goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final percent = goal.savedAmount / goal.targetAmount;
    final remaining = goal.targetAmount - goal.savedAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Center(child: Text(goal.emoji, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Mục tiêu: ${formatVnd(goal.targetAmount)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tiến độ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              Text(
                '${(percent * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
            ),
          ),
          const SizedBox(height: 14),
          // Saved / Remaining boxes
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFB),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đã tiết kiệm', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(formatVnd(goal.savedAmount), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Còn thiếu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(formatVnd(remaining), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Add money button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm tiền'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}