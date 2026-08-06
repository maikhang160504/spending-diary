import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';

/// Loading animation dùng Lottie (assets/animations/Loading.json).
/// Fallback về [CircularProgressIndicator] nếu asset lỗi.
class LoadingIndicator extends StatelessWidget {
  final double size;
  final String? message;
  final Color messageColor;

  const LoadingIndicator({
    super.key,
    this.size = 96,
    this.message,
    this.messageColor = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Lottie.asset(
            'assets/animations/Loading.json',
            repeat: true,
            errorBuilder: (_, _, _) => const Center(
              child: CircularProgressIndicator(
                color: AppColors.teal,
                strokeWidth: 3,
              ),
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: messageColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
