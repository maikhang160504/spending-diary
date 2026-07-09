import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/bill_processing_service.dart';
import '../../theme/app_colors.dart';

class CameraScreen extends StatefulWidget {
  final bool returnOnlyImagePath;
  final String? walletId;
  final String? initialMode;
  const CameraScreen({super.key, this.returnOnlyImagePath = false, this.walletId, this.initialMode});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  late String _mode;
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 5.0;
  Offset? _focusPoint;
  bool _showFocusRing = false;
  bool _permissionDenied = false;
  bool _isInitialized = false;
  bool _isTakingPhoto = false;
  FlashMode _flashMode = FlashMode.off;
  final _api = ApiClient();
  String? _billError;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode ?? 'Ảnh';
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_cameras[_cameraIndex]);
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    await _initCameraController(_cameras[_cameraIndex]);
  }

  Future<void> _initCameraController(CameraDescription camera) async {
    // Full HD (1920×1080) — đủ nét cho OCR bill, nhẹ hơn ultraHigh/max.
    final ctrl = CameraController(camera, ResolutionPreset.veryHigh, enableAudio: false);
    _controller = ctrl;
    try {
      await ctrl.initialize();
      _minZoom = await ctrl.getMinZoomLevel();
      _maxZoom = await ctrl.getMaxZoomLevel();
      await ctrl.setFlashMode(_flashMode);
      if (mounted) setState(() { _isInitialized = true; _zoomLevel = _minZoom; });
    } catch (_) {
      if (mounted) setState(() => _permissionDenied = true);
    }
  }

  Future<void> _onTapToFocus(TapDownDetails d, BoxConstraints box) async {
    setState(() { _focusPoint = d.localPosition; _showFocusRing = true; });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showFocusRing = false);
    });
    if (_controller == null || !_controller!.value.isInitialized) return;
    final x = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
    final y = (d.localPosition.dy / box.maxHeight).clamp(0.0, 1.0);
    try {
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setExposurePoint(Offset(x, y));
    } catch (_) {}
  }

  Future<void> _setZoom(double scale) async {
    final z = (_zoomLevel * scale).clamp(_minZoom, _maxZoom);
    setState(() => _zoomLevel = z);
    try { await _controller?.setZoomLevel(z); } catch (_) {}
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    setState(() { _isInitialized = false; _cameraIndex = (_cameraIndex + 1) % _cameras.length; });
    await _controller?.dispose();
    await _initCameraController(_cameras[_cameraIndex]);
  }

  Future<void> _toggleFlash() async {
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    setState(() => _flashMode = next);
    try { await _controller?.setFlashMode(next); } catch (_) {}
  }

  Future<void> _handleImagePath(String imagePath) async {
    if (widget.returnOnlyImagePath) {
      context.pop(imagePath);
      return;
    }
    if (_mode == 'Bill') {
      String? targetId = widget.walletId ?? ApiClient.lastSelectedWalletId;
      if (targetId == null || targetId.isEmpty) {
        try {
          final wallets = await _api.getWallets();
          wallets.sort((a, b) {
            final aType = a['type'] as String? ?? 'personal';
            final bType = b['type'] as String? ?? 'personal';
            if (aType == 'personal' && bType != 'personal') return -1;
            if (aType != 'personal' && bType == 'personal') return 1;
            return 0;
          });
          if (wallets.isNotEmpty) targetId = wallets[0]['id'] as String?;
        } catch (_) {}
      }
      targetId ??= '';

      // Gửi đi ngay lập tức (không block UI) và quay lại màn hình trước để hiển thị banner
      BillProcessingService.instance.submitBill(
        walletId: targetId,
        imagePath: imagePath,
      );

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi hóa đơn! Đang phân tích ngầm...'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.teal,
        ),
      );
    } else {
      context.push(AppRoutes.cameraInput, extra: {
        'imagePath': imagePath,
        'isBill': false,
        'walletId': widget.walletId ?? ApiClient.lastSelectedWalletId,
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto || _controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isTakingPhoto = true);
    try {
      final xFile = await _controller!.takePicture();
      if (!mounted) return;
      await _handleImagePath(xFile.path);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _pickFromGallery() async {
    XFile? xFile;
    try {
      final picker = ImagePicker();
      xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    } catch (e) {
      debugPrint('Failed to pick gallery image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở thư viện ảnh. Hãy cấp quyền trong phần Cài đặt.')),
        );
      }
      return;
    }
    if (xFile == null || !mounted) return;
    await _handleImagePath(xFile.path);
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white54, size: 56),
          const SizedBox(height: 16),
          const Text('Cần quyền truy cập camera', style: TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 8),
          TextButton(onPressed: openAppSettings, child: const Text('Mở cài đặt', style: TextStyle(color: AppColors.teal))),
          TextButton(onPressed: () => context.pop(), child: const Text('Quay lại', style: TextStyle(color: Colors.white54))),
        ])),
      );
    }
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
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
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
                  child: Row(children: [
                    _ModeChip(label: 'Ảnh', selected: _mode == 'Ảnh', onTap: () => setState(() => _mode = 'Ảnh')),
                    _ModeChip(label: 'Bill', selected: _mode == 'Bill', onTap: () => setState(() => _mode = 'Bill')),
                  ]),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _toggleFlash,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(
                      _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                      color: _flashMode == FlashMode.off ? Colors.white54 : Colors.yellow,
                      size: 20,
                    ),
                  ),
                ),
              ]),
            ),
            // Bill mode tip banner
            if (_mode == 'Bill')
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.yellow.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.yellow.withValues(alpha: 0.4)),
                ),
                child: const Row(children: [
                  Icon(Icons.receipt_long, color: Colors.yellow, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Hãy chụp thẳng vào toàn bộ hóa đơn, giữ phẳng và đủ ánh sáng',
                    style: TextStyle(color: Colors.yellow, fontSize: 11, fontWeight: FontWeight.w500),
                  )),
                ]),
              ),

            // ── Camera Viewfinder (tỉ lệ 4:3, bo góc 16, không khung) ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4, // ảnh đứng tỉ lệ 4:3
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GestureDetector(
                        onScaleUpdate: (d) => _setZoom(d.scale),
                        child: LayoutBuilder(builder: (ctx, box) {
                          return GestureDetector(
                            onTapDown: (d) => _onTapToFocus(d, box),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Real camera preview or loading indicator
                                if (_isInitialized && _controller != null)
                                  FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _controller!.value.previewSize?.height ?? box.maxWidth,
                                      height: _controller!.value.previewSize?.width ?? (box.maxWidth * _controller!.value.aspectRatio),
                                      child: CameraPreview(_controller!),
                                    ),
                                  )
                                else
                                  Container(
                                    color: const Color(0xFF0D1117),
                                    child: const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2)),
                                  ),

                                if (_mode == 'Bill')
                                  const _BillScanFrameOverlay(),

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

                                // Bill error banner
                                if (_billError != null)
                                  Positioned(top: 12, left: 16, right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
                                      child: Row(children: [
                                        const Icon(Icons.error_outline, color: Colors.white, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(_billError!, style: const TextStyle(color: Colors.white, fontSize: 12))),
                                        GestureDetector(onTap: () => setState(() => _billError = null),
                                          child: const Icon(Icons.close, color: Colors.white, size: 16)),
                                      ]),
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
                  ),
                ),
              ),
            ),

            // ── Bottom Controls ───────────────────────────────────
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(40, 20, 40, 28),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _CtrlBtn(icon: Icons.photo_library_outlined, label: 'Thư viện', onTap: _pickFromGallery),
                    // Capture button
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _mode == 'Bill' ? Colors.yellow : AppColors.teal,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_mode == 'Bill' ? Colors.yellow : AppColors.teal).withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isTakingPhoto
                              ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2))
                              : Container(width: 56, height: 56, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        ),
                      ),
                    ),
                    _CtrlBtn(icon: Icons.cameraswitch_outlined, label: 'Xoay cam', onTap: _flipCamera),
                  ]),
                  if (_mode == 'Bill') ...[
                    const SizedBox(height: 12),
                    Text(
                      _isTakingPhoto ? 'Mimso đang đọc hóa đơn...' : 'Chụp để xử lý tự động',
                      style: TextStyle(
                        color: _isTakingPhoto ? Colors.yellow : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class _BillScanFrameOverlay extends StatefulWidget {
  const _BillScanFrameOverlay();

  @override
  State<_BillScanFrameOverlay> createState() => _BillScanFrameOverlayState();
}

class _BillScanFrameOverlayState extends State<_BillScanFrameOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final frameW = w * 0.8;
        final frameH = h * 0.8;
        final left = (w - frameW) / 2;
        final top = (h - frameH) / 2;

        return Stack(
          children: [
            // Darkened background outside the frame
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: frameW,
                      height: frameH,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Yellow frame border
            Align(
              alignment: Alignment.center,
              child: Container(
                width: frameW,
                height: frameH,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // Animated scanner bar
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final currentY = top + (frameH * _controller.value);
                return Positioned(
                  left: left + 10,
                  top: currentY,
                  child: Container(
                    width: frameW - 20,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.yellow.withOpacity(0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}