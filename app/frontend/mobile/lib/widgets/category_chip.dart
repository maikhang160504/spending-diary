import 'package:flutter/material.dart';

import '../theme/categories.dart';

enum CategoryChipSize { compact, regular }

/// Tinted category pill with icon — used on story cards and detail screens.
class CategoryChip extends StatelessWidget {
  final String category;
  final CategoryChipSize size;
  final bool onDark;

  const CategoryChip({
    super.key,
    required this.category,
    this.size = CategoryChipSize.compact,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final code = CategoryTheme.canonicalCodeOf(category);
    final style = CategoryTheme.of(code);
    final isCompact = size == CategoryChipSize.compact;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: CategoryTheme.chipBackground(code, onDark: onDark),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: CategoryTheme.chipBorder(code, onDark: onDark),
          width: 1,
        ),
        boxShadow: onDark ? null : CategoryTheme.chipShadow(code),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isCompact ? 17 : 21,
            height: isCompact ? 17 : 21,
            decoration: BoxDecoration(
              color: CategoryTheme.chipIconBackground(code, onDark: onDark),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: CategoryTheme.iconOf(code, size: isCompact ? 10 : 13),
          ),
          SizedBox(width: isCompact ? 5 : 7),
          Text(
            style.label,
            style: TextStyle(
              color: CategoryTheme.chipForeground(code, onDark: onDark),
              fontSize: isCompact ? 10 : 12,
              fontWeight: FontWeight.w600,
              height: 1.1,
              letterSpacing: 0.05,
            ),
          ),
        ],
      ),
    );
  }
}
