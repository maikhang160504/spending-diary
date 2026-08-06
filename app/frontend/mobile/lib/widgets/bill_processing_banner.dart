import 'package:flutter/material.dart';

import '../services/bill_processing_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class BillProcessingBanner extends StatelessWidget {
  final BillJob job;
  final VoidCallback? onDismiss;

  const BillProcessingBanner({super.key, required this.job, this.onDismiss});

  String get _statusLabel {
    switch (job.phase) {
      case BillJobPhase.uploading:
        return job.isText ? 'Đang gửi thông tin...' : 'Đang gửi ảnh bill...';
      case BillJobPhase.processing:
        return job.isText ? 'MiMo đang phân tích...' : 'MiMo đang đọc bill...';
      case BillJobPhase.done:
        return job.isText ? 'Phân tích hoàn tất' : 'Bill đã xử lý xong';
      case BillJobPhase.failed:
        return job.isText ? 'Phân tích thất bại' : 'Bill xử lý thất bại';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isFailed = job.phase == BillJobPhase.failed;
    final accent = isFailed ? AppColors.danger : AppColors.teal;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isFailed
                      ? Icons.error_outline_rounded
                      : Icons.receipt_long_outlined,
                  color: accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: onDismiss,
                  ),
              ],
            ),
            if (job.isActive) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: job.progress,
                  minHeight: 5,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                job.phase == BillJobPhase.uploading
                    ? 'Bạn có thể tiếp tục dùng app'
                    : (job.isText
                          ? 'Đang phân tích thông minh · ${job.elapsedSeconds}s'
                          : 'Đang phân tích OCR · ${job.elapsedSeconds}s'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ] else if (isFailed && job.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                job.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
