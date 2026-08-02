import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../utils/formatters.dart';
import '../../widgets/premium_upsell_bottom_sheet.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
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
      if (e.message.contains('PREMIUM_REQUIRED_WALLET_LIMIT')) {
        if (mounted) {
          context.pop(); // Đóng popup tạo ví
          showPremiumUpsellSheet(context);
        }
      } else {
        setState(() => _error = e.localizedMessage);
      }
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

  // Derive a gentle lighter color for the gradient end
  Color _lightVariant(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withSaturation((hsl.saturation * 0.7).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.18).clamp(0.0, 0.92))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accentColor = _parseHex(_selectedColor);
    final gradientEnd = _lightVariant(accentColor);
    final walletName = _nameCtrl.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      key: const ValueKey('create_wallet_bottom_sheet'),
      child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Live-preview header (màu ví làm gradient) ──────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, gradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // Wallet icon bubble
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                            ),
                            child: Center(
                              child: Text(_selectedIcon, style: const TextStyle(fontSize: 26)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  walletName.isEmpty ? 'Tên ví của bạn' : walletName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(children: [
                                  Icon(
                                    _walletType == 'group' ? Icons.group_outlined : Icons.account_balance_wallet_outlined,
                                    color: Colors.white70, size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _walletType == 'group' ? 'Ví chung (nhóm)' : 'Ví cá nhân',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                            onPressed: () => context.pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Form body ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500))),
                          ]),
                        ),
                      ],

                      // Tên ví
                      Text('Tên ví', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: palette.textSecondary)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          hintText: 'VD: Ví chi tiêu nhóm, Quỹ du lịch...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          counterText: '',
                        ),
                        style: TextStyle(color: palette.textPrimary),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Vui lòng nhập tên ví';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Loại ví
                      Text('Loại ví', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: palette.textSecondary)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _typeButton('personal', Icons.account_balance_wallet_outlined, 'Cá nhân', palette, accentColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _typeButton('group', Icons.group_outlined, 'Ví chung', palette, accentColor)),
                      ]),
                      const SizedBox(height: 16),

                      // Số dư ban đầu
                      Text('Số dư ban đầu (tùy chọn)', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: palette.textSecondary)),
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

                      // Màu sắc
                      Text('Màu sắc ví', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: palette.textSecondary)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _colors.length,
                          itemBuilder: (context, index) {
                            final hex = _colors[index];
                            final color = _parseHex(hex);
                            final isSelected = _selectedColor == hex;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedColor = hex),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isSelected ? 48 : 40,
                                height: isSelected ? 48 : 40,
                                margin: EdgeInsets.only(right: 10, top: isSelected ? 0 : 4, bottom: isSelected ? 0 : 4),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                                  boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 2))] : null,
                                ),
                                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Biểu tượng
                      Text('Biểu tượng', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: palette.textSecondary)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 52,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _icons.length,
                          itemBuilder: (context, index) {
                            final emoji = _icons[index];
                            final isSelected = _selectedIcon == emoji;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedIcon = emoji),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 52, height: 52,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? accentColor.withValues(alpha: 0.15) : palette.surfaceAlt,
                                  shape: BoxShape.circle,
                                  border: isSelected ? Border.all(color: accentColor, width: 2) : Border.all(color: palette.border),
                                  boxShadow: isSelected ? [BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 6)] : null,
                                ),
                                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Nút tạo ví — dùng màu ví đã chọn
                      SizedBox(
                        width: double.infinity,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [accentColor, gradientEnd]),
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                            ),
                            child: _loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Tạo ví', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeButton(String type, IconData icon, String label, dynamic palette, Color accentColor) {
    final isSelected = _walletType == type;
    return GestureDetector(
      onTap: () => setState(() => _walletType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.12) : palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: isSelected ? accentColor : Colors.transparent, width: 1.5),
        ),
        child: Column(children: [
          Icon(icon, color: isSelected ? accentColor : palette.textSecondary),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isSelected ? accentColor : palette.textSecondary)),
        ]),
      ),
    );
  }
}
