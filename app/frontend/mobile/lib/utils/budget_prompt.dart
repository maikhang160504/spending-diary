import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/categories.dart';
import '../utils/formatters.dart';
import '../widgets/mimo_snackbar.dart';

/// Kiểm tra xem danh mục chi tiêu có hạn mức chưa.
/// Nếu chưa, hiển thị modal AI gợi ý hạn mức thông minh và cho phép tạo ngay.
Future<void> checkCategoryLimitAndSuggest(
  BuildContext context,
  String categoryCode, {
  String? walletId,
}) async {
  final lower = categoryCode.toLowerCase();
  if (lower == 'salary' ||
      lower == 'bonus' ||
      lower == 'business' ||
      lower == 'other' ||
      lower == 'others') {
    return;
  }

  try {
    final api = ApiClient();
    final budgets = await api.getBudgets();

    final canonicalTarget = CategoryTheme.canonicalCodeOf(categoryCode);
    final hasLimit = budgets.any((b) {
      final rawCat =
          b['categoryCode'] as String? ?? b['category_code'] as String? ?? '';
      return CategoryTheme.canonicalCodeOf(rawCat) == canonicalTarget;
    });

    if (!hasLimit && context.mounted) {
      await showDialog(
        context: context,
        useRootNavigator: true,
        builder: (ctx) =>
            _SmartLimitDialog(categoryCode: categoryCode, walletId: walletId),
      );
    }
  } catch (_) {
    // Thất bại âm thầm
  }
}

class _SmartLimitDialog extends StatefulWidget {
  final String categoryCode;
  final String? walletId;
  const _SmartLimitDialog({required this.categoryCode, this.walletId});

  @override
  State<_SmartLimitDialog> createState() => _SmartLimitDialogState();
}

class _SmartLimitDialogState extends State<_SmartLimitDialog> {
  final _api = ApiClient();
  final _ctrl = TextEditingController(text: '2000000');
  final _customCtrl = TextEditingController();
  int _selectedAmount = 1000000;
  bool _submitting = false;
  bool _showCustomInput = false;

  // Gợi ý động từ peer group — mặc định fallback cứng
  List<int> _suggestions = [1000000, 2000000, 5000000];
  int? _peerAvgAmount; // Trung vị chi tiêu của nhóm đồng trang
  bool _loadingSuggestions = true;

  static const List<int> _fallbackSuggestions = [1000000, 2000000, 5000000];

  @override
  void initState() {
    super.initState();
    _loadPeerSuggestions();
  }

