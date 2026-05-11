import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// Add Transaction Screen - matches /add route
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  String _selectedCategory = 'Ăn uống';
  bool _isExpense = true;
  final _amountController = TextEditingController(text: '0');
  final _noteController = TextEditingController();

  final List<_CategoryItem> _categories = const [
    _CategoryItem(emoji: '🍔', label: 'Ăn uống', color: Color(0xFFEC4899)),
    _CategoryItem(emoji: '🛍️', label: 'Mua sắm', color: Color(0xFF8B5CF6)),
    _CategoryItem(emoji: '🚗', label: 'Di chuyển', color: Color(0xFF3B82F6)),
    _CategoryItem(emoji: '🎬', label: 'Giải trí', color: Color(0xFFF59E0B)),
    _CategoryItem(emoji: '🏠', label: 'Nhà ở', color: Color(0xFF10B981)),
    _CategoryItem(emoji: '💊', label: 'Sức khỏe', color: Color(0xFFEF4444)),
    _CategoryItem(emoji: '📚', label: 'Học tập', color: Color(0xFF6366F1)),
    _CategoryItem(emoji: '✈️', label: 'Du lịch', color: Color(0xFF14B8A6)),
    _CategoryItem(emoji: '💰', label: 'Khác', color: Color(0xFF94A3B8)),
  ];

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
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Thêm giao dịch', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.camera),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        child: Row(
                          children: const [
                            Icon(Icons.camera_alt_outlined, size: 16),
                            SizedBox(width: 4),
                            Text('Chụp bill', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Income / Expense Toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isExpense = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isExpense ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadii.md),
                              ),
                              child: Center(
                                child: Text('Chi tiêu', style: TextStyle(
                                  color: _isExpense ? AppColors.teal : Colors.white,
                                  fontWeight: FontWeight.w600,
                                )),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isExpense = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isExpense ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadii.md),
                              ),
                              child: Center(
                                child: Text('Thu nhập', style: TextStyle(
                                  color: !_isExpense ? AppColors.teal : Colors.white,
                                  fontWeight: FontWeight.w600,
                                )),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Amount display
                  Text(
                    '${_isExpense ? '-' : '+'} ${_amountController.text} đ',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 40,
                        ),
                  ),
                  Text('Nhập số tiền', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category picker
                    Text('Danh mục', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat.label;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat.label),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? cat.color.withValues(alpha: 0.12) : Colors.white,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(color: isSelected ? cat.color : AppColors.border),
                              boxShadow: isSelected ? null : const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(cat.emoji, style: const TextStyle(fontSize: 22)),
                                const SizedBox(height: 4),
                                Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? cat.color : AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Date & time
                    Text('Thời gian', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, color: AppColors.teal, size: 18),
                                const SizedBox(width: 8),
                                Text('Hôm nay', style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: AppColors.teal, size: 18),
                                const SizedBox(width: 8),
                                Text('08:30', style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Note
                    Text('Ghi chú', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Thêm ghi chú cho giao dịch này...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Photo button
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.camera),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_outlined, color: AppColors.teal, size: 20),
                            const SizedBox(width: 8),
                            Text('Thêm ảnh hoặc bill', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        ),
                        child: const Text('Lưu giao dịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Numpad
            _NumPad(onKeyTap: (key) {
              setState(() {
                if (key == '⌫') {
                  if (_amountController.text.length > 1) {
                    _amountController.text = _amountController.text.substring(0, _amountController.text.length - 1);
                  } else {
                    _amountController.text = '0';
                  }
                } else if (_amountController.text == '0') {
                  _amountController.text = key;
                } else {
                  _amountController.text += key;
                }
              });
            }),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem {
  final String emoji;
  final String label;
  final Color color;
  const _CategoryItem({required this.emoji, required this.label, required this.color});
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
