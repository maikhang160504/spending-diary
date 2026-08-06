import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class InAppNotification {
  final String title;
  final String message;
  final String? deepLink;
  final String? actionLabel;
  final VoidCallback? onAction;

  const InAppNotification({
    required this.title,
    required this.message,
    this.deepLink,
    this.actionLabel,
    this.onAction,
  });
}

class InAppNotificationController extends ChangeNotifier {
  InAppNotification? _current;
  InAppNotification? get current => _current;

  void show(InAppNotification notification) {
    _current = notification;
    notifyListeners();
  }

  void dismiss() {
    _current = null;
    notifyListeners();
  }
}

final inAppNotificationController = InAppNotificationController();

class InAppNotificationBanner extends StatefulWidget {
  final InAppNotification notification;
  final VoidCallback onDismiss;

  const InAppNotificationBanner({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<double>(
      begin: -100.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward();
    _autoHide = Timer(const Duration(seconds: 8), _dismiss);
  }

  void _dismiss() {
    if (mounted) {
      _ctrl.reverse().then((_) {
        if (mounted) widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slide.value),
          child: Opacity(opacity: _fade.value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          _dismiss();
          if (widget.notification.onAction != null) {
            widget.notification.onAction!();
          }
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color:
                    widget.notification.title.contains('🚨') ||
                        widget.notification.title.contains('Cảnh báo')
                    ? Colors.amber.withValues(alpha: 0.5)
                    : AppColors.teal.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        widget.notification.title.contains('🚨') ||
                            widget.notification.title.contains('Cảnh báo')
                        ? Colors.amber.withValues(alpha: 0.12)
                        : AppColors.teal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.notification.title.contains('🚨') ||
                            widget.notification.title.contains('Cảnh báo')
                        ? Icons.warning_amber_rounded
                        : Icons.notifications_active_outlined,
                    color:
                        widget.notification.title.contains('🚨') ||
                            widget.notification.title.contains('Cảnh báo')
                        ? Colors.amber
                        : AppColors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Text content
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.notification.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.notification.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                      if (widget.notification.actionLabel != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _dismiss();
                            if (widget.notification.onAction != null) {
                              widget.notification.onAction!();
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.notification.actionLabel!,
                                style: const TextStyle(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: AppColors.teal,
                                size: 10,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Dismiss button
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                  onPressed: _dismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
