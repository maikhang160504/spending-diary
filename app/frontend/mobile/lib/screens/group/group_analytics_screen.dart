import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_banner.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_palette.dart';
import '../../theme/categories.dart';
import 'package:fl_chart/fl_chart.dart';

class GroupAnalyticsScreen extends StatefulWidget {
  final String walletId;

  const GroupAnalyticsScreen({super.key, required this.walletId});

  @override
  State<GroupAnalyticsScreen> createState() => _GroupAnalyticsScreenState();
}

class _GroupAnalyticsScreenState extends State<GroupAnalyticsScreen> {
  final _api = ApiClient();
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _overview;
  List<dynamic> _categories = [];
  Map<String, dynamic>? _settlement;
  List<dynamic> _timeline = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getGroupOverview(widget.walletId),
        _api.getGroupCategories(widget.walletId),
        _api.getGroupSettlement(widget.walletId),
        _api.getGroupTimeline(widget.walletId),
      ]);

      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _categories = results[1] as List<dynamic>? ?? [];
        _settlement = results[2] as Map<String, dynamic>;
        _timeline = results[3] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        title: const Text(
          'Báo cáo Ví Nhóm',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: context.palette.bg,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: LoadingIndicator())
          : _error != null
          ? Center(
              child: ErrorBanner(message: _error!, onRetry: _fetchData),
            )
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOverviewSection(),
                  const SizedBox(height: 24),
                  _buildCategoriesSection(),
                  const SizedBox(height: 24),
                  _buildSettlementSection(),
                  const SizedBox(height: 24),
                  _buildTimelineSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewSection() {
    if (_overview == null) return const SizedBox.shrink();

    final totalIncome = (_overview!['totalFund'] as num?)?.toInt() ?? 0;
    final totalExpense = (_overview!['totalSpent'] as num?)?.toInt() ?? 0;
    final remaining = (_overview!['remaining'] as num?)?.toInt() ?? 0;

    // Calculate progress percentage
    double progress = 0;
    if (totalIncome > 0) {
      progress = totalExpense / totalIncome;
      if (progress > 1.0) progress = 1.0;
    } else if (totalExpense > 0) {
      progress = 1.0; // Over budget completely
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng quan Ngân sách',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quỹ (Thu)',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              Text(
                formatVnd(totalIncome),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã chi',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              Text(
                formatVnd(totalExpense),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppColors.teal.withValues(alpha: 0.2),
              color: progress > 0.8 ? AppColors.danger : AppColors.teal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Còn lại',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                formatVnd(remaining),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: remaining < 0
                      ? AppColors.danger
                      : context.palette.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi tiêu theo danh mục',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ..._categories.take(5).map((cat) {
            final code =
                cat['categoryCode'] as String? ??
                cat['category_code'] as String? ??
                'Others';
            final amount = (cat['total'] as num?)?.toInt() ?? 0;
            final percent = (cat['percent'] as num?)?.toDouble() ?? 0.0;
            final theme = CategoryTheme.of(code);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: theme.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              theme.icon,
                              size: 16,
                              color: theme.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            theme.label,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatVnd(amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                          Text(
                            '${percent.toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 6,
                      backgroundColor: theme.color.withValues(alpha: 0.1),
                      color: theme.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSettlementSection() {
    if (_settlement == null) return const SizedBox.shrink();

    final members = _settlement!['memberBalances'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi tiết Nộp/Chi của thành viên',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (members.isEmpty)
            const Text(
              'Chưa có dữ liệu thành viên',
              style: TextStyle(color: AppColors.muted),
            ),
          ...members.map((m) {
            final name =
                m['username'] as String? ?? m['email'] as String? ?? 'Unknown';
            final contributed = (m['contributed'] as num?)?.toInt() ?? 0;
            final spent = (m['spent'] as num?)?.toInt() ?? 0;
            final balance = (m['balance'] as num?)?.toInt() ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đã nộp: ${formatVnd(contributed)}  •  Đã chi: ${formatVnd(spent)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: balance > 0
                          ? AppColors.teal.withValues(alpha: 0.1)
                          : (balance < 0
                                ? AppColors.danger.withValues(alpha: 0.1)
                                : context.palette.surfaceAlt),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      balance > 0
                          ? 'Dư: +${formatVnd(balance)}'
                          : (balance < 0
                                ? 'Thiếu: ${formatVnd(balance)}'
                                : 'Đủ'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: balance > 0
                            ? AppColors.teal
                            : (balance < 0
                                  ? AppColors.danger
                                  : AppColors.muted),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    if (_timeline.isEmpty) return const SizedBox.shrink();

    // Get up to last 7 days
    final recent = _timeline.length > 7
        ? _timeline.sublist(_timeline.length - 7)
        : _timeline;
    double maxVal = 0;
    for (var t in recent) {
      final exp = (t['expense'] as num?)?.toDouble() ?? 0;
      if (exp > maxVal) maxVal = exp;
    }
    if (maxVal == 0) maxVal = 100000;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Biểu đồ chi tiêu (7 ngày gần nhất)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.palette.card,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        formatVnd(rod.toY.toInt()),
                        const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= recent.length) {
                          return const SizedBox.shrink();
                        }
                        final dayStr = recent[index]['day'] as String? ?? '';
                        final shortDay = dayStr.length >= 10
                            ? '${dayStr.substring(8, 10)}/${dayStr.substring(5, 7)}'
                            : dayStr;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            shortDay,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        );
                      },
                      reservedSize: 22,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(recent.length, (i) {
                  final amount =
                      (recent[i]['expense'] as num?)?.toDouble() ?? 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: amount,
                        color: AppColors.danger,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal * 1.2,
                          color: context.palette.surfaceAlt,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
