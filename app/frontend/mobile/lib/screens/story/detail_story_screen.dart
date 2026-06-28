import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../services/transaction_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/mimo_emotion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/skeleton.dart';

/// Detail Story Screen — hỗ trợ lướt (swipe) qua nhiều story + chỉnh sửa/xóa.
class DetailStoryScreen extends StatefulWidget {
  /// storyId từ GoRouter path params
  final String storyId;

  /// Danh sách id để lướt qua (tùy chọn). Nếu null/empty → chỉ hiển thị [storyId].
  final List<String>? storyIds;

  /// Vị trí bắt đầu trong [storyIds].
  final int initialIndex;

  const DetailStoryScreen({
    super.key,
    required this.storyId,
    this.storyIds,
    this.initialIndex = 0,
  });

  @override
  State<DetailStoryScreen> createState() => _DetailStoryScreenState();
}

class _DetailStoryScreenState extends State<DetailStoryScreen> {
  late final List<String> _ids;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final passed = widget.storyIds?.where((e) => e.isNotEmpty).toList();
    _ids = (passed != null && passed.isNotEmpty) ? passed : [widget.storyId];
    final start = widget.initialIndex.clamp(0, _ids.length - 1);
    _pageController = PageController(initialPage: start);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _ids.length,
        itemBuilder: (ctx, i) => _StoryPage(
          key: ValueKey(_ids[i]),
          storyId: _ids[i],
        ),
      ),
    );
  }
}

