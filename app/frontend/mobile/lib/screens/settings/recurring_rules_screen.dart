import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';

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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể cập nhật trạng thái quy tắc')),
        );
      }
    }
  }

  Future<void> _deleteRule(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa quy tắc giao dịch định kỳ này? Giao dịch tự động trong tương lai sẽ bị hủy.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa quy tắc định kỳ thành công ✓'),
            backgroundColor: AppColors.teal,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa quy tắc định kỳ')),
        );
      }
    }
  }

  void _openAddRuleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddRecurringRuleSheet(
        onSaved: () {
          _loadRules();
        },
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
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
    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        title: const Text('Giao dịch định kỳ', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.palette.textPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sync_alt, color: AppColors.teal, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có quy tắc định kỳ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Tạo quy tắc tự động ghi nhận các khoản thu chi cố định như tiền nhà, tiền lương, hóa đơn hàng tháng...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _openAddRuleSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm quy tắc đầu tiên'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  itemCount: _rules.length,
                  itemBuilder: (ctx, index) {
                    final rule = _rules[index];
                    final isExpense = rule['type'] == 'expense';
                    final catCode = rule['categoryCode'] as String? ?? 'Other';
                    final catStyle = CategoryTheme.of(catCode);
                    final freq = rule['frequency'] as String;
                    final isActive = rule['isActive'] as bool? ?? true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      elevation: 0,
                      color: context.palette.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: catStyle.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadii.md),
                              ),
                              child: Center(child: CategoryTheme.iconOf(catCode, size: 24)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          rule['note'] != null && rule['note'].toString().isNotEmpty
                                              ? rule['note']
                                              : catStyle.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${isExpense ? '-' : '+'}${formatVnd((rule['amount'] as num).toInt())}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: isExpense ? AppColors.danger : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _frequencyColor(freq).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _translateFrequency(freq),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: _frequencyColor(freq),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(Icons.calendar_month, size: 12, color: AppColors.muted),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Kỳ tới: ${_formatDate(rule['nextOccurrence'])}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isActive,
                              activeThumbColor: AppColors.teal,
                              onChanged: (val) => _toggleRuleActive(rule['id'], isActive),
                            ),
                            IconButton(
                              onPressed: () => _deleteRule(rule['id']),
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _rules.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _openAddRuleSheet,
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add),
            ),
    );
  }
}

class AddRecurringRuleSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const AddRecurringRuleSheet({super.key, required this.onSaved});

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
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1)); // Default to tomorrow

  List<dynamic> _wallets = [];
  bool _loadingWallets = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final list = await _api.getWallets();
      if (mounted) {
        setState(() {
          _wallets = list; // All wallets including group wallets
          if (_wallets.isNotEmpty) {
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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

  Future<void> _submit() async {
    final rawAmount = _amountCtrl.text;
    final amount = parseMoneyInput(rawAmount);

    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Vui lòng nhập số tiền hợp lệ');
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
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      await _api.createRecurringRule({
        'walletId': _selectedWalletId,
        'amount': amount,
        'type': _selectedType,
        'categoryCode': _selectedCategory,
        'note': _noteCtrl.text.trim(),
        'frequency': _selectedFrequency,
        'nextOccurrence': dateStr,
        'isActive': true,
      });

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo quy tắc định kỳ thành công ✓'),
            backgroundColor: AppColors.teal,
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: context.palette.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
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
                'Tạo giao dịch định kỳ',
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w500),
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
                        color: _selectedType == 'expense' ? AppColors.danger : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Chi tiêu',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _selectedType == 'expense' ? AppColors.danger : AppColors.textSecondary,
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
                        color: _selectedType == 'income' ? AppColors.success : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Thu nhập',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _selectedType == 'income' ? AppColors.success : AppColors.textSecondary,
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
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Số tiền',
              suffixText: 'đ',
              hintText: '0',
            ),
          ),
          const SizedBox(height: 16),
          // Chọn Ví
          if (_loadingWallets)
            const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: AppColors.teal)))
          else if (_wallets.isEmpty)
            const Text('Không tìm thấy ví. Hãy tạo ví trước.', style: TextStyle(color: AppColors.danger))
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedWalletId,
              decoration: const InputDecoration(labelText: 'Áp dụng cho Ví'),
              dropdownColor: context.palette.card,
              onChanged: (val) => setState(() => _selectedWalletId = val),
              items: _wallets.map((w) {
                final isGroup = w['type'] == 'group';
                return DropdownMenuItem<String>(
                  value: w['id'] as String,
                  child: Row(
                    children: [
                      Icon(
                        isGroup ? Icons.group_outlined : Icons.account_balance_wallet,
                        color: AppColors.teal,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(isGroup ? '${w['name']} (Ví chung)' : w['name'] as String),
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
            onChanged: (val) => setState(() => _selectedCategory = val ?? 'Other'),
            items: CategoryTheme.primaryCodes.where((code) {
              final isInc = _selectedType == 'income';
              // Lọc các danh mục tương ứng
              if (isInc) {
                return ['Salary', 'Bonus', 'Business', 'Investment', 'Other'].contains(code);
              } else {
                return !['Salary', 'Bonus'].contains(code);
              }
            }).map((code) {
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
            }).toList(),
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
          const Text('Tần suất lặp lại', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
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
                      color: isSelected ? AppColors.teal.withValues(alpha: 0.1) : context.palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: isSelected ? AppColors.teal : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isSelected ? AppColors.teal : AppColors.textSecondary,
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
            leading: const Icon(Icons.calendar_month, color: AppColors.teal),
            title: const Text('Ngày bắt đầu phát sinh', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(
              '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.teal),
            ),
            trailing: TextButton(
              onPressed: _selectDate,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Tạo quy tắc định kỳ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
