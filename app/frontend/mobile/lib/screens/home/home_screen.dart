import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const _HeaderSection(),
              const SizedBox(height: 12),
              const _SegmentTabs(selected: 'Story'),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  children: MockData.homeStories
                      .map(
                        (story) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _StoryCard(story: story),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thu Bay, 9 thang 05 2026',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Chao ban!', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                      const SizedBox(width: 4),
                      const Text('👋', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('7 ngay', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                        Text('Streak', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              _WalletChip(label: 'Vi rieng', icon: Icons.account_balance_wallet_outlined, isSelected: true),
              SizedBox(width: 8),
              _WalletChip(label: 'Gia dinh (4)', icon: Icons.group_outlined),
              SizedBox(width: 8),
              _WalletChip(label: 'Nhom ban (3)', icon: Icons.groups_outlined),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.teal, size: 16),
                    const SizedBox(width: 6),
                    Text('So du hien tai', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(formatVnd(5380000), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _BalanceStat(label: 'Thu nhap', value: formatVnd(8000000), color: AppColors.teal)),
                    Container(width: 1, height: 28, color: AppColors.border),
                    Expanded(child: _BalanceStat(label: 'Chi tieu', value: formatVnd(2620000), color: AppColors.danger)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;

  const _WalletChip({
    required this.label,
    required this.icon,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.teal : Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected ? AppColors.teal : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BalanceStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  final String selected;

  const _SegmentTabs({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            _SegmentItem(label: 'Story', icon: Icons.article_outlined, isSelected: selected == 'Story'),
            _SegmentItem(label: 'Gallery', icon: Icons.grid_view, isSelected: selected == 'Gallery'),
            _SegmentItem(label: 'Calendar', icon: Icons.calendar_month, isSelected: selected == 'Calendar'),
          ],
        ),
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;

  const _SegmentItem({
    required this.label,
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.teal : AppColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected ? AppColors.teal : AppColors.muted,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final HomeStory story;

  const _StoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final commentColor = story.aiPositive ? const Color(0xFFECFDF3) : const Color(0xFFFFF7ED);
    final borderColor = story.aiPositive ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                  child: Text(story.userName.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(story.userName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(story.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.more_horiz, color: AppColors.muted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(story.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Image.network(story.imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Text(story.categoryEmoji),
                      const SizedBox(width: 6),
                      Text(story.category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '-${formatVnd(story.amount)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: commentColor,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.teal,
                        child: const Text('😊', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Text('Mimo AI', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(story.aiMessage, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(onPressed: () {}, icon: const Icon(Icons.sentiment_satisfied_alt, size: 16), label: const Text('Dung')),
                      TextButton.icon(onPressed: () {}, icon: const Icon(Icons.sentiment_dissatisfied, size: 16), label: const Text('Sai')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}