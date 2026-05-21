import 'package:flutter/material.dart';

/// Centralized category styling — single source of truth.
/// Maps category code/name to color + emoji.
class CategoryStyle {
  final Color color;
  final String emoji;
  final String label;

  const CategoryStyle({required this.color, required this.emoji, required this.label});
}

class CategoryTheme {
  static const Map<String, CategoryStyle> styles = {
    'Food':        CategoryStyle(color: Color(0xFFEC4899), emoji: '🍔', label: 'Ăn uống'),
    'Shopping':    CategoryStyle(color: Color(0xFF8B5CF6), emoji: '🛍', label: 'Mua sắm'),
    'Transport':   CategoryStyle(color: Color(0xFF3B82F6), emoji: '🚗', label: 'Di chuyển'),
    'Entertainment': CategoryStyle(color: Color(0xFFF59E0B), emoji: '🎬', label: 'Giải trí'),
    'Education':   CategoryStyle(color: Color(0xFF06B6D4), emoji: '📚', label: 'Giáo dục'),
    'Health':      CategoryStyle(color: Color(0xFF10B981), emoji: '💊', label: 'Sức khỏe'),
    'Bills':       CategoryStyle(color: Color(0xFFEF4444), emoji: '📄', label: 'Hoá đơn'),
    'Investment':  CategoryStyle(color: Color(0xFF6366F1), emoji: '📈', label: 'Đầu tư'),
    'Gift':        CategoryStyle(color: Color(0xFFE11D48), emoji: '🎁', label: 'Quà tặng'),
    'Other':       CategoryStyle(color: Color(0xFF64748B), emoji: '📌', label: 'Khác'),
    'salary':      CategoryStyle(color: Color(0xFF16A34A), emoji: '💰', label: 'Lương'),
    'bonus':       CategoryStyle(color: Color(0xFF22C55E), emoji: '🎉', label: 'Thưởng'),
    'freelance':   CategoryStyle(color: Color(0xFF0EA5E9), emoji: '💻', label: 'Freelance'),
    'Ăn uống':     CategoryStyle(color: Color(0xFFEC4899), emoji: '🍔', label: 'Ăn uống'),
    'Mua sắm':     CategoryStyle(color: Color(0xFF8B5CF6), emoji: '🛍', label: 'Mua sắm'),
    'Di chuyển':   CategoryStyle(color: Color(0xFF3B82F6), emoji: '🚗', label: 'Di chuyển'),
    'Giải trí':    CategoryStyle(color: Color(0xFFF59E0B), emoji: '🎬', label: 'Giải trí'),
  };

  static const _fallback = CategoryStyle(color: Color(0xFF14B8A6), emoji: '📌', label: 'Khác');

  static CategoryStyle of(String category) => styles[category] ?? _fallback;

  static Color colorOf(String category) => of(category).color;
  static String emojiOf(String category) => of(category).emoji;
}
