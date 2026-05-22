import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/mimo_overlay.dart';

class CameraConfirmScreen extends StatefulWidget {
  /// Extracted expense data passed from CameraInputScreen via GoRouter extra.
  final Map<String, dynamic>? extractedData;

  const CameraConfirmScreen({super.key, this.extractedData});

  @override
  State<CameraConfirmScreen> createState() => _CameraConfirmScreenState();
}

class _CameraConfirmScreenState extends State<CameraConfirmScreen> {
  final _api = ApiClient();
  bool _saving = false;
  String? _saveError;

  // Editable fields
  late int _amount;
  late String _category;
  late String _note;
  late double _confidence;

  @override
  void initState() {
    super.initState();
    final extracted = widget.extractedData?['extracted'] as Map<String, dynamic>?;
    _amount = ((extracted?['amount'] ?? 0) is num) ? (extracted!['amount'] as num).toInt() : 0;
    _category = extracted?['category'] as String? ?? 'Others';
    _note = extracted?['note'] as String? ?? '';
    _confidence = ((extracted?['confidence'] ?? 0.0) is num) ? (extracted!['confidence'] as num).toDouble() : 0.0;
  }

  Future<void> _onConfirm() async {
    setState(() { _saving = true; _saveError = null; });
    try {
      final wallets = await _api.getWallets();
      if (wallets.isEmpty) throw Exception('Không có ví nào');
      await _api.createTransaction({
        'walletId': wallets[0]['id'],
        'amount': _amount,
        'type': 'expense',
        'categoryCode': _category,
        'note': _note,
        'source': 'text',
      });
      if (!mounted) return;
      setState(() => _saving = false);
      context.go(AppRoutes.home);

      // Show MiMo overlay using MiMoResponse
      final mimoMessages = [
        MiMoResponse(message: '✅ Đã lưu! Mimo ghi nhận rồi nhé 😊', status: 'Happy'),
        MiMoResponse(message: '💾 Giao dịch đã được lưu thành công!', status: 'Happy'),
        MiMoResponse(message: '🎉 Tốt lắm! Tiếp tục theo dõi chi tiêu nhé!', status: 'Happy'),
      ];
      Future.delayed(const Duration(milliseconds: 400), () {
        mimoController.show(mimoMessages[Random().nextInt(mimoMessages.length)]);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _saveError = e.localizedMessage; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _saveError = 'Không thể lưu giao dịch'; });
    }
  }

  void _showEditSheet() {
    final amountCtrl = TextEditingController(text: _amount.toString());
    final noteCtrl = TextEditingController(text: _note);
    String editCategory = _category;

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
              Text('Ghi chú', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(hintText: 'Ghi chú cho giao dịch'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _amount = int.tryParse(amountCtrl.text) ?? _amount;
                      _note = noteCtrl.text;
                      _category = editCategory;
                    });
                    ctx.pop();
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Lưu chỉnh sửa'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Color get _confidenceColor {
    if (_confidence >= 0.8) return AppColors.teal;
    if (_confidence >= 0.6) return const Color(0xFFF59E0B);
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final confidencePct = (_confidence * 100).toStringAsFixed(0);
    final isLowConfidence = _confidence < 0.6;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=1200&q=80',
              fit: BoxFit.cover,
              errorWidget: (ctx, url, e) => Container(color: Colors.black87),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xAA000000), Color(0xFF000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Text('AI xác nhận', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 40),
                    ],
                  ),
                  // Confidence badge
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _confidenceColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _confidenceColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_awesome, color: _confidenceColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'AI nhận dạng với độ chính xác $confidencePct%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _confidenceColor, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                  // Low confidence warning
                  if (isLowConfidence) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.warning_amber, color: AppColors.danger, size: 14),
                        const SizedBox(width: 6),
                        Text('Độ chính xác thấp — hãy kiểm tra lại', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
                      ]),
                    ),
                  ],
                  const Spacer(),
                  // Error banner
                  if (_saveError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Text(_saveError!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  // Transaction card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.md)),
                          child: const Icon(Icons.receipt_long, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Giao dịch mới', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(_note.isNotEmpty ? _note : _category,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                        Text(formatVnd(_amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),
                      _DetailRow(label: 'Danh mục', value: _category),
                      _DetailRow(label: 'Số tiền', value: formatVnd(_amount)),
                      if (_note.isNotEmpty) _DetailRow(label: 'Ghi chú', value: _note),
                      _DetailRow(label: 'Thời gian', value: _formatNow()),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // Buttons
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _showEditSheet,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        ),
                        child: const Text('Chỉnh sửa'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        ),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Xác nhận ✓', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNow() {
    final dt = DateTime.now();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70))),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
