import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/mimo_snackbar.dart';
import '../../widgets/skeleton.dart';
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
  }

  @override
  void dispose() {
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
      _transactions = details['transactions'] ?? [];
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
        // Note: paidBy might not be passed in reviewExtra from the backend right now unless we added it to `transaction_done` payload.
        // Wait, the backend _processGroupBillBackground DOES NOT send paidBy in transaction_done, but we can just let them pick again or default to the first one. Or we could pass it in. For now, just pre-fill amount and note.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAddTransaction(
            initialAmount: amount != null ? amount.toString() : null,
            initialNote: note,
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
          value: selectedMemberId,
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

  void _showAddTransaction({String? initialAmount, String? initialNote, String? initialPaidBy}) {
    final amountCtrl = TextEditingController(text: initialAmount);
    final noteCtrl = TextEditingController(text: initialNote);
    String? selectedMemberId = initialPaidBy ?? (_members.isNotEmpty ? _members.first['id'] : null);
    bool isSubmitting = false;

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
              Text(
                'Thêm giao dịch nhóm',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyTextInputFormatter()],
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
                value: selectedMemberId,
                decoration: const InputDecoration(
                  labelText: 'Người thanh toán',
                ),
                items: _members.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['id'],
                    child: Text(m['display_name'] ?? 'Unknown'),
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
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amountText = amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                          final amount = num.tryParse(amountText) ?? 0;
                          final note = noteCtrl.text.trim();

                          if (amount <= 0 || note.isEmpty) {
                            MimoSnackBar.show(
                              context,
                              message: 'Vui lòng nhập đủ thông tin',
                              type: MimoSnackBarType.error,
                            );
                            return;
                          }

                          setSheet(() => isSubmitting = true);
                          try {
                            await _api.addGroupTransaction(
                              widget.groupId,
                              {
                                'paidBy': selectedMemberId,
                                'amount': amount,
                                'note': note,
                              },
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadGroupData();
                              MimoSnackBar.show(
                                context,
                                message: 'Đã thêm giao dịch',
                                type: MimoSnackBarType.success,
                              );
                            }
                          } on ApiException catch (e) {
                            MimoSnackBar.show(
                              context,
                              message: e.localizedMessage,
                              type: MimoSnackBarType.error,
                            );
                            setSheet(() => isSubmitting = false);
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
                      : const Text('Lưu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _calculateDebts() async {
    try {
      await _api.splitGroupBills(widget.groupId);
      _loadGroupData();
      if (mounted) {
        MimoSnackBar.show(context, message: 'Đã tính toán xong công nợ', type: MimoSnackBarType.success);
      }
    } on ApiException catch (e) {
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

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        title: Text(_group?['name'] ?? 'Chi tiết nhóm'),
        backgroundColor: context.palette.bg,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Mã tham gia',
            onPressed: () {
              final code = _group?['invite_code'] ?? '';
              Clipboard.setData(ClipboardData(text: code));
              MimoSnackBar.show(context, message: 'Đã copy mã mời: $code', type: MimoSnackBarType.success);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.teal,
          tabs: const [
            Tab(text: 'Thành viên & Công nợ'),
            Tab(text: 'Giao dịch'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMembersTab(),
          _buildTransactionsTab(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'group_add_ocr',
            onPressed: () async {
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
                  // Wait for the bill processing service to do its job
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
            icon: const Icon(Icons.document_scanner_rounded),
            label: const Text('Quét OCR'),
            backgroundColor: AppColors.teal.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'group_add_tx',
            onPressed: _showAddTransaction,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm thủ công'),
            backgroundColor: AppColors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thành viên (${_members.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                onPressed: _calculateDebts,
                icon: const Icon(Icons.calculate_rounded),
                label: const Text('Tính nợ'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._members.map((m) {
            final totalPaid = _transactions
                .where((tx) => tx['paid_by'] == m['id'])
                .fold(0.0, (sum, tx) => sum + (num.tryParse(tx['amount'].toString()) ?? 0));
                
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.teal.withValues(alpha: 0.2),
                child: Text(
                  m['display_name'].toString().isNotEmpty ? m['display_name'][0].toUpperCase() : '?', 
                  style: TextStyle(color: AppColors.teal)
                ),
              ),
              title: Text(m['display_name'] ?? 'Unknown'),
              subtitle: Text('Đã chi: ${formatVnd(parseToInt(totalPaid))}'),
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Công nợ cần thanh toán',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_debts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Chưa có khoản nợ nào cần thanh toán.')),
            )
          else
            ..._debts.map((d) {
              final isSettled = d['status'] == 'settled';
              return Card(
                elevation: 0,
                color: context.palette.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(color: context.palette.textPrimary),
                                children: [
                                  TextSpan(text: d['from_member_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const TextSpan(text: ' cần trả '),
                                  TextSpan(text: d['to_member_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatVnd(parseToInt(d['amount'])),
                              style: TextStyle(
                                color: isSettled ? Colors.grey : AppColors.danger,
                                fontWeight: FontWeight.bold,
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
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.teal.withValues(alpha: 0.1),
                child: Icon(Icons.receipt_long_rounded, color: AppColors.teal),
              ),
              title: Text(tx['note'] ?? 'Giao dịch'),
              subtitle: Text('${tx['paid_by_name']} trả • ${formatDateTimeFull(parseToLocalDateTime(tx['occurred_at']) ?? DateTime.now())}'),
              trailing: Text(
                formatVnd(parseToInt(tx['amount'])),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          );
        },
      ),
    );
  }
}
