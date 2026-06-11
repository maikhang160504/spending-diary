import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wordmark SpendDiary theo mô tả branding (gradient mint–teal, lá thay dấu chấm i).
class SpendDiaryWordmark extends StatelessWidget {
  final double scale;
  final double opacity;
  final double blurSigma;
  final double textShimmer;
  final double leafWiggle;
  final bool showTagline;

  const SpendDiaryWordmark({
    super.key,
    this.scale = 1,
    this.opacity = 1,
    this.blurSigma = 0,
    this.textShimmer = 1,
    this.leafWiggle = 0,
    this.showTagline = true,
  });

  static const _mint = Color(0xFF7FE3C3);
  static const _teal = Color(0xFF42C9A8);

  @override
  Widget build(BuildContext context) {
    final wordStyle = GoogleFonts.nunito(
      fontSize: 38,
      fontWeight: FontWeight.w800,
      height: 1.05,
      letterSpacing: -0.5,
    );

    Widget title = _SpendDiaryTitleText(
      style: wordStyle,
      textShimmer: textShimmer,
    );

    Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        if (showTagline) ...[
          const SizedBox(height: 10),
          _TaglineRow(leafWiggle: leafWiggle),
        ],
      ],
    );

    column = Transform.scale(scale: scale, child: column);

    if (blurSigma > 0.1) {
      column = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: column,
      );
    }

    return Opacity(opacity: opacity.clamp(0, 1), child: column);
  }
}

class _SpendDiaryTitleText extends StatelessWidget {
  final TextStyle style;
  final double textShimmer;
  const _SpendDiaryTitleText({
    required this.style,
    this.textShimmer = 1,
  });

  /// SpendD|ı|ary — ı = i không chấm (U+0131); lá thay dấu chấm, không dùng WidgetSpan.
  static const _iIndex = 6;
  static const _dotlessI = '\u0131';

  TextSpan _titleSpan(TextStyle Function([double]) part) {
    return TextSpan(
      style: part(),
      children: [
        TextSpan(text: 'S', style: part(1.08)),
        const TextSpan(text: 'pend'),
        TextSpan(text: 'D', style: part(1.08)),
        TextSpan(text: _dotlessI, style: part()),
        const TextSpan(text: 'ary'),
      ],
    );
  }

  /// Đo layout chữ + vị trí lá (luôn có fallback nếu getBoxesForSelection rỗng).
  ({TextPainter painter, double leafLeft, double leafTop}) _layout(
    TextStyle Function([double]) part,
    double leafSize,
    TextScaler textScaler,
  ) {
    final span = _titleSpan(part);
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      textScaler: textScaler,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: true,
        applyHeightToLastDescent: true,
      ),
    )..layout();

    final leafTopPad = leafSize * 0.45;
    final boxes = painter.getBoxesForSelection(
      const TextSelection(baseOffset: _iIndex, extentOffset: _iIndex + 1),
    );

    double leafLeft;
    double leafTop;
    if (boxes.isNotEmpty) {
      final box = boxes.first;
      final iW = box.right - box.left;
      leafLeft = box.left + (iW - leafSize) / 2 - leafSize * 0.05;
      leafTop = leafTopPad + box.top + leafSize * 0.18;
    } else {
      final iStart = painter.getOffsetForCaret(
        const TextPosition(offset: _iIndex),
        Rect.zero,
      );
      final iEnd = painter.getOffsetForCaret(
        const TextPosition(offset: _iIndex + 1),
        Rect.zero,
      );
      final iW = (iEnd.dx - iStart.dx).clamp(4.0, 80.0);
      leafLeft = iStart.dx + (iW - leafSize) / 2 - leafSize * 0.05;
      leafTop = leafTopPad + iStart.dy + leafSize * 0.10;
    }

    return (painter: painter, leafLeft: leafLeft, leafTop: leafTop);
  }

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(color: Colors.white);
    final fs = style.fontSize ?? 38;
    TextStyle part([double sizeScale = 1.0]) =>
        style.copyWith(fontSize: fs * sizeScale).merge(base);

    final leafSize = fs * 0.34;
    final textScaler = MediaQuery.textScalerOf(context);
    final layout = _layout(part, leafSize, textScaler);
    final painter = layout.painter;
    final leafTopPad = leafSize * 0.45;

    Widget text = SizedBox(
      width: painter.width,
      child: Text.rich(
        _titleSpan(part),
        textScaler: textScaler,
        textAlign: TextAlign.left,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: true,
          applyHeightToLastDescent: true,
        ),
      ),
    );

    text = ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [SpendDiaryWordmark._mint, SpendDiaryWordmark._teal, Color(0xFF14B8A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: text,
    );

    if (textShimmer < 1) {
      text = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final x = bounds.width * textShimmer.clamp(0, 1);
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,
              Colors.white.withValues(alpha: 0.35),
              Colors.white,
            ],
            stops: [
              ((x - 80) / bounds.width).clamp(0, 1),
              (x / bounds.width).clamp(0, 1),
              ((x + 80) / bounds.width).clamp(0, 1),
            ],
          ).createShader(bounds);
        },
        child: text,
      );
    }

    final leaf = Icon(
      Icons.eco_rounded,
      size: leafSize,
      color: const Color(0xFF0D9488),
      shadows: const [
        Shadow(color: Color(0xFF42C9A8), blurRadius: 6),
      ],
    );

    return SizedBox(
      width: painter.width,
      height: painter.height + leafTopPad,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: leafTopPad, child: text),
          Positioned(left: layout.leafLeft, top: layout.leafTop, child: leaf),
        ],
      ),
    );
  }
}

class _TaglineRow extends StatelessWidget {
  final double leafWiggle;
  const _TaglineRow({required this.leafWiggle});

  @override
  Widget build(BuildContext context) {
    final wiggle = math.sin(leafWiggle * math.pi * 4) * 3 * leafWiggle.clamp(0, 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DecorLine(width: 36),
        const SizedBox(width: 8),
        Transform.rotate(
          angle: wiggle * math.pi / 180,
          child: Icon(Icons.favorite_rounded, size: 12, color: const Color(0xFF42C9A9).withValues(alpha: 0.75)),
        ),
        const SizedBox(width: 6),
        Text(
          'Nhật ký chi tiêu',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.favorite_rounded, size: 12, color: const Color(0xFF42C9A9).withValues(alpha: 0.75)),
        const SizedBox(width: 8),
        _DecorLine(width: 36, mirror: true),
      ],
    );
  }
}

class _DecorLine extends StatelessWidget {
  final double width;
  final bool mirror;
  const _DecorLine({required this.width, this.mirror = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: mirror ? Alignment.centerRight : Alignment.centerLeft,
          end: mirror ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            const Color(0xFF42C9A8).withValues(alpha: 0),
            const Color(0xFF42C9A8).withValues(alpha: 0.5),
          ],
        ),
      ),
    );
  }
}

/// Ánh sáng quét ngang trên icon cuốn sổ.
class NotebookIconShimmer extends StatelessWidget {
  final double size;
  final double progress;
  const NotebookIconShimmer({super.key, required this.size, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/logo/Logo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, e, s) => Icon(Icons.menu_book_rounded, size: size * 0.7, color: const Color(0xFF42C9A8)),
          ),
          if (progress < 1)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(painter: _IconShimmerPainter(progress: progress)),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconShimmerPainter extends CustomPainter {
  final double progress;
  _IconShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final band = size.width * 0.35;
    final x = -band + (size.width + band * 2) * p;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(x, 0, band, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _IconShimmerPainter old) => old.progress != progress;
}
