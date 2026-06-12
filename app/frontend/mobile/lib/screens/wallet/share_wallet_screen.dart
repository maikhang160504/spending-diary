import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/app_queries.dart';
import '../../services/push_notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../services/transaction_notifier.dart';
import '../../utils/formatters.dart';
import '../../utils/mimo_emotion.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/notification_overlay.dart';

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
  List<dynamic> _transactions = [];
  Map<String, dynamic> _dashboard = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.walletId != null && widget.walletId!.isNotEmpty) {
      ApiClient.lastSelectedWalletId = widget.walletId;
    }
    // Tắt các thông báo khi vào ví chung
    inAppNotificationController.dismiss();
    PushNotificationService.instance.cancelAll();
    _loadData();
  }

  @override
  void dispose() {
    AppQueries.invalidateWalletData();
    super.dispose();
  }

  int get _totalIncome {
    final totals = _dashboard['totals'] as Map<String, dynamic>?;
    final v = totals?['income'] ?? _dashboard['totalIncome'] ?? 0;
    return v is num ? v.toInt() : 0;
  }

  int get _totalExpense {
    final totals = _dashboard['totals'] as Map<String, dynamic>?;
    final v = totals?['expense'] ?? _dashboard['totalExpense'] ?? 0;
    return v is num ? v.toInt() : 0;
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
        _api.getDashboard(walletId: id),
        _api.getTransactions(walletId: id, pageSize: 50),
      ]);
      if (!mounted) return;
      
      final txResult = results[4] as Map<String, dynamic>;
      final txData = txResult['data'];
      List<dynamic> txs = [];
      if (txData is Map<String, dynamic>) {
        txs = txData['items'] ?? [];
      } else if (txData is List<dynamic>) {
        txs = txData;
      }

      setState(() {
        _wallet = results[0] as Map<String, dynamic>;
        _members = results[1] as List<dynamic>;
        _stories = results[2] as List<dynamic>;
        _dashboard = results[3] as Map<String, dynamic>;
        _transactions = txs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Không thể tải dữ liệu ví'; });
    }
  }

  Future<void> _showInviteDialog() async {
    String? inviteCode;
    bool generatingCode = false;
    String? inviteError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final palette = ctx.palette;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text(
                    'Mời thành viên tham gia ví',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  if (inviteError != null) ...[
                    Text(inviteError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                    const SizedBox(height: 10),
                  ],
                  // Invite Code Section
                  Text('Mời bằng Mã mời (6 ký tự)', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: palette.textSecondary)),
                  const SizedBox(height: 8),
                  if (inviteCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.vpn_key_outlined, color: AppColors.teal),
                          const SizedBox(width: 10),
                          SelectableText(
                            inviteCode!,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Mã mời có hiệu lực trong 7 ngày, cho phép tối đa 10 lượt sử dụng.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: generatingCode
                            ? null
                            : () async {
                                setDialogState(() => generatingCode = true);
                                try {
                                  final res = await _api.generateWalletInviteCode(widget.walletId!);
                                  setDialogState(() {
                                    inviteCode = res['code'];
                                    generatingCode = false;
                                  });
                                } catch (_) {
                                  setDialogState(() {
                                    inviteError = 'Không thể tạo mã mời.';
                                    generatingCode = false;
                                  });
                                }
                              },
                        icon: generatingCode
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.qr_code_scanner),
                        label: const Text('Tạo mã mời mới'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.teal,
                          side: const BorderSide(color: AppColors.teal),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(Map<String, dynamic> member) async {
    final name = member['username'] as String? ?? member['email'] as String? ?? 'thành viên này';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Xoá thành viên'),
            content: Text('Bạn có chắc muốn xoá $name khỏi ví không?'),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                child: const Text('Huỷ'),
              ),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        setDialogState(() {
                          isSubmitting = true;
                        });
                        Navigator.pop(ctx, true);
                      },
                child: const Text('Xoá', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        );
      },
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
                  _transactions.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: EmptyState(
                              emoji: '📝',
                              title: 'Chưa có giao dịch',
                              subtitle: 'Ghi nhận giao dịch chung đầu tiên ngay!',
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final navIds = _transactions
                                .map<String>((t) => (t['storyId'] as String?) ?? (t['story_id'] as String?) ?? (t['id'] as String?) ?? '')
                                .where((e) => e.isNotEmpty)
                                .toList();
                            return _TransactionStoryCard(
                              tx: _transactions[i],
                              allStoryIds: navIds,
                              walletOwnerId: _wallet['ownerId'] ?? _wallet['owner_id'],
                            );
                          },
                          childCount: _transactions.length,
                        ),
                      ),
                if (_tab == 'Gallery')
                  _stories.isEmpty
                    ? const SliverToBoxAdapter(child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('Chưa có ảnh nào', style: TextStyle(color: AppColors.muted))),
                      ))
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final galleryStories = _stories.where((s) =>
                                (s['cover_image_url'] as String? ?? s['coverImageUrl'] as String? ?? '').isNotEmpty
                              ).toList();
                              final galleryIds = galleryStories
                                  .map((s) => (s['id'] as String?) ?? '')
                                  .where((e) => e.isNotEmpty)
                                  .toList();
                              return _StoryGalleryCard(
                                story: galleryStories[i] as Map<String, dynamic>,
                                allStoryIds: galleryIds,
                                initialIndex: i,
                              );
                            },
                            childCount: _stories.where((s) => (s['cover_image_url'] as String? ?? s['coverImageUrl'] as String? ?? '').isNotEmpty).length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, mainAxisSpacing: 5, crossAxisSpacing: 5, childAspectRatio: 1.0,
                          ),
                        ),
                      ),
                if (_tab == 'Calendar')
                  SliverToBoxAdapter(
                    child: _InlineCalendarView(
                      byDay: (_dashboard['byDay'] as List<dynamic>?) ?? [],
                      transactions: _transactions,
                      walletOwnerId: _wallet['ownerId'] ?? _wallet['owner_id'],
                    ),
                  ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.camera, extra: {'walletId': widget.walletId}),
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.camera_alt_outlined, color: Colors.white),
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
            onTap: () => context.push(AppRoutes.camera, extra: {'walletId': widget.walletId}),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.push(AppRoutes.chat, extra: {'walletId': widget.walletId}),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
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
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _BalanceStat(label: 'Thu nhập', value: formatVnd(_totalIncome), color: AppColors.teal)),
              Container(width: 1, height: 28, color: context.palette.border),
              Expanded(child: _BalanceStat(label: 'Chi tiêu', value: formatVnd(_totalExpense), color: AppColors.danger)),
            ]),
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
          _TabItem(label: 'Giao dịch', icon: Icons.article_outlined, isSelected: _tab == 'Story', onTap: () => setState(() => _tab = 'Story')),
          _TabItem(label: 'Gallery', icon: Icons.grid_view, isSelected: _tab == 'Gallery', onTap: () => setState(() => _tab = 'Gallery')),
          _TabItem(label: 'Calendar', icon: Icons.calendar_month, isSelected: _tab == 'Calendar', onTap: () => setState(() => _tab = 'Calendar')),
        ]),
      ),
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

