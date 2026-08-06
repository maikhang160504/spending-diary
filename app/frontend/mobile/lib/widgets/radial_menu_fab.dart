import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RadialMenuFab extends StatefulWidget {
  final VoidCallback onSelectChat;
  final VoidCallback onSelectBill;
  final VoidCallback onSelectPhoto;
  final VoidCallback onSelectReport;
  final Color? accentColor;

  const RadialMenuFab({
    super.key,
    required this.onSelectChat,
    required this.onSelectBill,
    required this.onSelectPhoto,
    required this.onSelectReport,
    this.accentColor,
  });

  @override
  State<RadialMenuFab> createState() => _RadialMenuFabState();
}

class _RadialMenuFabState extends State<RadialMenuFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpen = false;
  final double _radius = 90.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  Widget _buildItem(
    double angle,
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    // angle in radians
    final double rad = angle * math.pi / 180.0;
    // Tọa độ gốc dưới phải, bay lên và sang trái
    final double x = -_radius * math.cos(rad);
    final double y = -_radius * math.sin(rad);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(x * _controller.value, y * _controller.value),
          child: Transform.scale(
            scale: _controller.value,
            child: Opacity(
              opacity: _controller.value,
              child: Tooltip(
                message: tooltip,
                preferBelow: false,
                verticalOffset: 24,
                child: FloatingActionButton.small(
                  heroTag: tooltip, // unique tag to avoid hero conflicts
                  onPressed: () {
                    _toggle();
                    onTap();
                  },
                  backgroundColor: context.theme.cardColor,
                  foregroundColor: widget.accentColor ?? AppColors.teal,
                  elevation: 4,
                  child: Icon(icon, size: 20),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.accentColor ?? AppColors.teal;
    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          // If open, add a transparent barrier to close when tapping outside
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggle,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
          // Báo cáo (0°)
          _buildItem(0, Icons.bar_chart, 'Báo cáo', widget.onSelectReport),
          // Ảnh (30°)
          _buildItem(30, Icons.image_outlined, 'Tải ảnh', widget.onSelectPhoto),
          // Quét Bill (60°)
          _buildItem(
            60,
            Icons.document_scanner_outlined,
            'Quét Bill',
            widget.onSelectBill,
          ),
          // Chat (90°)
          _buildItem(
            90,
            Icons.chat_bubble_outline,
            'Chat với AI',
            widget.onSelectChat,
          ),

          // Main Trigger Button
          FloatingActionButton(
            heroTag: 'main_radial_fab',
            onPressed: _toggle,
            backgroundColor: activeColor,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle:
                      _controller.value * math.pi / 4, // Xoay 45 độ thành dấu X
                  child: Icon(
                    _isOpen ? Icons.close : Icons.auto_awesome,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension on BuildContext {
  ThemeData get theme => Theme.of(this);
}
