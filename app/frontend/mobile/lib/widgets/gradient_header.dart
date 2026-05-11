// lib/widgets/common/gradient_scaffold.dart
// Shared scaffold với header gradient và SafeArea
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Header gradient tái sử dụng cho mọi screen
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final List<Widget>? extra; // Extra widgets bên dưới title/subtitle

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        leading != null ? 8 : 24,
        20,
        24,
        extra != null ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (extra != null) ...[const SizedBox(height: 16), ...?extra],
        ],
      ),
    );
  }
}

/// Back button cho header
class HeaderBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const HeaderBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap ?? () => Navigator.maybePop(context),
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
      ),
    );
  }
}

/// Icon button trong header
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const HeaderIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
