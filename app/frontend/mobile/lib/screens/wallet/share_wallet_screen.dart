import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/loading_indicator.dart';

class ShareWalletScreen extends StatefulWidget {
  final String? walletId;
  const ShareWalletScreen({super.key, this.walletId});
  @override
  State<ShareWalletScreen> createState() => _ShareWalletScreenState();
}

class _ShareWalletScreenState extends State<ShareWalletScreen> {
  final _api = ApiClient();
  String _tab = 'Story';
  bool _showMembers = false;
  bool _loading = true;
  Map<String, dynamic> _wallet = {};
  List<dynamic> _members = [];
  List<dynamic> _stories = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final id = widget.walletId;
    if (id == null || id.isEmpty) {
      setState(() { _loading = false; _error = 'Không tìm thấy ví'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getWallet(id),
        _api.getWalletMembers(id),
        _api.getStories(walletId: id),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = results[0] as Map<String, dynamic>;
        _members = results[1] as List<dynamic>;
        _stories = results[2] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Không thể tải dữ liệu ví'; });
    }
  }

  Future<void> _showInviteDialog() async {
    final emailCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mời thành viên'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Email người dùng',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim()),
            child: const Text('Mời'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    try {
      final updated = await _api.inviteWalletMember(widget.walletId!, result);
      if (!mounted) return;
      setState(() => _members = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã mời thành viên thành công')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.localizedMessage)));
    }
  }

  Future<void> _confirmRemove(Map<String, dynamic> member) async {
    final name = member['username'] as String? ?? member['email'] as String? ?? 'thành viên này';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá thành viên'),
        content: Text('Bạn có chắc muốn xoá $name khỏi ví không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _api.removeWalletMember(widget.walletId!, member['id'] as String);
      if (!mounted) return;
      setState(() => _members.removeWhere((m) => m['id'] == member['id']));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xoá thành viên')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.localizedMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger))));
    }
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSegmentTabs()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (_tab == 'Story')
                  _stories.isEmpty
                    ? SliverToBoxAdapter(child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text('Chưa có story nào', style: TextStyle(color: AppColors.muted))),
                      ))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _SharedStoryCard(story: _stories[i] as Map<String, dynamic>),
                          childCount: _stories.length,
                        ),
                      ),
                if (_tab == 'Gallery')
                  _stories.isEmpty
                    ? SliverToBoxAdapter(child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text('Chưa có ảnh nào', style: TextStyle(color: AppColors.muted))),
                      ))
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _SharedGalleryCard(story: _stories[i] as Map<String, dynamic>),
                            childCount: _stories.length,
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
            if (_showMembers)
              GestureDetector(
                onTap: () => setState(() => _showMembers = false),
                child: Container(color: Colors.black45),
              ),
            if (_showMembers)
              Positioned(
                right: 0, top: 0, bottom: 0,
                width: 260,
                child: Container(
                  color: context.palette.card,
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
                      Expanded(
                        child: ListView(
                          children: [
                            ..._members.map((m) {
                              final member = m as Map<String, dynamic>;
                              final name = member['username'] as String? ?? member['email'] as String? ?? '?';
                              final role = member['role'] as String? ?? 'member';
                              final isOwner = role == 'owner';
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                                  backgroundImage: member['avatarUrl'] != null
                                      ? NetworkImage(member['avatarUrl'] as String) : null,
                                  child: member['avatarUrl'] == null
                                      ? Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700))
                                      : null,
                                ),
                                title: Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  isOwner ? 'Chủ ví 👑' : role,
                                  style: TextStyle(fontSize: 11, color: isOwner ? AppColors.teal : AppColors.muted),
                                ),
                                trailing: isOwner ? null : IconButton(
                                  icon: const Icon(Icons.person_remove_outlined, size: 18, color: AppColors.danger),
                                  onPressed: () => _confirmRemove(member),
                                ),
                              );
                            }),
                            const Divider(height: 1),
                            ListTile(
                              leading: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(border: Border.all(color: AppColors.teal, width: 1.5), shape: BoxShape.circle),
                                child: const Icon(Icons.person_add_alt_1, color: AppColors.teal, size: 20),
                              ),
                              title: const Text('Mời thành viên', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600, fontSize: 14)),
                              onTap: () { setState(() => _showMembers = false); _showInviteDialog(); },
                            ),
                          ],
                        ),
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
    final walletName = _wallet['name'] as String? ?? 'Ví chung';
    final balance = (_wallet['balance'] as num?)?.toInt() ?? 0;
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
            Text(walletName, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            Text('${_members.length} thành viên', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: _showInviteDialog,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.palette.card, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AppColors.teal, size: 16),
              const SizedBox(width: 6),
              Text('Số dư ví chung', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Text(formatVnd(balance), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 24)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSegmentTabs() {
    return Container(
      color: context.palette.bg,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: context.palette.surfaceAlt, borderRadius: BorderRadius.circular(AppRadii.lg)),
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
          boxShadow: isSelected ? AppShadows.soft : null,
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
  final Map<String, dynamic> story;
  const _SharedStoryCard({required this.story});
  @override
  Widget build(BuildContext context) {
    final id = story['id'] as String? ?? '';
    final title = story['title'] as String? ?? 'Story';
    final imageUrl = story['cover_image_url'] as String? ?? '';
    final occurredOn = story['occurred_on'] as String? ?? '';
    return GestureDetector(
      onTap: id.isNotEmpty ? () => context.push(AppRoutes.storyDetailOf(id)) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 6),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: context.palette.softShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(children: [
              const Icon(Icons.article_outlined, color: AppColors.teal, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
              Text(occurredOn.length >= 10 ? occurredOn.substring(5, 10) : '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            ]),
          ),
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(AppRadii.lg), bottomRight: Radius.circular(AppRadii.lg)),
              child: CachedNetworkImage(imageUrl: imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover, memCacheWidth: 1080,
                errorWidget: (ctx, url, e) => Container(height: 80, color: const Color(0xFFCBD5E1))),
            ),
          if (imageUrl.isEmpty) const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _SharedGalleryCard extends StatelessWidget {
  final Map<String, dynamic> story;
  const _SharedGalleryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final id = story['id'] as String? ?? '';
    final title = story['title'] as String? ?? '';
    final imageUrl = story['cover_image_url'] as String? ?? '';
    return GestureDetector(
      onTap: id.isNotEmpty ? () => context.push(AppRoutes.storyDetailOf(id)) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Stack(fit: StackFit.expand, children: [
          imageUrl.isNotEmpty
              ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, memCacheWidth: 600,
                  errorWidget: (ctx, url, e) => Container(color: const Color(0xFFCBD5E1)))
              : Container(color: const Color(0xFFCBD5E1),
                  child: const Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 24)),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
              stops: const [0.5, 1.0],
            ),
          ))),
          if (title.isNotEmpty)
            Positioned(left: 5, bottom: 5, right: 5,
              child: Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}