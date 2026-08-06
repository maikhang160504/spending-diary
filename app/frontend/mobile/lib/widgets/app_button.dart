import 'package:flutter/material.dart';

import '../theme/app_radii.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isSecondary = false,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = isSecondary
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Text(label),
          )
        : FilledButton(onPressed: onPressed, child: Text(label));

    if (!isFullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}
