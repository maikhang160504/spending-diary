import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

/// Spending Limits Screen - matches /limits route
class LimitsScreen extends StatefulWidget {
  const LimitsScreen({super.key});

  @override
  State<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends State<LimitsScreen> {
  final List<_LimitItem> _limits = [
    _LimitItem(emoji: '🍔', label: 'Ăn uống', color: const Color(0xFFEC4899), limit: 2000000, spent: 680000),
    _LimitItem(emoji: '🛍️', label: 'Mua sắm', color: const Color(0xFF8B5CF6), limit: 1500000, spent: 1350000),
    _LimitItem(emoji: '🚗', label: 'Di chuyển', color: const Color(0xFF3B82F6), limit: 500000, spent: 60000),
    _LimitItem(emoji: '🎬', label: 'Giải trí', color: const Color(0xFFF59E0B), limit: 800000, spent: 150000),
    _LimitItem(emoji: '🏠', label: 'Nhà ở', color: const Color(0xFF10B981), limit: 3000000, spent: 3000000),
    _LimitItem(emoji: '💊', label: 'Sức khỏe', color: const Color(0xFFEF4444), limit: 500000, spent: 0),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              // Header
              Container(
                decoration: const BoxDecoration(
                  gradient: AppGradients.teal,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadii.xl),
                    bottomRight: Radius.circular(AppRadii.xl),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Giới hạn chi tiêu', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Kiểm soát ngân sách theo danh mục', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                          ],
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Summary chips
                    Row(
                      children: [
                        _SummaryChip(
                          label: 'Tổng ngân sách',
                          value: formatVnd(_limits.fold(0, (s, l) => s + l.limit)),
                        ),
                        const SizedBox(width: 10),
                        _SummaryChip(
                          label: 'Đã chi',
                          value: formatVnd(_limits.fold(0, (s, l) => s + l.spent)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Status indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: const Center(child: Text('⚠️', style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mua sắm gần đạt giới hạn', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('Còn lại 150.000 đ (10%)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFD97706))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Limit list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Giới hạn theo danh mục', style: Theme.of(context).textTheme.titleSmall),
                        Text('Tháng 5/2026', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._limits.map((item) => _LimitCard(item: item, onEdit: () => _showEditDialog(context, item))),
                    const SizedBox(height: 12),
                    // Add new limit
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(color: AppColors.teal, style: BorderStyle.solid),
                          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline, color: AppColors.teal, size: 20),
                            const SizedBox(width: 8),
                            Text('Thêm giới hạn mới', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
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
      ),
    );
  }

  void _showEditDialog(BuildContext context, _LimitItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditLimitSheet(item: item, onSave: (newLimit) {
        setState(() => item.limit = newLimit);
      }),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            const SizedBox(height: 2),
            Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _LimitItem {
  final String emoji;
  final String label;
  final Color color;
  int limit;
  final int spent;

  _LimitItem({required this.emoji, required this.label, required this.color, required this.limit, required this.spent});
}

class _LimitCard extends StatelessWidget {
  final _LimitItem item;
  final VoidCallback onEdit;
  const _LimitCard({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final percent = item.limit > 0 ? (item.spent / item.limit).clamp(0.0, 1.0) : 0.0;
    final remaining = item.limit - item.spent;
    final isOverBudget = item.spent > item.limit;
    final isWarning = percent > 0.85 && !isOverBudget;
    final barColor = isOverBudget ? AppColors.danger : (isWarning ? const Color(0xFFF59E0B) : item.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      isOverBudget ? 'Vượt ngân sách!' : 'Còn lại: ${formatVnd(remaining)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isOverBudget ? AppColors.danger : AppColors.muted,
                            fontWeight: isOverBudget ? FontWeight.w600 : FontWeight.normal,
                          ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatVnd(item.spent), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text('/ ${formatVnd(item.limit)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(percent * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: barColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditLimitSheet extends StatefulWidget {
  final _LimitItem item;
  final ValueChanged<int> onSave;
  const _EditLimitSheet({required this.item, required this.onSave});

  @override
  State<_EditLimitSheet> createState() => _EditLimitSheetState();
}

class _EditLimitSheetState extends State<_EditLimitSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.limit.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.item.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text('Sửa giới hạn ${widget.item.label}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Số tiền giới hạn (đ)', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: '0'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.onSave(int.tryParse(_controller.text) ?? widget.item.limit);
                    Navigator.pop(context);
                  },
                  child: const Text('Lưu'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
