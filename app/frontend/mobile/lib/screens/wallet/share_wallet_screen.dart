import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class ShareWalletScreen extends StatelessWidget {
  const ShareWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final members = const ['An', 'Lan', 'Minh', 'Khanh'];
    final activities = const [
      _ActivityItem('Lan', 'Vua them chi tieu mua sam', 180000, '10:30'),
      _ActivityItem('Minh', 'Da chuyen vao vi chung', 500000, 'Hom qua'),
      _ActivityItem('An', 'Thanh toan an uong', 95000, 'Hom qua'),
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _WalletHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _WalletSummary(),
                    const SizedBox(height: 20),
                    Text('Thanh vien', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ...members.map((name) => _MemberAvatar(name: name)),
                        const SizedBox(width: 8),
                        _InviteButton(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _InviteLinkCard(),
                    const SizedBox(height: 20),
                    Text('Hoat dong gan day', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    ...activities.map((item) => _ActivityCard(item: item)),
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

class _WalletHeader extends StatelessWidget {
  const _WalletHeader();

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
          Text('Vi chung', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text('Gia dinh 👨‍👩‍👧‍👦', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _WalletSummary extends StatelessWidget {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('So du hien tai', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(formatVnd(12850000), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _WalletStat(label: 'Thu nhap', value: formatVnd(5200000), color: AppColors.success)),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(child: _WalletStat(label: 'Chi tieu', value: formatVnd(3150000), color: AppColors.danger)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _WalletStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final String name;

  const _MemberAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.teal.withValues(alpha: 0.2),
        child: Text(name.substring(0, 1), style: const TextStyle(color: AppColors.tealDark, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.person_add_alt_1, size: 16),
      label: const Text('Moi'),
    );
  }
}

class _InviteLinkCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lien ket moi thanh vien', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('mimo.app/invite/giadinh', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.copy, color: AppColors.teal)),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final String user;
  final String note;
  final int amount;
  final String time;

  const _ActivityItem(this.user, this.note, this.amount, this.time);
}

class _ActivityCard extends StatelessWidget {
  final _ActivityItem item;

  const _ActivityCard({required this.item});

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
          CircleAvatar(
            backgroundColor: AppColors.teal.withValues(alpha: 0.2),
            child: Text(item.user.substring(0, 1), style: const TextStyle(color: AppColors.tealDark)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.user} • ${item.note}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(item.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          Text('-${formatVnd(item.amount)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}