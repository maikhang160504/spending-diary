import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class CameraInputScreen extends StatefulWidget {
  const CameraInputScreen({super.key});

  @override
  State<CameraInputScreen> createState() => _CameraInputScreenState();
}

class _CameraInputScreenState extends State<CameraInputScreen> {
  final _controller = TextEditingController();
  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_hasText) return;
    context.push(AppRoutes.cameraConfirm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Text('Nhập mô tả', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
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
                        Text('Mô tả chi tiêu của bạn', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('AI sẽ nhận dạng và điền tự động sau khi bạn mô tả', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 14),
                        ListenableBuilder(
                          listenable: _controller,
                          builder: (context, child) => TextField(
                            controller: _controller,
                            maxLines: 3,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'VD: Mua cà phê sáng 45k, ăn phở trưa...',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                borderSide: BorderSide(color: _hasText ? AppColors.teal : Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                borderSide: const BorderSide(color: AppColors.teal, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.info_outline, size: 13, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text('Bắt buộc — giúp AI phân loại chính xác hơn', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontSize: 11)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, child) => SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _hasText ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _hasText ? AppColors.teal : Colors.white24,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.auto_awesome, size: 18),
                          const SizedBox(width: 8),
                          Text(_hasText ? 'Phân tích với AI ✨' : 'Nhập mô tả để tiếp tục', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ]),
                      ),
                    ),
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