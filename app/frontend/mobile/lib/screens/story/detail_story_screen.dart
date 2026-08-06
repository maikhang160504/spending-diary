import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_client.dart';
import '../../services/transaction_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/mimo_emotion.dart';
import '../../widgets/mimo_snackbar.dart';
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: PageView.builder(
            controller: _pageController,
            itemCount: _ids.length,
            itemBuilder: (ctx, i) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 0.0;
                  if (_pageController.position.haveDimensions) {
                    value =
                        (_pageController.page ??
                            _pageController.initialPage.toDouble()) -
                        i;
                  }
                  final double opacity = (1 - (value.abs() * 0.4)).clamp(
                    0.0,
                    1.0,
                  );
                  final double scale = (1 - (value.abs() * 0.08)).clamp(
                    0.85,
                    1.0,
                  );
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: _StoryPage(key: ValueKey(_ids[i]), storyId: _ids[i]),
              );
            },
          ),
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
      setState(() {
        _loading = false;
        _error = 'Không tìm thấy giao dịch';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
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
      final data = await _api.getTransaction(id);
      return data;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _buildStoryFromTx(Map<String, dynamic> tx) {
    return {
      'note': tx['note'],
      'title': tx['note'],
      'amount': tx['amount'],
      'imageUrl': tx['image_url'] ?? tx['imageUrl'],
      'categoryCode':
          tx['category_code'] ?? tx['categoryCode'] ?? tx['category_name'],
      'occurred_on':
          tx['occurred_at'] ??
          tx['occurredAt'] ??
          tx['created_at'] ??
          tx['createdAt'],
      'aiComment': tx['ai_message'] ?? tx['aiComment'],
      'mascotMood': tx['mascot_mood'] ?? tx['mascotMood'],
      'items': [
        {
          'transactions': [tx],
        },
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
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Sửa danh mục',
                style: Theme.of(
                  ctx,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
    try {
      await _api.updateTransaction(_primaryTxId!, {'categoryCode': picked});
      notifyTransactionChanged();
      await _loadStory();
      if (mounted) {
        MimoSnackBar.showSuccess(
          context,
          message:
              'Đã cập nhật giao dịch và ghi nhận góp ý! Mimo sẽ học thêm từ bạn 🙏',
          emotion: 'Love',
        );
      }
    } catch (_) {
      if (mounted) {
        MimoSnackBar.showError(
          context,
          message: 'Không thể gửi góp ý. Thử lại sau.',
          emotion: 'Sorry',
        );
      }
    }
    if (mounted) setState(() => _correcting = false);
  }

  // ── Xóa story (xóa toàn bộ transaction thuộc story) ──
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giao dịch này?'),
        content: const Text(
          'Giao dịch và ảnh hóa đơn sẽ bị xóa vĩnh viễn khỏi câu chuyện chi tiêu của bạn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final txIds = _allTxIds();
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
      if (mounted) {
        MimoSnackBar.showSuccess(
          context,
          message: 'Đã xóa giao dịch ✓',
          emotion: 'Success',
        );
      }
      navigator.pop();
    } catch (_) {
      if (mounted) {
        MimoSnackBar.showError(
          context,
          message: 'Không thể xóa giao dịch',
          emotion: 'Sad',
        );
      }
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
      MimoSnackBar.showInfo(
        context,
        message: 'Không tìm thấy giao dịch để sửa',
      );
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
            if ((tx['id'] as String?) == txId) {
              primaryTx = tx as Map<String, dynamic>;
              break;
            }
          }
        }
        if (primaryTx != null) break;
      }
    }

    final curAmount = parseToInt(
      primaryTx?['amount'] ?? _story?['amount'] ?? 0,
    );
    final curNote =
        (primaryTx?['note'] as String?) ?? (_story?['note'] as String?) ?? '';
    final curCat =
        (primaryTx?['category_code'] as String?) ??
        (primaryTx?['categoryCode'] as String?) ??
        (_story?['categoryCode'] as String?) ??
        'Other';

    final amountCtrl = TextEditingController(text: curAmount.toString());
    final noteCtrl = TextEditingController(text: curNote);
    String editCategory = CategoryTheme.canonicalCodeOf(
      CategoryTheme.styles.containsKey(curCat) ? curCat : 'Other',
    );
    if (!CategoryTheme.primaryCodes.contains(editCategory)) {
      editCategory = 'Other';
    }
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadii.xl),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chỉnh sửa giao dịch',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Số tiền',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Nhập số tiền',
                      suffixText: 'đ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Danh mục',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: editCategory,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    items: CategoryTheme.styles.entries
                        .where(
                          (e) => CategoryTheme.primaryCodes.contains(e.key),
                        )
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Row(
                              children: [
                                CategoryTheme.iconOf(e.key, size: 22),
                                const SizedBox(width: 8),
                                Text(e.value.label),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => editCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ghi chú',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ghi chú cho giao dịch',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              try {
                                final newAmt =
                                    int.tryParse(amountCtrl.text) ?? curAmount;
                                final newNote = noteCtrl.text;
                                await _api.updateTransaction(txId, {
                                  'amount': newAmt,
                                  'categoryCode': editCategory,
                                  'note': newNote,
                                });
                                if (mounted) {
                                  setState(() {
                                    if (primaryTx != null) {
                                      primaryTx['amount'] = newAmt;
                                      primaryTx['category_code'] = editCategory;
                                      primaryTx['categoryCode'] = editCategory;
                                      primaryTx['note'] = newNote;
                                    }
                                    if (_story != null) {
                                      _story!['amount'] = newAmt;
                                      _story!['categoryCode'] = editCategory;
                                      _story!['note'] = newNote;
                                      _story!['title'] = newNote;
                                    }
                                  });
                                }
                                notifyTransactionChanged();
                                if (ctx.mounted) ctx.pop();
                                if (mounted) {
                                  MimoSnackBar.showSuccess(
                                    context,
                                    message: 'Đã cập nhật giao dịch ✓',
                                    emotion: 'Celebrate',
                                  );
                                }
                                await _loadStory();
                              } catch (_) {
                                setSheetState(() => saving = false);
                                if (mounted) {
                                  MimoSnackBar.showError(
                                    context,
                                    message: 'Không thể cập nhật giao dịch',
                                    emotion: 'Sad',
                                  );
                                }
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: CategoryTheme.colorOf(editCategory),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Lưu chỉnh sửa'),
                    ),
                  ),
                ],
              ),
            ),
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

    String title =
        _story?['title'] as String? ?? _story?['note'] as String? ?? '';
    final isGeneric =
        title.isEmpty ||
        title.toLowerCase() == 'giao dịch' ||
        title.toLowerCase() == 'khoản chi' ||
        title.toLowerCase() == 'khoản thu' ||
        title.toLowerCase() == 'chi tiêu';
    if (isGeneric && items != null && items.isNotEmpty) {
      final firstItem = items.first;
      final rawText =
          firstItem['raw_text'] as String? ?? firstItem['rawText'] as String?;
      if (rawText != null && rawText.trim().isNotEmpty) {
        title = rawText.trim();
      }
    }
    if (title.isEmpty) {
      title = 'Giao dịch';
    }

    final aiMessage =
        _story?['aiMessage'] as String? ??
        _story?['ai_message'] as String? ??
        _story?['aiComment'] as String? ??
        _story?['ai_comment'] as String? ??
        _story?['story'] as String? ??
        'Mimo đã ghi nhận giao dịch này!';
    final occurredAt = _story != null ? resolveStoryDisplayIso(_story!) : null;
    final aiEmotionRaw =
        _story?['mascotMood'] as String? ??
        _story?['mascot_mood'] as String? ??
        _story?['aiEmotion'] as String? ??
        _story?['ai_emotion'] as String?;
    final mascotMood = normalizeMimoAssetName(
      aiEmotionRaw,
      fallback: 'Success',
    );

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

    String? imageUrl =
        _story?['imageUrl'] as String? ?? _story?['cover_image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      if (items != null) {
        for (final item in items) {
          final mUrl =
              item['media_url'] as String? ?? item['mediaUrl'] as String?;
          if (mUrl != null && mUrl.isNotEmpty) {
            imageUrl = mUrl;
            break;
          }
          final txs = item['transactions'] as List<dynamic>?;
          if (txs != null) {
            for (final tx in txs) {
              final tUrl =
                  tx['image_url'] as String? ?? tx['imageUrl'] as String?;
              if (tUrl != null && tUrl.isNotEmpty) {
                imageUrl = tUrl;
                break;
              }
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
              ? GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FullScreenImagePreview(imageUrl: imageUrl!),
                      ),
                    );
                  },
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 1080,
                    errorWidget: (ctx, url, err) =>
                        Container(color: const Color(0xFF0D1117)),
                  ),
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
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
                  : _buildContent(
                      title,
                      amount,
                      aiMessage,
                      occurredAt,
                      categoryCode,
                      mascotMood,
                      items,
                      imageUrl,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
        const Spacer(),
        const SkeletonLine(width: 200, height: 40),
        const SizedBox(height: 12),
        const SkeletonLine(width: 160, height: 20),
        const Spacer(),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(_error!, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _loadStory,
          child: const Text('Thử lại', style: TextStyle(color: AppColors.teal)),
        ),
        const Spacer(),
      ],
    );
  }

  String? _resolveStoryCategoryCode(List<dynamic>? items) {
    final fromStory =
        _story?['categoryCode'] as String? ??
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
          final raw =
              tx['category_code'] as String? ??
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

  Widget _buildContent(
    String title,
    int amount,
    String aiMessage,
    String? occurredAt,
    String? categoryCode,
    String mascotMood,
    List<dynamic>? items,
    String? imageUrl,
  ) {
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

    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final amountColor = hasImage
        ? (isExpense ? Colors.white : const Color(0xFF5EEAD4))
        : Colors.white;
    final catColor = CategoryTheme.colorOf(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              _glassActionButton(
                icon: Icons.close,
                tooltip: 'Đóng',
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              _glassActionButton(
                icon: Icons.delete_outline,
                tooltip: 'Xóa',
                onPressed: _confirmDelete,
              ),
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
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: hasImage
                        ? [
                            Color.lerp(
                              const Color(0xCC121218),
                              catColor,
                              0.14,
                            )!,
                            const Color(0xF0121218),
                          ]
                        : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                  ),
                  border: Border(
                    top: BorderSide(color: catColor.withValues(alpha: 0.35)),
                  ),
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
                  borderRadius: BorderRadius.circular(28),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CategoryChip(
                          category: category,
                          size: CategoryChipSize.regular,
                          onDark: true,
                        ),
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
                                          color: catColor.withValues(
                                            alpha: isExpense ? 0.35 : 0.5,
                                          ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: catColor.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: catColor.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDate(occurredAt),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (imageUrl != null && imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImagePreview(
                                    imageUrl: imageUrl,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 16,
                                    color: catColor,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Xem ảnh hóa đơn đính kèm',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    size: 12,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 3,
                                height: 52,
                                margin: const EdgeInsets.only(
                                  right: 12,
                                  top: 2,
                                ),
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
                                                color: AppColors.teal
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.asset(
                                              'assets/MiMo/emotions/$mascotMood.png',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Center(
                                                    child: Text(
                                                      '😎',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                      ),
                                                    ),
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
                                        color: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: _correcting
                                          ? null
                                          : _reportCorrection,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.md,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _correcting
                                                ? const SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : Icon(
                                                    Icons
                                                        .thumb_down_alt_outlined,
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                    size: 13,
                                                  ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'AI nhận nhầm?',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.75,
                                                ),
                                                fontSize: 11,
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
                        // Show transaction list only when there are multiple sub-transactions (bill with many items)
                        if (txList.length > 1) ...[
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 14,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: catColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              Text(
                                'DANH SÁCH CHI TIÊU',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...txList.map((tx) {
                            final txAmount = parseToInt(tx['amount']);
                            final txNote = tx['note'] as String? ?? '';
                            final txCat =
                                tx['category_name'] as String? ??
                                tx['category_code'] as String? ??
                                'Other';
                            final txTime =
                                txTimestampIso(
                                  Map<String, dynamic>.from(tx as Map),
                                ) ??
                                '';
                            final txImg =
                                tx['image_url'] as String? ??
                                tx['imageUrl'] as String?;
                            final txIsExpense =
                                (tx['type'] as String? ?? 'expense')
                                    .toLowerCase() ==
                                'expense';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Left: icon circle
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: CategoryTheme.colorOf(
                                            txCat,
                                          ).withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Center(
                                          child: CategoryTheme.iconOf(
                                            txCat,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Middle: note + time
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              txNote.isNotEmpty
                                                  ? txNote
                                                  : CategoryTheme.of(
                                                      txCat,
                                                    ).label,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (txTime.isNotEmpty)
                                              Text(
                                                _formatTxTime(txTime),
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.4),
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Right: amount
                                      Text(
                                        txIsExpense
                                            ? '-${formatVnd(txAmount)}'
                                            : '+${formatVnd(txAmount)}',
                                        style: TextStyle(
                                          color: txIsExpense
                                              ? const Color(0xFFFF9B9B)
                                              : const Color(0xFF5EEAD4),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (txImg != null &&
                                      txImg.isNotEmpty &&
                                      txImg != imageUrl) ...[
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
                                          errorWidget: (_, _, _) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 20),
                        // Edit button — color follows category
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _showEditSheet,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text(
                              'Chỉnh sửa giao dịch',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: catColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.lg,
                                ),
                              ),
                              elevation: 0,
                              shadowColor: catColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.paddingOf(context).bottom + 16,
                        ),
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

class FullScreenImagePreview extends StatefulWidget {
  final String imageUrl;

  const FullScreenImagePreview({super.key, required this.imageUrl});

  @override
  State<FullScreenImagePreview> createState() => _FullScreenImagePreviewState();
}

class _FullScreenImagePreviewState extends State<FullScreenImagePreview> {
  bool _isSharing = false;

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/mimo_shared_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await file.writeAsBytes(response.bodyBytes);
        // ignore: deprecated_member_use
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Mimo Finance - Giao dịch của tôi');
      } else {
        if (mounted) {
          MimoSnackBar.showInfo(
            context,
            message: 'Không thể tải ảnh, vui lòng thử lại sau!',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        MimoSnackBar.showInfo(
          context,
          message: 'Có lỗi xảy ra khi lưu/chia sẻ ảnh!',
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: AppColors.teal),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.error, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: _isSharing
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _shareImage,
                          tooltip: 'Lưu / Chia sẻ',
                        ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
