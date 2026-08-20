import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      if (parsed == null || parsed <= 0) {
        MimoSnackBar.showWarning(
          context,
          message: 'Vui lòng nhập số tiền hạn mức lớn hơn 0.',
        );
        return;
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Category Icon + Title + Close Button
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: style.color.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: CategoryTheme.iconOf(widget.categoryCode, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 12, color: AppColors.teal),
                            const SizedBox(width: 4),
                            Text(
                              'AI Gợi ý Hạn mức',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.teal,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        style.label,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Peer Context Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.teal.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.teal.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insights_rounded, size: 18, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _peerAvgAmount != null
                          ? 'Nhóm tương tự chi trung bình ${formatVnd(_peerAvgAmount!)}/tháng'
                          : 'Thiết lập hạn mức giúp bạn kiểm soát chi tiêu tốt hơn',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3 Tier Suggestion Cards (Side by Side in 1 Row)
            if (_loadingSuggestions)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.teal),
                ),
              )
            else if (!_showCustomInput)
              Row(
                children: List.generate(_suggestions.length, (i) {
                  final amt = _suggestions[i];
                  final isSelected = _selectedAmount == amt;
                  final tierLabels = _peerAvgAmount != null
                      ? ['Tiết kiệm', 'Chuẩn nhóm ⭐', 'Thoải mái']
                      : ['Mức thấp', 'Đề xuất ⭐', 'Mức cao'];

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : 4,
                        right: i == _suggestions.length - 1 ? 0 : 4,
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAmount = amt;
                            _ctrl.text = amt.toString();
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppGradients.teal : null,
                            color: isSelected
                                ? null
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : AppColors.surface),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.teal
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : AppColors.border),
                              width: isSelected ? 2 : 1.2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.teal.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tierLabels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : (isDark ? Colors.white60 : AppColors.muted),
                                ),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formatVnd(amt),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white : AppColors.textPrimary),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

            // Custom Input View
            if (_showCustomInput)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tùy chỉnh hạn mức tháng',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        MoneyTextInputFormatter(),
                      ],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: 3,000,000',
                        suffixText: 'đ',
                        suffixStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.teal, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 22),

            // Action Buttons
            Row(
              children: [
                // Custom Toggle Button
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showCustomInput = !_showCustomInput;
                      if (_showCustomInput) {
                        final digits = _selectedAmount.toString();
                        final formatter = MoneyTextInputFormatter();
                        final formatted = formatter.formatEditUpdate(
                          TextEditingValue.empty,
                          TextEditingValue(text: digits),
                        );
                        _customCtrl.text = formatted.text;
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(
                      color: _showCustomInput
                          ? AppColors.teal
                          : (isDark ? Colors.white24 : AppColors.border),
                      width: 1.5,
                    ),
                    backgroundColor: _showCustomInput
                        ? AppColors.teal.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                  child: Text(
                    _showCustomInput ? 'Gợi ý' : 'Tùy chỉnh',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _showCustomInput
                          ? AppColors.teal
                          : (isDark ? Colors.white70 : AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Save / Apply Button
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _saveQuickLimit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      shadowColor: AppColors.teal.withValues(alpha: 0.4),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '✨ Thiết lập hạn mức',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
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
