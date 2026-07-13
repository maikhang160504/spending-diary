import 'dart:math' as math;

import 'dart:ui';



import 'package:flutter/material.dart';



import '../theme/app_colors.dart';

import '../theme/app_radii.dart';



/// Một thẻ mascot giữa màn hình — xoay 1 vòng rồi giữ thẻ AI vừa chọn.

class AiStyleCardFlipTransition {

  static Future<void> run({

    required BuildContext context,

    required String fromStyle,

    required String toStyle,

    required VoidCallback onComplete,

  }) async {

    if (fromStyle == toStyle) {

      onComplete();

      return;

    }

    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(

      builder: (ctx) => _FlipOverlay(

        fromStyle: fromStyle,

        toStyle: toStyle,

        onDone: () {

          entry.remove();

          onComplete();

        },

      ),

    );

    overlay.insert(entry);

  }

}



class _FlipOverlay extends StatefulWidget {

  final String fromStyle;

  final String toStyle;

  final VoidCallback onDone;



  const _FlipOverlay({

    required this.fromStyle,

    required this.toStyle,

    required this.onDone,

  });



  @override

  State<_FlipOverlay> createState() => _FlipOverlayState();

}



class _FlipOverlayState extends State<_FlipOverlay> with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;

  late final Animation<double> _anim;

  bool _holdFinalCard = false;

  bool _showToast = false;



  static const _spinDuration = Duration(milliseconds: 900);

  static const _holdDuration = Duration(milliseconds: 1400);



  @override

  void initState() {

    super.initState();

    _ctrl = AnimationController(vsync: this, duration: _spinDuration);

    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);

    _ctrl.forward().then((_) {

      if (!mounted) return;

      setState(() => _holdFinalCard = true);

      Future.delayed(_holdDuration, () {

        if (!mounted) return;

        setState(() => _showToast = true);

        Future.delayed(const Duration(milliseconds: 700), () {

          if (mounted) widget.onDone();

        });

      });

    });

  }



  @override

  void dispose() {

    _ctrl.dispose();

    super.dispose();

  }



  String get _toLabel {
    switch (widget.toStyle) {
      case 'dan_doi': return 'Dận Dỗi';
      case 'kho_tinh': return 'Khó Tính';
      case 'ngot_ngao': return 'Ngọt Ngào';
      case 'dui_de':
      default: return 'Dui Dẻ';
    }
  }



  @override

  Widget build(BuildContext context) {

    return AnimatedBuilder(

      animation: _anim,

      builder: (context, _) => _buildFrame(context),

    );

  }



  Widget _buildFrame(BuildContext context) {

    final size = MediaQuery.sizeOf(context);

    final cardW = math.min(size.width * 0.78, 300.0);

    final cardH = cardW * 0.82;



    if (_holdFinalCard) {

      return Material(

        color: Colors.transparent,

        child: Stack(

          children: [

            Positioned.fill(

              child: Container(color: Colors.black.withValues(alpha: 0.06)),

            ),

            Center(

              child: _StyleFlipCard(

                width: cardW,

                height: cardH,

                style: widget.toStyle,

                showCardBack: false,

                lightSweep: 0,

              ),

            ),

            if (_showToast)

              Positioned(

                bottom: MediaQuery.paddingOf(context).bottom + 48,

                left: 24,

                right: 24,

                child: _SuccessToast(label: 'Đã chuyển sang phong cách $_toLabel'),

              ),

          ],

        ),

      );

    }



    final t = _anim.value;

    double cardScale;

    if (t < 0.12) {

      cardScale = 1.0 + (t / 0.12) * 0.08;

    } else if (t < 0.88) {

      cardScale = 1.08;

    } else {

      cardScale = 1.08 - ((t - 0.88) / 0.12) * 0.08;

    }



    final blur = t < 0.1 ? 0.0 : (t < 0.9 ? 12.0 : 12.0 * (1 - (t - 0.9) / 0.1));

    final spinT = ((t - 0.1) / 0.8).clamp(0.0, 1.0);

    // Một vòng xoay (2π): nửa đầu thẻ cũ → nửa sau thẻ mới

    final angleY = spinT * 2 * math.pi;

    final secondHalf = spinT >= 0.5;

    final displayStyle = secondHalf ? widget.toStyle : widget.fromStyle;

    final showCardBack = spinT > 0.48 && spinT < 0.52;

    final sweep = math.sin(spinT * math.pi) * 0.7;



    return Material(

      color: Colors.transparent,

      child: Stack(

        children: [

          Positioned.fill(

            child: GestureDetector(

              onTap: () {},

              child: BackdropFilter(

                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),

                child: Container(color: Colors.black.withValues(alpha: 0.08 * (blur / 12))),

              ),

            ),

          ),

          Center(

            child: Transform.scale(

              scale: cardScale,

              child: Transform(

                alignment: Alignment.center,

                transform: Matrix4.identity()

                  ..setEntry(3, 2, 0.001)

                  ..rotateY(angleY),

                child: _StyleFlipCard(

                  width: cardW,

                  height: cardH,

                  style: displayStyle,

                  showCardBack: showCardBack,

                  lightSweep: sweep,

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }

}



class _StyleFlipCard extends StatelessWidget {

  final double width;

  final double height;

  final String style;

  final bool showCardBack;

  final double lightSweep;



  const _StyleFlipCard({

    required this.width,

    required this.height,

    required this.style,

    required this.showCardBack,

    required this.lightSweep,

  });



  @override

  Widget build(BuildContext context) {

    if (showCardBack) {

      return _cardBack();

    }



    String asset = 'assets/MiMo/emotions/Sassy.png';
    String label = 'Dui Dẻ';
    String description = 'Vui vẻ, hài hước';
    Color accent = AppColors.teal;
    String emoji = '😎';

    switch (style) {
      case 'dan_doi':
        asset = 'assets/MiMo/emotions/Sad.png';
        label = 'Dận Dỗi';
        description = 'Hay dỗi, mít ướt';
        accent = const Color(0xFF6366F1); // Indigo
        emoji = '🥺';
        break;
      case 'kho_tinh':
        asset = 'assets/MiMo/emotions/Angry.png';
        label = 'Khó Tính';
        description = 'Nghiêm túc, kỷ luật';
        accent = const Color(0xFFF97316); // Orange
        emoji = '🔥';
        break;
      case 'ngot_ngao':
        asset = 'assets/MiMo/emotions/Love.png';
        label = 'Ngọt Ngào';
        description = 'Thấu cảm, chữa lành';
        accent = const Color(0xFFEC4899); // Pink
        emoji = '💖';
        break;
      case 'dui_de':
      default:
        asset = 'assets/MiMo/emotions/Sassy.png';
        label = 'Dui Dẻ';
        description = 'Vui vẻ, hài hước';
        accent = AppColors.teal;
        emoji = '😎';
        break;
    }

    return SizedBox(

      width: width,

      height: height,

      child: Stack(

        children: [

          Container(

            width: width,

            height: height,

            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(AppRadii.lg),

              border: Border.all(color: accent, width: 2.5),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withValues(alpha: 0.14),

                  blurRadius: 28,

                  offset: const Offset(0, 12),

                ),

              ],

            ),

            child: Column(

              mainAxisAlignment: MainAxisAlignment.center,

              mainAxisSize: MainAxisSize.min,

              children: [

                Flexible(

                  child: FittedBox(

                    fit: BoxFit.contain,

                    child: Image.asset(

                      asset,

                      width: width * 0.34,

                      height: width * 0.34,

                      errorBuilder: (_, e, s) => Text(emoji, style: TextStyle(fontSize: width * 0.2)),

                    ),

                  ),

                ),

                const SizedBox(height: 8),

                Text(

                  label,

                  style: Theme.of(context).textTheme.titleMedium?.copyWith(

                    fontWeight: FontWeight.w800,

                    color: accent,

                  ),

                ),

                const SizedBox(height: 2),

                Text(

                  description,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),

                ),

              ],

            ),

          ),

          if (lightSweep > 0.05)

            Positioned.fill(

              child: ClipRRect(

                borderRadius: BorderRadius.circular(AppRadii.lg),

                child: CustomPaint(painter: _CardLightSweepPainter(intensity: lightSweep)),

              ),

            ),

        ],

      ),

    );

  }



  Widget _cardBack() {

    return Container(

      width: width,

      height: height,

      decoration: BoxDecoration(

        color: const Color(0xFFF1F5F9),

        borderRadius: BorderRadius.circular(AppRadii.lg),

        border: Border.all(color: const Color(0xFFCBD5E1), width: 2),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.1),

            blurRadius: 20,

            offset: const Offset(0, 8),

          ),

        ],

      ),

      child: Column(

        mainAxisAlignment: MainAxisAlignment.center,

        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(Icons.auto_awesome_outlined, size: width * 0.18, color: const Color(0xFF94A3B8)),

          const SizedBox(height: 6),

          Text(

            'Mimo AI',

            style: TextStyle(

              fontSize: width * 0.065,

              fontWeight: FontWeight.w700,

              color: const Color(0xFF64748B),

            ),

          ),

        ],

      ),

    );

  }

}



