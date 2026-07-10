import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Popup mascot: [emotionAsset] = tên file `assets/MiMo/emotions/{Name}.png`.
class MiMoResponse {
  final String emotionAsset;
  final String message;

  const MiMoResponse({required this.emotionAsset, required this.message});

  /// Alias field cũ — cùng giá trị [emotionAsset].
  String get status => emotionAsset;
}

/// MiMo mascot popup — hiển thị sau khi thêm chi tiêu thành công.
/// Đặt trong Stack overlay của AppShell, góc phải dưới ngay trên nav bar.
class MiMoOverlay extends StatefulWidget {
  final MiMoResponse response;
  final VoidCallback onDismiss;

  const MiMoOverlay({super.key, required this.response, required this.onDismiss});

  @override
  State<MiMoOverlay> createState() => _MiMoOverlayState();
}

class _MiMoOverlayState extends State<MiMoOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _slide = Tween<Offset>(begin: const Offset(0.5, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _ctrl.forward();
    // Auto-hide after 20 seconds
    _autoHide = Timer(const Duration(seconds: 20), _dismiss);
  }

  void _dismiss() {
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.bottomRight,
        child: GestureDetector(
          onTap: _dismiss,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Speech bubble (bên trái mascot)
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 210),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(right: 8, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadii.lg),
                      topRight: Radius.circular(AppRadii.lg),
                      bottomLeft: Radius.circular(AppRadii.lg),
                      bottomRight: Radius.circular(4),
                    ),
                    boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                          child: Text('Mimo AI', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.teal)),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(widget.response.message, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.4)),
                    ],
                  ),
                ),
              ),
              // MiMo character image stacked: background frame + status image
              SizedBox(
                width: 84,
                height: 100,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Status image
                    Positioned(
                      bottom: 0,
                      child: Image.asset(
                        'assets/MiMo/emotions/${widget.response.status}.png',
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, e, st) => Image.asset(
                          'assets/MiMo/emotions/Happy.png',
                          height: 90,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx2, e2, st2) => const SizedBox(
                            width: 84, height: 90,
                            child: Center(child: Text('😊', style: TextStyle(fontSize: 40))),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mixin / helper để trigger MiMo từ bất kỳ đâu qua GlobalKey hoặc ValueNotifier
class MiMoController extends ChangeNotifier {
  MiMoResponse? _current;
  MiMoResponse? get current => _current;

  void show(MiMoResponse response) {
    _current = response;
    notifyListeners();
  }

  void dismiss() {
    _current = null;
    notifyListeners();
  }
}

/// Global instance — được dùng từ CameraConfirmScreen để trigger popup
final mimoController = MiMoController();
