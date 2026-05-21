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
  double _zoomLevel = 1.0;
  Offset? _focusPoint;
  bool _showFocusRing = false;

  void _onTapToFocus(TapDownDetails d, BoxConstraints box) {
    setState(() {
      _focusPoint = d.localPosition;
      _showFocusRing = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showFocusRing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                  child: Row(children: [
                    _ModeChip(label: 'Ảnh', selected: _mode == 'Ảnh', onTap: () => setState(() => _mode = 'Ảnh')),
                    _ModeChip(label: 'Bill', selected: _mode == 'Bill', onTap: () => setState(() => _mode = 'Bill')),
                  ]),
                ),
                const Spacer(),
                const SizedBox(width: 40),
              ]),
            ),

            // ── Camera Viewfinder ─────────────────────────────────
            Expanded(
              child: GestureDetector(
                // Zoom via vertical drag
                onScaleUpdate: (d) => setState(() => _zoomLevel = (_zoomLevel * d.scale).clamp(1.0, 5.0)),
                child: LayoutBuilder(builder: (ctx, box) {
                  return GestureDetector(
                    onTapDown: (d) => _onTapToFocus(d, box),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Simulated camera preview
                        Container(
                          color: const Color(0xFF0D1117),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.camera_alt_outlined, size: 56, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(height: 10),
                            Text('Camera đang hoạt động', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13)),
                          ]),
                        ),

                        // Bill framing overlay
                        if (_mode == 'Bill')
                          Center(
                            child: Container(
                              width: 280, height: 180,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.teal, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.receipt_long, color: AppColors.teal, size: 32),
                                const SizedBox(height: 8),
                                Text('Đặt bill vào khung', style: TextStyle(color: AppColors.teal.withValues(alpha: 0.85), fontSize: 12)),
                              ]),
                            ),
                          ),

                        // Corner brackets for bill mode
                        if (_mode == 'Bill') ...[
                          Positioned(left: (box.maxWidth - 280) / 2 - 2, top: (box.maxHeight - 180) / 2 - 2,
                            child: _Corner(topLeft: true)),
                          Positioned(right: (box.maxWidth - 280) / 2 - 2, top: (box.maxHeight - 180) / 2 - 2,
                            child: _Corner(topRight: true)),
                          Positioned(left: (box.maxWidth - 280) / 2 - 2, bottom: (box.maxHeight - 180) / 2 - 2,
                            child: _Corner(bottomLeft: true)),
                          Positioned(right: (box.maxWidth - 280) / 2 - 2, bottom: (box.maxHeight - 180) / 2 - 2,
                            child: _Corner(bottomRight: true)),
                        ],

                        // Focus ring
                        if (_focusPoint != null && _showFocusRing)
                          Positioned(
                            left: _focusPoint!.dx - 30,
                            top: _focusPoint!.dy - 30,
                            child: Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.yellow, width: 1.5),
                              ),
                            ),
                          ),

                        // Zoom indicator
                        if (_zoomLevel > 1.05)
                          Positioned(bottom: 16, left: 0, right: 0,
                            child: Center(child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                              child: Text('${_zoomLevel.toStringAsFixed(1)}×', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            )),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // ── Bottom Controls ───────────────────────────────────
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(40, 20, 40, 28),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                // Gallery / upload
                _CtrlBtn(icon: Icons.photo_library_outlined, label: 'Thư viện', onTap: () {}),
                // Shutter
                GestureDetector(
                  onTap: () => context.push(AppRoutes.cameraInput),
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: Center(child: Container(
                      width: 56, height: 56,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    )),
                  ),
                ),
                // Flip
                _CtrlBtn(icon: Icons.cameraswitch_outlined, label: 'Xoay cam', onTap: () {}),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final bool topLeft, topRight, bottomLeft, bottomRight;
  const _Corner({this.topLeft = false, this.topRight = false, this.bottomLeft = false, this.bottomRight = false});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _CornerPainter(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool topLeft, topRight, bottomLeft, bottomRight;
  _CornerPainter({this.topLeft = false, this.topRight = false, this.bottomLeft = false, this.bottomRight = false});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.teal..strokeWidth = 3..style = PaintingStyle.stroke;
    const len = 20.0;
    if (topLeft) { canvas.drawLine(Offset.zero, Offset(len, 0), paint); canvas.drawLine(Offset.zero, Offset(0, len), paint); }
    if (topRight) { canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint); canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint); }
    if (bottomLeft) { canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint); canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint); }
    if (bottomRight) { canvas.drawLine(Offset(size.width, size.height), Offset(size.width - len, size.height), paint); canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), paint); }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Column(children: [
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    ),
    const SizedBox(height: 6),
    Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
  ]);
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(label == 'Ảnh' ? Icons.image_outlined : Icons.receipt_outlined, size: 14,
            color: selected ? AppColors.textPrimary : Colors.white),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: selected ? AppColors.textPrimary : Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}