class _CardLightSweepPainter extends CustomPainter {

  final double intensity;

  _CardLightSweepPainter({required this.intensity});



  @override

  void paint(Canvas canvas, Size size) {

    final paint = Paint()

      ..shader = LinearGradient(

        colors: [

          Colors.white.withValues(alpha: 0),

          Colors.white.withValues(alpha: 0.45 * intensity),

          Colors.white.withValues(alpha: 0),

        ],

      ).createShader(Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.4, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

  }



  @override

  bool shouldRepaint(covariant _CardLightSweepPainter old) => old.intensity != intensity;

}



class _SuccessToast extends StatefulWidget {

  final String label;

  const _SuccessToast({required this.label});



  @override

  State<_SuccessToast> createState() => _SuccessToastState();

}



class _SuccessToastState extends State<_SuccessToast> with SingleTickerProviderStateMixin {

  late final AnimationController _fade;



  @override

  void initState() {

    super.initState();

    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _fade.forward();

    Future.delayed(const Duration(milliseconds: 650), () {

      if (mounted) _fade.reverse();

    });

  }



  @override

  void dispose() {

    _fade.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    return FadeTransition(

      opacity: _fade,

      child: Container(

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        decoration: BoxDecoration(

          color: AppColors.teal,

          borderRadius: BorderRadius.circular(AppRadii.lg),

          boxShadow: AppShadows.soft,

        ),

        child: Row(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),

            const SizedBox(width: 8),

            Flexible(

              child: Text(

                widget.label,

                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),

                textAlign: TextAlign.center,

              ),

            ),

          ],

        ),

      ),

    );

  }

}


