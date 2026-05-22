import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';

/// Add Transaction Screen — /add (AT-01..AT-06)
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _api = ApiClient();

  String _selectedCategoryCode = 'Food';
  bool _isExpense = true;
  bool _saving = false;
  String? _error;

  // Amount as raw digits string
  String _amountRaw = '0';

  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Categories loaded from API (AT-03), fallback to const list
  List<_CategoryItem> _categories = const [
    _CategoryItem(emoji: '🍔', label: 'Ăn uống',   code: 'Food',          color: Color(0xFFEC4899)),
    _CategoryItem(emoji: '🛍️', label: 'Mua sắm',   code: 'Shopping',      color: Color(0xFF8B5CF6)),
    _CategoryItem(emoji: '🚗', label: 'Di chuyển',  code: 'Transport',     color: Color(0xFF3B82F6)),
    _CategoryItem(emoji: '🎬', label: 'Giải trí',   code: 'Entertainment', color: Color(0xFFF59E0B)),
    _CategoryItem(emoji: '🏠', label: 'Nhà ở',      code: 'Housing',       color: Color(0xFF10B981)),
    _CategoryItem(emoji: '💊', label: 'Sức khỏe',   code: 'Health',        color: Color(0xFFEF4444)),
    _CategoryItem(emoji: '📚', label: 'Học tập',    code: 'Education',     color: Color(0xFF6366F1)),
    _CategoryItem(emoji: '✈️', label: 'Du lịch',    code: 'Travel',        color: Color(0xFF14B8A6)),
    _CategoryItem(emoji: '💰', label: 'Khác',       code: 'Others',        color: Color(0xFF94A3B8)),
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.getCategories();
      if (!mounted || cats.isEmpty) return;
      setState(() {
        _categories = cats.map((c) {
          final code = c['code'] as String? ?? 'Others';
          final name = c['name'] as String? ?? code;
          final emoji = c['emoji'] as String? ?? '💰';
          return _CategoryItem(
            emoji: emoji,
            label: name,
            code: code,
            color: _codeToColor(code),
          );
        }).toList();
      });
    } catch (_) {}
  }

  Color _codeToColor(String code) {
    const map = {
      'Food': Color(0xFFEC4899),
      'Shopping': Color(0xFF8B5CF6),
      'Transport': Color(0xFF3B82F6),
      'Entertainment': Color(0xFFF59E0B),
      'Housing': Color(0xFF10B981),
      'Health': Color(0xFFEF4444),
      'Education': Color(0xFF6366F1),
      'Travel': Color(0xFF14B8A6),
      'Income': Color(0xFF22C55E),
    };
    return map[code] ?? const Color(0xFF94A3B8);
  }

  // AT-06: Comma-formatted display
  String get _amountFormatted {
    if (_amountRaw == '0') return '0';
    final n = int.tryParse(_amountRaw) ?? 0;
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - 1 - i;
      buf.write(s[fromEnd]);
      if ((i + 1) % 3 == 0 && i + 1 < s.length) buf.write('.');
    }
    return buf.toString().split('').reversed.join();
  }

  void _onNumKey(String key) {
    setState(() {
      if (key == '⌫') {
        if (_amountRaw.length > 1) {
          _amountRaw = _amountRaw.substring(0, _amountRaw.length - 1);
        } else {
          _amountRaw = '0';
        }
      } else if (key == '000') {
        if (_amountRaw != '0') _amountRaw += '000';
      } else if (_amountRaw == '0') {
        _amountRaw = key;
      } else {
        if (_amountRaw.length < 12) _amountRaw += key;
      }
    });
  }

  // AT-05: Date picker
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.teal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // AT-05: Time picker
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.teal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // AT-04: Save → POST /transactions
  Future<void> _save() async {
    final amount = int.tryParse(_amountRaw) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Vui lòng nhập số tiền hợp lệ');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final wallets = await _api.getWallets();
      if (wallets.isEmpty) throw Exception('Không có ví nào');
      final occurredAt = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      ).toIso8601String();

      await _api.createTransaction({
        'walletId': wallets[0]['id'],
        'amount': amount,
        'type': _isExpense ? 'expense' : 'income',
        'categoryCode': _selectedCategoryCode,
        'note': _noteController.text.trim(),
        'occurredAt': occurredAt,
        'source': 'manual',
      });
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = e.localizedMessage; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'Không thể lưu giao dịch'; });
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Hôm nay';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
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
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 28),
              child: Column(children: [
                Row(children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Thêm giao dịch', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.camera),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Row(children: [
                      Icon(Icons.camera_alt_outlined, size: 16),
                      SizedBox(width: 4),
                      Text('Chụp bill', style: TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                // Income / Expense Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.lg)),
                  child: Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _isExpense = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isExpense ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Center(child: Text('Chi tiêu', style: TextStyle(color: _isExpense ? AppColors.teal : Colors.white, fontWeight: FontWeight.w600))),
                      ),
                    )),
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _isExpense = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isExpense ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Center(child: Text('Thu nhập', style: TextStyle(color: !_isExpense ? AppColors.teal : Colors.white, fontWeight: FontWeight.w600))),
                      ),
                    )),
                  ]),
                ),
                const SizedBox(height: 20),
                // Amount display — AT-06 comma format
                Text(
                  '${_isExpense ? '-' : '+'} $_amountFormatted đ',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 40),
                ),
                Text('Nhập số tiền', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
              ]),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Error
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(AppRadii.md)),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Category picker — AT-03 from API
                  Text('Danh mục', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategoryCode == cat.code;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedCategoryCode = cat.code;
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? cat.color.withValues(alpha: 0.12) : Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: isSelected ? cat.color : AppColors.border),
                            boxShadow: isSelected ? null : const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            CategoryTheme.iconOf(cat.code, size: 26),
                            const SizedBox(height: 4),
                            Text(cat.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isSelected ? cat.color : AppColors.textSecondary),
                                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Date & time — AT-05 picker
                  Text('Thời gian', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined, color: AppColors.teal, size: 18),
                          const SizedBox(width: 8),
                          Text(_formatDate(_selectedDate), style: Theme.of(context).textTheme.bodyMedium),
                        ]),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          const Icon(Icons.access_time, color: AppColors.teal, size: 18),
                          const SizedBox(width: 8),
                          Text('${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ]),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 20),
                  // Note
                  Text('Ghi chú', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Thêm ghi chú cho giao dịch này...', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 20),
                  // Photo button
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.camera),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.camera_alt_outlined, color: AppColors.teal, size: 20),
                        const SizedBox(width: 8),
                        Text('Thêm ảnh hoặc bill', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Save button — AT-04
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Lưu giao dịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
            // Numpad
            _NumPad(onKeyTap: _onNumKey),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem {
  final String emoji, label, code;
  final Color color;
  const _CategoryItem({required this.emoji, required this.label, required this.code, required this.color});
}

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  const _NumPad({required this.onKeyTap});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '000', '0', '⌫'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        children: keys.map((k) => GestureDetector(
          onTap: () => onKeyTap(k),
          child: Container(
            decoration: BoxDecoration(
              color: k == '⌫' ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Center(
              child: k == '⌫'
                  ? const Icon(Icons.backspace_outlined, color: AppColors.danger, size: 20)
                  : Text(k, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
        )).toList(),
      ),
    );
  }
}
