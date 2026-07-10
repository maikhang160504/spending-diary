import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AiAssistantPopupMenu extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onSelectBill;
  final VoidCallback onSelectPhotoText;
  final VoidCallback onSelectChat;

  const AiAssistantPopupMenu({
    super.key,
    required this.onClose,
    required this.onSelectBill,
    required this.onSelectPhotoText,
    required this.onSelectChat,
  });

  @override
  State<AiAssistantPopupMenu> createState() => AiAssistantPopupMenuState();
}

class AiAssistantPopupMenuState extends State<AiAssistantPopupMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _auraScale;
  late Animation<double> _auraOpacity;
  late Animation<double> _cardSlideY;
  late Animation<double> _cardScale;
  late Animation<double> _backdropOpacity;

  // Staggered animations for the 3 items
  late List<Animation<double>> _itemSlideY;
  late List<Animation<double>> _itemOpacity;

  double _dragOffset = 0.0;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Backdrop blur / dim animation
    _backdropOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Multi-colored aura blooming animation
    _auraScale = Tween<double>(begin: 0.2, end: 2.5).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _auraOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.8), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 0.0), weight: 60),
    ]).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Arc Card entry animation (Slide & Scale Y)
    _cardSlideY = Tween<double>(begin: 400.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _cardScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.2, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // Staggered list items animation
    _itemSlideY = List.generate(3, (index) {
      final start = 0.4 + (index * 0.08);
      final end = (start + 0.25).clamp(0.0, 1.0);
      return Tween<double>(begin: 40.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });

    _itemOpacity = List.generate(3, (index) {
      final start = 0.4 + (index * 0.08);
      final end = (start + 0.25).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    // Start entering
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void closePopup() => _close();

  void _close() {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    _ctrl.reverse().then((_) {
      widget.onClose();
    });
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isClosing) return;
    setState(() {
      _dragOffset = (_dragOffset + details.primaryDelta!).clamp(0.0, 500.0);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isClosing) return;
    if (_dragOffset > 80.0 || details.primaryVelocity! > 300) {
      // Swipe down to close
      _close();
    } else {
      // Snap back
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // 1. Backdrop Blur / Dim Background
        AnimatedBuilder(
          animation: _backdropOpacity,
          builder: (context, child) {
            return Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                child: Container(
                  color: Colors.black.withOpacity(_backdropOpacity.value * 0.65),
                  child: _backdropOpacity.value > 0.1
                      ? BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: _backdropOpacity.value * 6,
                            sigmaY: _backdropOpacity.value * 6,
                          ),
                          child: const SizedBox.expand(),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            );
          },
        ),

        // 3. Sliding Arc Card
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            // Apply drag offset for swipe down close gesture
            final double currentSlideY = _cardSlideY.value + _dragOffset;
            final double currentScale = (_cardScale.value - (_dragOffset / 1000)).clamp(0.7, 1.0);

            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Transform.translate(
                offset: Offset(0.0, currentSlideY),
                child: Transform.scale(
                  scale: currentScale,
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onVerticalDragUpdate: _handleVerticalDragUpdate,
                    onVerticalDragEnd: _handleVerticalDragEnd,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: Container(
            width: size.width,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.5)
                      : Colors.black.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle bar
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),

                // Title / Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.teal,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Trợ Lý Tài Chính Mimo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Chọn một phương thức để ghi chép hoặc trò chuyện cùng AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 3 Options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        index: 0,
                        icon: Icons.document_scanner_rounded,
                        title: 'Quét Hóa Đơn (Bill)',
                        subtitle: 'Tự động đọc và bóc tách dữ liệu hóa đơn',
                        color: const Color(0xFF14B8A6),
                        onTap: () {
                          _close();
                          widget.onSelectBill();
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        index: 1,
                        icon: Icons.add_photo_alternate_rounded,
                        title: 'Chụp ảnh + Ghi chú',
                        subtitle: 'Chụp hình đính kèm và nhập ghi chú nhanh',
                        color: const Color(0xFF06B6D4),
                        onTap: () {
                          _close();
                          widget.onSelectPhotoText();
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        index: 2,
                        icon: Icons.forum_rounded,
                        title: 'Trò Chuyện Với Mimo',
                        subtitle: 'Hỏi đáp, lập kế hoạch chi tiêu cùng chatbot',
                        color: const Color(0xFF3B82F6),
                        onTap: () {
                          _close();
                          widget.onSelectChat();
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _itemOpacity[index].value,
          child: Transform.translate(
            offset: Offset(0.0, _itemSlideY[index].value),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white24 : Colors.black26,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
