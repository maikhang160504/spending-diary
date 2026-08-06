import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../goals/goal_screen.dart';
import 'loans_screen.dart';

class FinancialToolsScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? initialJoinCode;

  const FinancialToolsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialJoinCode,
  });

  @override
  State<FinancialToolsScreen> createState() => _FinancialToolsScreenState();
}

class _FinancialToolsScreenState extends State<FinancialToolsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialJoinCode != null && widget.initialJoinCode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFeatureCard(
          GoalScreen(
            isChallenge: true,
            initialJoinCode: widget.initialJoinCode,
          ),
        );
      });
    }
  }

  void _openFeatureCard(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const _ToolsHeader(),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quản lý và lập kế hoạch tài chính hiệu quả hơn với các bộ công cụ thông minh.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Use >480 so 2-col activates inside the 600px constrained box
                            final double cardWidth = constraints.maxWidth > 480
                                ? (constraints.maxWidth - 16) / 2
                                : constraints.maxWidth;
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildToolCard(
                                    context: context,
                                    icon: Icons.savings_rounded,
                                    iconColor: const Color(0xFF0D9488),
                                    iconBgColor: const Color(0xFFCCFBF1),
                                    title: 'Tiết kiệm',
                                    subtitle: 'Tích lũy cho mục tiêu tương lai',
                                    onTap: () => _openFeatureCard(
                                      const GoalScreen(isChallenge: false),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildToolCard(
                                    context: context,
                                    icon: Icons.track_changes_rounded,
                                    iconColor: const Color(0xFFD97706),
                                    iconBgColor: const Color(0xFFFEF3C7),
                                    title: 'Thử thách',
                                    subtitle: 'Tiết kiệm cùng bạn bè...',
                                    onTap: () => _openFeatureCard(
                                      GoalScreen(
                                        isChallenge: true,
                                        initialJoinCode: widget.initialJoinCode,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _buildToolCard(
                                    context: context,
                                    icon: Icons.handshake_rounded,
                                    iconColor: const Color(0xFF6366F1),
                                    iconBgColor: const Color(0xFFEDE9FE),
                                    title: 'Vay mượn',
                                    subtitle: 'Quản lý khoản vay và cho mượn',
                                    onTap: () =>
                                        _openFeatureCard(const LoansScreen()),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:
                              Theme.of(context).textTheme.bodyLarge?.color ??
                              Colors.black87,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolsHeader extends StatelessWidget {
  const _ToolsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadii.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ] else ...[
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calculate_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Công cụ tiền tệ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Quản lý và lập kế hoạch tài chính hiệu quả',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
