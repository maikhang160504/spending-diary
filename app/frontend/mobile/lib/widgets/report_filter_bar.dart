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

// ── Compact period navigator for landscape filter bar ───────────────────────
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
