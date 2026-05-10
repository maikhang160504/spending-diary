import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class CameraInputScreen extends StatelessWidget {
  const CameraInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=80',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0xFF000000)],
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
                      Text('Nhap mo ta', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white)),
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
                        Text('Nhap mo ta chi tieu', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white)),
                        const SizedBox(height: 6),
                        Text('Giup AI hieu ro hon ve giao dich nay', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 16),
                        TextField(
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'VD: Mua cafe sang, tra sua chieu...',
                            hintStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Ban co the bo qua neu muon', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.cameraConfirm),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                          ),
                          child: const Text('Bo qua'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.cameraConfirm),
                          child: const Text('Tiep tuc'),
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