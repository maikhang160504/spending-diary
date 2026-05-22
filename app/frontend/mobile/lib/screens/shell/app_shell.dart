import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/mimo_overlay.dart';

/// AppShell wraps the 4 ShellRoute tabs + persistent bottom nav + MiMo overlay
class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    mimoController.addListener(_onMiMoChanged);
  }

  @override
  void dispose() {
    mimoController.removeListener(_onMiMoChanged);
    super.dispose();
  }

  void _onMiMoChanged() => setState(() {});

  static int _tabIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith(AppRoutes.report))   return 1;
    if (loc.startsWith(AppRoutes.goals))    return 2;
    if (loc.startsWith(AppRoutes.settings)) return 3;
    return 0;
  }

  void _onTabTap(BuildContext context, int index) {
    const routes = [AppRoutes.home, AppRoutes.report, AppRoutes.goals, AppRoutes.settings];
    context.go(routes[index]);
  }

  // FAB → BottomSheet với 2 options: Nhập tay / Chụp bill (SH-01)
  void _onFabTap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _FabBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _tabIndex(context);

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          // MiMo overlay — góc phải dưới, ngay trên nav bar
          if (mimoController.current != null)
            Positioned(
              right: 12,
              bottom: 88,
              child: MiMoOverlay(
                response: mimoController.current!,
                onDismiss: mimoController.dismiss,
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
          boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', isActive: currentIndex == 0, onTap: () => _onTabTap(context, 0)),
                    _NavItem(icon: Icons.trending_up_outlined, activeIcon: Icons.trending_up, label: 'Report', isActive: currentIndex == 1, onTap: () => _onTabTap(context, 1)),
                    const Expanded(child: SizedBox()), // gap for FAB
                    _NavItem(icon: Icons.radio_button_unchecked_outlined, activeIcon: Icons.adjust_rounded, label: 'Goals', isActive: currentIndex == 2, onTap: () => _onTabTap(context, 2)),
                    _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings', isActive: currentIndex == 3, onTap: () => _onTabTap(context, 3)),
                  ],
                ),
                // FAB raised above bar (SH-02: animated rotation on tap)
                Positioned(
                  top: -22,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _AnimatedFab(onTap: () => _onFabTap(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav Item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.teal : const Color(0xFF94A3B8);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(isActive ? activeIcon : icon, color: color, size: 24, key: ValueKey(isActive)),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: color),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}

// ── Animated FAB (SH-02) ─────────────────────────────────────────────────────

class _AnimatedFab extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedFab({required this.onTap});

  @override
  State<_AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<_AnimatedFab> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _rotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_ctrl.isCompleted) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Center(
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x4014B8A6), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: AnimatedBuilder(
              animation: _rotation,
              builder: (_, child) => Transform.rotate(
                angle: _rotation.value * 0.785398, // 45 degrees
                child: child,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

// ── FAB BottomSheet (SH-01) ──────────────────────────────────────────────────

class _FabBottomSheet extends StatelessWidget {
  const _FabBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 20),
        Text('Thêm giao dịch', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: _SheetOption(
              emoji: '✏️',
              label: 'Nhập tay',
              subtitle: 'Điền thông tin thủ công',
              color: AppColors.teal,
              onTap: () {
                context.pop();
                context.push(AppRoutes.addTransaction);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SheetOption(
              emoji: '📷',
              label: 'Chụp bill',
              subtitle: 'AI nhận dạng tự động',
              color: const Color(0xFF6366F1),
              onTap: () {
                context.pop();
                context.push(AppRoutes.camera);
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final String emoji, label, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SheetOption({required this.emoji, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
