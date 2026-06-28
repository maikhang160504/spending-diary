import 'package:flutter/material.dart';

/// Centralized category styling — single source of truth.
/// Maps category code/name to color + emoji + asset icon.
class CategoryStyle {
  final Color color;
  final String emoji;
  final String label;
  final String iconAsset;

  const CategoryStyle({required this.color, required this.emoji, required this.label, required this.iconAsset});
}

class CategoryTheme {
  static const _base = 'assets/MiMo/category';

  static const List<String> primaryCodes = [
    'Food',
    'Shopping',
    'Essentials',
    'Transport',
    'Housing',
    'Entertainment',
    'Health',
    'Education',
    'Beauty',
    'Social',
    'Business',
    'Bonus',
    'Charity',
    'Debt',
    'Investment',
    'Saving',
    'Salary',
    'Other'
  ];

  static const Map<String, CategoryStyle> styles = {
    // ── 18 canonical categories matching assets/MiMo/category/ ──────
    'Food':          CategoryStyle(color: Color(0xFFEC4899), emoji: '🍔', label: 'Ăn uống',         iconAsset: '$_base/Food.png'),
    'Transport':     CategoryStyle(color: Color(0xFF3B82F6), emoji: '🚗', label: 'Di chuyển',       iconAsset: '$_base/Transport.png'),
    'Shopping':      CategoryStyle(color: Color(0xFF8B5CF6), emoji: '🛍️', label: 'Mua sắm',         iconAsset: '$_base/Shopping.png'),
    'Entertainment': CategoryStyle(color: Color(0xFFF59E0B), emoji: '🎬', label: 'Giải trí',        iconAsset: '$_base/Entertainment.png'),
    'Health':        CategoryStyle(color: Color(0xFF10B981), emoji: '💊', label: 'Sức khỏe',        iconAsset: '$_base/Health.png'),
    'Education':     CategoryStyle(color: Color(0xFF06B6D4), emoji: '📚', label: 'Giáo dục',        iconAsset: '$_base/Education.png'),
    'Beauty':        CategoryStyle(color: Color(0xFFDB2777), emoji: '💅', label: 'Làm đẹp',         iconAsset: '$_base/Beauty.png'),
    'Housing':       CategoryStyle(color: Color(0xFF22C55E), emoji: '🏠', label: 'Nhà ở',           iconAsset: '$_base/Housing.png'),
    'Social':        CategoryStyle(color: Color(0xFFE11D48), emoji: '🍻', label: 'Xã hội',          iconAsset: '$_base/Social.png'),
    'Business':      CategoryStyle(color: Color(0xFF0284C7), emoji: '💼', label: 'Kinh doanh',      iconAsset: '$_base/Business.png'),
    'Bonus':         CategoryStyle(color: Color(0xFFD97706), emoji: '🎁', label: 'Thưởng',          iconAsset: '$_base/Bonus.png'),
    'Charity':       CategoryStyle(color: Color(0xFFDC143C), emoji: '❤️', label: 'Từ thiện',        iconAsset: '$_base/Charity.png'),
    'Essentials':    CategoryStyle(color: Color(0xFF64748B), emoji: '🧴', label: 'Đồ dùng thiết yếu',iconAsset: '$_base/Essentials.png'),
    'Debt':          CategoryStyle(color: Color(0xFFDC2626), emoji: '💸', label: 'Nợ',              iconAsset: '$_base/Debt.png'),
    'Investment':    CategoryStyle(color: Color(0xFF6366F1), emoji: '📈', label: 'Đầu tư',          iconAsset: '$_base/Investment.png'),
    'Saving':        CategoryStyle(color: Color(0xFF7C3AED), emoji: '🐷', label: 'Tiết kiệm',       iconAsset: '$_base/Savings.png'),
    'Other':         CategoryStyle(color: Color(0xFF94A3B8), emoji: '📌', label: 'Khác',            iconAsset: '$_base/Other.png'),
    'Salary':        CategoryStyle(color: Color(0xFF16A34A), emoji: '💵', label: 'Lương',           iconAsset: '$_base/Salary.png'),
    // ── Aliases for backward-compat ──────────────────────────────────
    'Transportation':CategoryStyle(color: Color(0xFF3B82F6), emoji: '🚗', label: 'Di chuyển',       iconAsset: '$_base/Transport.png'),
    'Savings':       CategoryStyle(color: Color(0xFF7C3AED), emoji: '🐷', label: 'Tiết kiệm',       iconAsset: '$_base/Savings.png'),
    'Others':        CategoryStyle(color: Color(0xFF94A3B8), emoji: '📌', label: 'Khác',            iconAsset: '$_base/Other.png'),
    'salary':        CategoryStyle(color: Color(0xFF16A34A), emoji: '💵', label: 'Lương',           iconAsset: '$_base/Salary.png'),
    'bonus':         CategoryStyle(color: Color(0xFFD97706), emoji: '🎁', label: 'Thưởng',          iconAsset: '$_base/Bonus.png'),
    'freelance':     CategoryStyle(color: Color(0xFF0284C7), emoji: '💻', label: 'Freelance',       iconAsset: '$_base/Business.png'),
    'Bills':         CategoryStyle(color: Color(0xFF64748B), emoji: '🧴', label: 'Hoá đơn',         iconAsset: '$_base/Essentials.png'),
    'Gift':          CategoryStyle(color: Color(0xFFE11D48), emoji: '🎁', label: 'Quà tặng',        iconAsset: '$_base/Social.png'),
    'Travel':        CategoryStyle(color: Color(0xFFF97316), emoji: '✈️', label: 'Du lịch',         iconAsset: '$_base/Transport.png'),
  };

