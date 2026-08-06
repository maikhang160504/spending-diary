import 'package:flutter/material.dart';

class AppColors {
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealDark = Color(0xFF0F766E);
  // Nền chung — đồng bộ với giá trị các màn hình đang dùng (#F5F7FA),
  // khắc phục lệch sắc nền giữa theme và screen (Color Consistency Lock).
  static const Color surface = Color(0xFFF5F7FA);
  static const Color surfaceAlt = Color(0xFFEEF2F7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color border = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF94A3B8);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  /// Shadow nhuốm theo nền (slate, không dùng đen tuyền) — cảm giác mềm & premium.
  static const Color shadow = Color(0x14334155); // slate-700 ~8%
}

class AppGradients {
  static const LinearGradient teal = LinearGradient(
    colors: [AppColors.teal, AppColors.tealDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Bộ shadow dùng chung — thay cho các shadow đen tuyền rải rác.
class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> soft = [
    BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3)),
  ];
}

/// Bộ quản lý màu sắc ví đang chọn toàn cục — mặc định là màu xanh teal ban đầu.
final ValueNotifier<Color> selectedWalletColorNotifier = ValueNotifier<Color>(
  AppColors.teal,
);

Color parseWalletColorHex(String? hex) {
  if (hex == null || hex.isEmpty) return AppColors.teal;
  final cleanHex = hex.replaceAll('#', '').trim();
  try {
    return Color(
      int.parse(cleanHex.length == 6 ? 'FF$cleanHex' : cleanHex, radix: 16),
    );
  } catch (_) {
    return AppColors.teal;
  }
}
