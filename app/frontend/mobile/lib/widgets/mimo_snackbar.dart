import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

enum MimoSnackBarType { success, error, warning, info }

/// Hiệu ứng thông báo Snackbar Mascot Mimo sinh động, đẹp mắt, có hiệu ứng nảy (bounce-in).
class MimoSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    String? emotion,
    MimoSnackBarType type = MimoSnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.hideCurrentSnackBar();

      final String assetName = emotion ?? _defaultEmotion(type);
      final Color accentColor = _getAccentColor(type);
      final String label = _getLabel(type);

      messenger.showSnackBar(
        SnackBar(
          content: _MimoSnackBarWidget(
            message: message,
            emotionAsset: assetName,
            accentColor: accentColor,
            label: label,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
          duration: duration,
        ),
      );
    } catch (_) {}
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    String emotion = 'Celebrate',
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      emotion: emotion,
      type: MimoSnackBarType.success,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    String emotion = 'Sad',
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      emotion: emotion,
      type: MimoSnackBarType.error,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    String emotion = 'Alert',
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      emotion: emotion,
      type: MimoSnackBarType.warning,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    String emotion = 'Hello',
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      emotion: emotion,
      type: MimoSnackBarType.info,
      duration: duration,
    );
  }

  static String _defaultEmotion(MimoSnackBarType type) {
    switch (type) {
      case MimoSnackBarType.success:
        return 'Celebrate';
      case MimoSnackBarType.error:
        return 'Sad';
      case MimoSnackBarType.warning:
        return 'Alert';
      case MimoSnackBarType.info:
        return 'Hello';
    }
  }

  static Color _getAccentColor(MimoSnackBarType type) {
    switch (type) {
      case MimoSnackBarType.success:
        return AppColors.teal;
      case MimoSnackBarType.error:
        return AppColors.danger;
      case MimoSnackBarType.warning:
        return const Color(0xFFFB8C00);
      case MimoSnackBarType.info:
        return const Color(0xFF0288D1);
    }
  }

  static String _getLabel(MimoSnackBarType type) {
    switch (type) {
      case MimoSnackBarType.success:
        return 'Mimo Khen';
      case MimoSnackBarType.error:
        return 'Mimo Nhắc';
      case MimoSnackBarType.warning:
        return 'Mimo Lưu Ý';
      case MimoSnackBarType.info:
        return 'Mimo AI';
    }
  }
}

class _MimoSnackBarWidget extends StatefulWidget {
  final String message;
  final String emotionAsset;
  final Color accentColor;
  final String label;

  const _MimoSnackBarWidget({
    required this.message,
    required this.emotionAsset,
    required this.accentColor,
    required this.label,
  });

  @override
  State<_MimoSnackBarWidget> createState() => _MimoSnackBarWidgetState();
}

class _MimoSnackBarWidgetState extends State<_MimoSnackBarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.bottomLeft,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              const BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mascot Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  'assets/MiMo/emotions/${widget.emotionAsset}.png',
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.pets, color: AppColors.teal, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              // Message Bubble Info
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
