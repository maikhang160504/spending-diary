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

  static const Map<String, CategoryStyle> styles = {
    'Food':          CategoryStyle(color: Color(0xFFEC4899), emoji: '🍔', label: 'Ăn uống',    iconAsset: '$_base/Food.png'),
    'Shopping':      CategoryStyle(color: Color(0xFF8B5CF6), emoji: '🛍', label: 'Mua sắm',    iconAsset: '$_base/Shopping.png'),
    'Transport':     CategoryStyle(color: Color(0xFF3B82F6), emoji: '🚗', label: 'Di chuyển',  iconAsset: '$_base/Transport.png'),
    'Entertainment': CategoryStyle(color: Color(0xFFF59E0B), emoji: '🎬', label: 'Giải trí',   iconAsset: '$_base/Entertainment.png'),
    'Education':     CategoryStyle(color: Color(0xFF06B6D4), emoji: '📚', label: 'Giáo dục',   iconAsset: '$_base/Education.png'),
    'Health':        CategoryStyle(color: Color(0xFF10B981), emoji: '💊', label: 'Sức khỏe',   iconAsset: '$_base/Health.png'),
    'Housing':       CategoryStyle(color: Color(0xFF22C55E), emoji: '🏠', label: 'Nhà ở',      iconAsset: '$_base/Housing.png'),
    'Essentials':    CategoryStyle(color: Color(0xFFEF4444), emoji: '📄', label: 'Hoá đơn',    iconAsset: '$_base/Essentials.png'),
    'Bills':         CategoryStyle(color: Color(0xFFEF4444), emoji: '📄', label: 'Hoá đơn',    iconAsset: '$_base/Essentials.png'),
    'Beauty':        CategoryStyle(color: Color(0xFFDB2777), emoji: '💅', label: 'Làm đẹp',    iconAsset: '$_base/Beauty.png'),
    'Social':        CategoryStyle(color: Color(0xFFE11D48), emoji: '🎁', label: 'Xã hội',     iconAsset: '$_base/Social.png'),
    'Gift':          CategoryStyle(color: Color(0xFFE11D48), emoji: '🎁', label: 'Quà tặng',   iconAsset: '$_base/Social.png'),
    'Investment':    CategoryStyle(color: Color(0xFF6366F1), emoji: '📈', label: 'Đầu tư',     iconAsset: '$_base/Investment.png'),
    'Savings':       CategoryStyle(color: Color(0xFF0EA5E9), emoji: '🏦', label: 'Tiết kiệm',  iconAsset: '$_base/Savings.png'),
    'Salary':        CategoryStyle(color: Color(0xFF16A34A), emoji: '�', label: 'Lương',      iconAsset: '$_base/Salary.png'),
    'salary':        CategoryStyle(color: Color(0xFF16A34A), emoji: '💰', label: 'Lương',      iconAsset: '$_base/Salary.png'),
    'Bonus':         CategoryStyle(color: Color(0xFF22C55E), emoji: '🎉', label: 'Thưởng',     iconAsset: '$_base/Bonus.png'),
    'bonus':         CategoryStyle(color: Color(0xFF22C55E), emoji: '🎉', label: 'Thưởng',     iconAsset: '$_base/Bonus.png'),
    'Business':      CategoryStyle(color: Color(0xFF0EA5E9), emoji: '💼', label: 'Kinh doanh', iconAsset: '$_base/Business.png'),
    'freelance':     CategoryStyle(color: Color(0xFF0EA5E9), emoji: '💻', label: 'Freelance',  iconAsset: '$_base/Business.png'),
    'Charity':       CategoryStyle(color: Color(0xFFEC4899), emoji: '❤️', label: 'Từ thiện',   iconAsset: '$_base/Charity.png'),
    'Debt':          CategoryStyle(color: Color(0xFFDC2626), emoji: '💳', label: 'Nợ',         iconAsset: '$_base/Debt.png'),
    'Travel':        CategoryStyle(color: Color(0xFF14B8A6), emoji: '✈️', label: 'Du lịch',    iconAsset: '$_base/Transport.png'),
    'Others':        CategoryStyle(color: Color(0xFF64748B), emoji: '📌', label: 'Khác',       iconAsset: '$_base/Other.png'),
    'Other':         CategoryStyle(color: Color(0xFF64748B), emoji: '📌', label: 'Khác',       iconAsset: '$_base/Other.png'),
    'Ăn uống':       CategoryStyle(color: Color(0xFFEC4899), emoji: '🍔', label: 'Ăn uống',    iconAsset: '$_base/Food.png'),
    'Mua sắm':       CategoryStyle(color: Color(0xFF8B5CF6), emoji: '🛍', label: 'Mua sắm',    iconAsset: '$_base/Shopping.png'),
    'Di chuyển':     CategoryStyle(color: Color(0xFF3B82F6), emoji: '🚗', label: 'Di chuyển',  iconAsset: '$_base/Transport.png'),
    'Giải trí':      CategoryStyle(color: Color(0xFFF59E0B), emoji: '🎬', label: 'Giải trí',   iconAsset: '$_base/Entertainment.png'),
  };

  static const _fallback = CategoryStyle(color: Color(0xFF14B8A6), emoji: '📌', label: 'Khác', iconAsset: '$_base/Other.png');

  static CategoryStyle of(String category) => styles[category] ?? _fallback;
  static Color colorOf(String category) => of(category).color;
  static String emojiOf(String category) => of(category).emoji;

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
}
