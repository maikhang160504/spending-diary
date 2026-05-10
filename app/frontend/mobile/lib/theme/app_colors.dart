import 'package:flutter/material.dart';

class AppColors {
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealDark = Color(0xFF0F766E);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color border = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF94A3B8);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
}

class AppGradients {
  static const LinearGradient teal = LinearGradient(
    colors: [AppColors.teal, AppColors.tealDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
