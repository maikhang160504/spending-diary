import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../utils/formatters.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateWalletScreen(),
    );
  }

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();

  String _walletType = 'personal'; // personal | group
  String _selectedIcon = '💼';
  String _selectedColor = '#14B8A6'; // Hex format
  bool _loading = false;
  String? _error;

  final List<String> _icons = ['💼', '🏠', '🛒', '🚗', '🍔', '🎮', '✈️', '❤️', '💡', '🎓', '🏥', '🌟'];
  final List<String> _colors = [
    '#14B8A6', // Teal
    '#0F766E', // Teal Dark
    '#3B82F6', // Blue
    '#EF4444', // Red
    '#F59E0B', // Amber
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#64748B', // Slate
  ];

  Color _parseHex(String hex) {
    final str = hex.replaceAll('#', '');
    if (str.length == 6) {
      return Color(int.parse('FF$str', radix: 16));
    }
    return AppColors.teal;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final rawBalance = _balanceCtrl.text.replaceAll(',', '').trim();
    final balance = int.tryParse(rawBalance) ?? 0;

    try {
      final res = await _api.createWallet({
        'name': _nameCtrl.text.trim(),
        'type': _walletType,
        'currency': 'VND',
        'icon': _selectedIcon,
        'color': _selectedColor,
        'balance': balance,
      });
      if (mounted) {
        context.pop(res);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.localizedMessage);
    } catch (_) {
      setState(() => _error = 'Không thể tạo ví, vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      key: const ValueKey('create_wallet_bottom_sheet'),
      child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tạo ví mới',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => context.pop(),
                      color: palette.muted,
                    )
                  ],
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Wallet Name Field
                Text(
                  'Tên ví',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'VD: Ví chi tiêu nhóm, Quỹ du lịch...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: TextStyle(color: palette.textPrimary),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên ví';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Wallet Type Selection
                Text(
                  'Loại ví',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _walletType = 'personal'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _walletType == 'personal'
                                ? AppColors.teal.withValues(alpha: 0.1)
                                : palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(
                              color: _walletType == 'personal'
                                  ? AppColors.teal
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: _walletType == 'personal'
                                    ? AppColors.teal
                                    : palette.textSecondary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cá nhân',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _walletType == 'personal'
                                      ? AppColors.teal
                                      : palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _walletType = 'group'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _walletType == 'group'
                                ? AppColors.teal.withValues(alpha: 0.1)
                                : palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(
                              color: _walletType == 'group'
                                  ? AppColors.teal
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.group_outlined,
                                color: _walletType == 'group'
                                    ? AppColors.teal
                                    : palette.textSecondary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ví chung (Nhóm)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _walletType == 'group'
                                      ? AppColors.teal
                                      : palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Initial Balance Field
                Text(
                  'Số dư ban đầu (tùy chọn)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _balanceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyTextInputFormatter()],
                  decoration: const InputDecoration(
                    hintText: 'VD: 1,000,000',
                    suffixText: 'đ',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: TextStyle(color: palette.textPrimary),
                ),
                const SizedBox(height: 16),

                // Wallet Color Selection
                Text(
                  'Màu sắc',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _colors.length,
                    itemBuilder: (context, index) {
                      final hex = _colors[index];
                      final color = _parseHex(hex);
                      final isSelected = _selectedColor == hex;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = hex),
                        child: Container(
                          width: 40,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: palette.textPrimary, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Wallet Icon Selection
                Text(
                  'Biểu tượng',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _icons.length,
                    itemBuilder: (context, index) {
                      final emoji = _icons[index];
                      final isSelected = _selectedIcon == emoji;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = emoji),
                        child: Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.teal.withValues(alpha: 0.15)
                                : palette.surfaceAlt,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: AppColors.teal, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Tạo ví',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
