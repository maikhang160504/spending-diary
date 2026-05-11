import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedPersonality = 'Bạn Thân Nam';

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
                    // Profile card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, color: AppColors.teal, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Người dùng SpendDiary', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('user@email.com', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
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
                          _SettingRow(icon: Icons.person_outline, label: 'Thông tin cá nhân', subtitle: 'user@email.com', showDivider: true),
                          _SettingRow(icon: Icons.attach_money, label: 'Thu nhập hàng tháng', subtitle: '8.000.000 đ', showDivider: false),
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
                          // AI personality
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
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
                                        onTap: () => setState(() => _selectedPersonality = 'Bạn Thân Nam'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _selectedPersonality == 'Bạn Thân Nam' ? AppColors.teal.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(AppRadii.md),
                                            border: Border.all(
                                              color: _selectedPersonality == 'Bạn Thân Nam' ? AppColors.teal : AppColors.border,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              const Text('😎', style: TextStyle(fontSize: 22)),
                                              const SizedBox(height: 4),
                                              Text('Bạn Thân Nam', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _selectedPersonality = 'Bạn Thân Nữ'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _selectedPersonality == 'Bạn Thân Nữ' ? AppColors.teal.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(AppRadii.md),
                                            border: Border.all(
                                              color: _selectedPersonality == 'Bạn Thân Nữ' ? AppColors.teal : AppColors.border,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              const Text('✨', style: TextStyle(fontSize: 22)),
                                              const SizedBox(height: 4),
                                              Text('Bạn Thân Nữ', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          // Notifications toggle
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
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
                                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                                  activeThumbColor: AppColors.teal,
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          // Dark mode toggle
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
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
                                  onChanged: (v) => setState(() => _darkModeEnabled = v),
                                  activeThumbColor: AppColors.teal,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Bảo mật section
                    Text('Bảo mật', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: const _SettingRow(icon: Icons.shield_outlined, label: 'Đổi mật khẩu', showDivider: false),
                    ),
                    const SizedBox(height: 24),
                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {},
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
                width: 36,
                height: 36,
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