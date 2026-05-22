import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/skeleton.dart';

/// Detail Story Screen — DS-01..DS-04
class DetailStoryScreen extends StatefulWidget {
  /// DS-01: storyId from GoRouter path params
  final String storyId;

  const DetailStoryScreen({super.key, required this.storyId});

  @override
  State<DetailStoryScreen> createState() => _DetailStoryScreenState();
}

class _DetailStoryScreenState extends State<DetailStoryScreen> {
  final _api = ApiClient();
  bool _loading = true;
  Map<String, dynamic>? _story;
  List<dynamic> _transactions = [];
  String? _error;
  bool _correcting = false;

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

  // DS-02: Load GET /stories/:id
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
        _transactions = (data['transactions'] as List<dynamic>?) ?? [];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.localizedMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải dữ liệu');
    }
    if (mounted) setState(() => _loading = false);
  }

  // DS-04: "AI nhận nhầm" → POST /ai/corrections
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

  // DS-03: "Chỉnh sửa" → push AddTransactionScreen with prefilled data
  void _onEdit() {
    if (_story == null) return;
    final tx = _transactions.isNotEmpty ? _transactions.first : null;
    context.push(AppRoutes.addTransaction, extra: tx);
  }

  Color _categoryColor(String? code) =>
      _catColors[code ?? ''] ?? AppColors.teal;

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
    final categoryCode = _story?['categoryCode'] as String? ?? _story?['category'] as String?;
    final catColor = _categoryColor(categoryCode);
    final title = _story?['title'] as String? ?? _story?['note'] as String? ?? 'Giao dịch';
    final amount = ((_story?['amount'] ?? 0) as num).toInt();
    final imageUrl = _story?['imageUrl'] as String?;
    final aiMessage = _story?['aiMessage'] as String? ?? 'Mimo đã ghi nhận giao dịch này!';
    final occurredAt = _story?['occurredAt'] as String?;

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (ctx, url, err) => Container(color: const Color(0xFF0D1117)),
                  )
                : Container(color: const Color(0xFF0D1117)),
          ),
          // Gradient overlay
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
                      : _buildContent(catColor, title, amount, aiMessage, occurredAt, categoryCode),
            ),
          ),
        ],
      ),
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

  Widget _buildContent(Color catColor, String title, int amount, String aiMessage, String? occurredAt, String? categoryCode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar: category badge + close
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

        // Transaction info
        Center(
          child: Column(children: [
            Text(
              '-${formatVnd(amount)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white),
                textAlign: TextAlign.center),
            if (occurredAt != null) ...[
              const SizedBox(height: 4),
              Text(_formatDate(occurredAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ],
          ]),
        ),

        // AI feedback + DS-04 correction button
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                child: const Center(child: Text('😎', style: TextStyle(fontSize: 14))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(aiMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
              ),
            ]),
            const SizedBox(height: 10),
            // DS-04: AI nhận nhầm correction
            GestureDetector(
              onTap: _correcting ? null : _reportCorrection,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _correcting
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.thumb_down_alt_outlined, color: Colors.white70, size: 13),
                  const SizedBox(width: 6),
                  const Text('AI nhận nhầm?', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),
        // Bottom buttons: Đóng + DS-03 Chỉnh sửa
        Row(children: [
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
              onPressed: _onEdit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
              ),
              child: const Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}