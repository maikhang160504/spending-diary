import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'goal_detail_screen.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/mimo_overlay.dart';
import '../../widgets/premium_upsell_bottom_sheet.dart';
import '../../widgets/mimo_snackbar.dart';

class GoalScreen extends StatefulWidget {
  final bool isChallenge;
  final String? initialJoinCode;
  const GoalScreen({
    super.key,
    this.isChallenge = false,
    this.initialJoinCode,
  });

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _api = ApiClient();
  List<dynamic> _goals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    if (widget.initialJoinCode != null && widget.initialJoinCode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showJoinGoal(initialCode: widget.initialJoinCode);
      });
    }
  }

  Future<void> _loadGoals() async {
    setState(() { _loading = true; _error = null; });
    try {
      final type = widget.isChallenge ? 'challenge' : 'personal';
      final goalResult = await _api.getGoals(type);
      _goals = goalResult.where((g) {
        final gType = g['type']?.toString() ?? 'personal';
        final isChallengeGoal = gType.startsWith('challenge');
        if (widget.isChallenge) return isChallengeGoal;
        return !isChallengeGoal;
      }).toList();
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
    bool isGroup = false;
    DateTime? deadlineDate;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.isChallenge ? 'Tạo thử thách mới' : 'Tạo khoản tiết kiệm mới', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text('Loại mục tiêu:', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSheet(() => isGroup = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isGroup ? AppColors.teal.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: !isGroup ? AppColors.teal : context.palette.border),
                        ),
                        alignment: Alignment.center,
                        child: Text('👤 Cá nhân', style: TextStyle(fontWeight: !isGroup ? FontWeight.w700 : FontWeight.normal, color: !isGroup ? AppColors.teal : context.palette.textPrimary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSheet(() => isGroup = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isGroup ? AppColors.teal.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: isGroup ? AppColors.teal : context.palette.border),
                        ),
                        alignment: Alignment.center,
                        child: Text('👥 Nhóm (Có mã mời)', style: TextStyle(fontWeight: isGroup ? FontWeight.w700 : FontWeight.normal, color: isGroup ? AppColors.teal : context.palette.textPrimary)),
                      ),
                    ),
                  ),
                ],
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
              TextField(
                controller: nameCtrl,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Tên mục tiêu', hintText: 'VD: Mua iPhone', counterText: ''),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyTextInputFormatter()],
                decoration: const InputDecoration(labelText: 'Số tiền mục tiêu', hintText: 'VD: 25,000,000', suffixText: 'đ'),
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
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên mục tiêu'), backgroundColor: AppColors.danger));
                            return;
                          }
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số tiền mục tiêu phải lớn hơn 0'), backgroundColor: AppColors.danger));
                            return;
                          }
                          if (amount > 100000000000) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số tiền tối đa 100 tỷ đồng'), backgroundColor: AppColors.danger));
                            return;
                          }
                          setSheet(() { isSubmitting = true; });
                          ctx.pop();
                          String? deadlineStr;
                          if (deadlineDate != null) {
                            deadlineStr = '${deadlineDate!.year}-${deadlineDate!.month.toString().padLeft(2, '0')}-${deadlineDate!.day.toString().padLeft(2, '0')}';
                          }
                          try {
                            final created = await _api.createGoal({
                              'name': name,
                              'targetAmount': amount,
                              'emoji': emoji,
                              'walletId': null,
                              'isGroup': isGroup,
                              'type': isGroup
                                  ? (widget.isChallenge ? 'challenge_group' : 'saving_group')
                                  : (widget.isChallenge ? 'challenge' : 'personal'),
                              'deadline': deadlineStr,
                            });
                            await _loadGoals();
                            final celebMsg = widget.isChallenge
                                ? 'Xuất sắc! Thử thách "$name" đã khởi tạo, quyết tâm đạt mục tiêu nhé!'
                                : 'Quỹ tiết kiệm "$name" đã sẵn sàng! Cùng tích lũy từng ngày nha!';
                            mimoController.show(MiMoResponse(
                              emotionAsset: 'Celebrate',
                              message: celebMsg,
                            ));
                            if (isGroup && created['id'] != null) {
                              if (mounted) {
                                _showInviteGoal(created['id'].toString(), name);
                              }
                            }
                          } on ApiException catch (e) {
                            if (e.message.contains('PREMIUM_REQUIRED_GOAL_LIMIT')) {
                              if (mounted) {
                                showPremiumUpsellSheet(context);
                              }
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.localizedMessage), backgroundColor: AppColors.danger),
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Không thể tạo mục tiêu mới'), backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Tạo mục tiêu'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGoal(String goalId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Xóa mục tiêu?'),
            content: const Text('Thao tác này không thể hoàn tác.'),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => ctx.pop(false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        setDialogState(() { isSubmitting = true; });
                        ctx.pop(true);
                      },
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    try {
      await _api.deleteGoal(goalId);
      _loadGoals();
    } catch (_) {}
  }

  void _showContribute(String goalId, String goalName) {
    final amountCtrl = TextEditingController();
    bool isSubmitting = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Thêm tiền vào "$goalName"', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [MoneyTextInputFormatter()],
                decoration: const InputDecoration(labelText: 'Số tiền', hintText: 'VD: 500,000', suffixText: 'đ'),
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
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số tiền phải lớn hơn 0'), backgroundColor: AppColors.danger));
                            return;
                          }
                          if (amount > 100000000000) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số tiền tối đa 100 tỷ đồng'), backgroundColor: AppColors.danger));
                            return;
                          }
                          setSheetState(() { isSubmitting = true; });
                          ctx.pop();
                          try {
                            await _api.contributeGoal(goalId, amount);
                            if (!mounted) return;
                            _loadGoals();
                            if (mounted) {
                              MimoSnackBar.showSuccess(
                                context,
                                message: 'Đã nạp ${formatVnd(amount.toInt())} vào "$goalName" thành công!',
                                emotion: 'Celebrate',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              MimoSnackBar.showError(
                                context,
                                message: 'Thất bại: $e',
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Thêm tiền'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showJoinGoal({String? initialCode}) {
    final codeCtrl = TextEditingController(text: initialCode ?? '');
    bool isSubmitting = false;
    String? errorMsg;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.isChallenge ? 'Nhập mã tham gia thử thách' : 'Nhập mã tham gia nhóm tiết kiệm', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Mã mời (6 ký tự)',
                  hintText: 'VD: A1B2C3',
                  errorText: errorMsg,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = codeCtrl.text.trim();
                          if (code.isEmpty) return;
                          setSheetState(() { isSubmitting = true; errorMsg = null; });
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          try {
                            await _api.joinGoal(code);
                            if (!mounted) return;
                            if (ctx.mounted) ctx.pop();
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text(widget.isChallenge ? '🎉 Tham gia thử thách thành công!' : '🎉 Tham gia nhóm tiết kiệm thành công!'), backgroundColor: AppColors.teal),
                            );
                            _loadGoals();
                          } on ApiException catch (e) {
                            if (e.message.contains('PREMIUM_REQUIRED_GOAL_LIMIT')) {
                              if (ctx.mounted) {
                                ctx.pop();
                                showPremiumUpsellSheet(context);
                              }
                            } else {
                              setSheetState(() {
                                isSubmitting = false;
                                errorMsg = e.localizedMessage;
                              });
                            }
                          } catch (e) {
                            setSheetState(() {
                              isSubmitting = false;
                              errorMsg = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Tham gia ngay'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showInviteGoal(String goalId, String goalName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Đang tạo mã mời...'),
          ],
        ),
      ),
    );
    String? code;
    try {
      code = await _api.inviteGoal(goalId);
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo mã mời: $e')),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final shareLink = 'spenddiary://app/goals?tab=challenge&code=$code';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
        elevation: 10,
        backgroundColor: context.palette.card,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.teal.withValues(alpha: 0.2), AppColors.teal.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, size: 40, color: AppColors.teal),
              ),
              const SizedBox(height: 16),
              Text(
                'Mời tham gia thử thách',
                style: TextStyle(color: context.palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                goalName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.teal, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Text(
                'MÃ MỜI THAM GIA',
                style: TextStyle(color: context.palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        code ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.palette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.teal),
                      tooltip: 'Copy mã',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép mã mời thử thách!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hoặc chia sẻ liên kết:',
                style: TextStyle(color: context.palette.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.palette.surfaceAlt.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: context.palette.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        shareLink,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.palette.textSecondary, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: shareLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép liên kết tham gia!')),
                        );
                      },
                      child: const Text('Copy link', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => ctx.pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                  ),
                  child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: RefreshIndicator(
              onRefresh: _loadGoals,
              color: AppColors.teal,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GoalHeader(
                      isChallenge: widget.isChallenge,
                      onAdd: _showCreateGoal,
                      onJoin: _showJoinGoal,
                    ),
                if (_error != null)
                  ErrorBanner(message: _error!, onRetry: _loadGoals),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: _loading
                      ? Column(children: List.generate(2, (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: SkeletonCard(height: 240),
                        )))
                      : _goals.isEmpty
                          ? EmptyState(
                              emoji: widget.isChallenge ? '🏆' : '🐷',
                              title: widget.isChallenge ? 'Chưa có thử thách nào' : 'Chưa có khoản tiết kiệm nào',
                              subtitle: widget.isChallenge
                                  ? 'Bắt đầu bằng cách tạo thử thách tiết kiệm cùng bạn bè'
                                  : 'Bắt đầu bằng cách tạo khoản tiết kiệm đầu tiên cho tương lai',
                              action: FilledButton(
                                onPressed: _showCreateGoal,
                                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                                child: Text(widget.isChallenge ? 'Tạo thử thách' : 'Tạo tiết kiệm'),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final w = constraints.maxWidth;
                                final isWide = w >= 600;
                                final columns = w > 900 ? 3 : (isWide ? 2 : 1);
                                final cardWidth = columns == 1 ? w : (w - (columns - 1) * 16) / columns;

                                return Column(
                                  children: [
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: _goals.map((g) => SizedBox(
                                        width: cardWidth,
                                        child: _ApiGoalCard(
                                          goal: g,
                                          onContribute: () => _showContribute(g['id'] as String, g['name'] as String),
                                          onDelete: () => _deleteGoal(g['id'] as String),
                                          onInvite: (widget.isChallenge || g['type'] == 'saving_group' || g['type'] == 'challenge_group' || g['inviteCode'] != null)
                                              ? () => _showInviteGoal(g['id'] as String, g['name'] as String)
                                              : null,
                                          onTap: () async {
                                            final reload = await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: g['id'] as String)),
                                            );
                                            if (reload == true) _loadGoals();
                                          },
                                        ),
                                      )).toList(),
                                    ),
                                    const SizedBox(height: 16),
                                    // Footer pill add button
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _showCreateGoal,
                                        icon: const Icon(Icons.add_circle_outline, size: 20),
                                        label: Text(widget.isChallenge ? '+ Thêm thử thách mới' : '+ Thêm khoản tiết kiệm mới'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.teal,
                                          side: BorderSide(color: AppColors.teal.withValues(alpha: 0.5), width: 1.5),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _GoalHeader extends StatelessWidget {
  final bool isChallenge;
  final VoidCallback onAdd;
  final VoidCallback? onJoin;
  const _GoalHeader({required this.onAdd, this.onJoin, this.isChallenge = false});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadii.xl)),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 16 + topPadding, 20, 24),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isChallenge ? 'Thử thách' : 'Tiết kiệm',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  isChallenge
                      ? 'Tiết kiệm cùng bạn bè với thử thách chung'
                      : 'Tạo mục tiêu tiết kiệm và theo dõi tiến độ của bạn',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onJoin != null) ...[
            Tooltip(
              message: 'Nhập mã mời',
              child: GestureDetector(
                onTap: onJoin,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_add_outlined, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Tooltip(
            message: 'Tạo mới',
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Goal Card ────────────────────────────────────────────────────────────────

class _ApiGoalCard extends StatelessWidget {
  final dynamic goal;
  final VoidCallback onContribute;
  final VoidCallback onDelete;
  final VoidCallback? onInvite;
  final VoidCallback onTap;

  const _ApiGoalCard({
    required this.goal,
    required this.onContribute,
    required this.onDelete,
    this.onInvite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isChallenge = goal['type']?.toString().startsWith('challenge') == true;
    final targetAmountVal = goal['target_amount'] ?? goal['targetAmount'];
    final memberAmountVal = goal['member_current_amount'] ?? goal['memberCurrentAmount'];
    final currentAmountVal = isChallenge
        ? (memberAmountVal ?? goal['current_amount'] ?? goal['currentAmount'])
        : (goal['current_amount'] ?? goal['currentAmount']);
    final targetAmount = num.tryParse(targetAmountVal?.toString() ?? '')?.toInt() ?? 0;
    final currentAmount = num.tryParse(currentAmountVal?.toString() ?? '')?.toInt() ?? 0;
    final remaining = targetAmount - currentAmount;
    final percent = targetAmount > 0 ? currentAmount / targetAmount : 0.0;
    final emoji = goal['emoji'] as String? ?? '🎯';
    final name = goal['name'] as String? ?? 'Mục tiêu';
    final status = isChallenge
        ? (goal['member_status'] ?? goal['status'] ?? 'active')
        : (goal['status'] as String? ?? 'active');
    final isCompleted = status == 'completed' || percent >= 1.0;
    final isNearGoal = percent >= 0.8 && !isCompleted;

    // Color follows completion state
    final progressColor = isCompleted
        ? const Color(0xFF10B981)
        : isNearGoal
            ? const Color(0xFFF59E0B)
            : AppColors.teal;
    final progressEndColor = isCompleted
        ? const Color(0xFF34D399)
        : isNearGoal
            ? const Color(0xFFFBBF24)
            : const Color(0xFF0ED2F7);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: context.palette.cardShadow,
          border: isCompleted
              ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5)
              : isNearGoal
                  ? Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5)
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ───────────────────────────────────────────────
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      progressColor.withValues(alpha: 0.2),
                      progressColor.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Delete button
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                // Status badge
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('🎉 Hoàn thành!', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700)),
                  )
                else if (isNearGoal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('🔥 Gần đến nơi!', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w700)),
                  )
                else
                  Text(
                    'Mục tiêu: ${formatVnd(targetAmount)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
                  ),
              ])),
            ]),

            const SizedBox(height: 20),

            // ── Progress header ─────────────────────────────────────────
            Row(children: [
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: progressColor, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${formatVnd(currentAmount)} / ${formatVnd(targetAmount)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary, fontSize: 11),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 8),

            // ── Gradient progress bar (12px thick) ───────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(height: 12, color: context.palette.surfaceAlt),
                  FractionallySizedBox(
                    widthFactor: percent.clamp(0.0, 1.0),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [progressColor, progressEndColor]),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: progressColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Savings info row ─────────────────────────────────────────
            Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Đã tiết kiệm', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(formatVnd(currentAmount), style: TextStyle(color: progressColor, fontWeight: FontWeight.w800, fontSize: 14)),
                ]),
              )),
              const SizedBox(width: 10),
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Còn thiếu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(formatVnd(remaining > 0 ? remaining : 0), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                ]),
              )),
            ]),

            // ── Contribute button ─────────────────────────────────────────
            if (!isCompleted) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onContribute,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Thêm tiến độ'),
                      style: FilledButton.styleFrom(
                        backgroundColor: progressColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (onInvite != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onInvite,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Mời'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        side: const BorderSide(color: AppColors.teal),
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}