/// Một trang story đơn lẻ trong PageView.
class _StoryPage extends StatefulWidget {
  final String storyId;
  const _StoryPage({super.key, required this.storyId});

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage> {
  final _api = ApiClient();
  bool _loading = true;
  Map<String, dynamic>? _story;
  String? _error;
  bool _correcting = false;
  String? _primaryTxId;

  @override
  void initState() {
    super.initState();
    _loadStory();
  }

  Future<void> _loadStory() async {
    if (widget.storyId.isEmpty) {
      setState(() { _loading = false; _error = 'Không tìm thấy giao dịch'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getStory(widget.storyId);
      if (!mounted) return;
      setState(() {
        _story = data;
        _primaryTxId = _firstTxId(data);
      });
    } catch (_) {
      // Fallback: story tạo từ bill → id có thể là transactionId, thử load transaction.
      final tx = await _findTransaction(widget.storyId);
      if (!mounted) return;
      if (tx != null) {
        setState(() {
          _story = _buildStoryFromTx(tx);
          _primaryTxId = tx['id'] as String? ?? widget.storyId;
        });
      } else {
        setState(() => _error = 'Không thể tải dữ liệu');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Lấy transaction theo id (dùng cho fallback bill-detail).
  Future<Map<String, dynamic>?> _findTransaction(String id) async {
    try {
      final res = await _api.getTransactions(pageSize: 100);
      final data = res['data'];
      List<dynamic> items;
      if (data is Map<String, dynamic>) {
        items = (data['items'] as List<dynamic>?) ?? [];
      } else if (data is List<dynamic>) {
        items = data;
      } else {
        items = [];
      }
      for (final t in items) {
        if ((t['id'] as String?) == id) return t as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _buildStoryFromTx(Map<String, dynamic> tx) {
    return {
      'note': tx['note'],
      'title': tx['note'],
      'amount': tx['amount'],
      'imageUrl': tx['image_url'] ?? tx['imageUrl'],
      'categoryCode': tx['category_code'] ?? tx['categoryCode'] ?? tx['category_name'],
      'occurred_on': tx['occurred_at'] ?? tx['occurredAt'] ?? tx['created_at'] ?? tx['createdAt'],
      'aiComment': tx['ai_message'] ?? tx['aiComment'],
      'mascotMood': tx['mascot_mood'] ?? tx['mascotMood'],
      'items': [
        {'transactions': [tx]}
      ],
    };
  }

  String? _firstTxId(Map<String, dynamic> story) {
    final items = story['items'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        final txs = item['transactions'] as List<dynamic>?;
        if (txs != null && txs.isNotEmpty) {
          return txs[0]['id'] as String?;
        }
      }
    }
    return story['id'] as String? ?? widget.storyId;
  }

  Future<void> _reportCorrection() async {
    if (_story == null || _primaryTxId == null) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Sửa danh mục',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: CategoryTheme.primaryCodes.map((code) {
                  final style = CategoryTheme.of(code);
                  return ListTile(
                    leading: CategoryTheme.iconOf(code, size: 22),
                    title: Text(style.label),
                    onTap: () => Navigator.pop(ctx, code),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;

    setState(() => _correcting = true);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.updateTransaction(_primaryTxId!, {
        'categoryCode': picked,
      });
      notifyTransactionChanged();
      await _loadStory();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật giao dịch và ghi nhận góp ý! Mimo sẽ học thêm từ bạn 🙏'),
          backgroundColor: AppColors.teal,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không thể gửi góp ý. Thử lại sau.')),
      );
    }
    if (mounted) setState(() => _correcting = false);
  }

  // ── Xóa story (xóa toàn bộ transaction thuộc story) ──
  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: const Text('Bạn có chắc muốn xóa? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => ctx.pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final txIds = _allTxIds();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (txIds.isEmpty && _primaryTxId != null) {
        await _api.deleteTransaction(_primaryTxId!);
      } else {
        for (final id in txIds) {
          await _api.deleteTransaction(id);
        }
      }
      notifyTransactionChanged();
      messenger.showSnackBar(const SnackBar(content: Text('Đã xóa giao dịch ✓'), backgroundColor: AppColors.teal));
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Không thể xóa giao dịch')));
    }
  }

  List<String> _allTxIds() {
    final ids = <String>[];
    final items = _story?['items'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        final txs = item['transactions'] as List<dynamic>?;
        if (txs != null) {
          for (final tx in txs) {
            final id = tx['id'] as String?;
            if (id != null && id.isNotEmpty) ids.add(id);
          }
        }
      }
    }
    return ids;
  }

  // ── Chỉnh sửa transaction chính ──
  void _showEditSheet() {
    if (_story == null) return;
    final txId = _primaryTxId;
    if (txId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy giao dịch để sửa')));
      return;
    }

    // Lấy dữ liệu hiện tại từ transaction chính.
    Map<String, dynamic>? primaryTx;
    final items = _story?['items'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        final txs = item['transactions'] as List<dynamic>?;
        if (txs != null) {
          for (final tx in txs) {
            if ((tx['id'] as String?) == txId) { primaryTx = tx as Map<String, dynamic>; break; }
          }
        }
        if (primaryTx != null) break;
      }
    }

    final curAmount = parseToInt(primaryTx?['amount'] ?? _story?['amount'] ?? 0);
    final curNote = (primaryTx?['note'] as String?) ?? (_story?['note'] as String?) ?? '';
    final curCat = (primaryTx?['category_code'] as String?)
        ?? (primaryTx?['categoryCode'] as String?)
        ?? (_story?['categoryCode'] as String?)
        ?? 'Other';

    final amountCtrl = TextEditingController(text: curAmount.toString());
    final noteCtrl = TextEditingController(text: curNote);
    String editCategory = CategoryTheme.canonicalCodeOf(
        CategoryTheme.styles.containsKey(curCat) ? curCat : 'Other');
    if (!CategoryTheme.primaryCodes.contains(editCategory)) {
      editCategory = 'Other';
    }
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Chỉnh sửa giao dịch', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text('Số tiền', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Nhập số tiền', suffixText: 'đ'),
              ),
              const SizedBox(height: 12),
              Text('Danh mục', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: editCategory,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                items: CategoryTheme.styles.entries
                    .where((e) => CategoryTheme.primaryCodes.contains(e.key))
                    .map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Row(children: [
                            CategoryTheme.iconOf(e.key, size: 22),
                            const SizedBox(width: 8),
                            Text(e.value.label),
                          ]),
                        ))
                    .toList(),
                onChanged: (val) { if (val != null) setSheetState(() => editCategory = val); },
              ),
              const SizedBox(height: 12),
              Text('Ghi chú', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: noteCtrl, decoration: const InputDecoration(hintText: 'Ghi chú cho giao dịch')),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setSheetState(() => saving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _api.updateTransaction(txId, {
                              'amount': int.tryParse(amountCtrl.text) ?? curAmount,
                              'categoryCode': editCategory,
                              'note': noteCtrl.text,
                            });
                            notifyTransactionChanged();
                            if (ctx.mounted) ctx.pop();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Đã cập nhật giao dịch ✓'), backgroundColor: AppColors.teal));
                            await _loadStory();
                          } catch (_) {
                            setSheetState(() => saving = false);
                            messenger.showSnackBar(const SnackBar(content: Text('Không thể cập nhật giao dịch')));
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Lưu chỉnh sửa'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    final dt = parseToLocalDateTime(iso);
    if (dt == null) return '';
    return formatDateTimeFull(dt);
  }

