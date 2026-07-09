import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/categories.dart';
import '../routes/app_routes.dart';
import '../utils/formatters.dart';

/// Kiểm tra xem danh mục chi tiêu có hạn mức chưa.
/// Nếu chưa, hiển thị modal AI gợi ý hạn mức thông minh và cho phép tạo ngay.
Future<void> checkCategoryLimitAndSuggest(BuildContext context, String categoryCode) async {
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
      final rawCat = b['categoryCode'] as String? ?? b['category_code'] as String? ?? '';
      return CategoryTheme.canonicalCodeOf(rawCat) == canonicalTarget;
    });

    if (!hasLimit && context.mounted) {
      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => _SmartLimitDialog(categoryCode: categoryCode),
      );
    }
  } catch (_) {
    // Thất bại âm thầm
  }
}

class _SmartLimitDialog extends StatefulWidget {
  final String categoryCode;
  const _SmartLimitDialog({required this.categoryCode});

  @override
  State<_SmartLimitDialog> createState() => _SmartLimitDialogState();
}

class _SmartLimitDialogState extends State<_SmartLimitDialog> {
  final _api = ApiClient();
  final _ctrl = TextEditingController(text: '2000000');
  int _selectedAmount = 2000000;
  bool _submitting = false;

  final List<int> _suggestions = [1000000, 2000000, 5000000];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _saveQuickLimit() async {
    setState(() => _submitting = true);
    try {
      final wallets = await _api.getWallets();
      if (wallets.isNotEmpty) {
        await _api.createBudget({
          'walletId': wallets[0]['id'],
          'categoryCode': widget.categoryCode,
          'amountLimit': _selectedAmount,
          'period': 'month',
          'startDate': DateTime.now().toIso8601String().split('T')[0],
        });
      }
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Đã thiết lập hạn mức ${formatVnd(_selectedAmount)} cho danh mục!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.teal,
          ),
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
            Text(
              'Danh mục này chưa được đặt hạn mức. Hãy chọn nhanh hạn mức gợi ý dưới đây để kiểm soát chi tiêu tốt hơn:',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((amt) {
                final selected = _selectedAmount == amt;
                return ChoiceChip(
                  label: Text(
                    formatVnd(amt),
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppColors.teal,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedAmount = amt;
                        _ctrl.text = amt.toString();
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      context.push('${AppRoutes.limits}?categoryCode=${widget.categoryCode}');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Tùy chỉnh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
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
                            '✨ Lưu nhanh ${formatVnd(_selectedAmount)}',
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
