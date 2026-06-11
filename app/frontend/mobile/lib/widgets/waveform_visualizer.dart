import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class WaveformVisualizer extends StatefulWidget {
  final bool isAnimating;
  final double height;
  final double width;
  final Color color;

  const WaveformVisualizer({
    super.key,
    required this.isAnimating,
    this.height = 36.0,
    this.width = 80.0,
    this.color = AppColors.teal,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heightMultipliers = [0.3, 0.6, 0.9, 0.7, 0.4, 0.8, 0.5];
  final List<double> _speeds = [1.2, 1.8, 2.2, 1.5, 2.0, 2.5, 1.4];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_heightMultipliers.length, (index) {
              final double animatedValue = widget.isAnimating
                  ? sin((_controller.value * 2 * pi * _speeds[index])) * 0.5 + 0.5
                  : 0.2;
              final double height = widget.height * (0.2 + 0.8 * animatedValue * _heightMultipliers[index]);
              
              return Container(
                width: 4.0,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: widget.isAnimating ? 1.0 : 0.4),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
