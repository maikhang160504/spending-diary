import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class HomeCalendarScreen extends StatelessWidget {
  const HomeCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const _HeaderSection(),
              const SizedBox(height: 12),
              const _SegmentTabs(selected: 'Calendar'),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spending Calendar 📅', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chevron_left, color: AppColors.muted),
                        const SizedBox(width: 8),
                        Text('thang 03 2026', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _DayLabel('S'),
                        _DayLabel('M'),
                        _DayLabel('T'),
                        _DayLabel('W'),
                        _DayLabel('T'),
                        _DayLabel('F'),
                        _DayLabel('S'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _CalendarGrid(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('26 thang 03 2026', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Text(formatVnd(210000), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Icon(Icons.chevron_left, color: AppColors.muted),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Expanded(
                          child: _CalendarExpenseCard(
                            imageUrl: 'https://images.unsplash.com/photo-1517602302552-471fe67acf66?auto=format&fit=crop&w=600&q=80',
                            label: 'Giai tri',
                            emoji: '🎬',
                            amount: '150.000 đ',
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _CalendarExpenseCard(
                            imageUrl: 'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=600&q=80',
                            label: 'Di chuyen',
                            emoji: '🚗',
                            amount: '60.000 đ',
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
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

class _DayLabel extends StatelessWidget {
  final String label;

  const _DayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Center(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dayValues = const [
      23, 24, 25, 26, 27, 28, 1,
      2, 3, 4, 5, 6, 7, 8,
      9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22,
      23, 24, 25, 26, 27, 28, 29,
      30, 31, 1, 2, 3, 4, 5,
    ];

    final entries = {for (final entry in MockData.calendarEntries) entry.day: entry};

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: dayValues.length,
      itemBuilder: (context, index) {
        final day = dayValues[index];
        final entry = entries[day];

        return Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            shape: BoxShape.circle,
          ),
          child: entry == null
              ? Text('$day', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted))
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(radius: 18, backgroundImage: NetworkImage(entry.imageUrl)),
                    if (entry.count > 1)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('+${entry.count}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _CalendarExpenseCard extends StatelessWidget {
  final String imageUrl;
  final String label;
  final String emoji;
  final String amount;
  final Color color;

  const _CalendarExpenseCard({
    required this.imageUrl,
    required this.label,
    required this.emoji,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
              child: Row(
                children: [
                  Text(emoji),
                  const SizedBox(width: 4),
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
                  Text('Thu Bay, 9 thang 05 2026', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
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