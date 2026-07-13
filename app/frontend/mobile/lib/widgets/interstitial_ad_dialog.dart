import 'dart:async';
import 'package:flutter/material.dart';

/// Interstitial Ad Dialog giả lập (Mock Ad).
///
/// Hiển thị một banner quảng cáo full-screen với countdown 5 giây.
/// Sau khi countdown kết thúc, nút X xuất hiện cho phép user đóng.
/// Khi đóng → callback [onDismissed] được gọi (thường để show Premium upsell).
class InterstitialAdDialog extends StatefulWidget {
  const InterstitialAdDialog({
    super.key,
    required this.onDismissed,
  });

  /// Callback sau khi user bấm nút X để đóng quảng cáo.
  final VoidCallback onDismissed;

  @override
  State<InterstitialAdDialog> createState() => _InterstitialAdDialogState();
}

class _InterstitialAdDialogState extends State<InterstitialAdDialog>
    with SingleTickerProviderStateMixin {
  static const int _countdownSeconds = 5;
  int _remaining = _countdownSeconds;
  Timer? _timer;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        if (mounted) setState(() => _remaining = 0);
      } else {
        if (mounted) setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    widget.onDismissed();
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              // ── Ad content ──────────────────────────────────────────
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mock Ad Banner
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App logo mock
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C63FF), Color(0xFFFF6B6B)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.gamepad_rounded, color: Colors.white, size: 40),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'GameZone Pro',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Hàng nghìn game miễn phí!\nTải ngay hôm nay.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFB0B8C8),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C63FF), Color(0xFFFF6B6B)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Tải miễn phí',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Quảng cáo • SpendDiary Ads Network',
                            style: TextStyle(color: Color(0xFF5C6480), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Close button / Countdown ─────────────────────────────
              Positioned(
                top: 16,
                right: 16,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _remaining > 0
                      ? Container(
                          key: const ValueKey('countdown'),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Center(
                            child: Text(
                              '$_remaining',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('close'),
                          onTap: _dismiss,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white38),
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                ),
              ),

              // ── Skip label ────────────────────────────────────────────
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Text(
                  _remaining > 0
                      ? 'Quảng cáo sẽ đóng sau $_remaining giây...'
                      : 'Bấm X để đóng quảng cáo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper để hiển thị Interstitial Ad dialog.
Future<void> showInterstitialAdDialog(
  BuildContext context, {
  required VoidCallback onDismissed,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (_) => InterstitialAdDialog(onDismissed: onDismissed),
  );
}
