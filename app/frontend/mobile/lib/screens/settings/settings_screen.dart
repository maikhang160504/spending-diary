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
  bool _pushEnabled = true;
  bool _insightsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                    _ProfileCard(),
                    const SizedBox(height: 20),
                    _SectionTitle(title: 'Tai khoan'),
                    const SizedBox(height: 8),
                    _SettingsTile(icon: Icons.person_outline, title: 'Thong tin ca nhan', subtitle: 'Cap nhat ten, avatar, gioi tinh'),
                    _SettingsTile(icon: Icons.lock_outline, title: 'Bao mat', subtitle: 'Doi mat khau, khoa ung dung'),
                    _SettingsTile(icon: Icons.group_outlined, title: 'Vi chung', subtitle: 'Quan ly thanh vien va quyen han'),
                    const SizedBox(height: 16),
                    _SectionTitle(title: 'Tuy chon'),
                    const SizedBox(height: 8),
                    _SwitchTile(
                      title: 'Thong bao chi tieu',
                      subtitle: 'Nhan canh bao khi sap vuot ngan sach',
                      value: _pushEnabled,
                      onChanged: (value) => setState(() => _pushEnabled = value),
                    ),
                    _SwitchTile(
                      title: 'Goi y tu Mimo',
                      subtitle: 'Tu dong gui insight moi ngay',
                      value: _insightsEnabled,
                      onChanged: (value) => setState(() => _insightsEnabled = value),
                    ),
                    const SizedBox(height: 16),
                    _SectionTitle(title: 'Ho tro'),
                    const SizedBox(height: 8),
                    _SettingsTile(icon: Icons.help_outline, title: 'Cau hoi thuong gap', subtitle: 'Huong dan su dung nhanh'),
                    _SettingsTile(icon: Icons.chat_bubble_outline, title: 'Lien he ho tro', subtitle: 'Nhan phan hoi tu doi ngu'),
                    _SettingsTile(icon: Icons.info_outline, title: 'Thong tin ung dung', subtitle: 'Version 1.0.0'),
                    const SizedBox(height: 24),
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
          Text('Cai dat', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text('Quan ly tai khoan va tuy chinh ung dung', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.teal.withValues(alpha: 0.2),
            child: const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.tealDark)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('An Nguyen', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('an.nguyen@email.com', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined, color: AppColors.teal)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary));
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.teal),
        ],
      ),
    );
  }
}