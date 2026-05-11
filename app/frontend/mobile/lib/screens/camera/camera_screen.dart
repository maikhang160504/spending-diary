import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  String _mode = 'Ảnh';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2235),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  // Mode toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        _ModeChip(label: 'Ảnh', selected: _mode == 'Ảnh', onTap: () => setState(() => _mode = 'Ảnh')),
                        _ModeChip(label: 'Bill', selected: _mode == 'Bill', onTap: () => setState(() => _mode = 'Bill')),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            // Camera preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                color: const Color(0xFF0F1724),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('Camera Preview', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom controls
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Upload button
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.upload, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('Tải lên', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                  // Shutter button
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.cameraInput),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Flip camera
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cameraswitch, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('Xoay cam', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label == 'Ảnh' ? Icons.image_outlined : Icons.receipt_outlined,
              size: 14,
              color: selected ? AppColors.textPrimary : Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}