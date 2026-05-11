import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/mimo_overlay.dart';

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
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Text('AI xác nhận', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 40),
                    ],
                  ),
                  // AI analyzing badge
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.auto_awesome, color: AppColors.teal, size: 14),
                      const SizedBox(width: 6),
                      Text('AI đã nhận dạng với độ chính xác 94%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const Spacer(),
                  // Transaction card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.md)),
                          child: const Icon(Icons.receipt_long, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Giao dịch mới', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text('Cà phê sáng', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        ])),
                        Text(formatVnd(45000), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),
                      const _DetailRow(label: 'Danh mục', value: 'Ăn uống 🍔'),
                      const _DetailRow(label: 'Ví', value: 'Ví riêng'),
                      const _DetailRow(label: 'Thời gian', value: '08:30 - 11/05/2026'),
                      const _DetailRow(label: 'Ghi chú', value: 'Cà phê take-away'),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // Buttons
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        ),
                        child: const Text('Chỉnh sửa'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _onConfirm(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        ),
                        child: const Text('Xác nhận ✓', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onConfirm(BuildContext context) {
    // Navigate back to home
    context.go(AppRoutes.home);

    // Pick random MiMo response (simulate server response)
    final random = Random();
    final response = MockData.mimoResponses[random.nextInt(MockData.mimoResponses.length)];

    // Delay slightly so home screen loads first, then show MiMo
    Future.delayed(const Duration(milliseconds: 400), () {
      mimoController.show(response);
    });
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70))),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}