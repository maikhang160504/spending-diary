import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';

/// Reusable home header with gradient background, date, streak, wallet chips, and balance card.
/// Extracted from home_screen, home_gallery_screen, home_calendar_screen (X-01, X-04).
class HomeHeader extends StatelessWidget {
  final String userName;
  final int streakDays;
  final String balance;
  final String income;
  final String expense;
  final List<WalletInfo> wallets;
  final String? selectedWalletId;
  final ValueChanged<WalletInfo> onWalletTap;
  final VoidCallback? onStreakTap;

  const HomeHeader({
    super.key,
    required this.userName,
    this.streakDays = 0,
    required this.balance,
    required this.income,
    required this.expense,
    this.wallets = const [],
    this.selectedWalletId,
    required this.onWalletTap,
    this.onStreakTap,
  });

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_formattedDate(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            const SizedBox(height: 4),
            Row(children: [
              Text('Chào $userName!', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Text('👋', style: TextStyle(fontSize: 18)),
            ]),
          ]),
          GestureDetector(
            onTap: onStreakTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Row(children: [
                const Text('🔥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$streakDays ngày', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text('Streak', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontSize: 10)),
                ]),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Wallet chips
        if (wallets.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: wallets.map((w) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _WalletChipWidget(
                  label: w.label,
                  icon: w.icon,
                  isSelected: w.id == selectedWalletId,
                  onTap: () => onWalletTap(w),
                ),
              )).toList(),
            ),
          ),
        const SizedBox(height: 16),
        // Balance card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: AppColors.teal, size: 16),
              const SizedBox(width: 6),
              Text('Số dư hiện tại', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Text(balance, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 26)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _BalanceStatWidget(label: 'Thu nhập', value: income, color: AppColors.teal)),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(child: _BalanceStatWidget(label: 'Chi tiêu', value: expense, color: AppColors.danger)),
            ]),
          ]),
        ),
      ]),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const weekdays = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
    return '${weekdays[now.weekday % 7]}, ${now.day} tháng ${now.month.toString().padLeft(2, '0')} ${now.year}';
  }
}

/// Wallet info model for the header.
class WalletInfo {
  final String id;
  final String label;
  final IconData icon;
  final int memberCount;

  const WalletInfo({
    required this.id,
    required this.label,
    this.icon = Icons.account_balance_wallet_outlined,
    this.memberCount = 0,
  });
}

class _WalletChipWidget extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _WalletChipWidget({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.teal : Colors.white),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected ? AppColors.teal : Colors.white,
            fontWeight: FontWeight.w600,
          )),
        ]),
      ),
    );
  }
}

class _BalanceStatWidget extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BalanceStatWidget({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
