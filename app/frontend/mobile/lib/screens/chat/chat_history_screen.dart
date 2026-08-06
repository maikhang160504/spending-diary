import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/skeleton.dart';

/// Chat History Screen — CHH-01..CHH-03
class ChatHistoryScreen extends StatefulWidget {
  final String? walletId;
  const ChatHistoryScreen({super.key, this.walletId});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final _api = ApiClient();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<dynamic> _sessions = [];
  List<dynamic> _filtered = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    try {
      final sessions = await _api.getChatSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _filtered = sessions;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteSession(String sessionId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Xóa cuộc trò chuyện?'),
            content: const Text('Tất cả tin nhắn sẽ bị xóa vĩnh viễn.'),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
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
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    try {
      await _api.deleteChatSession(sessionId);
      if (!mounted) return;
      setState(() {
        _sessions.removeWhere((s) => s['id'] == sessionId);
        _filtered.removeWhere((s) => s['id'] == sessionId);
      });
    } catch (_) {}
  }

  // CHH-03: Client-side search filter
  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _sessions
          : _sessions.where((s) {
              final title = (s['title'] as String? ?? '').toLowerCase();
              return title.contains(q);
            }).toList();
    });
  }

  String _formatTime(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
      if (diff.inDays == 1) return 'Hôm qua';
      if (diff.inDays < 7) return '${diff.inDays} ngày trước';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: AppGradients.teal,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadii.xl),
                  bottomRight: Radius.circular(AppRadii.xl),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 14, 16, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lịch sử trò chuyện',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              '${_sessions.length} cuộc trò chuyện',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      // CHH-03: Search toggle
                      GestureDetector(
                        onTap: () => setState(() {
                          _searching = !_searching;
                          if (!_searching) {
                            _searchCtrl.clear();
                            _filtered = _sessions;
                          }
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _searching ? Icons.close : Icons.search,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Search bar
                  if (_searching) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm cuộc trò chuyện...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.15),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                          size: 18,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          borderSide: const BorderSide(color: Colors.white38),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // New chat button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: GestureDetector(
                onTap: () {
                  context.pop();
                  context.push(
                    AppRoutes.chat,
                    extra: {'walletId': widget.walletId, 'forceNew': true},
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppGradients.teal,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2014B8A6),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('✨', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trò chuyện mới với Mimo',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              'Bắt đầu cuộc trò chuyện mới',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Session list
            Expanded(
              child: _loading
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                      ),
                      itemCount: 4,
                      separatorBuilder: (_, idx) => const SizedBox(height: 10),
                      itemBuilder: (_, idx) => const SkeletonCard(height: 80),
                    )
                  : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('💬', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            _searching
                                ? 'Không tìm thấy kết quả'
                                : 'Chưa có cuộc trò chuyện nào',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      color: AppColors.teal,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                        ),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, idx) =>
                            const SizedBox(height: 10),
                        // CHH-02: Tap → push to chat with sessionId
                        itemBuilder: (ctx, i) {
                          final session = _filtered[i];
                          final sessionId = session['id'] as String;
                          return Dismissible(
                            key: ValueKey(sessionId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.lg,
                                ),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (_) async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) {
                                  bool isSubmitting = false;
                                  return StatefulBuilder(
                                    builder: (c, setDialogState) => AlertDialog(
                                      title: const Text('Xóa cuộc trò chuyện?'),
                                      content: const Text(
                                        'Tất cả tin nhắn sẽ bị xóa vĩnh viễn.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: isSubmitting
                                              ? null
                                              : () => Navigator.pop(c, false),
                                          child: const Text('Hủy'),
                                        ),
                                        TextButton(
                                          onPressed: isSubmitting
                                              ? null
                                              : () {
                                                  setDialogState(() {
                                                    isSubmitting = true;
                                                  });
                                                  Navigator.pop(c, true);
                                                },
                                          child: const Text(
                                            'Xóa',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                              return ok == true;
                            },
                            onDismissed: (_) async {
                              try {
                                await _api.deleteChatSession(sessionId);
                              } catch (_) {}
                              setState(() {
                                _sessions.removeWhere(
                                  (s) => s['id'] == sessionId,
                                );
                                _filtered.removeWhere(
                                  (s) => s['id'] == sessionId,
                                );
                              });
                            },
                            child: _SessionCard(
                              session: session,
                              timeStr: _formatTime(
                                session['created_at'] as String?,
                              ),
                              onTap: () {
                                context.pop();
                                context.push(
                                  AppRoutes.chat,
                                  extra: {
                                    'sessionId': sessionId,
                                    'walletId':
                                        session['wallet_id'] as String? ??
                                        session['walletId'] as String?,
                                  },
                                );
                              },
                              onDelete: () => _deleteSession(sessionId),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final dynamic session;
  final String timeStr;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SessionCard({
    required this.session,
    required this.timeStr,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = session['title'] as String? ?? 'Cuộc trò chuyện';
    final rawCount = session['message_count'];
    final msgCount = rawCount is int
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '') ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: context.palette.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Center(
                child: Text('💬', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      if (msgCount > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$msgCount tin nhắn',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.delete_outline,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
