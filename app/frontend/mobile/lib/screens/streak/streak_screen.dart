import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/skeleton.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  final _api = ApiClient();
  bool _loading = true;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalDays = 0;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getStreak();
      if (!mounted) return;
      setState(() {
        _currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
        _longestStreak = (data['longestStreak'] as num?)?.toInt() ?? 0;
        _totalDays = (data['totalDays'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // ST-04: Achievements computed from streak data
  List<_Achievement> get _achievements => [
    _Achievement(emoji: '🔥', title: 'Streak đầu tiên', subtitle: 'Ghi chép 3 ngày liên tục', achieved: _currentStreak >= 3),
    _Achievement(emoji: '⚡', title: 'Tuần hoàn hảo', subtitle: 'Ghi chép 7 ngày liên tục', achieved: _currentStreak >= 7),
    _Achievement(emoji: '🏆', title: 'Tháng vàng', subtitle: 'Ghi chép 30 ngày liên tục', achieved: _currentStreak >= 30),
    _Achievement(emoji: '💎', title: 'Kỷ lục cá nhân', subtitle: 'Đạt streak dài nhất của bạn', achieved: _longestStreak > 0 && _currentStreak >= _longestStreak),
    _Achievement(emoji: '📊', title: 'Nhà phân tích', subtitle: 'Tổng cộng 50 ngày ghi chép', achieved: _totalDays >= 50),
    _Achievement(emoji: '🌟', title: 'Chuyên gia', subtitle: 'Tổng cộng 100 ngày ghi chép', achieved: _totalDays >= 100),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStreak,
          color: AppColors.teal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Container(
                decoration: const BoxDecoration(
                  gradient: AppGradients.teal,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadii.xl),
                    bottomRight: Radius.circular(AppRadii.xl),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 16, 24, 24),
                child: Row(children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Chuỗi ghi chép', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('Duy trì thói quen tốt mỗi ngày', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Streak summary card — ST-01 real data
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      boxShadow: context.palette.softShadow,
                    ),
                    child: Column(children: [
                      // Fire animation chạy khi đang giữ chuỗi thành công
                      SizedBox(
                        height: 96,
                        child: _currentStreak > 0
                            ? Lottie.asset(
                                'assets/animations/Fire.json',
                                height: 96,
                                repeat: true,
                                errorBuilder: (_, _, _) => const Text('🔥', style: TextStyle(fontSize: 48)),
                              )
                            : const Center(child: Text('🔥', style: TextStyle(fontSize: 48))),
                      ),
                      const SizedBox(height: 8),
                      _loading
                          ? const SkeletonLine(width: 80, height: 52)
                          : Text('$_currentStreak', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, fontSize: 52)),
                      Text('Ngày liên tục', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(child: _StatBox(
                          icon: Icons.emoji_events_outlined,
                          label: 'Kỷ lục',
                          value: _loading ? '...' : '$_longestStreak',
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _StatBox(
                          icon: Icons.calendar_today_outlined,
                          label: 'Tổng số ngày',
                          value: _loading ? '...' : '$_totalDays',
                        )),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // 30-day heatmap — ST-02 from streak data
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      boxShadow: context.palette.softShadow,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('30 ngày gần nhất', style: Theme.of(context).textTheme.titleSmall),
                        const Icon(Icons.trending_up, color: AppColors.teal, size: 18),
                      ]),
                      const SizedBox(height: 14),
                      _StreakGrid(currentStreak: _currentStreak),
                      const SizedBox(height: 10),
                      Text('Mỗi ô màu xanh = 1 ngày có giao dịch ✓',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // Achievements — ST-04 computed
                  Row(children: [
                    const Icon(Icons.emoji_events, color: AppColors.teal, size: 18),
                    const SizedBox(width: 6),
                    Text('Thành tích', style: Theme.of(context).textTheme.titleSmall),
                  ]),
                  const SizedBox(height: 12),
                  ..._achievements.map((a) => _AchievementCard(item: a)),
                  const SizedBox(height: 20),
                  // Tips
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Mẹo duy trì streak', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFF16A34A))),
                      const SizedBox(height: 10),
                      const _TipRow(emoji: '💡', text: 'Ghi chép mỗi ngày giúp bạn kiểm soát chi tiêu tốt hơn'),
                      const _TipRow(emoji: '🎯', text: 'Streak càng dài, bạn càng hiểu rõ thói quen chi tiêu của mình'),
                      const _TipRow(emoji: '🔥', text: 'Đừng phá chuỗi! Mỗi ngày chỉ cần 1 giao dịch là được'),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Streak Grid (ST-02) ───────────────────────────────────────────────────────

class _StreakGrid extends StatelessWidget {
  final int currentStreak;
  const _StreakGrid({required this.currentStreak});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // ST-03: "Hôm nay" pill dynamic
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        // index 0 = 29 days ago, index 29 = today
        final dayOffset = 29 - index;
        final isActive = dayOffset < currentStreak;
        final isToday = dayOffset == 0;
        final date = today.subtract(Duration(days: dayOffset));

        return Tooltip(
          message: '${date.day}/${date.month}',
          child: Column(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isActive ? AppColors.teal : context.palette.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: isActive
                    ? Center(child: Text('🔥', style: TextStyle(fontSize: isToday ? 10 : 9)))
                    : null,
              ),
            ),
            if (isToday)
              const Text('Hôm\nnay', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 7, color: AppColors.teal, fontWeight: FontWeight.w600)),
          ]),
        );
      },
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatBox({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: context.palette.surfaceAlt, borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Column(children: [
        Icon(icon, color: AppColors.teal, size: 22),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Achievement {
  final String emoji, title, subtitle;
  final bool achieved;
  const _Achievement({required this.emoji, required this.title, required this.subtitle, required this.achieved});
}

class _AchievementCard extends StatelessWidget {
  final _Achievement item;
  const _AchievementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: context.palette.softShadow,
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: item.achieved ? AppColors.teal.withValues(alpha: 0.12) : context.palette.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ])),
        if (item.achieved)
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          )
        else
          const Icon(Icons.lock_outline, color: AppColors.muted, size: 22),
      ]),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String emoji, text;
  const _TipRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}
