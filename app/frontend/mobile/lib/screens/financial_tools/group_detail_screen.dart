import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/mimo_snackbar.dart';
import '../../services/transaction_notifier.dart';
import '../../widgets/notification_overlay.dart';
import '../../widgets/bill_processing_banner.dart';
import '../../routes/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../services/bill_processing_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic>? reviewExtra;

  const GroupDetailScreen({super.key, required this.groupId, this.reviewExtra});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late TabController _tabController;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _group;
  List<dynamic> _members = [];
  List<dynamic> _transactions = [];
  List<dynamic> _debts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGroupData();
    transactionNotifier.addListener(_loadGroupData);
  }

  @override
  void dispose() {
    transactionNotifier.removeListener(_loadGroupData);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final details = await _api.getExpenseGroupDetails(widget.groupId);
      _group = details['group'];
      _members = details['members'] ?? [];
      _transactions = (details['transactions'] as List<dynamic>? ?? [])
          .where((t) => t['processingStatus'] != 'processing')
          .toList();
      _debts = details['debts'] ?? [];
    } on ApiException catch (e) {
      _error = e.localizedMessage;
    } catch (_) {
      _error = 'Lỗi tải dữ liệu nhóm';
    }

    if (mounted) {
      setState(() => _loading = false);
      if (widget.reviewExtra?['reviewGroupBill'] == true) {
        final amount = widget.reviewExtra?['amount'];
        final note = widget.reviewExtra?['note'];
        final transactionId = widget.reviewExtra?['transactionId'];
        final paidBy = widget.reviewExtra?['paidBy'];
        // Pre-fill amount, note, paidBy and pass transactionId to update it
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAddTransaction(
            initialAmount: amount?.toString(),
            initialNote: note,
            initialPaidBy: paidBy?.toString(),
            transactionId: transactionId,
          );
        });
      }
    }
  }

  Future<String?> _showMemberPickerDialog() async {
    String? selectedMemberId = _members.isNotEmpty ? _members.first['id'] : null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Người thanh toán'),
        content: DropdownButtonFormField<String>(
          initialValue: selectedMemberId,
          decoration: const InputDecoration(
            labelText: 'Ai đã trả bill này?',
          ),
          items: _members.map((m) {
            return DropdownMenuItem<String>(
              value: m['id'],
              child: Text(m['display_name'] ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (val) {
            selectedMemberId = val;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, selectedMemberId),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }
  void _showAddManualMemberDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm thành viên thủ công', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Tên thành viên',
            hintText: 'Nhập tên...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _api.addManualGroupMember(widget.groupId, name);
                _loadGroupData();
                if (mounted) {
                  MimoSnackBar.show(context, message: 'Đã thêm thành viên mới', type: MimoSnackBarType.success);
                }
              } on ApiException catch (e) {
                if (mounted) {
                  MimoSnackBar.show(context, message: e.localizedMessage, type: MimoSnackBarType.error);
                }
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showAddTransaction({
    String? initialAmount,
    String? initialNote,
    String? initialPaidBy,
    String? transactionId,
  }) {
    // Format initial amount with thousands separators
    String initialFormattedAmount = '';
    if (initialAmount != null && initialAmount.isNotEmpty) {
      final digits = initialAmount.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        final formatter = MoneyTextInputFormatter();
        initialFormattedAmount = formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: digits),
        ).text;
      }
    }

    final amountCtrl = TextEditingController(text: initialFormattedAmount);
    final noteCtrl = TextEditingController(text: initialNote);
    final validIds = _members.map((m) => m['id']?.toString()).toSet();
    String? selectedMemberId;
    if (initialPaidBy != null && validIds.contains(initialPaidBy)) {
      selectedMemberId = initialPaidBy;
    } else if (_members.isNotEmpty) {
      selectedMemberId = _members.first['id']?.toString();
    }
    bool isSubmitting = false;
    bool isDeleting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    transactionId != null ? 'Chỉnh sửa giao dịch nhóm' : 'Thêm giao dịch nhóm',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (transactionId != null)
                    IconButton(
                      tooltip: 'Xóa giao dịch',
                      icon: isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger),
                            )
                          : const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      onPressed: (isSubmitting || isDeleting)
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Xóa giao dịch'),
                                  content: const Text('Bạn có chắc chắn muốn xóa giao dịch nhóm này không?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                setSheet(() => isDeleting = true);
                                try {
                                  await _api.deleteGroupTransaction(transactionId);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadGroupData();
                                  if (mounted) {
                                    MimoSnackBar.showSuccess(context, message: 'Đã xóa giao dịch nhóm');
                                  }
                                } on ApiException catch (e) {
                                  if (mounted) {
                                    MimoSnackBar.showError(context, message: e.localizedMessage);
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    MimoSnackBar.showError(context, message: 'Lỗi khi xóa giao dịch');
                                  }
                                } finally {
                                  if (ctx.mounted) setSheet(() => isDeleting = false);
                                }
                              }
                            },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  MoneyTextInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Số tiền',
                  suffixText: 'đ',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedMemberId,
                decoration: const InputDecoration(
                  labelText: 'Người thanh toán',
                ),
                items: _members.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['id']?.toString(),
                    child: Text(m['display_name'] ?? 'Thành viên'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setSheet(() => selectedMemberId = val);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (isSubmitting || isDeleting)
                      ? null
                      : () async {
                          final amountText = amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                          final amount = num.tryParse(amountText) ?? 0;
                          final note = noteCtrl.text.trim();

                          if (amount <= 0) {
                            MimoSnackBar.show(
                              context,
                              message: 'Vui lòng nhập số tiền',
                              type: MimoSnackBarType.error,
                            );
                            return;
                          }
                          if (selectedMemberId == null || selectedMemberId!.isEmpty) {
                            MimoSnackBar.show(
                              context,
                              message: 'Vui lòng chọn người thanh toán',
                              type: MimoSnackBarType.error,
                            );
                            return;
                          }
                          if (transactionId == null && note.isEmpty) {
                            MimoSnackBar.show(
                              context,
                              message: 'Vui lòng nhập đủ thông tin',
                              type: MimoSnackBarType.error,
                            );
                            return;
                          }

                          setSheet(() => isSubmitting = true);
                          try {
                            if (transactionId != null) {
                              await _api.updateGroupTransaction(
                                transactionId,
                                {
                                  'paidBy': selectedMemberId,
                                  'amount': amount,
                                  'note': note,
                                  'isDraft': false,
                                },
                              );
                            } else {
                              await _api.addGroupTransaction(
                                widget.groupId,
                                {
                                  'paidBy': selectedMemberId,
                                  'amount': amount,
                                  'note': note,
                                },
                              );
                            }
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            _loadGroupData();
                            if (mounted) {
                              MimoSnackBar.show(
                                context,
                                message: transactionId != null ? 'Đã cập nhật giao dịch' : 'Đã thêm giao dịch',
                                type: MimoSnackBarType.success,
                              );
                            }
                          } on ApiException catch (e) {
                            if (mounted) {
                              MimoSnackBar.show(
                                context,
                                message: e.localizedMessage,
                                type: MimoSnackBarType.error,
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              MimoSnackBar.show(
                                context,
                                message: 'Lỗi lưu giao dịch. Vui lòng thử lại.',
                                type: MimoSnackBarType.error,
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setSheet(() => isSubmitting = false);
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(transactionId != null ? 'Cập nhật' : 'Lưu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.document_scanner_rounded, color: AppColors.teal),
                ),
                title: const Text('Quét hóa đơn (OCR)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Tự động bóc tách từ ảnh'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final imagePath = await context.push<String>(
                    AppRoutes.camera,
                    extra: {
                      'groupId': widget.groupId,
                      'initialMode': 'Bill',
                      'returnOnlyImagePath': true,
                    },
                  );
                  if (imagePath != null && mounted) {
                    final memberId = await _showMemberPickerDialog();
                    if (memberId != null && mounted) {
                      BillProcessingService.instance.submitGroupBill(
                        groupId: widget.groupId,
                        imagePath: imagePath,
                        paidBy: memberId,
                      );
                      MimoSnackBar.showSuccess(
                        context,
                        message: 'Đã gửi hóa đơn nhóm! Đang phân tích ngầm...',
                      );
                    }
                  }
                },
              ),
              const Divider(height: 1, indent: 64),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: AppColors.teal),
                ),
                title: const Text('Thêm thủ công', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Tự nhập thông tin giao dịch'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddTransaction();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeMember(String memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa thành viên'),
        content: const Text('Bạn có chắc chắn muốn xóa thành viên này khỏi nhóm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Xóa')
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _api.removeGroupMember(widget.groupId, memberId);
        _loadGroupData();
        if (mounted) {
          MimoSnackBar.showSuccess(context, message: 'Đã xóa thành viên');
        }
      } on ApiException catch (e) {
        if (mounted) {
          MimoSnackBar.showError(context, message: e.localizedMessage);
        }
      }
    }
  }

  void _calculateDebts() async {
    try {
      await _api.splitGroupBills(widget.groupId);
      _loadGroupData();
      if (mounted) {
        MimoSnackBar.show(context, message: 'Đã tính toán xong công nợ', type: MimoSnackBarType.success);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      MimoSnackBar.show(context, message: e.localizedMessage, type: MimoSnackBarType.error);
    }
  }

  void _settleDebt(String debtId) async {
    try {
      await _api.settleGroupDebt(widget.groupId, debtId);
      _loadGroupData();
      if (mounted) {
        MimoSnackBar.show(context, message: 'Đã xác nhận thanh toán', type: MimoSnackBarType.success);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      MimoSnackBar.show(context, message: e.localizedMessage, type: MimoSnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _group == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _group == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(child: ErrorBanner(message: _error!, onRetry: _loadGroupData)),
      );
    }

    final topInset = MediaQuery.of(context).padding.top;
    final billJobs = BillProcessingService.instance.activeJobs;
    final hasInAppNotification = inAppNotificationController.current != null;
    final billBannerTop = topInset + 12 + (hasInAppNotification ? 92 : 0);

    return Scaffold(
      backgroundColor: context.palette.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _GroupDetailHeader(
                groupName: _group?['name'] ?? 'Chi tiết nhóm',
                inviteCode: _group?['invite_code'] ?? '',
                tabController: _tabController,
                onAddManualMember: _showAddManualMemberDialog,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMembersTab(),
                    _buildTransactionsTab(),
                  ],
                ),
              ),
            ],
          ),
          if (billJobs.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: billBannerTop,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: billJobs.map((job) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BillProcessingBanner(
                            job: job,
                            onDismiss: job.phase == BillJobPhase.failed
                                ? () => BillProcessingService.instance
                                      .dismissJob(job.transactionId)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ListenableBuilder(
            listenable: inAppNotificationController,
            builder: (context, _) {
              final notif = inAppNotificationController.current;
              if (notif == null) return const SizedBox.shrink();
              return Positioned(
                top: topInset + 12,
                left: 16,
                right: 16,
                child: InAppNotificationBanner(
                  notification: notif,
                  onDismiss: inAppNotificationController.dismiss,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  Widget _buildMembersTab() {
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Thành viên (${_members.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                TextButton.icon(
                  onPressed: _calculateDebts,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.teal,
                  ),
                  icon: const Icon(Icons.calculate_rounded),
                  label: const Text('Tính nợ', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          ..._members.map((m) {
            final totalPaid = _transactions
                .where((tx) => tx['paid_by'] == m['id'])
                .fold(0.0, (sum, tx) => sum + (num.tryParse(tx['amount'].toString()) ?? 0));
                
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.teal.withValues(alpha: 0.2),
                    child: Text(
                      m['display_name'].toString().isNotEmpty ? m['display_name'][0].toUpperCase() : '?', 
                      style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600, fontSize: 22)
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['display_name'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Đã chi: ${formatVnd(parseToInt(totalPaid))}', style: TextStyle(color: context.palette.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    tooltip: 'Xóa thành viên',
                    onPressed: () => _removeMember(m['id']),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Công nợ cần thanh toán',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ),
          const SizedBox(height: 16),
          if (_debts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Chưa có khoản nợ nào cần thanh toán.')),
            )
          else
            ..._debts.map((d) {
              final isSettled = d['status'] == 'settled';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: context.palette.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(color: context.palette.textPrimary, fontSize: 15),
                              children: [
                                TextSpan(text: d['from_member_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                const TextSpan(text: ' cần trả '),
                                TextSpan(text: d['to_member_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatVnd(parseToInt(d['amount'])),
                            style: TextStyle(
                              color: isSettled ? context.palette.textSecondary : AppColors.danger,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              decoration: isSettled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isSettled)
                      OutlinedButton(
                        onPressed: () => _settleDebt(d['id']),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          side: const BorderSide(color: AppColors.teal),
                          foregroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                        child: const Text('Đã trả'),
                      )
                    else
                      const Icon(Icons.check_circle_rounded, color: Colors.green),
                  ],
                ),
              ),
            );
            }),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return const Center(child: Text('Chưa có giao dịch nào trong nhóm.'));
    }
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
        itemCount: _transactions.length,
        itemBuilder: (ctx, index) {
          final tx = _transactions[index];
          return Card(
            elevation: 0,
            color: context.palette.bg,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              onTap: () {
                _showAddTransaction(
                  initialAmount: tx['amount']?.toString(),
                  initialNote: tx['note']?.toString(),
                  initialPaidBy: tx['paid_by']?.toString() ?? tx['paid_by_id']?.toString(),
                  transactionId: tx['id']?.toString(),
                );
              },
              leading: CircleAvatar(
                backgroundColor: AppColors.teal.withValues(alpha: 0.1),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.teal),
              ),
              title: Text(
                tx['note'] != null && tx['note'].toString().trim().isNotEmpty
                    ? tx['note']
                    : 'Giao dịch không tên',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${tx['paid_by_name'] ?? 'Thành viên'} trả • ${formatDateTimeFull(parseToLocalDateTime(tx['occurred_at']) ?? DateTime.now())}',
                style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatVnd(parseToInt(tx['amount'])),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GroupDetailHeader extends StatelessWidget {
  final String groupName;
  final String inviteCode;
  final TabController tabController;
  final VoidCallback onAddManualMember;

  const _GroupDetailHeader({
    required this.groupName,
    required this.inviteCode,
    required this.tabController,
    required this.onAddManualMember,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                if (Navigator.canPop(context))
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
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
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
                        'Chi tiết nhóm & giao dịch',
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
                Tooltip(
                  message: 'Thêm thủ công',
                  child: GestureDetector(
                    onTap: onAddManualMember,
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Mã tham gia',
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
                        ),
                        builder: (ctx) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Mã tham gia nhóm',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(AppRadii.lg),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    inviteCode,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4,
                                      color: AppColors.teal,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.teal,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: inviteCode));
                                      Navigator.pop(ctx);
                                      MimoSnackBar.showSuccess(context, message: 'Đã copy mã mời: $inviteCode');
                                    },
                                    icon: const Icon(Icons.copy_rounded),
                                    label: const Text('Sao chép mã', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            dividerColor: Colors.transparent,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Thành viên & Nợ'),
              Tab(text: 'Giao dịch'),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

