import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../widgets/mimo_snackbar.dart';

class RecurringRulesScreen extends StatefulWidget {
  const RecurringRulesScreen({super.key});

  @override
  State<RecurringRulesScreen> createState() => _RecurringRulesScreenState();
}

class _RecurringRulesScreenState extends State<RecurringRulesScreen> {
  final _api = ApiClient();
  bool _loading = true;
  List<dynamic> _rules = [];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getRecurringRules();
      setState(() {
        _rules = data;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _toggleRuleActive(String id, bool currentValue) async {
    try {
      await _api.updateRecurringRule(id, {'isActive': !currentValue});
      // Update local state directly
      setState(() {
        final idx = _rules.indexWhere((r) => r['id'] == id);
        if (idx != -1) {
          _rules[idx]['isActive'] = !currentValue;
        }
      });
      if (mounted) {
        MimoSnackBar.showSuccess(
          context,
          message: !currentValue
              ? 'Đã bật tự động ghi nhận định kỳ ✓'
              : 'Đã tạm dừng quy tắc định kỳ',
        );
      }
    } catch (_) {
      if (mounted) {
        MimoSnackBar.showInfo(
          context,
          message: 'Không thể cập nhật trạng thái quy tắc',
        );
      }
    }
  }

  Future<void> _deleteRule(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa quy tắc giao dịch định kỳ này? Giao dịch tự động trong tương lai sẽ bị hủy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.deleteRecurringRule(id);
      setState(() {
        _rules.removeWhere((r) => r['id'] == id);
      });
      if (mounted) {
        MimoSnackBar.showSuccess(
          context,
          message: 'Đã xóa quy tắc định kỳ thành công ✓',
        );
      }
    } catch (_) {
      if (mounted) {
        MimoSnackBar.showInfo(
          context,
          message: 'Không thể xóa quy tắc định kỳ',
        );
      }
    }
  }

  void _openAddRuleSheet({Map<String, dynamic>? rule}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddRecurringRuleSheet(
        editRule: rule,
        onSaved: () {
          _loadRules();
        },
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      final datePart =
          '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
      final timePart =
          ' ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      return '$datePart$timePart';
    } catch (_) {
      return dateStr;
    }
  }

  String _translateFrequency(String freq) {
    switch (freq.toLowerCase()) {
      case 'daily':
        return 'Hàng ngày';
      case 'weekly':
        return 'Hàng tuần';
      case 'monthly':
        return 'Hàng tháng';
      default:
        return freq;
    }
  }

  Color _frequencyColor(String freq) {
    switch (freq.toLowerCase()) {
      case 'daily':
        return const Color(0xFF10B981);
      case 'weekly':
        return const Color(0xFF3B82F6);
      case 'monthly':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _rules
        .where((r) => (r['isActive'] as bool? ?? true))
        .length;

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        title: const Text(
          'Giao dịch định kỳ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.palette.textPrimary,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            )
          : _rules.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.teal.withValues(alpha: 0.22),
                            AppColors.teal.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sync_alt_rounded,
                        color: AppColors.teal,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Chưa có quy tắc định kỳ nào',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Thiết lập để Mimo tự động ghi chép các khoản thu chi lặp lại định kỳ như tiền nhà, lương, hóa đơn đúng hạn.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _openAddRuleSheet,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text(
                        'Thêm quy tắc đầu tiên',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _rules.length + 1,
              itemBuilder: (ctx, index) {
                if (index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.teal.withValues(alpha: 0.14),
                          AppColors.teal.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      border: Border.all(
                        color: AppColors.teal.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_mode_rounded,
                            color: AppColors.teal,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tự động ghi nhận thu chi',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hệ thống tự tạo giao dịch đúng ngày giờ đã đặt & gửi thông báo cho bạn.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: context.palette.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Đang hoạt động: $activeCount / ${_rules.length} quy tắc',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.teal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final rule = _rules[index - 1];
                final isExpense = rule['type'] == 'expense';
                final catCode = rule['categoryCode'] as String? ?? 'Other';
                final catStyle = CategoryTheme.of(catCode);
                final freq = rule['frequency'] as String;
                final isActive = rule['isActive'] as bool? ?? true;
                final walletName =
                    rule['walletName'] as String? ?? 'Ví cá nhân';

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 0,
                  color: context.palette.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    side: BorderSide(
                      color: isActive
                          ? AppColors.border.withValues(alpha: 0.6)
                          : AppColors.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _openAddRuleSheet(rule: rule),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Icon, Title + Wallet, Amount
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: catStyle.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: CategoryTheme.iconOf(
                                    catCode,
                                    size: 26,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rule['note'] != null &&
                                              rule['note'].toString().isNotEmpty
                                          ? rule['note'].toString()
                                          : catStyle.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: context.palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 13,
                                          color: context.palette.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '$walletName • ${catStyle.label}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  context.palette.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${isExpense ? '-' : '+'}${formatVnd((rule['amount'] as num).toInt())}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: isExpense
                                      ? AppColors.danger
                                      : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Row 2: Schedule & Next Occurrence Box
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: context.palette.bg.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.border.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _frequencyColor(
                                      freq,
                                    ).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.repeat_rounded,
                                        size: 13,
                                        color: _frequencyColor(freq),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _translateFrequency(freq),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _frequencyColor(freq),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: context.palette.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Kỳ tới: ${_formatDate(rule['nextOccurrence'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.palette.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: context.palette.border.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Row 3: Controls and Actions
                          Row(
                            children: [
                              Transform.scale(
                                scale: 0.85,
                                child: Switch(
                                  value: isActive,
                                  activeThumbColor: AppColors.teal,
                                  onChanged: (val) =>
                                      _toggleRuleActive(rule['id'], isActive),
                                ),
                              ),
                              Text(
                                isActive ? 'Tự động chạy' : 'Đã tạm dừng',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? AppColors.teal
                                      : context.palette.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _openAddRuleSheet(rule: rule),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 17,
                                  color: AppColors.teal,
                                ),
                                label: const Text(
                                  'Sửa',
                                  style: TextStyle(
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: () => _deleteRule(rule['id']),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: AppColors.danger,
                                ),
                                label: const Text(
                                  'Xóa',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddRuleSheet,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm quy tắc',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class AddRecurringRuleSheet extends StatefulWidget {
  final Map<String, dynamic>? editRule;
  final VoidCallback onSaved;

  const AddRecurringRuleSheet({
    super.key,
    this.editRule,
    required this.onSaved,
  });

  @override
  State<AddRecurringRuleSheet> createState() => _AddRecurringRuleSheetState();
}

class _AddRecurringRuleSheetState extends State<AddRecurringRuleSheet> {
  final _api = ApiClient();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _selectedType = 'expense';
  String _selectedFrequency = 'monthly';
  String? _selectedWalletId;
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now().add(
    const Duration(days: 1),
  ); // Default to tomorrow
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  List<dynamic> _wallets = [];
  bool _loadingWallets = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.editRule != null) {
      final r = widget.editRule!;
      final amt = r['amount'] as num?;
      if (amt != null) {
        _amountCtrl.text = amt.toInt().toString();
      }
      _noteCtrl.text = (r['note'] ?? '').toString();
      _selectedType = (r['type'] ?? 'expense').toString();
      _selectedFrequency = (r['frequency'] ?? 'monthly').toString();
      _selectedCategory = (r['categoryCode'] ?? 'Food').toString();
      _selectedWalletId = r['walletId'] as String?;
      if (r['nextOccurrence'] != null) {
        try {
          final dt = DateTime.parse(r['nextOccurrence'].toString()).toLocal();
          _selectedDate = dt;
          _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        } catch (_) {}
      }
    }
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final list = await _api.getWallets();
      if (mounted) {
        setState(() {
          _wallets = list; // All wallets including group wallets
          if (_selectedWalletId == null && _wallets.isNotEmpty) {
            _selectedWalletId = _wallets.first['id'] as String;
          }
          _loadingWallets = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingWallets = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final initial = _selectedDate.isBefore(now) ? now : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submit() async {
    final rawAmount = _amountCtrl.text;
    final amount = parseMoneyInput(rawAmount);

    if (amount == null || amount <= 0) {
      setState(
        () => _errorMessage = 'Vui lòng nhập số tiền hợp lệ (phải lớn hơn 0)',
      );
      return;
    }
    if (amount > 100000000000) {
      setState(() => _errorMessage = 'Số tiền tối đa 100 tỷ đồng');
      return;
    }

    if (_selectedWalletId == null) {
      setState(() => _errorMessage = 'Vui lòng chọn ví áp dụng');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final localDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final dateStr = localDateTime.toUtc().toIso8601String();
      final body = {
        'walletId': _selectedWalletId,
        'amount': amount,
        'type': _selectedType,
        'categoryCode': _selectedCategory,
        'note': _noteCtrl.text.trim(),
        'frequency': _selectedFrequency,
        'nextOccurrence': dateStr,
        if (widget.editRule == null) 'isActive': true,
      };

      if (widget.editRule != null) {
        await _api.updateRecurringRule(widget.editRule!['id'] as String, body);
      } else {
        await _api.createRecurringRule(body);
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        MimoSnackBar.showSuccess(
          context,
          message: widget.editRule != null
              ? 'Đã cập nhật quy tắc định kỳ thành công ✓'
              : 'Đã tạo quy tắc định kỳ thành công ✓',
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = e.localizedMessage;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _errorMessage = 'Không thể kết nối tới máy chủ';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
      decoration: BoxDecoration(
        color: context.palette.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.editRule != null
                        ? 'Chỉnh sửa giao dịch định kỳ'
                        : 'Tạo giao dịch định kỳ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.danger,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Toggle Loại giao dịch
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedType = 'expense';
                        // Switch default category if needed
                        _selectedCategory = 'Food';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedType == 'expense'
                              ? AppColors.danger.withValues(alpha: 0.1)
                              : context.palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(
                            color: _selectedType == 'expense'
                                ? AppColors.danger
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Chi tiêu',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _selectedType == 'expense'
                                  ? AppColors.danger
                                  : context.palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedType = 'income';
                        _selectedCategory = 'Salary';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedType == 'income'
                              ? AppColors.success.withValues(alpha: 0.1)
                              : context.palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(
                            color: _selectedType == 'income'
                                ? AppColors.success
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Thu nhập',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _selectedType == 'income'
                                  ? AppColors.success
                                  : context.palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Input Số tiền
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  MoneyTextInputFormatter(),
                ],
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                decoration: const InputDecoration(
                  labelText: 'Số tiền',
                  suffixText: 'đ',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 16),
              // Chọn Ví
              if (_loadingWallets)
                const SizedBox(
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.teal),
                  ),
                )
              else if (_wallets.isEmpty)
                const Text(
                  'Không tìm thấy ví. Hãy tạo ví trước.',
                  style: TextStyle(color: AppColors.danger),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedWalletId,
                  decoration: const InputDecoration(
                    labelText: 'Áp dụng cho Ví',
                  ),
                  dropdownColor: context.palette.card,
                  onChanged: (val) => setState(() => _selectedWalletId = val),
                  items: _wallets.map((w) {
                    final isGroup = w['type'] == 'group';
                    return DropdownMenuItem<String>(
                      value: w['id'] as String,
                      child: Row(
                        children: [
                          Icon(
                            isGroup
                                ? Icons.group_outlined
                                : Icons.account_balance_wallet,
                            color: AppColors.teal,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isGroup
                                ? '${w['name']} (Ví chung)'
                                : w['name'] as String,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              // Danh mục
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                dropdownColor: context.palette.card,
                onChanged: (val) =>
                    setState(() => _selectedCategory = val ?? 'Other'),
                items: CategoryTheme.primaryCodes
                    .where((code) {
                      final isInc = _selectedType == 'income';
                      // Lọc các danh mục tương ứng
                      if (isInc) {
                        return [
                          'Salary',
                          'Bonus',
                          'Business',
                          'Investment',
                          'Other',
                        ].contains(code);
                      } else {
                        return !['Salary', 'Bonus'].contains(code);
                      }
                    })
                    .map((code) {
                      final cat = CategoryTheme.of(code);
                      return DropdownMenuItem<String>(
                        value: code,
                        child: Row(
                          children: [
                            Text(cat.emoji),
                            const SizedBox(width: 8),
                            Text(cat.label),
                          ],
                        ),
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 16),
              // Input Ghi chú
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú / Tên hóa đơn',
                  hintText: 'Ví dụ: Tiền mạng internet, Lương cứng...',
                ),
              ),
              const SizedBox(height: 16),
              // Tần suất
              Text(
                'Tần suất lặp lại',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['daily', 'weekly', 'monthly'].map((freq) {
                  final isSelected = _selectedFrequency == freq;
                  String label = 'Hàng tháng';
                  if (freq == 'daily') label = 'Hàng ngày';
                  if (freq == 'weekly') label = 'Hàng tuần';

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFrequency = freq),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.teal.withValues(alpha: 0.1)
                              : context.palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.teal
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isSelected
                                  ? AppColors.teal
                                  : context.palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Chọn Ngày chạy đầu tiên
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_month,
                  color: AppColors.teal,
                ),
                title: const Text(
                  'Ngày bắt đầu phát sinh',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.teal,
                  ),
                ),
                trailing: TextButton(
                  onPressed: _selectDate,
                  child: const Text('Thay đổi'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.access_time_rounded,
                  color: AppColors.teal,
                ),
                title: const Text(
                  'Giờ chạy tự động',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.teal,
                  ),
                ),
                trailing: TextButton(
                  onPressed: _selectTime,
                  child: const Text('Thay đổi'),
                ),
              ),
              const SizedBox(height: 24),
              // Nút submit
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          widget.editRule != null
                              ? 'Lưu thay đổi'
                              : 'Tạo quy tắc định kỳ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
