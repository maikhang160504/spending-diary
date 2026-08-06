// lib/widgets/wallet_chips.dart
// Shared wallet chips: Ví riêng / Gia đình / Nhóm bạn
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class WalletChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  static const _wallets = [
    _Wallet('Ví riêng', Icons.account_balance_wallet_outlined),
    _Wallet('Gia đình', Icons.group_outlined),
    _Wallet('Nhóm bạn', Icons.groups_outlined),
  ];

  const WalletChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _wallets.map((w) {
          final isSelected = selected == w.label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(w.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      w.icon,
                      size: 15,
                      color: isSelected ? AppColors.teal : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      w.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.teal : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Wallet {
  final String label;
  final IconData icon;
  const _Wallet(this.label, this.icon);
}
