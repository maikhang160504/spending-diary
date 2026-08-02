import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// ── ReportFilterBar ─────────────────────────────────────────────────────────
///
/// Responsive filter container for all report sub-screens.
///
/// • Portrait (phone/tablet): stacked vertically, each filter on its own row.
/// • Landscape phone (height < 500): ALL filters laid out in a single
///   horizontally-scrollable row so they never push chart content off screen.
///
/// Usage:
/// ```dart
/// ReportFilterBar(
///   isLandscapePhone: isLandscapePhone,
///   children: [
///     _buildPeriodSegment(),
///     _buildPeriodNavigator(),
///     _buildWalletChips(),
///   ],
/// )
/// ```
class ReportFilterBar extends StatelessWidget {
  final List<Widget> children;
  final bool isLandscapePhone;

  const ReportFilterBar({
    super.key,
    required this.children,
    required this.isLandscapePhone,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLandscapePhone) {
      // Portrait: stack vertically as before
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: children
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: c,
                ))
            .toList(),
      );
    }

    // Landscape phone: single horizontal scrollable row with dividers
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children.expand((child) sync* {
            yield child;
            if (child != children.last) {
              yield const SizedBox(width: 8);
              yield Container(
                width: 1,
                height: 28,
                color: Colors.grey.withValues(alpha: 0.3),
              );
              yield const SizedBox(width: 8);
            }
          }).toList(),
        ),
      ),
    );
  }
}

// ── Compact segmented control for landscape filter bar ──────────────────────
class FilterSegmentCompact extends StatelessWidget {
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onChanged;

  const FilterSegmentCompact({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: labels.map((label) {
          final isActive = label == selected;
          return GestureDetector(
            onTap: () => onChanged(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? AppColors.teal : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FilterPeriodNavCompact extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  const FilterPeriodNavCompact({
    super.key,
    required this.label,
    required this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPrev,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.teal),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: onNext,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: onNext != null ? AppColors.teal : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Compact wallet selector chip row ─────────────────────────────────────────
class FilterWalletSelector extends StatelessWidget {
  final List<dynamic> wallets;
  final String? selectedWalletId;
  final ValueChanged<String?> onWalletSelected;
  final bool isLandscape;

  const FilterWalletSelector({
    super.key,
    required this.wallets,
    required this.selectedWalletId,
    required this.onWalletSelected,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        shrinkWrap: isLandscape,
        children: [
          _buildChip(
            context,
            id: null,
            name: 'Tất cả ví',
            icon: Icons.account_balance_wallet_outlined,
            isSelected: selectedWalletId == null,
          ),
          ...wallets.map((w) {
            final id = w['id']?.toString() ?? '';
            final name = w['name']?.toString() ?? 'Ví';
            final iconName = w['icon']?.toString();
            return _buildChip(
              context,
              id: id,
              name: name,
              icon: _getWalletIcon(iconName),
              isSelected: selectedWalletId == id,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String? id,
    required String name,
    required IconData icon,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onWalletSelected(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.teal : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: isSelected ? AppColors.teal : Colors.grey.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.teal,
              ),
              const SizedBox(width: 5),
              Text(
                name,
                style: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getWalletIcon(String? icon) {
    switch (icon) {
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }
}

// ── Compact toggle switch (e.g. So cùng kỳ) ─────────────────────────────────
class FilterToggleCompact extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const FilterToggleCompact({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: value ? AppColors.teal.withValues(alpha: 0.12) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: value ? AppColors.teal : Colors.grey.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 15,
              color: value ? AppColors.teal : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                color: value ? AppColors.teal : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
