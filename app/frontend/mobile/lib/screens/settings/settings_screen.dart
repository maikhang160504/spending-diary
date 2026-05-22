import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/skeleton.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedPersonality = 'Dui Dẻ';
  final _api = ApiClient();

  // API data
  bool _loading = true;
  String _userName = 'Người dùng SpendDiary';
  String _email = 'user@email.com';
  int _monthlyIncome = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getMe(),
        _api.getSettings(),
      ]);
      final me = results[0];
      final settings = results[1];
      if (!mounted) return;
      setState(() {
        final user = me['user'] as Map<String, dynamic>?;
        _userName = (user?['username'] as String?) ?? 'Người dùng SpendDiary';
        _email = (user?['email'] as String?) ?? 'user@email.com';
        _monthlyIncome = ((user?['income_fixed'] ?? 0) is num) ? (user!['income_fixed'] as num).toInt() : 0;
        _selectedPersonality = (settings['verbal_style'] as String?) == 'strict' ? 'Dận Dữ' : 'Dui Dẻ';
        _notificationsEnabled = (settings['notifications_enabled'] as bool?) ?? true;
        _darkModeEnabled = (settings['theme_mode'] as bool?) ?? false;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await _api.updateSettings({key: value});
    } catch (_) {}
  }

  Future<void> _logout() async {
    try {
      await _api.logout();
    } catch (_) {
      await _api.clearTokens();
    }
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  void _showChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (dialogError != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                child: Text(dialogError!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
              const SizedBox(height: 8),
            ],
            TextField(controller: currentCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại')),
            const SizedBox(height: 8),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu mới (≥ 8 ký tự)')),
            const SizedBox(height: 8),
            TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu')),
          ]),
          actions: [
            TextButton(onPressed: () => ctx.pop(), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                if (newCtrl.text.length < 8) {
                  setDialogState(() => dialogError = 'Mật khẩu mới phải ≥ 8 ký tự');
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  setDialogState(() => dialogError = 'Mật khẩu xác nhận không khớp');
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _api.changePassword(currentCtrl.text, newCtrl.text);
                  if (!ctx.mounted) return;
                  ctx.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Đổi mật khẩu thành công ✓'), backgroundColor: AppColors.teal),
                  );
                } on ApiException catch (e) {
                  setDialogState(() => dialogError = e.localizedMessage);
                } catch (_) {
                  setDialogState(() => dialogError = 'Không thể đổi mật khẩu');
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SettingsHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Profile card — dynamic from API
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: _loading
                          ? const SkeletonCard(height: 56)
                          : Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: _avatarColor(_userName),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(child: Text(
                                    _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
                                  )),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_userName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(_email, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),
                    // Tài khoản section
                    Text('Tài khoản', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          _SettingRow(icon: Icons.person_outline, label: 'Thông tin cá nhân', subtitle: _email, showDivider: true),
                          _SettingRow(icon: Icons.attach_money, label: 'Thu nhập hàng tháng', subtitle: _monthlyIncome > 0 ? formatVnd(_monthlyIncome) : 'Chưa cài đặt', showDivider: false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tùy chỉnh section
                    Text('Tùy chỉnh', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          // AI personality — synced with onboarding Dui Dẻ / Dận Dữ
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.teal.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.auto_awesome, color: AppColors.teal, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Phong cách AI', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                          Text(_selectedPersonality, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: AppColors.muted),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _selectedPersonality = 'Dui Dẻ');
                                          _updateSetting('verbalStyle', 'funny');
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _selectedPersonality == 'Dui Dẻ' ? AppColors.teal.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(AppRadii.md),
                                            border: Border.all(color: _selectedPersonality == 'Dui Dẻ' ? AppColors.teal : AppColors.border),
                                          ),
                                          child: Column(children: [
                                            const Text('😎', style: TextStyle(fontSize: 22)),
                                            const SizedBox(height: 4),
                                            Text('Dui Dẻ', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                                          ]),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _selectedPersonality = 'Dận Dữ');
                                          _updateSetting('verbalStyle', 'strict');
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _selectedPersonality == 'Dận Dữ' ? AppColors.teal.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(AppRadii.md),
                                            border: Border.all(color: _selectedPersonality == 'Dận Dữ' ? AppColors.teal : AppColors.border),
                                          ),
                                          child: Column(children: [
                                            const Text('🔥', style: TextStyle(fontSize: 22)),
                                            const SizedBox(height: 4),
                                            Text('Dận Dữ', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                                          ]),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          // Notifications toggle — persisted via API
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.notifications_outlined, color: AppColors.teal, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Thông báo', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                              Switch(
                                value: _notificationsEnabled,
                                onChanged: (v) {
                                  setState(() => _notificationsEnabled = v);
                                  _updateSetting('notificationsEnabled', v);
                                },
                                activeThumbColor: AppColors.teal,
                              ),
                            ]),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          // Dark mode toggle — persisted via API
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.dark_mode_outlined, color: AppColors.teal, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Chế độ tối', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                              Switch(
                                value: _darkModeEnabled,
                                onChanged: (v) {
                                  setState(() => _darkModeEnabled = v);
                                  _updateSetting('themeMode', v);
                                },
                                activeThumbColor: AppColors.teal,
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Bảo mật section
                    Text('Bảo mật', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showChangePassword,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                        ),
                        child: const _SettingRow(icon: Icons.shield_outlined, label: 'Đổi mật khẩu', showDivider: false),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Logout button — real API
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
                        label: const Text('Đăng xuất', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.danger),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text('SpendDiary v1.0.0', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _avatarColor(String name) {
    if (name.isEmpty) return AppColors.teal;
    final hash = name.codeUnits.fold<int>(0, (prev, c) => prev + c);
    final colors = [
      AppColors.teal, const Color(0xFF6366F1), const Color(0xFFEC4899),
      const Color(0xFFF59E0B), const Color(0xFF3B82F6), const Color(0xFF10B981),
    ];
    return colors[hash % colors.length];
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cài đặt', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Quản lý tài khoản và tùy chỉnh ứng dụng', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool showDivider;

  const _SettingRow({required this.icon, required this.label, this.subtitle, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.teal, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: Color(0xFFE2E8F0)),
      ],
    );
  }
}