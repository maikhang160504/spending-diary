import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class CameraConfirmScreen extends StatelessWidget {
  const CameraConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=1200&q=80',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xAA000000), Color(0xFF000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Text('AI can xac nhan', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white)),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(AppRadii.md),
                              ),
                              child: const Icon(Icons.receipt_long, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Giao dich moi', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                                  const SizedBox(height: 4),
                                  Text('Cafe sang', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white)),
                                ],
                              ),
                            ),
                            Text(formatVnd(45000), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(label: 'Danh muc', value: 'An uong'),
                        _DetailRow(label: 'Vi', value: 'Vi rieng'),
                        _DetailRow(label: 'Thoi gian', value: '08:30 - 10/05/2026'),
                        _DetailRow(label: 'Ghi chu', value: 'Cafe take-away'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                          ),
                          child: const Text('Chinh sua'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Xac nhan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}