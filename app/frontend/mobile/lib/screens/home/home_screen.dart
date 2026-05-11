import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _tab = 'Story';
  String _wallet = 'Ví riêng';

  void _onWalletTap(String label) {
    // Ví chung → dẫn đến shared wallet screen
    if (label == 'Gia đình' || label == 'Nhóm bạn') {
      context.push(AppRoutes.shareWallet);
      return;
    }
    setState(() => _wallet = label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSegmentTabs()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (_tab == 'Story')
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _StoryCard(story: MockData.homeStories[i]),
                      childCount: MockData.homeStories.length,
                    ),
                  ),
                if (_tab == 'Gallery')
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _GalleryCard(item: MockData.galleryItems[i]),
                        childCount: MockData.galleryItems.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 5,
                        crossAxisSpacing: 5,
                        childAspectRatio: 0.75,
                      ),
                    ),
                  ),
                if (_tab == 'Calendar')
                  SliverToBoxAdapter(child: _InlineCalendarView()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
            // Chat FAB
            Positioned(
              right: AppSpacing.xxl,
              bottom: 24,
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.chat),
                child: Container(
                  height: 48, width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 6))],
                  ),
                  child: const Icon(Icons.smart_toy_outlined, color: AppColors.teal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Thứ Bảy, 9 tháng 05 2026', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            const SizedBox(height: 4),
            Row(children: [
              Text('Chào bạn!', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Text('👋', style: TextStyle(fontSize: 18)),
            ]),
          ]),
          GestureDetector(
            onTap: () => context.push(AppRoutes.streak),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Row(children: [
                const Text('🔥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('7 ngày', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text('Streak', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontSize: 10)),
                ]),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _WalletChip(label: 'Ví riêng', icon: Icons.account_balance_wallet_outlined, isSelected: _wallet == 'Ví riêng', onTap: () => _onWalletTap('Ví riêng')),
            const SizedBox(width: 8),
            _WalletChip(label: 'Gia đình (4)', icon: Icons.group_outlined, isSelected: false, onTap: () => _onWalletTap('Gia đình')),
            const SizedBox(width: 8),
            _WalletChip(label: 'Nhóm bạn (3)', icon: Icons.groups_outlined, isSelected: false, onTap: () => _onWalletTap('Nhóm bạn')),
            const SizedBox(width: 8),
            _WalletChip(label: 'Tạo ví', icon: Icons.add_circle_outline, isSelected: false, onTap: () {}),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: AppColors.teal, size: 16),
              const SizedBox(width: 6),
              Text('Số dư hiện tại', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Text('5.380.000 đ', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 26)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _BalanceStat(label: 'Thu nhập', value: '8.000.000 đ', color: AppColors.teal)),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(child: _BalanceStat(label: 'Chi tiêu', value: '2.620.000 đ', color: AppColors.danger)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSegmentTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(AppRadii.lg)),
        child: Row(children: [
          _SegmentItem(label: 'Story', icon: Icons.article_outlined, isSelected: _tab == 'Story', onTap: () => setState(() => _tab = 'Story')),
          _SegmentItem(label: 'Gallery', icon: Icons.grid_view, isSelected: _tab == 'Gallery', onTap: () => setState(() => _tab = 'Gallery')),
          _SegmentItem(label: 'Calendar', icon: Icons.calendar_month, isSelected: _tab == 'Calendar', onTap: () => setState(() => _tab = 'Calendar')),
        ]),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _WalletChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _WalletChip({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.teal : Colors.white),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isSelected ? AppColors.teal : Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BalanceStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _SegmentItem({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: isSelected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 3))] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.teal : AppColors.muted),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isSelected ? AppColors.teal : AppColors.muted, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ─── Gallery Card (inline, in home) ─────────────────────────────────────────

