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
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Container(
                decoration: const BoxDecoration(
                  gradient: AppGradients.teal,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadii.xl),
                    bottomRight: Radius.circular(AppRadii.xl),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 16, 24, 24),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chuỗi ghi chép', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text('Duy trì thói quen tốt mỗi ngày', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Streak summary card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 8),
                          Text('7', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, fontSize: 52)),
                          Text('Ngày liên tục', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F7FA),
                                    borderRadius: BorderRadius.circular(AppRadii.md),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.emoji_events_outlined, color: AppColors.teal, size: 22),
                                      const SizedBox(height: 4),
                                      Text('Kỷ lục', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                                      Text('15', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F7FA),
                                    borderRadius: BorderRadius.circular(AppRadii.md),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, color: AppColors.teal, size: 22),
                                      const SizedBox(height: 4),
                                      Text('Tổng số ngày', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                                      Text('45', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 30-day calendar heatmap
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('30 ngày gần nhất', style: Theme.of(context).textTheme.titleSmall),
                              const Icon(Icons.trending_up, color: AppColors.teal, size: 18),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _StreakGrid(),
                          const SizedBox(height: 10),
                          Text('Mỗi ô màu xanh = 1 ngày có giao dịch ✓', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Achievements
                    Row(
                      children: [
                        const Icon(Icons.emoji_events, color: AppColors.teal, size: 18),
                        const SizedBox(width: 6),
                        Text('Thành tích', style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...MockData.streakAchievements.map((item) => _AchievementCard(item: item)),
                    const SizedBox(height: 20),
                    // Tips card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mẹo duy trì streak', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFF16A34A))),
                          const SizedBox(height: 10),
                          _TipRow(emoji: '💡', text: 'Ghi chép mỗi ngày giúp bạn kiểm soát chi tiêu tốt hơn'),
                          _TipRow(emoji: '🎯', text: 'Streak càng dài, bạn càng hiểu rõ thói quen chi tiêu của mình'),
                          _TipRow(emoji: '🔥', text: 'Đừng phá chuỗi! Mỗi ngày chỉ cần 1 giao dịch là được'),
                        ],
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

class _StreakGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 30 days, last 7 are active (streak)
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        final isActive = index >= 23; // last 7 days active
        final isToday = index == 29;
        return Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isActive ? AppColors.teal : const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: isActive
                    ? Center(child: Text('🔥', style: TextStyle(fontSize: isToday ? 10 : 9)))
                    : null,
              ),
            ),
            if (isToday)
              const Text('Hôm\nnay', textAlign: TextAlign.center, style: TextStyle(fontSize: 7, color: AppColors.teal, fontWeight: FontWeight.w600)),
          ],
        );
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final StreakAchievement item;

  const _AchievementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: item.achieved ? AppColors.teal.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                if (item.date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          if (item.achieved)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            )
          else
            const Icon(Icons.lock_outline, color: AppColors.muted, size: 22),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String emoji;
  final String text;

  const _TipRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}