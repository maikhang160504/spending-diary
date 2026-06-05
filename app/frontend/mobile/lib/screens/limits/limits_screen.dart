import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/skeleton.dart';

/// Spending Limits Screen - matches /limits route
class LimitsScreen extends StatefulWidget {
  const LimitsScreen({super.key});

  @override
  State<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends State<LimitsScreen> {
  final _api = ApiClient();
  List<_LimitItem> _limits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() { _loading = true; _error = null; });
    try {
      final budgets = await _api.getBudgets();
      final seenCategories = <String>{};
      final uniqueBudgets = <dynamic>[];
      for (final b in budgets) {
        final rawCat = b['categoryCode'] as String? ?? b['category_code'] as String? ?? 'Other';
        final cat = CategoryTheme.canonicalCodeOf(rawCat);
        if (!seenCategories.contains(cat)) {
          seenCategories.add(cat);
          uniqueBudgets.add(b);
        }
      }
      _limits = uniqueBudgets.map((b) {
        final rawCat = b['categoryCode'] as String? ?? b['category_code'] as String? ?? 'Other';
        final cat = CategoryTheme.canonicalCodeOf(rawCat);
        final style = CategoryTheme.of(cat);
        return _LimitItem(
          id: b['id'] as String,
          emoji: style.emoji,
          label: style.label,
          color: style.color,
          categoryCode: cat,
          limit: ((b['amountLimit'] ?? b['amount_limit'] ?? 0) is num)
              ? (b['amountLimit'] ?? b['amount_limit'] as num).toInt()
              : 0,
          spent: ((b['spent'] ?? 0) is num) ? (b['spent'] as num).toInt() : 0,
        );
      }).toList();
    } on ApiException catch (e) {
      _error = e.localizedMessage;
    } catch (_) {
      _error = 'Không thể tải giới hạn';
    }
    if (mounted) setState(() => _loading = false);
  }

  // Find the first category near its limit (≥ 85% spent, not over)
  _LimitItem? get _warningItem {
    try {
      return _limits.firstWhere((l) {
        final pct = l.limit > 0 ? l.spent / l.limit : 0.0;
        return pct >= 0.85 && l.spent <= l.limit;
      });
    } catch (_) {
      return null;
    }
  }

  String get _currentMonth {
    final now = DateTime.now();
    return 'Tháng ${now.month}/${now.year}';
  }

  void _showAddBudget() {
    final amountCtrl = TextEditingController();
    String? selectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(builder: (ctx, setModalState) {
          // Available categories (not already budgeted)
          final existing = _limits.map((l) => l.categoryCode).toSet();
          final available = CategoryTheme.styles.entries
              .where((e) => CategoryTheme.primaryCodes.contains(e.key) && !existing.contains(e.key))
              .toList();

          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Thêm giới hạn mới', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                hint: const Text('Chọn danh mục'),
                items: available.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Row(children: [
                    CategoryTheme.iconOf(e.key, size: 22),
                    const SizedBox(width: 8),
                    Text(e.value.label),
                  ]),
                )).toList(),
                onChanged: (v) => setModalState(() => selectedCategory = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyTextInputFormatter()],
                decoration: const InputDecoration(labelText: 'Số tiền giới hạn', hintText: 'VD: 2,000,000', suffixText: 'đ'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (selectedCategory == null) return;
                          final rawText = amountCtrl.text.replaceAll(',', '').trim();
                          final amount = int.tryParse(rawText);
                          if (amount == null || amount <= 0) return;
                          setModalState(() {
                            isSubmitting = true;
                          });
                          ctx.pop();
                          try {
                            // Get first wallet
                            final wallets = await _api.getWallets();
                            if (wallets.isEmpty) return;
                            await _api.createBudget({
                              'walletId': wallets[0]['id'],
                              'categoryCode': selectedCategory,
                              'amountLimit': amount,
                              'period': 'month',
                              'startDate': DateTime.now().toIso8601String().split('T')[0],
                            });
                            _loadBudgets();
                          } catch (_) {}
                        },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Tạo giới hạn'),
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  void _showEditDialog(BuildContext context, _LimitItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditLimitSheet(item: item, onSave: (newLimit) async {
        setState(() => item.limit = newLimit);
        try {
          await _api.updateBudget(item.id, {'amountLimit': newLimit});
          _loadBudgets();
        } catch (_) {}
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warning = _warningItem;

    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBudgets,
          color: AppColors.teal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                            ),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Giới hạn chi tiêu', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Kiểm soát ngân sách theo danh mục', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                          ]),
                          GestureDetector(
                            onTap: _showAddBudget,
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Summary chips — dynamic
                      Row(children: [
                        _SummaryChip(label: 'Tổng ngân sách', value: _loading ? '...' : formatVnd(_limits.fold(0, (s, l) => s + l.limit))),
                        const SizedBox(width: 10),
                        _SummaryChip(label: 'Đã chi', value: _loading ? '...' : formatVnd(_limits.fold(0, (s, l) => s + l.spent))),
                      ]),
                    ],
                  ),
                ),
                if (_error != null) ErrorBanner(message: _error!, onRetry: _loadBudgets),
                const SizedBox(height: 16),
                // Dynamic warning banner
                if (warning != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: context.palette.softShadow,
                      ),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(AppRadii.md)),
                          child: const Center(child: Text('⚠️', style: TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${warning.label} gần đạt giới hạn', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            'Còn lại ${formatVnd(warning.limit - warning.spent)} (${((1 - warning.spent / warning.limit) * 100).toStringAsFixed(0)}%)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFD97706)),
                          ),
                        ])),
                      ]),
                    ),
                  ),
                const SizedBox(height: 16),
                // Limit list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Giới hạn theo danh mục', style: Theme.of(context).textTheme.titleSmall),
                        Text(_currentMonth, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                      ]),
                      const SizedBox(height: 12),
                      if (_loading)
                        ...List.generate(4, (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: SkeletonCard(height: 100),
                        ))
                      else if (_limits.isEmpty)
                        EmptyState(
                          emoji: '📊',
                          title: 'Chưa có giới hạn nào',
                          subtitle: 'Tạo giới hạn chi tiêu để kiểm soát ngân sách',
                          action: FilledButton(
                            onPressed: _showAddBudget,
                            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                            child: const Text('Tạo giới hạn'),
                          ),
                        )
                      else
                        ..._limits.map((item) => _LimitCard(item: item, onEdit: () => _showEditDialog(context, item))),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _showAddBudget,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: context.palette.card,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(color: AppColors.teal),
                            boxShadow: context.palette.softShadow,
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.add_circle_outline, color: AppColors.teal, size: 20),
                            const SizedBox(width: 8),
                            Text('Thêm giới hạn mới', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.md)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _LimitItem {
  final String id;
  final String emoji;
  final String label;
  final Color color;
  final String categoryCode;
  int limit;
  final int spent;

  _LimitItem({required this.id, required this.emoji, required this.label, required this.color, required this.categoryCode, required this.limit, required this.spent});
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
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: item.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.md)),
            child: Center(child: CategoryTheme.iconOf(item.categoryCode, size: 26)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text(
              isOverBudget ? 'Vượt ngân sách!' : 'Còn lại: ${formatVnd(remaining)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isOverBudget ? AppColors.danger : AppColors.muted,
                fontWeight: isOverBudget ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ])),
          GestureDetector(
            onTap: onEdit,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatVnd(item.spent), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text('/ ${formatVnd(item.limit)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
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
        ]),
      ]),
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
  bool _isSubmitting = false;

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
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(width: 28, height: 28, child: CategoryTheme.iconOf(widget.item.categoryCode, size: 28)),
            const SizedBox(width: 10),
            Text('Sửa giới hạn ${widget.item.label}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          Text('Số tiền giới hạn (đ)', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [MoneyTextInputFormatter()],
            decoration: const InputDecoration(hintText: '0'),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _isSubmitting ? null : () => context.pop(), child: const Text('Hủy'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      setState(() {
                        _isSubmitting = true;
                      });
                      final rawText = _controller.text.replaceAll(',', '').trim();
                      widget.onSave(int.tryParse(rawText) ?? widget.item.limit);
                      context.pop();
                    },
              child: const Text('Lưu'),
            )),
          ]),
        ],
      ),
    );
  }
}