  /// Tải chi tiêu trung vị của nhóm đồng trang (peer group) cho danh mục này.
  /// Từ đó tạo 3 mức gợi ý: ×0.6 (tiết kiệm), ×1.0 (chuẩn nhóm), ×1.5 (thoải mái).
  Future<void> _loadPeerSuggestions() async {
    try {
      final peerData = await _api.getPeerCompare();
      final categories = peerData['data'] as List<dynamic>? ?? [];

      // Tìm mục tương ứng danh mục hiện tại
      final canonical = widget.categoryCode.toLowerCase();
      final match = categories.firstWhere((c) {
        final code = (c['categoryCode'] as String? ?? '').toLowerCase();
        return code == canonical;
      }, orElse: () => null);

      final peerAvg = match != null
          ? (match['avgAmount'] as num?)?.toInt() ?? 0
          : 0;

      if (peerAvg > 50000) {
        // Làm tròn đến 50.000đ cho đẹp
        int round(int v) =>
            ((v / 50000).round() * 50000).clamp(50000, 99999999).toInt();
        final suggestions = [
          round((peerAvg * 0.8).round()), // Tiết kiệm hơn nhóm
          round(peerAvg), // Chuẩn nhóm
          round((peerAvg * 1.2).round()), // Thoải mái hơn nhóm
        ];
        if (mounted) {
          setState(() {
            _peerAvgAmount = peerAvg;
            _suggestions = suggestions;
            _selectedAmount = suggestions[1]; // Mặc định chọn mức chuẩn nhóm
            _loadingSuggestions = false;
          });
        }
      } else {
        // Không đủ dữ liệu peer → dùng fallback cứng
        if (mounted) {
          setState(() {
            _suggestions = _fallbackSuggestions;
            _selectedAmount = _fallbackSuggestions[0];
            _loadingSuggestions = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = _fallbackSuggestions;
          _selectedAmount = _fallbackSuggestions[0];
          _loadingSuggestions = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveQuickLimit() async {
    // Nếu đang nhập tùy chỉnh, đọc giá trị từ _customCtrl
    if (_showCustomInput) {
      final parsed = int.tryParse(
        _customCtrl.text.replaceAll(RegExp(r'[^\d]'), ''),
      );
      if (parsed == null || parsed <= 0) return;
      _selectedAmount = parsed;
    }

    setState(() => _submitting = true);
    try {
      String? targetWalletId = widget.walletId;
      if (targetWalletId == null || targetWalletId.isEmpty) {
        final wallets = await _api.getWallets();
        if (wallets.isNotEmpty) {
          targetWalletId = wallets[0]['id'] as String?;
        }
      }
      if (targetWalletId != null && targetWalletId.isNotEmpty) {
        await _api.createBudget({
          'walletId': targetWalletId,
          'categoryCode': widget.categoryCode,
          'amountLimit': _selectedAmount,
          'period': 'month',
          'startDate': DateTime.now().toIso8601String().split('T')[0],
        });
      }
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        MimoSnackBar.showSuccess(
          context,
          message: '🎉 Đã thiết lập hạn mức ${formatVnd(_selectedAmount)}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = CategoryTheme.of(widget.categoryCode);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CategoryTheme.iconOf(widget.categoryCode, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Gợi ý Hạn mức',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        style.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Mô tả + context peer
            Text(
              _peerAvgAmount != null
                  ? 'Gợi ý dựa trên chi tiêu trung bình của nhóm người dùng tương tự (${formatVnd(_peerAvgAmount!)}/tháng):'
                  : 'Danh mục này chưa được đặt hạn mức. Hãy chọn nhanh hạn mức gợi ý dưới đây để kiểm soát chi tiêu tốt hơn:',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Chip gợi ý
            _loadingSuggestions
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_suggestions.length, (i) {
                      final amt = _suggestions[i];
                      final selected =
                          !_showCustomInput && _selectedAmount == amt;
                      // Nhãn mô tả tầng khi có dữ liệu peer
                      final tierLabels = _peerAvgAmount != null
                          ? ['Tiết kiệm', 'Chuẩn nhóm', 'Thoải mái']
                          : <String>['', '', ''];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChoiceChip(
                            label: Text(
                              formatVnd(amt),
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: selected,
                            selectedColor: AppColors.teal,
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _selectedAmount = amt;
                                  _showCustomInput = false;
                                  _ctrl.text = amt.toString();
                                });
                              }
                            },
                          ),
                          if (tierLabels[i].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                tierLabels[i],
                                style: TextStyle(
                                  fontSize: 9,
                                  color: selected
                                      ? AppColors.teal
                                      : AppColors.textPrimary.withValues(
                                          alpha: 0.45,
                                        ),
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
            // Ô nhập tùy chỉnh (hiện ra khi bấm Tùy chỉnh)
            if (_showCustomInput) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _customCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nhập số tiền hạn mức',
                  hintText: 'Ví dụ: 3000000',
                  suffixText: 'đ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.teal),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.teal, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                // Nút Tùy chỉnh: toggle ô nhập inline
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showCustomInput = !_showCustomInput;
                      if (_showCustomInput) {
                        _customCtrl.text = '';
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color: _showCustomInput
                          ? AppColors.teal
                          : Colors.grey.shade400,
                    ),
                  ),
                  child: Text(
                    _showCustomInput ? 'Gợi ý' : 'Tùy chỉnh',
                    style: TextStyle(
                      color: _showCustomInput ? AppColors.teal : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _saveQuickLimit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _showCustomInput
                                ? '✨ Lưu hạn mức'
                                : '✨ Lưu nhanh ${formatVnd(_selectedAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
