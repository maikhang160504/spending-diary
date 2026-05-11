import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

/// Home Calendar Screen - matches /home with Calendar tab selected
class HomeCalendarScreen extends StatefulWidget {
  const HomeCalendarScreen({super.key});

  @override
  State<HomeCalendarScreen> createState() => _HomeCalendarScreenState();
}

class _HomeCalendarScreenState extends State<HomeCalendarScreen> {
  int _selectedDay = 26;
  String _selectedWallet = 'Ví riêng';
  int _currentMonth = 3;
  int _currentYear = 2026;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _HeaderSection(
                selectedWallet: _selectedWallet,
                onWalletChanged: (w) => setState(() => _selectedWallet = w),
              ),
              const SizedBox(height: 12),
              _SegmentTabs(
                selected: 'Calendar',
                onStory: () => context.pop(),
                onGallery: () => context.push(AppRoutes.homeGallery),
                onCalendar: () {},
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month nav
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() {
                  if (_currentMonth == 1) {
                    _currentMonth = 12;
                    _currentYear--;
                  } else {
                    _currentMonth--;
                  }
                }),
                                child: const Icon(Icons.chevron_left, color: AppColors.muted),
                              ),
                              Text('Tháng $_currentMonth/$_currentYear', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              GestureDetector(
                                onTap: () => setState(() {
                  if (_currentMonth == 12) {
                    _currentMonth = 1;
                    _currentYear++;
                  } else {
                    _currentMonth++;
                  }
                }),
                                child: const Icon(Icons.chevron_right, color: AppColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Day of week labels
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: const ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']
                                .map((d) => SizedBox(
                                      width: 36,
                                      child: Center(
                                        child: Text(d, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          _CalendarGrid(
                            selectedDay: _selectedDay,
                            onDaySelected: (d) => setState(() => _selectedDay = d),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Selected day transactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_selectedDay tháng 0$_currentMonth $currentYear',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          formatVnd(210000),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Expanded(
                          child: _CalendarExpenseCard(
                            imageUrl: 'https://images.unsplash.com/photo-1517602302552-471fe67acf66?auto=format&fit=crop&w=600&q=80',
                            label: 'Giải trí',
                            emoji: '🎬',
                            amount: '150.000 đ',
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _CalendarExpenseCard(
                            imageUrl: 'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=600&q=80',
                            label: 'Di chuyển',
                            emoji: '🚗',
                            amount: '60.000 đ',
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // All transactions for day
                    ..._dayTransactions.map((t) => _TransactionRow(tx: t)),
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

  int get currentYear => _currentYear;

  static const _dayTransactions = [
    _Tx(emoji: '🎬', title: 'Xem phim', category: 'Giải trí', amount: -150000, time: '19:30'),
    _Tx(emoji: '🚗', title: 'Grab về nhà', category: 'Di chuyển', amount: -60000, time: '22:10'),
  ];
}

class _Tx {
  final String emoji;
  final String title;
  final String category;
  final int amount;
  final String time;

  const _Tx({required this.emoji, required this.title, required this.category, required this.amount, required this.time});
}

class _TransactionRow extends StatelessWidget {
  final _Tx tx;

  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Center(child: Text(tx.emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(tx.category, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatVnd(tx.amount.abs()), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
              Text(tx.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onDaySelected;

  const _CalendarGrid({required this.selectedDay, required this.onDaySelected});

  @override
  Widget build(BuildContext context) {
    // March 2026 starts on Sunday (0) - adjust offset
    const startOffset = 0;
    const daysInMonth = 31;
    final entries = {for (final e in MockData.calendarEntries) e.day: e};
    final total = startOffset + daysInMonth;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: total,
      itemBuilder: (context, index) {
        if (index < startOffset) return const SizedBox();
        final day = index - startOffset + 1;
        final entry = entries[day];
        final isSelected = day == selectedDay;

        return GestureDetector(
          onTap: () => onDaySelected(day),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.teal : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: entry != null
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        child: Image.network(entry.imageUrls.first, width: 36, height: 36, fit: BoxFit.cover),
                      ),
                      if (entry.count > 1)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(10)),
                            child: Text('+${entry.count}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ),
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
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
          ),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String selectedWallet;
  final ValueChanged<String> onWalletChanged;

  const _HeaderSection({required this.selectedWallet, required this.onWalletChanged});

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
                  Text('Thứ Bảy, 9 tháng 05 2026', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Chào bạn!', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
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
                        Text('7 ngày', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text('Streak', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Wallet chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _WalletChip(label: 'Ví riêng', icon: Icons.account_balance_wallet_outlined, isSelected: selectedWallet == 'Ví riêng', onTap: () => onWalletChanged('Ví riêng')),
                const SizedBox(width: 8),
                _WalletChip(label: 'Gia đình (4)', icon: Icons.group_outlined, isSelected: selectedWallet == 'Gia đình', onTap: () => onWalletChanged('Gia đình')),
                const SizedBox(width: 8),
                _WalletChip(label: 'Nhóm bạn (3)', icon: Icons.groups_outlined, isSelected: selectedWallet == 'Nhóm bạn', onTap: () => onWalletChanged('Nhóm bạn')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Balance card
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
                    Text('Số dư hiện tại', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(formatVnd(5380000), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _BalanceStat(label: 'Thu nhập', value: formatVnd(8000000), color: AppColors.teal)),
                    Container(width: 1, height: 28, color: AppColors.border),
                    Expanded(child: _BalanceStat(label: 'Chi tiêu', value: formatVnd(2620000), color: AppColors.danger)),
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
  final VoidCallback onTap;

  const _WalletChip({required this.label, required this.icon, this.isSelected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? AppColors.teal : Colors.white),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isSelected ? AppColors.teal : Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BalanceStat({required this.label, required this.value, required this.color});

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
  final VoidCallback onStory;
  final VoidCallback onGallery;
  final VoidCallback onCalendar;

  const _SegmentTabs({required this.selected, required this.onStory, required this.onGallery, required this.onCalendar});

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
            _SegItem(label: 'Story', icon: Icons.article_outlined, isSelected: selected == 'Story', onTap: onStory),
            _SegItem(label: 'Gallery', icon: Icons.grid_view, isSelected: selected == 'Gallery', onTap: onGallery),
            _SegItem(label: 'Calendar', icon: Icons.calendar_month, isSelected: selected == 'Calendar', onTap: onCalendar),
          ],
        ),
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegItem({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: isSelected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 3))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? AppColors.teal : AppColors.muted),
              const SizedBox(width: 5),
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isSelected ? AppColors.teal : AppColors.muted, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}