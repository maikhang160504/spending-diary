import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
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

  // FAB → mở thẳng camera_screen
  void _onFabTap(BuildContext context) {
    context.push(AppRoutes.camera);
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
              bottom: 88, // above nav bar
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
                // FAB raised above bar with outer ring
                Positioned(
                  top: -22,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _onFabTap(context),
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
                            child: const Icon(Icons.add, color: Colors.white, size: 26),
                          ),
                        ),
                      ),
                    ),
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