class _TransactionStoryCard extends StatelessWidget {
  final dynamic tx;
  final List<String>? allStoryIds;
  final String? walletOwnerId;
  const _TransactionStoryCard({required this.tx, this.allStoryIds, this.walletOwnerId});

  static const _categories = [
    ('Food', 'Ăn uống'), ('Shopping', 'Mua sắm'), ('Transport', 'Di chuyển'),
    ('Entertainment', 'Giải trí'), ('Housing', 'Nhà ở'), ('Health', 'Sức khoẻ'),
    ('Education', 'Học tập'), ('Travel', 'Du lịch'), ('Others', 'Khác'),
  ];

  Future<void> _onLongPress(BuildContext context) async {
    final api = ApiClient();
    final note = tx['note'] as String? ?? '';
    final text = note.isNotEmpty ? note : (tx['category_name'] as String? ?? '');
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Sửa danh mục (AI training)',
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ..._categories.map((c) => ListTile(
            leading: CategoryTheme.iconOf(c.$1, size: 22),
            title: Text(c.$2),
            onTap: () => Navigator.pop(ctx, c.$1),
          )),
        ]),
      ),
    );
    if (picked == null) return;
    try {
      await api.aiCorrection({'text': text, 'categoryCode': picked, 'recordType': tx['type'] == 'income' ? 'Income' : 'Expense'});
      await api.updateTransaction(tx['id'] ?? '', {'categoryCode': picked});
      notifyTransactionChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật giao dịch và ghi nhận góp ý! Mimo sẽ học thêm từ bạn 🙏'),
            backgroundColor: AppColors.teal,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final amount = ((tx['amount'] ?? 0) is num) ? (tx['amount'] as num).toInt() : 0;
    final type = tx['type'] as String? ?? 'expense';
    final category = tx['category_name'] as String? ?? tx['categoryCode'] as String? ?? tx['category_code'] as String? ?? 'Other';
    final note = tx['note'] as String? ?? '';
    final createdAt = tx['createdAt'] as String? ?? tx['created_at'] as String? ?? '';
    final isExpense = type == 'expense';
    final catStyle = CategoryTheme.of(category);

    final storyId = tx['storyId'] as String? ?? tx['story_id'] as String? ?? tx['id'] as String? ?? '';
    final imageUrl = tx['imageUrl'] as String? ?? tx['image_url'] as String?;
    final aiComment = tx['aiComment'] as String? ?? tx['ai_message'] as String?;
    final mascotMoodRaw = tx['mascotMood'] as String? ?? tx['mascot_mood'] as String?;
    final mascotMood = normalizeMimoAssetName(mascotMoodRaw, fallback: 'Success');

    // User display
    final userName = tx['username'] as String? ?? tx['user_name'] as String? ?? 'Bạn';
    final userAvatar = tx['userAvatar'] as String? ?? tx['user_avatar'] as String?;

    final creatorId = tx['creatorId'] as String? ?? tx['creator_id'] as String? ?? '';
    final isWalletOwner = creatorId.isNotEmpty && walletOwnerId != null && creatorId == walletOwnerId;
    final showCrown = isWalletOwner;

    return GestureDetector(
      onTap: storyId.isNotEmpty
          ? () {
              final ids = allStoryIds;
              if (ids != null && ids.isNotEmpty) {
                final idx = ids.indexOf(storyId);
                context.push(AppRoutes.storyDetailOf(storyId), extra: {
                  'storyIds': ids,
                  'initialIndex': idx < 0 ? 0 : idx,
                });
              } else {
                context.push(AppRoutes.storyDetailOf(storyId));
              }
            }
          : null,
      onLongPress: () => _onLongPress(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: context.palette.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Post header: avatar + name + time + category badge ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  // User avatar circle (letter-based when no photo)
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: catStyle.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: catStyle.color.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: userAvatar != null && userAvatar.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: userAvatar,
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              errorWidget: (_, _, _) => Center(
                                child: Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : 'B',
                                  style: TextStyle(color: catStyle.color, fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'B',
                              style: TextStyle(color: catStyle.color, fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              userName,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (showCrown) ...[
                              const SizedBox(width: 4),
                              const Text('👑', style: TextStyle(fontSize: 14)),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: catStyle.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                catStyle.label,
                                style: TextStyle(color: catStyle.color, fontSize: 9, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (createdAt.isNotEmpty)
                              Text(
                                _formatTime(createdAt),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontSize: 10),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz, color: AppColors.muted, size: 20),
                ],
              ),
            ),

            // ── Caption: user's note (text they typed) ──
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  note,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),

            // ── Photo attachment — tỉ lệ vuông 1:1 (kích thước tối ưu cho story) ──
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 1080,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],

            // ── Amount chip shown below the image ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isExpense
                          ? AppColors.danger.withValues(alpha: 0.1)
                          : AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          size: 12,
                          color: isExpense ? AppColors.danger : AppColors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatVnd(amount),
                          style: TextStyle(
                            color: isExpense ? AppColors.danger : AppColors.teal,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: context.palette.divider),

            // ── AI comment: emotion avatar + comment bubble (luôn hiển thị) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/MiMo/emotions/$mascotMood.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text('😎', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.palette.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mimo AI',
                            style: TextStyle(
                              color: AppColors.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (aiComment != null && aiComment.isNotEmpty)
                                ? aiComment
                                : 'Mimo đã ghi nhận giao dịch này!',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.palette.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

class _StoryGalleryCard extends StatelessWidget {
  final Map<String, dynamic> story;
  final List<String>? allStoryIds;
  final int initialIndex;
  const _StoryGalleryCard({required this.story, this.allStoryIds, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final id = story['id'] as String? ?? '';
    final title = story['title'] as String? ?? '';
    final imageUrl = story['cover_image_url'] as String? ?? story['coverImageUrl'] as String? ?? '';
    final occurredOn = story['occurred_on'] as String? ?? story['occurredOn'] as String? ?? '';
    String dateStr = '';
    if (occurredOn.isNotEmpty) {
      try {
        final dt = DateTime.parse(occurredOn).toLocal();
        dateStr = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return GestureDetector(
      onTap: id.isNotEmpty
          ? () {
              final ids = allStoryIds;
              if (ids != null && ids.isNotEmpty) {
                final idx = ids.indexOf(id);
                context.push(AppRoutes.storyDetailOf(id), extra: {
                  'storyIds': ids,
                  'initialIndex': idx < 0 ? initialIndex : idx,
                });
              } else {
                context.push(AppRoutes.storyDetailOf(id));
              }
            }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Stack(fit: StackFit.expand, children: [
          imageUrl.isNotEmpty
              ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, memCacheWidth: 600,
                  errorWidget: (ctx, url, e) => Container(color: const Color(0xFFCBD5E1),
                      child: const Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 24)))
              : Container(color: const Color(0xFFCBD5E1),
                  child: const Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 24)),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
              stops: const [0.5, 1.0],
            ),
          ))),
          if (dateStr.isNotEmpty)
            Positioned(left: 5, top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                child: Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 8)),
              ),
            ),
          Positioned(left: 5, bottom: 5, right: 5,
            child: Text(
              title.isNotEmpty ? title : 'Story',
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}

class _InlineCalendarView extends StatefulWidget {
  final List<dynamic> byDay;
  final List<dynamic> transactions;
  final String? walletOwnerId;
  const _InlineCalendarView({this.byDay = const [] , this.transactions = const [], this.walletOwnerId});
  @override
  State<_InlineCalendarView> createState() => _InlineCalendarViewState();
}

class _InlineCalendarViewState extends State<_InlineCalendarView> {
  DateTime _focus = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;

  Map<int, Map<String, dynamic>> get _dayMap {
    final result = <int, Map<String, dynamic>>{};
    for (final entry in widget.byDay) {
      final e = entry as Map<String, dynamic>;
      final dayStr = e['day'] as String? ?? '';
      if (dayStr.isEmpty) continue;
      try {
        final dt = DateTime.parse(dayStr);
        if (dt.year == _focus.year && dt.month == _focus.month) {
          result[dt.day] = e;
        }
      } catch (_) {}
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_focus.year, _focus.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_focus.year, _focus.month);
    final startWeekday = firstDay.weekday % 7;
    final dayMap = _dayMap;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(children: [
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
        Row(children: ['S','M','T','W','T','F','S'].map((d) =>
          Expanded(child: Center(child: Text(d, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600))))).toList()),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: startWeekday + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.58,
          ),
          itemBuilder: (ctx, i) {
            if (i < startWeekday) return const SizedBox();
            final day = i - startWeekday + 1;
            final isSelected = _selectedDay == day;
            final isToday = _focus.month == DateTime.now().month && _focus.year == DateTime.now().year && day == DateTime.now().day;

            final dayTxList = widget.transactions.where((tx) {
              final dateStr = tx['occurredAt'] as String? ?? tx['occurred_at'] as String? ?? tx['createdAt'] as String? ?? tx['created_at'] as String? ?? '';
              if (dateStr.isEmpty) return false;
              try {
                final dt = DateTime.parse(dateStr).toLocal();
                return dt.year == _focus.year && dt.month == _focus.month && dt.day == day;
              } catch (_) {
                return false;
              }
            }).toList();

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = _selectedDay == day ? null : day),
              child: _buildDayCell(day, dayTxList, isSelected, isToday),
            );
          },
        ),
        if (_selectedDay != null && dayMap[_selectedDay!] != null) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              '$_selectedDay tháng ${_focus.month} ${_focus.year}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '-${formatVnd((dayMap[_selectedDay!]!['expense'] as num?)?.toInt() ?? 0)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
              ),
              if (((dayMap[_selectedDay!]!['income'] as num?)?.toInt() ?? 0) > 0)
                Text(
                  '+${formatVnd((dayMap[_selectedDay!]!['income'] as num?)?.toInt() ?? 0)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600),
                ),
            ]),
          ]),
          const SizedBox(height: 12),
          ...widget.transactions.where((tx) {
            final dateStr = tx['occurredAt'] as String? ?? tx['occurred_at'] as String? ?? tx['createdAt'] as String? ?? tx['created_at'] as String? ?? '';
            if (dateStr.isEmpty) return false;
            try {
              final dt = DateTime.parse(dateStr).toLocal();
              return dt.year == _focus.year && dt.month == _focus.month && dt.day == _selectedDay;
            } catch (_) {
              return false;
            }
          }).map((tx) {
            final dayNavIds = widget.transactions.where((t) {
              final ds = t['occurredAt'] as String? ?? t['occurred_at'] as String? ?? t['createdAt'] as String? ?? t['created_at'] as String? ?? '';
              if (ds.isEmpty) return false;
              try {
                final d = DateTime.parse(ds).toLocal();
                return d.year == _focus.year && d.month == _focus.month && d.day == _selectedDay;
              } catch (_) { return false; }
            }).map<String>((t) => (t['storyId'] as String?) ?? (t['story_id'] as String?) ?? (t['id'] as String?) ?? '').where((e) => e.isNotEmpty).toList();
            return _TransactionStoryCard(
              tx: tx,
              allStoryIds: dayNavIds,
              walletOwnerId: widget.walletOwnerId,
            );
          }),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildDayCell(int day, List<dynamic> dayTxList, bool isSelected, bool isToday) {
    if (dayTxList.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teal.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.teal, width: 1.5)
              : isToday
                  ? Border.all(color: AppColors.teal.withValues(alpha: 0.5), width: 1.5)
                  : Border.all(color: context.palette.border, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 36, height: 36),
            const SizedBox(height: 8),
            Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? AppColors.teal : context.palette.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    final imageTx = dayTxList.firstWhere(
      (tx) => (tx['imageUrl'] as String? ?? tx['image_url'] as String? ?? '').isNotEmpty,
      orElse: () => null,
    );

    final hasMultiple = dayTxList.length > 1;

    Widget buildCardContent(dynamic tx) {
      if (tx == null) return Container(color: const Color(0xFFCBD5E1));
      final imgUrl = tx['imageUrl'] as String? ?? tx['image_url'] as String? ?? '';
      if (imgUrl.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: imgUrl,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFFCBD5E1),
            child: const Icon(Icons.broken_image_outlined, size: 14, color: Colors.white70),
          ),
        );
      } else {
        final category = tx['category_name'] as String? ?? tx['categoryCode'] as String? ?? tx['category_code'] as String? ?? 'Other';
        return Container(
          color: CategoryTheme.colorOf(category).withValues(alpha: 0.85),
          child: Center(
            child: CategoryTheme.iconOf(category, size: 18),
          ),
        );
      }
    }

    final bottomTx = dayTxList.length > 1 ? dayTxList[1] : null;
    final topTx = imageTx ?? dayTxList[0];

    const cardSize = 36.0;

    Widget topCard = Container(
      width: cardSize,
      height: cardSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: buildCardContent(topTx),
      ),
    );

    Widget stackWidget;
    if (hasMultiple) {
      Widget bottomCard = Container(
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: buildCardContent(bottomTx ?? dayTxList[0]),
        ),
      );

      stackWidget = SizedBox(
        width: cardSize + 6,
        height: cardSize + 4,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              top: 4,
              child: Transform.rotate(
                angle: -0.1,
                child: bottomCard,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Transform.rotate(
                angle: 0.08,
                child: topCard,
              ),
            ),
          ],
        ),
      );
    } else {
      stackWidget = SizedBox(
        width: cardSize + 6,
        height: cardSize + 4,
        child: Center(
          child: topCard,
        ),
      );
    }

    final remainingCount = dayTxList.length - 1;

    Widget cardWithBadge = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        stackWidget,
        if (remainingCount > 0)
          Positioned(
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '+$remainingCount',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.teal.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: AppColors.teal, width: 1.5)
            : isToday
                ? Border.all(color: AppColors.teal.withValues(alpha: 0.5), width: 1.5)
                : Border.all(color: context.palette.border, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          cardWithBadge,
          const SizedBox(height: 8),
          Text(
            '$day',
            style: TextStyle(
              fontSize: 11,
              fontWeight: (isToday || isSelected) ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? AppColors.teal : context.palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}