  static const _fallback = CategoryStyle(color: Color(0xFF14B8A6), emoji: '📌', label: 'Khác', iconAsset: '$_base/Other.png');

  static CategoryStyle of(String category) => styles[category] ?? _fallback;
  static Color colorOf(String category) => of(category).color;
  static String emojiOf(String category) => of(category).emoji;

  static Color chipBackground(String category, {bool onDark = false}) {
    final c = of(canonicalCodeOf(category)).color;
    return c.withValues(alpha: onDark ? 0.28 : 0.11);
  }

  static Color chipBorder(String category, {bool onDark = false}) {
    final c = of(canonicalCodeOf(category)).color;
    return c.withValues(alpha: onDark ? 0.62 : 0.22);
  }

  static Color chipForeground(String category, {bool onDark = false}) {
    final c = of(canonicalCodeOf(category)).color;
    if (onDark) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withSaturation((hsl.saturation * 0.85).clamp(0.35, 1.0))
          .withLightness(0.82)
          .toColor();
    }
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * 0.72).clamp(0.28, 0.85))
        .withLightness((hsl.lightness * 0.72 + 0.18).clamp(0.42, 0.58))
        .toColor();
  }

  static Color chipIconBackground(String category, {bool onDark = false}) {
    final c = of(canonicalCodeOf(category)).color;
    return c.withValues(alpha: onDark ? 0.38 : 0.14);
  }

  static List<BoxShadow> chipShadow(String category) {
    final c = of(canonicalCodeOf(category)).color;
    return [
      BoxShadow(
        color: c.withValues(alpha: 0.06),
        blurRadius: 6,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Returns an [Image.asset] widget for the category icon, falling back to emoji text.
  static Widget iconOf(String category, {double size = 24}) {
    final style = of(category);
    return Image.asset(
      style.iconAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, st) => Text(style.emoji, style: TextStyle(fontSize: size * 0.75)),
    );
  }

  static String canonicalCodeOf(String category) {
    switch (category) {
      case 'Transportation':
      case 'Travel':
        return 'Transport';
      case 'Savings':
        return 'Saving';
      case 'Others':
        return 'Other';
      case 'salary':
        return 'Salary';
      case 'bonus':
        return 'Bonus';
      case 'freelance':
        return 'Business';
      case 'Bills':
        return 'Essentials';
      case 'Gift':
        return 'Social';
      default:
        // Return matching code in case-insensitive check if it exists in primaryCodes
        for (final code in primaryCodes) {
          if (code.toLowerCase() == category.toLowerCase()) {
            return code;
          }
        }
        return category;
    }
  }
}
