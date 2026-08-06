import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo cuốn sổ SpendDiary với hiệu ứng khóa, tờ hóa đơn, vòng gáy và dải sáng quét.
class SpendDiaryNotebookLogo extends StatelessWidget {
  final double size;
  final double logoScale;
  final double logoOpacity;
  final double lockSlide;
  final double receiptLift;
  final List<double> ringOpacity;
  final double shimmerProgress;

  const SpendDiaryNotebookLogo({
    super.key,
    this.size = 140,
    this.logoScale = 1,
    this.logoOpacity = 1,
    this.lockSlide = 1,
    this.receiptLift = 1,
    this.ringOpacity = const [1, 1, 1],
    this.shimmerProgress = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Opacity(
        opacity: logoOpacity.clamp(0, 1),
        child: Transform.scale(
          scale: logoScale,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Image.asset(
                'assets/logo/Logo.png',
                width: size * 0.88,
                height: size * 0.88,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.menu_book_rounded,
                  size: size * 0.6,
                  color: AppColors.teal,
                ),
              ),
              // Vòng gáy sổ — trái, lần lượt từ trên xuống
              Positioned(
                left: size * 0.06,
                top: size * 0.22,
                child: _SpineRing(opacity: ringOpacity.elementAt(0)),
              ),
              Positioned(
                left: size * 0.06,
                top: size * 0.38,
                child: _SpineRing(
                  opacity: ringOpacity.length > 1 ? ringOpacity[1] : 0,
                ),
              ),
              Positioned(
                left: size * 0.06,
                top: size * 0.54,
                child: _SpineRing(
                  opacity: ringOpacity.length > 2 ? ringOpacity[2] : 0,
                ),
              ),
              // Tờ hóa đơn trên bìa — trượt từ dưới lên ~15px
              Positioned(
                top: size * 0.18 + (1 - receiptLift) * 15,
                child: Opacity(
                  opacity: receiptLift.clamp(0, 1),
                  child: Container(
                    width: size * 0.42,
                    height: size * 0.2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: size * 0.28,
                          height: 2,
                          color: const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: size * 0.2,
                          height: 2,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Khóa bên phải — trượt từ ngoài vào
              Positioned(
                right: size * 0.02 + (1 - lockSlide) * 28,
                top: size * 0.42,
                child: Opacity(
                  opacity: lockSlide.clamp(0, 1),
                  child: Container(
                    width: size * 0.14,
                    height: size * 0.22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
              // Dải sáng quét chéo
              if (shimmerProgress < 1)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: _ShimmerSweepPainter(progress: shimmerProgress),
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

class _SpineRing extends StatelessWidget {
  final double opacity;
  const _SpineRing({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0, 1),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.teal.withValues(alpha: 0.85),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}

class _ShimmerSweepPainter extends CustomPainter {
  final double progress;
  _ShimmerSweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final bandW = size.width * 0.35;
    final x = -bandW + (size.width + bandW * 2) * p;
    final rect = Rect.fromLTWH(x, -size.height * 0.2, bandW, size.height * 1.4);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.srcOver;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 6);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShimmerSweepPainter old) =>
      old.progress != progress;
}
