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
import '../../utils/formatters.dart';
import '../../widgets/radial_menu_fab.dart';
import '../../widgets/segment_tabs.dart';
import '../../widgets/transaction_story_card.dart';
import '../../widgets/story_gallery_card.dart';
import '../../widgets/inline_calendar_view.dart';
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
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    if (widget.walletId != null && widget.walletId!.isNotEmpty) {
      ApiClient.lastSelectedWalletId = widget.walletId;
    }
    // Tắt các thông báo khi vào ví chung
    WidgetsBinding.instance.addPostFrameCallback((_) {
      inAppNotificationController.dismiss();
    });
    PushNotificationService.instance.cancelAll();
    _loadData();
  }

  @override
  void dispose() {
    AppQueries.invalidateWalletData();
    super.dispose();
  }

  Map<String, dynamic> _overview = {};

  int get _totalIncome {
    final v = _overview['totalFund'] ?? 0;
    return v is num ? v.toInt() : 0;
  }

  int get _totalExpense {
    final v = _overview['totalSpent'] ?? 0;
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
        _api.getDashboard(walletId: id), // still needed for calendar
        _api.getTransactions(walletId: id, pageSize: 50),
        AppQueries.me().result,
        _api.getGroupOverview(id),
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
        
        final meResult = results[5];
 // generic QueryResult
         final data = (meResult as dynamic).data as Map<String, dynamic>?;
         _currentUserId = data?['user']?['id'] as String?;
        _stories = results[2] as List<dynamic>;
        _dashboard = results[3] as Map<String, dynamic>;
        _transactions = txs;
        _overview = results[6] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Không thể tải dữ liệu ví'; });
    }
  }

  Future<void> _showInviteDialog() async {
    String? inviteCode;
    bool generatingCode = true; // start loading immediately
    String? inviteError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Load existing code immediately when dialog mounts
          if (generatingCode && inviteCode == null && inviteError == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final res = await _api.generateWalletInviteCode(widget.walletId!);
                if (ctx.mounted) {
                  setDialogState(() {
                    inviteCode = res['code'] as String?;
                    generatingCode = false;
                  });
                }
              } catch (_) {
                if (ctx.mounted) {
                  setDialogState(() {
                    inviteError = 'Không thể tạo mã mời.';
                    generatingCode = false;
                  });
                }
              }
            });
          }
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
                    const SizedBox(height: 8),
                    // Regenerate code button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: generatingCode ? null : () async {
                          setDialogState(() { generatingCode = true; inviteCode = null; });
                          try {
                            // Revoke old and generate new
                            final res = await _api.generateWalletInviteCode(widget.walletId!);
                            setDialogState(() {
                              inviteCode = res['code'] as String?;
                              generatingCode = false;
                            });
                          } catch (_) {
                            setDialogState(() {
                              inviteError = 'Không thể tạo lại mã mời.';
                              generatingCode = false;
                            });
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Tạo mã mới'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                      ),
                    ),
                  ] else if (generatingCode) ...[
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2),
                    )),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                                setDialogState(() => generatingCode = true);
                                try {
                                  final res = await _api.generateWalletInviteCode(widget.walletId!);
                                  setDialogState(() {
                                    inviteCode = res['code'] as String?;
                                    generatingCode = false;
                                  });
                                } catch (_) {
                                  setDialogState(() {
                                    inviteError = 'Không thể tạo mã mời.';
                                    generatingCode = false;
                                  });
                                }
                              },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Tạo mã mời'),
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

  Future<void> _confirmLeave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rời khỏi nhóm'),
        content: const Text('Bạn có chắc muốn rời khỏi ví nhóm này? Bạn sẽ không còn xem được các giao dịch trong nhóm.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rời nhóm', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _api.leaveWallet(widget.walletId!);
      if (!mounted) return;
      context.pop(); // Return to wallet list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã rời nhóm')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.localizedMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể rời nhóm, vui lòng thử lại.')));
    }
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
                            final tx = _transactions[i];
                            final storyIds = _transactions
                                .map<String>((t) => (t['storyId'] as String?) ?? (t['story_id'] as String?) ?? (t['id'] as String?) ?? '')
                                .where((e) => e.isNotEmpty)
                                .toList();
                            if (tx['id'] == 'create_wallet') {
                              return const SizedBox.shrink();
                            }
                            return TransactionStoryCard(
                              tx: tx,
                              allStoryIds: storyIds,
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
                              return StoryGalleryCard(
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
                    child: InlineCalendarView(
                      byDay: _dashboard['byDay'] as List<dynamic>? ?? [],
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
                              final isMe = member['id'] == _currentUserId;
                              final isCurrentUserOwner = _members.any((m) => m['id'] == _currentUserId && m['role'] == 'owner');
                              
                              Widget? trailingWidget;
                              if (isCurrentUserOwner) {
                                trailingWidget = isOwner ? null : IconButton(
                                  icon: const Icon(Icons.person_remove_outlined, size: 18, color: AppColors.danger),
                                  onPressed: () => _confirmRemove(member),
                                );
                              } else {
                                trailingWidget = isMe ? IconButton(
                                  icon: const Icon(Icons.exit_to_app, size: 18, color: AppColors.danger),
                                  tooltip: 'Rời nhóm',
                                  onPressed: () { setState(() => _showMembers = false); _confirmLeave(); },
                                ) : null;
                              }

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
                                trailing: trailingWidget,
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
      floatingActionButton: RadialMenuFab(
        onSelectChat: () {
          context.push(
            AppRoutes.chat,
            extra: {'walletId': widget.walletId},
          );
        },
        onSelectBill: () {
          context.push(
            AppRoutes.camera,
            extra: {
              'walletId': widget.walletId,
              'initialMode': 'Bill',
            },
          );
        },
        onSelectPhoto: () {
          context.push(
            AppRoutes.camera,
            extra: {
              'walletId': widget.walletId,
              'initialMode': 'Ảnh',
            },
          );
        },
        onSelectReport: () {
          context.push(AppRoutes.groupAnalyticsOf(widget.walletId!));
        },
      ),
    );
  }

  Widget _buildHeader() {
    final walletName = _wallet['name'] as String? ?? 'Ví chung';
    final walletIcon = _wallet['icon'] as String? ?? '💼';
    final walletColorHex = (_wallet['color'] as String? ?? '#0D9488').replaceAll('#', '');
    Color walletColor;
    try {
      walletColor = Color(int.parse(walletColorHex.length == 6 ? 'FF$walletColorHex' : walletColorHex, radix: 16));
    } catch (_) {
      walletColor = const Color(0xFF0D9488);
    }
    // Derive a lighter, gentle variant for gradient end
    final hsl = HSLColor.fromColor(walletColor);
    final lightColor = hsl
        .withSaturation((hsl.saturation * 0.72).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.18).clamp(0.0, 0.92))
        .toColor();

    final remaining = (_overview['remaining'] as num?)?.toInt() ?? (_wallet['balance'] as num?)?.toInt() ?? 0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [walletColor, lightColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(AppRadii.xl), bottomRight: Radius.circular(AppRadii.xl)),
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
          // Wallet icon + name
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
            child: Center(child: Text(walletIcon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(walletName, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              Text('${_members.length} thành viên', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ]),
          ),
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_awesome, color: walletColor, size: 16),
              const SizedBox(width: 6),
              Text('Còn lại', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Text(
              formatVnd(remaining),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                  ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: BalanceStat(label: 'Quỹ nhóm', value: formatVnd(_totalIncome), color: walletColor)),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(child: BalanceStat(label: 'Đã chi', value: formatVnd(_totalExpense), color: AppColors.danger)),
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
          SegmentItem(label: 'Giao dịch', icon: Icons.article_outlined, isSelected: _tab == 'Story', onTap: () => setState(() => _tab = 'Story')),
          SegmentItem(label: 'Gallery', icon: Icons.grid_view, isSelected: _tab == 'Gallery', onTap: () => setState(() => _tab = 'Gallery')),
          SegmentItem(label: 'Calendar', icon: Icons.calendar_month, isSelected: _tab == 'Calendar', onTap: () => setState(() => _tab = 'Calendar')),
        ]),
      ),
    );
  }
}