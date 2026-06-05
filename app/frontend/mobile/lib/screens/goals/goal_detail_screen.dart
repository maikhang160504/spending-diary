import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/loading_indicator.dart';

class GoalDetailScreen extends StatefulWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final _api = ApiClient();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _goal = {};
  List<dynamic> _contributions = [];
  List<dynamic> _topContributors = [];
  List<dynamic> _wallets = [];

  @override
  void initState() {
    super.initState();
    _loadGoalDetail();
  }

  Future<void> _loadGoalDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resList = await Future.wait([
        _api.getGoal(widget.goalId),
        _api.getWallets(),
      ]);
      final res = resList[0] as Map<String, dynamic>;
      final walletsList = resList[1] as List<dynamic>;
      setState(() {
        _goal = res;
        _wallets = walletsList;
        _contributions = res['contributions'] as List<dynamic>? ?? [];
        _topContributors = res['topContributors'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.localizedMessage;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Không thể tải chi tiết mục tiêu';
        _loading = false;
      });
    }
  }

  Future<void> _deleteGoal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Xóa mục tiêu'),
            content: const Text('Bạn có chắc chắn muốn xóa mục tiêu tiết kiệm này không? Thao tác này không thể hoàn tác.'),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        setDialogState(() {
                          isSubmitting = true;
                        });
                        Navigator.pop(ctx, true);
                      },
                child: const Text('Xóa', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true || !mounted) return;

    try {
      await _api.deleteGoal(widget.goalId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa mục tiêu thành công')),
        );
        context.pop(true); // Return true to indicate reload needed
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa mục tiêu')),
        );
      }
    }
  }

  void _showContributeSheet() {
    final amountCtrl = TextEditingController();
    bool isSubmitting = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đóng góp cho mục tiêu', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [MoneyTextInputFormatter()],
                decoration: const InputDecoration(labelText: 'Số tiền đóng góp', hintText: 'VD: 500,000', suffixText: 'đ'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final rawText = amountCtrl.text.replaceAll(',', '').replaceAll('.', '').trim();
                          final amount = double.tryParse(rawText);
                          if (amount == null || amount <= 0) return;
                          setSheetState(() {
                            isSubmitting = true;
                          });
                          ctx.pop();
                          try {
                            await _api.contributeGoal(widget.goalId, amount);
                            _loadGoalDetail();
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Không thể thực hiện đóng góp')),
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Đóng góp'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditGoalSheet() {
    final nameCtrl = TextEditingController(text: _goal['name']);
    final targetAmountVal = (_goal['target_amount'] as num?)?.toInt() ?? 0;
    final amountCtrl = TextEditingController(text: formatVnd(targetAmountVal).replaceAll('đ', '').trim());
    String emoji = _goal['emoji'] as String? ?? '🎯';
    String? selectedWalletId = _goal['wallet_id'] as String?;
    
    final deadlineStr = _goal['deadline'] as String?;
    DateTime? deadlineDate;
    if (deadlineStr != null) {
      try {
        deadlineDate = DateTime.parse(deadlineStr);
      } catch (_) {}
    }
    
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chỉnh sửa mục tiêu', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Text('Biểu tượng:', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['🎯', '📱', '🏠', '✈️', '🎓', '💰'].map((e) => GestureDetector(
                    onTap: () => setSheet(() => emoji = e),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: emoji == e ? AppColors.teal.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: emoji == e ? AppColors.teal : Colors.transparent, width: 1.5),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên mục tiêu')),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyTextInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Số tiền mục tiêu', suffixText: 'đ'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: selectedWalletId,
                  decoration: const InputDecoration(labelText: 'Liên kết ví'),
                  dropdownColor: ctx.palette.card,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Không liên kết (Cá nhân)'),
                    ),
                    ..._wallets.map((w) {
                      final name = w['name'] as String? ?? 'Ví';
                      final type = w['type'] as String? ?? 'personal';
                      final isGroup = type == 'group';
                      return DropdownMenuItem<String?>(
                        value: w['id'] as String?,
                        child: Text(isGroup ? 'Ví chung: $name' : 'Ví: $name'),
                      );
                    }),
                  ],
                  onChanged: (val) => setSheet(() => selectedWalletId = val),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: deadlineDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) {
                      setSheet(() => deadlineDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Hạn chót (Deadline)', suffixIcon: Icon(Icons.calendar_today)),
                    child: Text(deadlineDate == null ? 'Không có' : '${deadlineDate!.day}/${deadlineDate!.month}/${deadlineDate!.year}'),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final rawText = amountCtrl.text.replaceAll(',', '').replaceAll('.', '').trim();
                            final amount = double.tryParse(rawText);
                            if (name.isEmpty || amount == null || amount <= 0) return;
                            setSheet(() {
                              isSubmitting = true;
                            });
                            ctx.pop();
                            String? deadlineStr;
                            if (deadlineDate != null) {
                              deadlineStr = '${deadlineDate!.year}-${deadlineDate!.month.toString().padLeft(2, '0')}-${deadlineDate!.day.toString().padLeft(2, '0')}';
                            }
                            
                            setState(() => _loading = true);
                            try {
                              await _api.updateGoal(widget.goalId, {
                                'name': name,
                                'targetAmount': amount,
                                'emoji': emoji,
                                'walletId': selectedWalletId,
                                'deadline': deadlineStr,
                              });
                              _loadGoalDetail();
                            } catch (_) {
                              setState(() => _loading = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Không thể cập nhật mục tiêu')),
                                );
                              }
                            }
                          },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Lưu thay đổi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 16)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadGoalDetail,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final name = _goal['name'] as String? ?? 'Mục tiêu';
    final emoji = _goal['emoji'] as String? ?? '🎯';
    final targetAmount = (_goal['target_amount'] as num?)?.toInt() ?? 0;
    final currentAmount = (_goal['current_amount'] as num?)?.toInt() ?? 0;
    final status = _goal['status'] as String? ?? 'active';
    final deadlineStr = _goal['deadline'] as String?;

    final percent = targetAmount > 0 ? currentAmount / targetAmount : 0.0;
    final isCompleted = status == 'completed' || percent >= 1.0;
    final remaining = targetAmount - currentAmount;

    // Calculations for deadline
    int daysLeft = -1;
    bool isExpired = false;
    DateTime? deadlineDate;
    if (deadlineStr != null) {
      try {
        deadlineDate = DateTime.parse(deadlineStr);
        final diff = deadlineDate.difference(DateTime.now());
        daysLeft = diff.inDays;
        isExpired = deadlineDate.isBefore(DateTime.now()) && !isCompleted;
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                padding: const EdgeInsets.fromLTRB(12, 14, 24, 24),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chi tiết mục tiêu',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Main Info Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.palette.card,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: context.palette.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      if (_goal['walletName'] != null) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.group_outlined, color: AppColors.teal, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Ví liên kết: ${_goal['walletName']}',
                                style: const TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ] else ...[
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Mục tiêu cá nhân. Hãy chỉnh sửa mục tiêu để liên kết với Ví chung và mời người khác đóng góp.',
                                  style: TextStyle(color: context.palette.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                          child: const Text('🎉 Đã hoàn thành mục tiêu!', style: TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w700)),
                        )
                      else if (isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                          child: const Text('⚠️ Đã quá hạn chót!', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700)),
                        )
                      else if (deadlineDate != null)
                        Text(
                          'Hạn chót: ${deadlineDate.day}/${deadlineDate.month}/${deadlineDate.year} (${daysLeft >= 0 ? 'Còn $daysLeft ngày' : 'Đã quá hạn'})',
                          style: TextStyle(color: daysLeft < 5 ? AppColors.danger : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tiến độ tích lũy', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                          Text('${(percent * 100).toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: percent.clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: context.palette.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? AppColors.success : AppColors.teal),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AppRadii.md)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Đã tích lũy', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(formatVnd(currentAmount), style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: context.palette.surfaceAlt, borderRadius: BorderRadius.circular(AppRadii.md)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Còn thiếu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(formatVnd(remaining > 0 ? remaining : 0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (!isCompleted) ...[
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: _showContributeSheet,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Đóng góp'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _showEditGoalSheet,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.teal,
                                side: const BorderSide(color: AppColors.teal),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                              ),
                              child: const Text('Chỉnh sửa'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _deleteGoal,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(AppRadii.md),
                              ),
                              child: const Icon(Icons.delete_outline, color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Wallet members with access
              if (_goal['walletMembers'] != null && (_goal['walletMembers'] as List).isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Text(
                    'Thành viên cùng đóng góp 👥',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      boxShadow: context.palette.cardShadow,
                    ),
                    width: double.infinity,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: (_goal['walletMembers'] as List<dynamic>).map((m) {
                        final uName = m['username'] as String? ?? 'Thành viên';
                        final avatar = m['avatarUrl'] as String?;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                                child: avatar == null
                                    ? Text(uName[0].toUpperCase(), style: const TextStyle(color: AppColors.teal, fontSize: 8, fontWeight: FontWeight.w700))
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(uName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              // Top 3 Contributors
              if (_topContributors.isNotEmpty) ...[
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Text(
                    'Top đóng góp 🏆',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Render podium elements if we have multiple top contributors
                      // Position 2
                      if (_topContributors.length > 1)
                        Expanded(child: _buildPodiumItem(context, _topContributors[1], 2)),
                      // Position 1
                      Expanded(child: _buildPodiumItem(context, _topContributors[0], 1)),
                      // Position 3
                      if (_topContributors.length > 2)
                        Expanded(child: _buildPodiumItem(context, _topContributors[2], 3))
                      else if (_topContributors.length <= 2)
                        const Spacer(),
                    ],
                  ),
                ),
              ],

              // Contribution History
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Text(
                  'Lịch sử đóng góp 📜',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              if (_contributions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'Chưa có khoản đóng góp nào',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      boxShadow: context.palette.cardShadow,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _contributions.length,
                      separatorBuilder: (ctx, i) => Divider(height: 1, color: context.palette.divider),
                      itemBuilder: (ctx, i) {
                        final c = _contributions[i];
                        final uName = c['username'] as String? ?? 'Thành viên';
                        final avatar = c['avatarUrl'] as String?;
                        final amount = (c['amount'] as num?)?.toInt() ?? 0;
                        final dateStr = c['createdAt'] as String? ?? '';

                        String formattedDate = '';
                        if (dateStr.isNotEmpty) {
                          try {
                            final dt = DateTime.parse(dateStr);
                            formattedDate = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}';
                          } catch (_) {}
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                            child: avatar == null
                                ? Text(uName[0].toUpperCase(), style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700))
                                : null,
                          ),
                          title: Text(uName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(formattedDate, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                          trailing: Text(
                            '+${formatVnd(amount)}',
                            style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumItem(BuildContext context, dynamic contributor, int rank) {
    final uName = contributor['username'] as String? ?? 'Thành viên';
    final avatar = contributor['avatarUrl'] as String?;
    final total = (contributor['total'] as num?)?.toInt() ?? 0;

    double avatarSize = 48.0;
    double scale = 1.0;
    Color medalColor = const Color(0xFFFFD700); // Gold
    String rankEmoji = '🥇';

    if (rank == 2) {
      avatarSize = 40.0;
      scale = 0.9;
      medalColor = const Color(0xFFC0C0C0); // Silver
      rankEmoji = '🥈';
    } else if (rank == 3) {
      avatarSize = 40.0;
      scale = 0.9;
      medalColor = const Color(0xFFCD7F32); // Bronze
      rankEmoji = '🥉';
    }

    return Transform.scale(
      scale: scale,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: avatarSize + 6,
                height: avatarSize + 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: medalColor, width: 2.5),
                ),
                child: CircleAvatar(
                  backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Text(uName[0].toUpperCase(), style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700))
                      : null,
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(rankEmoji, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            uName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            formatVnd(total),
            style: const TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
