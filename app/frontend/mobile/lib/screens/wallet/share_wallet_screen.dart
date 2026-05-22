import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class ShareWalletScreen extends StatefulWidget {
  const ShareWalletScreen({super.key});
  @override
  State<ShareWalletScreen> createState() => _ShareWalletScreenState();
}

class _ShareWalletScreenState extends State<ShareWalletScreen> {
  String _tab = 'Story';
  bool _showMembers = false;

  static const _members = ['An', 'Lan', 'Minh', 'Khánh'];

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
                      (ctx, i) => _SharedStoryCard(story: MockData.homeStories[i]),
                      childCount: MockData.homeStories.length,
                    ),
                  ),
                if (_tab == 'Gallery')
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _SharedGalleryCard(item: MockData.galleryItems[i]),
                        childCount: MockData.galleryItems.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, mainAxisSpacing: 5, crossAxisSpacing: 5, childAspectRatio: 0.75,
                      ),
                    ),
                  ),
                if (_tab == 'Calendar')
                  SliverToBoxAdapter(child: _buildCalendar()),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
            // Member list drawer (slide in from right)
            if (_showMembers)
              GestureDetector(
                onTap: () => setState(() => _showMembers = false),
                child: Container(color: Colors.black45),
              ),
            if (_showMembers)
              Positioned(
                right: 0, top: 0, bottom: 0,
                width: 240,
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Thành viên (${_members.length})',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _showMembers = false)),
                        ]),
                      ),
                      const Divider(height: 1),
                      ..._members.map((name) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                          child: Text(name[0], style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
                        ),
                        title: Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: name == 'An' ? const Text('Chủ ví 👑', style: TextStyle(fontSize: 11, color: AppColors.teal)) : null,
                        trailing: name == 'An' ? null : IconButton(icon: const Icon(Icons.more_vert, size: 18, color: AppColors.muted), onPressed: () {}),
                      )),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(border: Border.all(color: AppColors.teal, width: 1.5), shape: BoxShape.circle),
                          child: const Icon(Icons.person_add_alt_1, color: AppColors.teal, size: 20),
                        ),
                        title: const Text('Mời thành viên', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600, fontSize: 14)),
                        onTap: () {},
                      ),
                    ]),
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
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(AppRadii.xl), bottomRight: Radius.circular(AppRadii.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 4),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ví chung · Gia đình', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            Text('${_members.length} thành viên', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
          ]),
          const Spacer(),
          // Add member
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          // Member list
          GestureDetector(
            onTap: () => setState(() => _showMembers = true),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.group, color: Colors.white, size: 18),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Balance card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AppColors.teal, size: 16),
              const SizedBox(width: 6),
              Text('Số dư ví chung', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Text('12.850.000 đ', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 24)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Stat(label: 'Đã nạp', value: '5.200.000 đ', color: AppColors.teal)),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(child: _Stat(label: 'Đã chi', value: '3.150.000 đ', color: AppColors.danger)),
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
          _TabItem(label: 'Story', icon: Icons.article_outlined, isSelected: _tab == 'Story', onTap: () => setState(() => _tab = 'Story')),
          _TabItem(label: 'Gallery', icon: Icons.grid_view, isSelected: _tab == 'Gallery', onTap: () => setState(() => _tab = 'Gallery')),
          _TabItem(label: 'Calendar', icon: Icons.calendar_month, isSelected: _tab == 'Calendar', onTap: () => setState(() => _tab = 'Calendar')),
        ]),
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final startWeekday = firstDay.weekday % 7;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('tháng ${now.month} ${now.year}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Row(children: ['S','M','T','W','T','F','S'].map((d) =>
          Expanded(child: Center(child: Text(d, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600))))).toList()),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: startWeekday + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
          itemBuilder: (ctx, i) {
            if (i < startWeekday) return const SizedBox();
            final day = i - startWeekday + 1;
            final isToday = day == now.day;
            return Container(
              decoration: BoxDecoration(
                border: isToday ? Border.all(color: AppColors.teal, width: 1.5) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text('$day', style: TextStyle(
                fontSize: 13, fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? AppColors.teal : AppColors.textPrimary,
              ))),
            );
          },
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _TabItem({required this.label, required this.icon, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
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
          Icon(icon, size: 15, color: isSelected ? AppColors.teal : AppColors.muted),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.teal : AppColors.muted, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
        ]),
      ),
    ),
  );
}

class _SharedStoryCard extends StatelessWidget {
  final HomeStory story;
  const _SharedStoryCard({required this.story});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push(AppRoutes.storyDetailOf('mock')),
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
            SizedBox(
              width: 40, height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(radius: 18, backgroundColor: AppColors.teal,
                    child: Text(story.userName[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  if (story.isOwner)
                    Positioned(
                      right: -2, top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Text('👑', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(story.userName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(story.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            ])),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz, color: AppColors.muted)),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 10), child: Text(story.title)),
        ClipRRect(child: CachedNetworkImage(imageUrl: story.imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Text('-${formatVnd(story.amount)}',
              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
      ]),
    ),
  );
}

class _SharedGalleryCard extends StatelessWidget {
  final GalleryItem item;
  const _SharedGalleryCard({required this.item});

  Color _catColor(String cat) {
    switch (cat) {
      case 'Ăn uống': return const Color(0xFFEC4899);
      case 'Mua sắm': return const Color(0xFF8B5CF6);
      case 'Di chuyển': return const Color(0xFF3B82F6);
      case 'Giải trí': return const Color(0xFFF59E0B);
      default: return AppColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push(AppRoutes.storyDetailOf('mock')),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover,
          errorWidget: (ctx, url, e) => Container(color: const Color(0xFFCBD5E1))),
        Positioned(left: 4, top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: _catColor(item.category), borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(item.categoryEmoji, style: const TextStyle(fontSize: 8)),
              const SizedBox(width: 2),
              Text(item.category, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        Positioned(left: 4, bottom: 4,
          child: Text('-${formatVnd(item.amount)}',
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)]))),
      ]),
    ),
  );
}