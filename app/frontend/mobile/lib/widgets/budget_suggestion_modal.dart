import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_palette.dart';
import '../theme/categories.dart';
import 'package:intl/intl.dart';

class BudgetSuggestionItem {
  final String categoryCode;
  final int suggestedAmount;
  final int baseSpending;
  final String reason;
  const BudgetSuggestionItem({
    required this.categoryCode,
    required this.suggestedAmount,
    required this.baseSpending,
    required this.reason,
  });
}

class BudgetSuggestionPreview {
  final String targetMonth;
  final List<BudgetSuggestionItem> items;
  final int totalSuggested;
  const BudgetSuggestionPreview({
    required this.targetMonth,
    required this.items,
    required this.totalSuggested,
  });
}

class BudgetSuggestionModal extends StatefulWidget {
  final BudgetSuggestionPreview preview;
  final void Function(Map<String, num> overrides)? onApply;
  final VoidCallback? onDismiss;

  const BudgetSuggestionModal({
    super.key,
    required this.preview,
    this.onApply,
    this.onDismiss,
  });

  @override
  State<BudgetSuggestionModal> createState() => _BudgetSuggestionModalState();
}

class _BudgetSuggestionModalState extends State<BudgetSuggestionModal> {
  final Map<String, bool> _selected = {};
  final Map<String, int> _amounts = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.preview.items) {
      _selected[item.categoryCode] = true;
      _amounts[item.categoryCode] = item.suggestedAmount; // Không làm tròn
    }
  }

  int get _totalSelectedAmount {
    int total = 0;
    for (final item in widget.preview.items) {
      if (_selected[item.categoryCode] ?? true) {
        total += _amounts[item.categoryCode] ?? item.suggestedAmount;
      }
    }
    return total;
  }

  int get _selectedCount {
    int count = 0;
    for (final item in widget.preview.items) {
      if (_selected[item.categoryCode] ?? true) {
        count++;
      }
    }
    return count;
  }
  
  String formatVnd(num value) {
    return NumberFormat('#,###', 'vi_VN').format(value);
  }

  String _formatTargetMonthLabel(String yyyyMm) {
    if (yyyyMm.length != 7) return yyyyMm;
    final parts = yyyyMm.split('-');
    if (parts.length != 2) return yyyyMm;
    return '${parts[1]}/${parts[0]}';
  }

  void _showEditDialog(String categoryCode, String label, int currentAmount) {
    final controller = TextEditingController(text: currentAmount.toString());
    final presets = [
      ('+10%', (currentAmount * 1.1).round()),
      ('+20%', (currentAmount * 1.2).round()),
      ('×1.5', (currentAmount * 1.5).round()),
      ('-10%', (currentAmount * 0.9).round()),
      ('-20%', (currentAmount * 0.8).round()),
    ];
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: ctx.palette.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            title: Text(
              'Tự điều chỉnh hạn mức: $label',
              style: TextStyle(
                color: ctx.palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: TextStyle(color: ctx.palette.textPrimary),
                  decoration: InputDecoration(
                    suffixText: 'đ',
                    suffixStyle: TextStyle(color: ctx.palette.textSecondary),
                    hintText: 'Nhập số tiền...',
                    hintStyle: TextStyle(
                      color: ctx.palette.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nhập nhanh',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ctx.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: presets.map((p) {
                    return ActionChip(
                      label: Text(
                        p.$1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.teal.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: AppColors.teal.withValues(alpha: 0.25),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          controller.text = p.$2.toString();
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              FilledButton(
                onPressed: () {
                  final val = int.tryParse(controller.text);
                  if (val != null && val >= 0) {
                    setState(() {
                      _amounts[categoryCode] = val;
                    });
                  }
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.teal;
    final monthLabel = _formatTargetMonthLabel(widget.preview.targetMonth);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hạn mức tháng $monthLabel',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đã chọn $_selectedCount/${widget.preview.items.length} danh mục',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng hạn mức đề xuất',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                ),
                Text(
                  '${formatVnd(_totalSelectedAmount)}đ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.preview.items.length,
              separatorBuilder: (ctx, idx) =>
                  const Divider(height: 1, indent: 48),
              itemBuilder: (ctx, idx) {
                final item = widget.preview.items[idx];
                final style = CategoryTheme.of(item.categoryCode);
                final isSel = _selected[item.categoryCode] ?? true;
                final currentAmt =
                    _amounts[item.categoryCode] ?? item.suggestedAmount;

                return InkWell(
                  onTap: () {
                    // Mở rộng hiển thị Tooltip lý do
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selected[item.categoryCode] = !isSel;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSel ? accent : Colors.transparent,
                              border: Border.all(
                                color: isSel
                                    ? accent
                                    : context.palette.textSecondary.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.check,
                              color: isSel ? Colors.white : Colors.transparent,
                              size: 14,
                            ),
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: style.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CategoryTheme.iconOf(
                              item.categoryCode,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Opacity(
                            opacity: isSel ? 1.0 : 0.45,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  style.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.palette.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.reason.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Tooltip(
                                    message: item.reason,
                                    triggerMode: TooltipTriggerMode.tap,
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    padding: const EdgeInsets.all(12),
                                    showDuration: const Duration(seconds: 5),
                                    textStyle: const TextStyle(fontSize: 13, color: Colors.white),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.reason,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.palette.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Opacity(
                          opacity: isSel ? 1.0 : 0.45,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${formatVnd(currentAmt)}đ',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                  if (isSel)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: accent,
                                      ),
                                      padding: const EdgeInsets.only(left: 4),
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showEditDialog(
                                        item.categoryCode,
                                        style.label,
                                        currentAmt,
                                      ),
                                    ),
                                ],
                              ),
                              if (item.baseSpending > 0 &&
                                  currentAmt != item.baseSpending)
                                Text(
                                  '${formatVnd(item.baseSpending)}đ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.palette.textSecondary
                                        .withValues(alpha: 0.6),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDismiss?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: context.palette.textSecondary.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Bỏ qua',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.palette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final overrides = <String, num>{};
                    for (final item in widget.preview.items) {
                      final isSel = _selected[item.categoryCode] ?? true;
                      if (!isSel) {
                        overrides[item.categoryCode] = -1; // -1 means skip
                      } else {
                        final amt = _amounts[item.categoryCode];
                        if (amt != null && amt != item.suggestedAmount) {
                          overrides[item.categoryCode] = amt;
                        }
                      }
                    }
                    Navigator.pop(context);
                    widget.onApply?.call(overrides);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Áp dụng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
