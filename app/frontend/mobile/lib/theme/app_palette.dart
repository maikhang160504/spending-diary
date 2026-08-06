import 'package:flutter/material.dart';

/// Bảng màu ngữ nghĩa (semantic) hỗ trợ cả Light & Dark mode.
///
/// Các màu nhấn (teal, success, danger) giữ nguyên ở cả hai chế độ nên vẫn
/// dùng từ [AppColors]. Riêng các màu nền/chữ/viền thay đổi theo theme thì
/// đọc qua `AppPalette.of(context)` (hoặc `context.palette`).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg; // nền scaffold
  final Color surfaceAlt; // nền phụ (track segment, chip nền)
  final Color card; // nền thẻ
  final Color textPrimary;
  final Color textSecondary;
  final Color muted;
  final Color border;
  final Color divider;
  final Color shadow;

  const AppPalette({
    required this.bg,
    required this.surfaceAlt,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.muted,
    required this.border,
    required this.divider,
    required this.shadow,
  });

  static const AppPalette light = AppPalette(
    bg: Color(0xFFF5F7FA),
    surfaceAlt: Color(0xFFEEF2F7),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    muted: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    divider: Color(0xFFF1F5F9),
    shadow: Color(0x14334155),
  );

  static const AppPalette dark = AppPalette(
    bg: Color(0xFF0B1120),
    surfaceAlt: Color(0xFF131C2E),
    card: Color(0xFF1A2336),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    muted: Color(0xFF64748B),
    border: Color(0xFF2A3346),
    divider: Color(0xFF232C40),
    shadow: Color(0x40000000),
  );

  /// Bóng đổ thẻ theo palette hiện tại.
  List<BoxShadow> get cardShadow => [
    BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 6)),
  ];
  List<BoxShadow> get softShadow => [
    BoxShadow(color: shadow, blurRadius: 10, offset: const Offset(0, 3)),
  ];

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surfaceAlt,
    Color? card,
    Color? textPrimary,
    Color? textSecondary,
    Color? muted,
    Color? border,
    Color? divider,
    Color? shadow,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      card: Color.lerp(card, other.card, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}
