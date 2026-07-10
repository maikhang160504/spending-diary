import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/loading_indicator.dart';
import 'goal_recap_screen.dart';

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
  List<dynamic> _contributorLeaderboard = [];
  List<dynamic> _progressLeaderboard = [];
  Map<String, dynamic>? _myProgress;
  String? _currentUserId;

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
        _api.getMe(),
      ]);
      final res = resList[0] as Map<String, dynamic>;
      setState(() {
        _goal = res;
        _contributions = res['contributions'] as List<dynamic>? ?? [];
        _topContributors = res['topContributors'] as List<dynamic>? ?? [];
        _contributorLeaderboard = res['contributorLeaderboard'] as List<dynamic>? ?? [];
        _progressLeaderboard = res['progressLeaderboard'] as List<dynamic>? ?? [];
        _myProgress = res['myProgress'] as Map<String, dynamic>?;
        
        final meResult = resList[2] as Map<String, dynamic>;
        _currentUserId = meResult['user']?['id'] as String? ?? meResult['id'] as String?;
        
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
    final ownerId = _goal['user_id'] as String?;
    final isOwner = ownerId == null || ownerId == _currentUserId;

    final title = isOwner ? 'Xóa mục tiêu' : 'Rời mục tiêu';
    final content = isOwner 
        ? 'Bạn có chắc chắn muốn xóa mục tiêu này không? Thao tác này không thể hoàn tác.'
        : 'Bạn có chắc chắn muốn rời khỏi mục tiêu nhóm này không?';
    final actionText = isOwner ? 'Xóa' : 'Rời';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(title),
            content: Text(content),
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
                child: Text(actionText, style: const TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true || !mounted) return;

    try {
      if (isOwner) {
        await _api.deleteGoal(widget.goalId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa mục tiêu thành công')),
          );
          context.pop(true);
        }
      } else {
        await _api.leaveGoal(widget.goalId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã rời khỏi mục tiêu')),
          );
          context.pop(true);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể $actionText mục tiêu')),
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
      builder: (ctx) {
        final isChallenge = _goal['type'] == 'challenge';
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isChallenge ? 'Cập nhật tiến độ thử thách' : 'Đóng góp cho mục tiêu',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
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
                    child: Text(isChallenge ? 'Cập nhật tiến độ' : 'Đóng góp'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditGoalSheet() {
    final isChallenge = _goal['type'] == 'challenge';
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
                Text(
                  isChallenge ? 'Chỉnh sửa thử thách' : 'Chỉnh sửa tiết kiệm',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
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

    final typeStr = _goal['type']?.toString() ?? '';
    final isGroupGoal = typeStr == 'saving_group' || typeStr == 'challenge_group' || typeStr == 'group' || _goal['is_group'] == true || _goal['isGroup'] == true;
    final isChallenge = typeStr.startsWith('challenge');
    final isGroupSaving = typeStr == 'saving_group';
    final titleText = isChallenge ? 'Chi tiết thử thách' : 'Chi tiết tiết kiệm';
    final inviteCode = isGroupGoal ? (_goal['inviteCode'] as String?) : null;

    final ownerId = _goal['user_id'] as String?;
    final name = _goal['name'] as String? ?? 'Mục tiêu';
    final emoji = _goal['emoji'] as String? ?? '🎯';
    final targetAmount = (_goal['target_amount'] as num?)?.toInt() ?? 0;
    final currentAmount = (_goal['current_amount'] as num?)?.toInt() ?? 0;
    final status = _goal['status'] as String? ?? 'active';
    final deadlineStr = _goal['deadline'] as String?;

    // Tính toán tiến độ hiển thị
    final int displayCurr = isChallenge
        ? ((_myProgress?['currentAmount'] as num?)?.toInt() ?? 0)
        : currentAmount;
    final double percent = targetAmount > 0 ? displayCurr / targetAmount : 0.0;
    final bool isCompleted = status == 'completed' || percent >= 1.0;
    final int remaining = targetAmount - displayCurr;

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
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop(true);
                        } else {
                          context.pop();
                        }
                      },
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
                        titleText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (inviteCode != null && inviteCode.isNotEmpty) ...[
                      Tooltip(
                        message: 'Mã mời: $inviteCode',
                        child: GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: inviteCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã sao chép mã mời: $inviteCode')),
                            );
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                            child: const Icon(Icons.qr_code, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                    if (ownerId == _currentUserId) ...[
                      GestureDetector(
                        onTap: _showEditGoalSheet,
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                          child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                    GestureDetector(
                      onTap: _deleteGoal,
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                        child: Icon(ownerId == _currentUserId ? Icons.delete_outline : Icons.exit_to_app, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Thẻ Mã mời (Invite Code Banner) nếu có
              if (inviteCode != null && inviteCode.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code, color: AppColors.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isChallenge ? 'Mã mời thử thách' : 'Mã mời nhóm tiết kiệm',
                                style: TextStyle(color: context.palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                inviteCode,
                                style: const TextStyle(color: AppColors.teal, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: inviteCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã sao chép mã mời vào bộ nhớ tạm!')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Sao chép'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.teal),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

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
                      Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isChallenge
                                  ? AppColors.warning.withValues(alpha: 0.15)
                                  : (isGroupSaving ? AppColors.teal.withValues(alpha: 0.15) : context.palette.surfaceAlt),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isChallenge ? Icons.emoji_events : (isGroupSaving ? Icons.groups : Icons.person),
                                  size: 12,
                                  color: isChallenge ? AppColors.warning : AppColors.teal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isChallenge
                                      ? 'Thử thách tiết kiệm'
                                      : (isGroupSaving ? 'Tiết kiệm nhóm' : 'Tiết kiệm cá nhân'),
                                  style: TextStyle(
                                    color: isChallenge ? AppColors.warning : AppColors.teal,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_goal['walletName'] != null)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.palette.surfaceAlt,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.account_balance_wallet, size: 12, color: AppColors.teal),
                                  const SizedBox(width: 4),
                                  Text(_goal['walletName'], style: const TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                          child: const Text('🎉 Đã hoàn thành!', style: TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w700)),
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
                          style: TextStyle(color: daysLeft < 5 ? AppColors.danger : context.palette.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isChallenge ? 'Tiến độ thử thách của bạn' : 'Tiến độ tích lũy',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
                          ),
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
                                  Text(isChallenge ? 'Bạn đã đạt' : 'Đã tích lũy', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(formatVnd(displayCurr), style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800, fontSize: 16)),
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
                                  Text('Còn thiếu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(formatVnd(remaining > 0 ? remaining : 0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (!isCompleted)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _showContributeSheet,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(isChallenge ? 'Đóng góp tiến độ' : 'Đóng góp'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            ),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => GoalRecapScreen(
                                      goal: {
                                        ..._goal,
                                        'name': name,
                                        'targetAmount': targetAmount,
                                        'currentAmount': displayCurr,
                                        'emoji': emoji,
                                        'isGroup': isGroupGoal,
                                        'type': typeStr,
                                        'contributionsCount': _contributions.length,
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Xem tổng kết hành trình (Recap) ✨',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Bảng xếp hạng Thử thách (nếu là challenge)
              if (isChallenge && _progressLeaderboard.isNotEmpty) ...[
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Text(
                    'Bảng xếp hạng tiến độ thử thách 🏁',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
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
                      itemCount: _progressLeaderboard.length,
                      separatorBuilder: (ctx, i) => Divider(height: 1, color: context.palette.divider),
                      itemBuilder: (ctx, i) {
                        final m = _progressLeaderboard[i];
                        final uName = m['username'] as String? ?? 'Thành viên';
                        final avatar = m['avatarUrl'] as String?;
                        final pct = (m['percentage'] as num?)?.toInt() ?? 0;
                        final isDone = m['status'] == 'completed' || pct >= 100;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                            child: avatar == null
                                ? Text(uName[0].toUpperCase(), style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700))
                                : null,
                          ),
                          title: Text(uName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('Đã hoàn thành $pct%', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDone ? AppColors.teal.withValues(alpha: 0.15) : context.palette.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isDone ? 'Hoàn thành 🎉' : 'Đang đua ⚡',
                              style: TextStyle(
                                color: isDone ? AppColors.teal : context.palette.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Bảng xếp hạng Đóng góp (nếu là tiết kiệm và có dữ liệu)
              if (!isChallenge && (_topContributors.isNotEmpty || _contributorLeaderboard.isNotEmpty)) ...[
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Text(
                    isGroupSaving ? 'Bảng xếp hạng đóng góp nhóm 🏆' : 'Top đóng góp 🏆',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
                if (_topContributors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_topContributors.length > 1)
                          Expanded(child: _buildPodiumItem(context, _topContributors[1], 2)),
                        Expanded(child: _buildPodiumItem(context, _topContributors[0], 1)),
                        if (_topContributors.length > 2)
                          Expanded(child: _buildPodiumItem(context, _topContributors[2], 3))
                        else if (_topContributors.length <= 2)
                          const Spacer(),
                      ],
                    ),
                  ),
                if (_contributorLeaderboard.isNotEmpty) ...[
                  const SizedBox(height: 16),
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
                        itemCount: _contributorLeaderboard.length,
                        separatorBuilder: (ctx, i) => Divider(height: 1, color: context.palette.divider),
                        itemBuilder: (ctx, i) {
                          final m = _contributorLeaderboard[i];
                          final uName = m['username'] as String? ?? 'Thành viên';
                          final avatar = m['avatarUrl'] as String?;
                          final total = (m['totalContributed'] as num?)?.toInt() ?? (m['total'] as num?)?.toInt() ?? 0;
                          final pct = (m['percentage'] as num?)?.toInt() ?? 0;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                              child: avatar == null
                                  ? Text(uName[0].toUpperCase(), style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700))
                                  : null,
                            ),
                            title: Text(uName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('Đóng góp $pct%', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                            trailing: Text(
                              formatVnd(total),
                              style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
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
    final total = (contributor['totalContributed'] as num?)?.toInt() ?? (contributor['total'] as num?)?.toInt() ?? 0;

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
