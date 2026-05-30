import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../services/transaction_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../data/mock_data.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
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

  static const _catColors = {
    'Food': Color(0xFFEC4899),
    'Shopping': Color(0xFF8B5CF6),
    'Transport': Color(0xFF3B82F6),
    'Entertainment': Color(0xFFF59E0B),
    'Housing': Color(0xFF10B981),
    'Health': Color(0xFFEF4444),
    'Education': Color(0xFF6366F1),
    'Travel': Color(0xFF14B8A6),
    'Income': Color(0xFF22C55E),
  };

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
    if (_story == null) return;
    setState(() => _correcting = true);
    try {
      await _api.aiCorrection({
        'storyId': widget.storyId,
        'reason': 'wrong_category',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cảm ơn! Mimo sẽ học thêm từ góp ý của bạn 🙏'), backgroundColor: AppColors.teal),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gửi góp ý. Thử lại sau.')),
        );
      }
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

    final curAmount = ((primaryTx?['amount'] ?? _story?['amount'] ?? 0) as num).toInt();
    final curNote = (primaryTx?['note'] as String?) ?? (_story?['note'] as String?) ?? '';
    final curCat = (primaryTx?['category_code'] as String?)
        ?? (primaryTx?['categoryCode'] as String?)
        ?? (_story?['categoryCode'] as String?)
        ?? 'Other';

    final amountCtrl = TextEditingController(text: curAmount.toString());
    final noteCtrl = TextEditingController(text: curNote);
    String editCategory = CategoryTheme.styles.containsKey(curCat) ? curCat : 'Other';
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

  Color _categoryColor(String? code) => _catColors[code ?? ''] ?? AppColors.teal;

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} • ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryCode = _story?['categoryCode'] as String? ?? _story?['category_code'] as String? ?? _story?['category'] as String?;
    final title = _story?['title'] as String? ?? _story?['note'] as String? ?? 'Giao dịch';
    final aiMessage = _story?['aiMessage'] as String? ?? _story?['ai_message'] as String? ?? _story?['aiComment'] as String? ?? _story?['ai_comment'] as String? ?? _story?['story'] as String? ?? 'Mimo đã ghi nhận giao dịch này!';
    final occurredAt = _story?['occurredAt'] as String? ?? _story?['occurred_on'] as String?;
    final aiEmotionRaw = _story?['mascotMood'] as String? ?? _story?['mascot_mood'] as String? ?? _story?['aiEmotion'] as String? ?? _story?['ai_emotion'] as String?;
    final mascotMood = mapApiStatusToAsset(aiEmotionRaw, fallback: 'Chill');
    final items = _story?['items'] as List<dynamic>?;

    int amount = 0;
    if (items != null) {
      for (final item in items) {
        final txs = item['transactions'] as List<dynamic>?;
        if (txs != null) {
          for (final tx in txs) {
            final amt = ((tx['amount'] ?? 0) is num) ? (tx['amount'] as num).toInt() : 0;
            amount += amt;
          }
        }
      }
    }
    if (amount == 0) {
      amount = ((_story?['amount'] ?? _story?['total_amount'] ?? 0) as num).toInt();
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

    final catColor = _categoryColor(categoryCode);

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
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0xCC000000)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _loading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _buildContent(catColor, title, amount, aiMessage, occurredAt, categoryCode, mascotMood, items),
          ),
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

  Widget _buildContent(Color catColor, String title, int amount, String aiMessage, String? occurredAt, String? categoryCode, String mascotMood, List<dynamic>? items) {
    final txList = <dynamic>[];
    if (items != null) {
      for (final item in items) {
        final txs = item['transactions'] as List<dynamic>?;
        if (txs != null) txList.addAll(txs);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(999)),
              child: Text(
                categoryCode ?? 'Khác',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            Row(children: [
              CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Xóa',
                  onPressed: _confirmDelete,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Text(
                        '-${formatVnd(amount)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 32,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      if (occurredAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(occurredAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // AI feedback + Correction button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/MiMo/emotions/$mascotMood.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('😎', style: TextStyle(fontSize: 18)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mimo AI',
                                  style: TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  aiMessage,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _correcting ? null : _reportCorrection,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _correcting
                                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.thumb_down_alt_outlined, color: Colors.white70, size: 13),
                              const SizedBox(width: 6),
                              const Text('AI nhận nhầm?', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (txList.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'DANH SÁCH CHI TIÊU',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  ...txList.map((tx) {
                    final txAmount = ((tx['amount'] ?? 0) is num) ? (tx['amount'] as num).toInt() : 0;
                    final txNote = tx['note'] as String? ?? '';
                    final txCat = tx['category_name'] as String? ?? tx['category_code'] as String? ?? 'Other';
                    final txTime = tx['occurred_at'] as String? ?? tx['occurredAt'] as String? ?? '';
                    final txImg = tx['image_url'] as String? ?? tx['imageUrl'] as String?;
                    final isExpense = (tx['type'] as String? ?? 'expense') == 'expense';
                    final catStyle = CategoryTheme.of(txCat);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: catStyle.color.withValues(alpha: 0.2), shape: BoxShape.circle),
                                child: Center(child: CategoryTheme.iconOf(txCat, size: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      txNote.isNotEmpty ? txNote : catStyle.label,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(catStyle.label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isExpense ? '-${formatVnd(txAmount)}' : '+${formatVnd(txAmount)}',
                                    style: TextStyle(
                                      color: isExpense ? AppColors.danger : AppColors.teal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (txTime.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(_formatTxTime(txTime), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          if (txImg != null && txImg.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: CachedNetworkImage(
                                  imageUrl: txImg,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 1080,
                                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Bottom buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                ),
                child: const Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTxTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