class _GalleryCard extends StatelessWidget {
  final GalleryItem item;
  const _GalleryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPositive = item.amount >= 0;
    return GestureDetector(
      onTap: () => context.push(AppRoutes.storyDetail),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Stack(fit: StackFit.expand, children: [
          Image.network(item.imageUrl, fit: BoxFit.cover),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)], stops: const [0.45, 1.0]),
          ))),
          // Category badge
          Positioned(left: 5, top: 5, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: _catColor(item.category), borderRadius: BorderRadius.circular(999)),
            child: Text(item.categoryEmoji, style: const TextStyle(fontSize: 9)),
          )),
          // Amount + title at bottom
          Positioned(left: 5, right: 5, bottom: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${isPositive ? '+' : '-'}${formatVnd(item.amount.abs())}',
              style: TextStyle(color: isPositive ? const Color(0xFF4ADE80) : Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
            Text(item.title, style: const TextStyle(color: Colors.white70, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'Ăn uống': return const Color(0xFFEC4899);
      case 'Mua sắm': return const Color(0xFF8B5CF6);
      case 'Di chuyển': return const Color(0xFF3B82F6);
      default: return AppColors.teal;
    }
  }
}

// ─── Inline Calendar View ─────────────────────────────────────────────────────

class _InlineCalendarView extends StatefulWidget {
  @override
  State<_InlineCalendarView> createState() => _InlineCalendarViewState();
}

class _InlineCalendarViewState extends State<_InlineCalendarView> {
  DateTime _focus = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;

  List<CalendarEntry> get _entries => MockData.calendarEntries
      .where((e) => e.month == _focus.month && e.year == _focus.year)
      .toList();

  List<CalendarEntry> get _selectedEntries => _selectedDay == null
      ? []
      : _entries.where((e) => e.day == _selectedDay).toList();

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_focus.year, _focus.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_focus.year, _focus.month);
    final startWeekday = firstDay.weekday % 7; // 0=Sun
    final entryMap = {for (final e in _entries) e.day: e};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(children: [
        // Month nav
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () => setState(() { _focus = DateTime(_focus.year, _focus.month - 1); _selectedDay = null; }),
          ),
          Text('tháng ${_focus.month} ${_focus.year}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () => setState(() { _focus = DateTime(_focus.year, _focus.month + 1); _selectedDay = null; }),
          ),
        ]),
        // Weekday headers
        Row(children: ['S','M','T','W','T','F','S'].map((d) =>
          Expanded(child: Center(child: Text(d, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600))))).toList()),
        const SizedBox(height: 8),
        // Calendar grid — each cell shows stacked photos or day number
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: startWeekday + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 0.85),
          itemBuilder: (ctx, i) {
            if (i < startWeekday) return const SizedBox();
            final day = i - startWeekday + 1;
            final entry = entryMap[day];
            final isSelected = _selectedDay == day;
            final isToday = _focus.month == DateTime.now().month && _focus.year == DateTime.now().year && day == DateTime.now().day;

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = _selectedDay == day ? null : day),
              child: entry != null
                  ? _StackedPhotoCell(entry: entry, isSelected: isSelected)
                  : Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.teal.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday ? Border.all(color: AppColors.teal, width: 1.5) : null,
                      ),
                      child: Center(child: Text('$day', style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? AppColors.teal : AppColors.textPrimary,
                      ))),
                    ),
            );
          },
        ),
        // Selected day gallery
        if (_selectedDay != null && _selectedEntries.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Text('$_selectedDay tháng ${_focus.month}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.teal)),
              const SizedBox(width: 8),
              Text('${_selectedEntries.fold<int>(0, (s, e) => s + e.count)} giao dịch',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            ]),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedEntries.fold<int>(0, (s, e) => s + e.imageUrls.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 5, crossAxisSpacing: 5, childAspectRatio: 1),
            itemBuilder: (ctx, idx) {
              // Flatten all images from selected entries
              final allImages = _selectedEntries.expand((e) => e.imageUrls).toList();
              final url = allImages[idx];
              return GestureDetector(
                onTap: () => context.push(AppRoutes.storyDetail),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _StackedPhotoCell extends StatelessWidget {
  final CalendarEntry entry;
  final bool isSelected;
  const _StackedPhotoCell({required this.entry, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final photos = entry.imageUrls.take(3).toList().reversed.toList();
    const angles = [0.18, -0.12, 0.0]; // radians tilt: back → front
    const size = 38.0;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Stacked images
        SizedBox(
          width: size + 8,
          height: size + 8,
          child: Stack(
            children: List.generate(photos.length, (i) {
              final angle = angles[i % angles.length];
              return Positioned(
                top: 0, left: 0, right: 0, bottom: 0,
                child: Transform.rotate(
                  angle: angle,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Image.network(photos[i], fit: BoxFit.cover,
                          errorBuilder: (ctx, e, st) => Container(color: const Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // Day number overlay at bottom
        Positioned(bottom: -2, left: 0, right: 0,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: isSelected ? AppColors.teal : Colors.black54, borderRadius: BorderRadius.circular(999)),
            child: Text('${entry.day}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ),
        // +N badge if more than 3
        if (entry.count > 3)
          Positioned(top: -4, right: -4,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
              child: Center(child: Text('+${entry.count - 3}', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700))),
            ),
          ),
      ],
    );
  }
}

// ─── Story Card ───────────────────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  final HomeStory story;
  const _StoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.storyDetail),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.teal,
                  child: Text(story.userName.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(story.userName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(story.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
              ])),
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz, color: AppColors.muted)),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 10), child: Text(story.title, style: Theme.of(context).textTheme.bodyMedium)),
          Stack(children: [
            ClipRRect(child: Image.network(story.imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover)),
            Positioned(left: 12, top: 12, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _catColor(story.category), borderRadius: BorderRadius.circular(999)),
              child: Row(children: [
                Text(story.categoryEmoji),
                const SizedBox(width: 4),
                Text(story.category, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            )),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text('-${formatVnd(story.amount)}', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 20)),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFEFCE8), borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: const Color(0xFFFDE68A))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 24, height: 24, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                    child: const Center(child: Text('😎', style: TextStyle(fontSize: 12)))),
                const SizedBox(width: 8),
                Text('Mimo AI', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Text(story.aiMessage, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _FeedbackButton(label: '😊 Đúng', onTap: () {}),
                const SizedBox(width: 10),
                _FeedbackButton(label: '😅 Sai', onTap: () {}),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'Ăn uống': return const Color(0xFFEC4899);
      case 'Mua sắm': return const Color(0xFF8B5CF6);
      case 'Di chuyển': return const Color(0xFF3B82F6);
      case 'Giải trí': return const Color(0xFFF59E0B);
      default: return AppColors.teal;
    }
  }
}

class _FeedbackButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FeedbackButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}