  Widget _glassActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 20),
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _story?['items'] as List<dynamic>?;
    final categoryCode = _resolveStoryCategoryCode(items);
    
    String title = _story?['title'] as String? ?? _story?['note'] as String? ?? '';
    final isGeneric = title.isEmpty || 
        title.toLowerCase() == 'giao dịch' || 
        title.toLowerCase() == 'khoản chi' || 
        title.toLowerCase() == 'khoản thu' ||
        title.toLowerCase() == 'chi tiêu';
    if (isGeneric && items != null && items.isNotEmpty) {
      final firstItem = items.first;
      final rawText = firstItem['raw_text'] as String? ?? firstItem['rawText'] as String?;
      if (rawText != null && rawText.trim().isNotEmpty) {
        title = rawText.trim();
      }
    }
    if (title.isEmpty) {
      title = 'Giao dịch';
    }

    final aiMessage = _story?['aiMessage'] as String? ?? _story?['ai_message'] as String? ?? _story?['aiComment'] as String? ?? _story?['ai_comment'] as String? ?? _story?['story'] as String? ?? 'Mimo đã ghi nhận giao dịch này!';
    final occurredAt = _story != null ? resolveStoryDisplayIso(_story!) : null;
    final aiEmotionRaw = _story?['mascotMood'] as String? ?? _story?['mascot_mood'] as String? ?? _story?['aiEmotion'] as String? ?? _story?['ai_emotion'] as String?;
    final mascotMood = normalizeMimoAssetName(aiEmotionRaw, fallback: 'Success');

    int amount = 0;
    if (items != null) {
      for (final item in items) {
        final txs = item['transactions'] as List<dynamic>?;
        if (txs != null) {
          for (final tx in txs) {
            final amt = parseToInt(tx['amount']);
            amount += amt;
          }
        }
      }
    }
    if (amount == 0) {
      amount = parseToInt(_story?['amount'] ?? _story?['total_amount'] ?? 0);
    }

    String? imageUrl = _story?['imageUrl'] as String? ?? _story?['cover_image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      if (items != null) {
        for (final item in items) {
          final mUrl = item['media_url'] as String? ?? item['mediaUrl'] as String?;
          if (mUrl != null && mUrl.isNotEmpty) { imageUrl = mUrl; break; }
          final txs = item['transactions'] as List<dynamic>?;
          if (txs != null) {
            for (final tx in txs) {
              final tUrl = tx['image_url'] as String? ?? tx['imageUrl'] as String?;
              if (tUrl != null && tUrl.isNotEmpty) { imageUrl = tUrl; break; }
            }
          }
          if (imageUrl != null && imageUrl.isNotEmpty) break;
        }
      }
    }

    return Stack(
      children: [
        Positioned.fill(
          child: (imageUrl != null && imageUrl.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 1080,
                  errorWidget: (ctx, url, err) => Container(color: const Color(0xFF0D1117)),
                )
              : Container(color: const Color(0xFF0D1117)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.7, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.28),
                  Colors.black.withValues(alpha: 0.55),
                  const Color(0xE6121218),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: _loading
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _buildLoading(),
                )
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: _buildError(),
                    )
                  : _buildContent(title, amount, aiMessage, occurredAt, categoryCode, mascotMood, items),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        CircleAvatar(backgroundColor: Colors.black54,
          child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop())),
      ]),
      const Spacer(),
      const SkeletonLine(width: 200, height: 40),
      const SizedBox(height: 12),
      const SkeletonLine(width: 160, height: 20),
      const Spacer(),
    ]);
  }

  Widget _buildError() {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        CircleAvatar(backgroundColor: Colors.black54,
          child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop())),
      ]),
      const Spacer(),
      Text(_error!, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 12),
      TextButton(onPressed: _loadStory, child: const Text('Thử lại', style: TextStyle(color: AppColors.teal))),
      const Spacer(),
    ]);
  }

  String? _resolveStoryCategoryCode(List<dynamic>? items) {
    final fromStory = _story?['categoryCode'] as String? ??
        _story?['category_code'] as String? ??
        _story?['category'] as String?;
    if (fromStory != null && fromStory.isNotEmpty) {
      final canonical = CategoryTheme.canonicalCodeOf(fromStory);
      if (canonical != 'Other' || fromStory.toLowerCase() == 'other') {
        return canonical;
      }
    }
    if (items != null) {
      for (final item in items) {
        final txs = item['transactions'] as List<dynamic>?;
        if (txs == null) continue;
        for (final tx in txs) {
          final raw = tx['category_code'] as String? ??
              tx['categoryCode'] as String? ??
              tx['category_name'] as String? ??
              tx['category'] as String?;
          if (raw != null && raw.isNotEmpty) {
            return CategoryTheme.canonicalCodeOf(raw);
          }
        }
      }
    }
    return fromStory != null && fromStory.isNotEmpty
        ? CategoryTheme.canonicalCodeOf(fromStory)
        : 'Other';
  }

  Widget _buildContent(String title, int amount, String aiMessage, String? occurredAt, String? categoryCode, String mascotMood, List<dynamic>? items) {
    final category = CategoryTheme.canonicalCodeOf(categoryCode ?? 'Other');
    final txList = <dynamic>[];
    if (items != null) {
      for (final item in items) {
        final txs = item['transactions'] as List<dynamic>?;
        if (txs != null) txList.addAll(txs);
      }
    }

    bool isExpense = true;
    final storyType = (_story?['type'] as String? ?? '').toLowerCase();
    if (storyType == 'income') {
      isExpense = false;
    } else {
      for (final tx in txList) {
        final txType = (tx['type'] as String? ?? '').toLowerCase();
        if (txType == 'income') {
          isExpense = false;
          break;
        }
      }
    }

    final amountColor = isExpense ? Colors.white : const Color(0xFF5EEAD4);
    final catColor = CategoryTheme.colorOf(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _glassActionButton(icon: Icons.delete_outline, tooltip: 'Xóa', onPressed: _confirmDelete),
              const SizedBox(width: 8),
              _glassActionButton(icon: Icons.close, tooltip: 'Đóng', onPressed: () => context.pop()),
            ],
          ),
        ),
        const Spacer(flex: 1),
        Flexible(
          flex: 3,
          child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -48,
              left: 24,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      catColor.withValues(alpha: 0.28),
                      catColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(const Color(0xCC121218), catColor, 0.14)!,
                    const Color(0xF0121218),
                  ],
                ),
                border: Border(top: BorderSide(color: catColor.withValues(alpha: 0.35))),
                boxShadow: [
                  BoxShadow(
                    color: catColor.withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, -12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                catColor.withValues(alpha: 0.35),
                                catColor,
                                catColor.withValues(alpha: 0.35),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      CategoryChip(category: category, size: CategoryChipSize.regular, onDark: true),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 56,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  catColor,
                                  catColor.withValues(alpha: 0.35),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${isExpense ? '-' : '+'}${formatVnd(amount)}',
                                  style: TextStyle(
                                    color: amountColor,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                    height: 1.05,
                                    shadows: [
                                      Shadow(
                                        color: catColor.withValues(alpha: isExpense ? 0.35 : 0.5),
                                        blurRadius: 18,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (occurredAt != null && occurredAt.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: catColor.withValues(alpha: 0.28)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded, size: 14, color: catColor.withValues(alpha: 0.85)),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(occurredAt),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 3,
                          height: 52,
                          margin: const EdgeInsets.only(right: 12, top: 2),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.teal,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.teal.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
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
                                  const Text(
                                    'Mimo AI',
                                    style: TextStyle(
                                      color: AppColors.teal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                aiMessage,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _correcting ? null : _reportCorrection,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadii.md),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _correcting
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            )
                                          : Icon(Icons.thumb_down_alt_outlined, color: Colors.white.withValues(alpha: 0.75), size: 13),
                                      const SizedBox(width: 6),
                                      Text('AI nhận nhầm?', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
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
                  if (txList.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'DANH SÁCH CHI TIÊU',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...txList.map((tx) {
                      final txAmount = parseToInt(tx['amount']);
                      final txNote = tx['note'] as String? ?? '';
                      final txCat = tx['category_name'] as String? ?? tx['category_code'] as String? ?? 'Other';
                      final txTime = txTimestampIso(Map<String, dynamic>.from(tx as Map)) ?? '';
                      final txImg = tx['image_url'] as String? ?? tx['imageUrl'] as String?;
                      final txIsExpense = (tx['type'] as String? ?? 'expense').toLowerCase() == 'expense';
                      final catStyle = CategoryTheme.of(txCat);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        txNote.isNotEmpty ? txNote : catStyle.label,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      const SizedBox(height: 8),
                                      CategoryChip(category: txCat, size: CategoryChipSize.compact, onDark: true),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      txIsExpense ? '-${formatVnd(txAmount)}' : '+${formatVnd(txAmount)}',
                                      style: TextStyle(
                                        color: txIsExpense ? const Color(0xFFFF9B9B) : const Color(0xFF5EEAD4),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (txTime.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(_formatTxTime(txTime), style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 10)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            if (txImg != null && txImg.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: CachedNetworkImage(
                                    imageUrl: txImg,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 1080,
                                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                          ),
                          onPressed: () => context.pop(),
                          child: const Text('Đóng'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _showEditSheet,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                            elevation: 0,
                          ),
                          child: const Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                ],
              ),
            ),
          ),
        ),
          ],
        ),
      ),
      ],
    );
  }

  String _formatTxTime(String iso) {
    final dt = parseToLocalDateTime(iso);
    if (dt == null) return '';
    return formatTimeOnly(dt);
  }
}
