import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/skeleton.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  final _api = ApiClient();
  List<dynamic> _goals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() { _loading = true; _error = null; });
    try {
      _goals = await _api.getGoals();
    } on ApiException catch (e) {
      _error = e.localizedMessage;
    } catch (_) {
      _error = 'Không thể tải mục tiêu';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showCreateGoal() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String emoji = '🎯';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tạo mục tiêu mới', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Emoji picker row
          Row(children: [
            Text('Biểu tượng:', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(width: 8),
            ...['🎯', '📱', '🏠', '✈️', '🎓', '💰'].map((e) => GestureDetector(
              onTap: () => (ctx as Element).markNeedsBuild(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            )),
          ]),
          const SizedBox(height: 12),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên mục tiêu', hintText: 'VD: Mua iPhone')),
          const SizedBox(height: 10),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tiền mục tiêu', hintText: 'VD: 25000000')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim());
                if (name.isEmpty || amount == null || amount <= 0) return;
                Navigator.pop(ctx);
                try {
                  await _api.createGoal({'name': name, 'targetAmount': amount, 'emoji': emoji});
                  _loadGoals();
                } catch (_) {}
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Tạo mục tiêu'),
            ),
          ),
        ]),
      ),
    );
  }

  void _showContribute(String goalId, String goalName) {
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Thêm tiền vào "$goalName"', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, autofocus: true,
            decoration: const InputDecoration(labelText: 'Số tiền', hintText: 'VD: 500000', suffixText: 'đ')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                Navigator.pop(ctx);
                try {
                  await _api.contributeGoal(goalId, amount);
                  _loadGoals();
                } catch (_) {}
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Thêm tiền'),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadGoals,
          color: AppColors.teal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GoalHeader(onAdd: _showCreateGoal),
                if (_error != null)
                  ErrorBanner(message: _error!, onRetry: _loadGoals),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: _loading
                      ? Column(children: List.generate(2, (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: SkeletonCard(height: 240),
                        )))
                      : _goals.isEmpty
                          ? EmptyState(
                              emoji: '🎯',
                              title: 'Chưa có mục tiêu nào',
                              subtitle: 'Bắt đầu bằng cách tạo mục tiêu tiết kiệm đầu tiên',
                              action: FilledButton(
                                onPressed: _showCreateGoal,
                                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                                child: const Text('Tạo mục tiêu'),
                              ),
                            )
                          : Column(children: _goals.map((g) => _ApiGoalCard(
                              goal: g,
                              onContribute: () => _showContribute(g['id'] as String, g['name'] as String),
                            )).toList()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalHeader extends StatelessWidget {
  final VoidCallback onAdd;
  const _GoalHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mục tiêu', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Đặt mục tiêu và theo dõi tiến độ tiết kiệm', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ],
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiGoalCard extends StatelessWidget {
  final dynamic goal;
  final VoidCallback onContribute;

  const _ApiGoalCard({required this.goal, required this.onContribute});

  @override
  Widget build(BuildContext context) {
    final targetAmount = ((goal['target_amount'] ?? 0) is num) ? (goal['target_amount'] as num).toInt() : 0;
    final currentAmount = ((goal['current_amount'] ?? 0) is num) ? (goal['current_amount'] as num).toInt() : 0;
    final remaining = targetAmount - currentAmount;
    final percent = targetAmount > 0 ? currentAmount / targetAmount : 0.0;
    final emoji = goal['emoji'] as String? ?? '🎯';
    final name = goal['name'] as String? ?? 'Mục tiêu';
    final status = goal['status'] as String? ?? 'active';
    final isCompleted = status == 'completed' || percent >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4))],
        border: isCompleted ? Border.all(color: AppColors.teal.withValues(alpha: 0.4), width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.teal.withValues(alpha: 0.15) : AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                    child: const Text('🎉 Hoàn thành!', style: TextStyle(color: AppColors.teal, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
              ]),
              const SizedBox(height: 2),
              Text('Mục tiêu: ${formatVnd(targetAmount)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Tiến độ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            Text('${(percent * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? AppColors.success : AppColors.teal),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFF0FDFB), borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Đã tiết kiệm', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(formatVnd(currentAmount), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w700)),
              ]),
            )),
            const SizedBox(width: 10),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Còn thiếu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(formatVnd(remaining > 0 ? remaining : 0), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
            )),
          ]),
          const SizedBox(height: 14),
          if (!isCompleted)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onContribute,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm tiền'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}