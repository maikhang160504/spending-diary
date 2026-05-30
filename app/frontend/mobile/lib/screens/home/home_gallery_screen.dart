import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../services/api_client.dart';
import '../../widgets/loading_indicator.dart';

class HomeGalleryScreen extends StatefulWidget {
  const HomeGalleryScreen({super.key});

  @override
  State<HomeGalleryScreen> createState() => _HomeGalleryScreenState();
}

class _HomeGalleryScreenState extends State<HomeGalleryScreen> {
  final _api = ApiClient();
  List<dynamic> _stories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      final res = await _api.getStories();
      if (mounted) {
        setState(() {
          _stories = res.where((s) =>
            (s['cover_image_url'] as String? ?? s['coverImageUrl'] as String? ?? '').isNotEmpty
          ).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HeaderSection(),
              _SegmentTabs(
                selected: 'Gallery',
                onTabSelected: (tab) {
                  if (tab == 'Story') context.pop();
                  if (tab == 'Calendar') context.push(AppRoutes.homeCalendar);
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Gallery', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(width: 6),
                        const Text('📸', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _loading
                        ? const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: LoadingIndicator(),
                          ))
                        : _stories.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Text('Chưa có story nào',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                                ),
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _stories.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 6,
                                  crossAxisSpacing: 6,
                                  childAspectRatio: 0.72,
                                ),
                                itemBuilder: (context, index) => _GalleryCard(story: _stories[index]),
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
                    const Text('🔥', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('7 ngày', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                        Text('Streak', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                _WalletChip(label: 'Ví riêng', icon: Icons.account_balance_wallet_outlined, isSelected: true),
                SizedBox(width: 8),
                _WalletChip(label: 'Gia đình (4)', icon: Icons.group_outlined),
                SizedBox(width: 8),
                _WalletChip(label: 'Nhóm bạn (3)', icon: Icons.groups_outlined),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.card,
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
                Text('5.380.000 đ', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 26)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _BalanceStat(label: 'Thu nhập', value: '8.000.000 đ', color: AppColors.teal)),
                    Container(width: 1, height: 28, color: AppColors.border),
                    Expanded(child: _BalanceStat(label: 'Chi tiêu', value: '2.620.000 đ', color: AppColors.danger)),
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

  const _WalletChip({required this.label, required this.icon, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.teal : Colors.white),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isSelected ? AppColors.teal : Colors.white, fontWeight: FontWeight.w600)),
        ],
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
  final ValueChanged<String> onTabSelected;

  const _SegmentTabs({required this.selected, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.palette.bg,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            _SegmentItem(label: 'Story', icon: Icons.article_outlined, isSelected: selected == 'Story', onTap: () => onTabSelected('Story')),
            _SegmentItem(label: 'Gallery', icon: Icons.grid_view, isSelected: selected == 'Gallery', onTap: () => onTabSelected('Gallery')),
            _SegmentItem(label: 'Calendar', icon: Icons.calendar_month, isSelected: selected == 'Calendar', onTap: () => onTabSelected('Calendar')),
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
            boxShadow: isSelected ? AppShadows.soft : null,
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
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final Map<String, dynamic> story;

  const _GalleryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final id = story['id'] as String? ?? '';
    final title = story['title'] as String? ?? 'Story';
    final category = story['category_code'] as String? ?? story['categoryCode'] as String? ?? '';
    final imageUrl = story['cover_image_url'] as String? ?? story['coverImageUrl'] as String? ?? '';
    final occurredOn = story['occurred_on'] as String? ?? story['occurredOn'] as String? ?? '';
    final amount = ((story['total_amount'] ?? story['totalAmount'] ?? 0) is num)
        ? ((story['total_amount'] ?? story['totalAmount'] ?? 0) as num).toInt()
        : 0;

    String dateStr = '';
    if (occurredOn.isNotEmpty) {
      try {
        final dt = DateTime.parse(occurredOn);
        dateStr = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return GestureDetector(
      onTap: id.isNotEmpty ? () => context.push(AppRoutes.storyDetailOf(id)) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 600,
                    errorWidget: (ctx, url, e) => Container(
                      color: const Color(0xFFCBD5E1),
                      child: const Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 24),
                    ),
                  )
                : Container(
                    color: const Color(0xFFCBD5E1),
                    child: const Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 24),
                  ),
            // Dark gradient overlay at bottom
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
            // Date top-left
            if (dateStr.isNotEmpty)
              Positioned(
                left: 5,
                top: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
                ),
              ),
            // Category top-right
            if (category.isNotEmpty)
              Positioned(
                right: 5,
                top: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    category.length > 8 ? '${category.substring(0, 6)}...' : category,
                    style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            // Amount bottom-left (prominent)
            Positioned(
              left: 5,
              right: 5,
              bottom: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (amount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '-${formatVnd(amount)}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white70, fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}