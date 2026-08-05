import re

with open('app/frontend/mobile/lib/screens/chat/chat_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('class _BudgetSuggestionCard extends StatefulWidget {')
end_idx = content.find('class _ActionConfirmCard extends StatelessWidget {', start_idx)

if start_idx == -1 or end_idx == -1:
    print("Could not find start or end")
    exit(1)

old_code = content[start_idx:end_idx]

new_code = """class _BudgetSuggestionModal extends StatefulWidget {
  final _BudgetSuggestionPreview preview;
  final void Function(Map<String, num> overrides)? onApply;
  final VoidCallback? onDismiss;

  const _BudgetSuggestionModal({
    required this.preview,
    this.onApply,
    this.onDismiss,
  });

  @override
  State<_BudgetSuggestionModal> createState() => _BudgetSuggestionModalState();
}

class _BudgetSuggestionModalState extends State<_BudgetSuggestionModal> {
  final Map<String, bool> _selected = {};
  final Map<String, int> _amounts = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.preview.items) {
      _selected[item.categoryCode] = true;
      final raw = item.suggestedAmount;
      _amounts[item.categoryCode] = ((raw / 1000).round() * 1000);
    }
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
              'Sửa hạn mức: $label',
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
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
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

  String _formatTargetMonthLabel(String yyyyMM) {
    try {
      final parts = yyyyMM.split('-');
      if (parts.length == 2) {
        return '${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return yyyyMM;
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.teal;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: context.palette.background,
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
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hạn mức ${_formatTargetMonthLabel(widget.preview.targetMonth)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: accent,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.preview.items.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final item = widget.preview.items[idx];
                final style = CategoryTheme.of(item.categoryCode);
                final isSel = _selected[item.categoryCode] ?? true;
                final currentAmt = _amounts[item.categoryCode] ?? item.suggestedAmount;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selected[item.categoryCode] = !isSel;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isSel ? accent : Colors.transparent,
                            border: Border.all(
                              color: isSel ? accent : context.palette.textSecondary.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.check,
                            color: isSel ? Colors.white : Colors.transparent,
                            size: 12,
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
                            child: CategoryTheme.iconOf(item.categoryCode, size: 18),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.palette.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.reason.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.reason,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.palette.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                  if (isSel)
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16, color: accent),
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
                              if (item.baseSpending > 0 && currentAmt != item.baseSpending)
                                Text(
                                  '${formatVnd(item.baseSpending)}đ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.palette.textSecondary.withValues(alpha: 0.6),
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
                        overrides[item.categoryCode] = -1;
                      } else {
                        overrides[item.categoryCode] =
                            _amounts[item.categoryCode] ?? item.suggestedAmount;
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
                      fontWeight: FontWeight.w700,
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

class _BudgetSuggestionCard extends StatelessWidget {
  final _BudgetSuggestionPreview preview;
  final bool isApplied;
  final bool isDismissed;
  final void Function(Map<String, num> overrides)? onApply;
  final VoidCallback? onDismiss;

  const _BudgetSuggestionCard({
    required this.preview,
    this.isApplied = false,
    this.isDismissed = false,
    this.onApply,
    this.onDismiss,
  });

  String _formatTargetMonthLabel(String yyyyMM) {
    try {
      final parts = yyyyMM.split('-');
      if (parts.length == 2) {
        return '${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return yyyyMM;
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.teal;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 1.5),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: accent, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hạn mức ${_formatTargetMonthLabel(preview.targetMonth)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mimo đã phân tích chi tiêu và có một số gợi ý hạn mức mới cho bạn.',
            style: TextStyle(
              fontSize: 12,
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (isApplied)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: accent, size: 16),
                SizedBox(width: 6),
                Text(
                  'Đã áp dụng hạn mức',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else if (isDismissed)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cancel,
                  color: Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Đã bỏ qua gợi ý',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => _BudgetSuggestionModal(
                      preview: preview,
                      onApply: onApply,
                      onDismiss: onDismiss,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Xem gợi ý'),
              ),
            ),
        ],
      ),
    );
  }
}
"""

content = content[:start_idx] + new_code + content[end_idx:]

with open('app/frontend/mobile/lib/screens/chat/chat_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Replaced successfully")
