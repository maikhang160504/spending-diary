import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import '../../services/app_queries.dart';
import '../../services/transaction_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _selectedRange = '7 ngày';
  String? _selectedWalletId;
  List<dynamic> _wallets = [];

  // API data
  bool _loading = true;
  int _totalExpense = 0;
  int _totalIncome = 0;
  List<ReportCategory> _categoryStats = [];
  List<ReportBar> _reportBars = [];
  List<TrendPoint> _trendPoints = [];
  List<ReportMoM> _momStats = [];
  int _cumulativeLimit = 0;
  List<CumulativePoint> _cumulativePoints = [];

  ReportCategory _toCat(Map<String, dynamic> row) {
    final code = row['categoryCode'] as String? ?? 'Others';
    // Dùng CategoryTheme làm nguồn chuẩn để khớp ảnh trong assets/MiMo/category.
    final style = CategoryTheme.of(code);
    return ReportCategory(
      code: code,
      label: style.label,
      emoji: style.emoji,
      percent: (row['percent'] as num?)?.toDouble() ?? 0,
      amount: (row['total'] as num?)?.toInt() ?? 0,
      color: style.color.toARGB32(),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadStats();
    transactionNotifier.addListener(_onTransactionChanged);
  }

  @override
  void dispose() {
    transactionNotifier.removeListener(_onTransactionChanged);
    super.dispose();
  }

  void _onTransactionChanged() {
    if (!mounted) return;
    AppQueries.invalidateWalletData();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final rangeParam = _selectedRange == '7 ngày' ? 'week'
        : _selectedRange == '30 ngày' ? 'month'
        : null;

    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    if (_selectedRange == '7 ngày') {
      startDate = now.subtract(const Duration(days: 6));
    } else if (_selectedRange == '30 ngày') {
      startDate = now.subtract(const Duration(days: 29));
    } else {
      startDate = DateTime(now.year, now.month, 1);
    }

    final fromStr = startDate.toIso8601String();
    final toStr = endDate.toIso8601String();

    final hasCache = AppQueries.statsByCategory(rangeParam, _selectedWalletId, from: fromStr, to: toStr).state.data != null;
    setState(() => _loading = !hasCache);
    try {
      final walletsResult = await AppQueries.wallets().result;
      final wallets = walletsResult.data ?? [];

      final dashF = AppQueries.dashboard(_selectedWalletId, from: fromStr, to: toStr).result;
      final catsF = AppQueries.statsByCategory(rangeParam, _selectedWalletId, from: fromStr, to: toStr).result;
      final monthlyF = AppQueries.statsByMonth(now.year, _selectedWalletId).result;

      final dashboard = (await dashF).data ?? <String, dynamic>{};
      final cats = (await catsF).data ?? <dynamic>[];
      final monthly = (await monthlyF).data ?? <dynamic>[];

      List<dynamic>? momData;
      Map<String, dynamic>? cumulativeData;
      if (_selectedRange == 'Theo tháng') {
        final momRes = await AppQueries.statsMoM(_selectedWalletId).result;
        final cumRes = await AppQueries.statsCumulativeVsBudget(_selectedWalletId).result;
        momData = momRes.data;
        cumulativeData = cumRes.data;
      }

      if (!mounted) return;

      final totals = dashboard['totals'] as Map<String, dynamic>?;
      final byDay = (dashboard['byDay'] as List<dynamic>?) ?? [];

      setState(() {
        _wallets = wallets;
        _totalExpense = (totals?['expense'] as num?)?.toInt() ?? 0;
        _totalIncome = (totals?['income'] as num?)?.toInt() ?? 0;
        _categoryStats = cats.map((c) => _toCat(c as Map<String, dynamic>)).toList();
        _reportBars = byDay.map((d) {
          final e = d as Map<String, dynamic>;
          final dayStr = e['day'] as String? ?? '';
          final label = dayStr.length >= 10 ? dayStr.substring(8, 10) : '';
          return ReportBar(label: label, amount: (e['expense'] as num?)?.toInt() ?? 0);
        }).toList();

        _trendPoints = monthly.map((m) {
          final e = m as Map<String, dynamic>;
          final monthStr = e['month'] as String? ?? '';
          final parts = monthStr.split('-');
          final monthNum = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final income = (e['income'] as num?)?.toInt() ?? 0;
          final expense = (e['expense'] as num?)?.toInt() ?? 0;
          return TrendPoint(label: 'T$monthNum', amount: income - expense);
        }).toList();

        if (momData != null) {
          _momStats = momData.map((m) {
            final e = m as Map<String, dynamic>;
            final code = e['categoryCode'] as String? ?? 'Others';
            final style = CategoryTheme.of(code);
            return ReportMoM(
              code: code,
              label: style.label,
              emoji: style.emoji,
              thisMonth: (e['thisMonth'] as num?)?.toInt() ?? 0,
              lastMonth: (e['lastMonth'] as num?)?.toInt() ?? 0,
              color: style.color.toARGB32(),
            );
          }).toList();
        } else {
          _momStats = [];
        }

        if (cumulativeData != null) {
          _cumulativeLimit = (cumulativeData['limit'] as num?)?.toInt() ?? 0;
          final list = (cumulativeData['dailyCumulative'] as List<dynamic>?) ?? [];
          final totalDays = list.length;
          _cumulativePoints = List.generate(totalDays, (index) {
            final e = list[index] as Map<String, dynamic>;
            final dayStr = e['day'] as String? ?? '';
            final label = dayStr.length >= 10 ? dayStr.substring(8, 10) : '';
            final cumulative = (e['cumulative'] as num?)?.toInt() ?? 0;
            final budgetLimitLine = totalDays > 0
                ? (_cumulativeLimit.toDouble() / totalDays) * (index + 1)
                : 0.0;
            return CumulativePoint(
              dayLabel: label,
              cumulativeAmount: cumulative,
              budgetLimitLine: budgetLimitLine,
            );
          });
        } else {
          _cumulativeLimit = 0;
          _cumulativePoints = [];
        }
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasSavingsData = _trendPoints.isNotEmpty && _trendPoints.any((p) => p.amount != 0);

    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: AppColors.teal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReportHeader(
                  selectedWalletId: _selectedWalletId,
                  wallets: _wallets,
                  onWalletChanged: (v) {
                    setState(() => _selectedWalletId = v);
                    _loadStats();
                  },
                ),
                const SizedBox(height: 16),
                _RangeTabs(
                  selected: _selectedRange,
                  onChanged: (v) {
                    setState(() => _selectedRange = v);
                    _loadStats();
                  },
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total card — dynamic from API
                      _TotalCard(
                        totalExpense: _totalExpense,
                        totalIncome: _totalIncome,
                        loading: _loading,
                      ),
                      const SizedBox(height: 20),
                      // Bar chart (mock for now) / MoM Grouped Bar Chart
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.palette.card,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          boxShadow: context.palette.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedRange == 'Theo tháng'
                                  ? 'So sánh tháng này vs tháng trước'
                                  : 'Chi tiêu theo ngày',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (_selectedRange == 'Theo tháng') ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCBD5E1),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Tháng trước', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500)),
                                  const SizedBox(width: 16),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.teal,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Tháng này', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            _selectedRange == 'Theo tháng'
                                ? _MoMGroupedBarChart(stats: _momStats)
                                : (_reportBars.isEmpty
                                    ? const Center(child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 24),
                                        child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.muted))))
                                    : _BarChart(bars: _reportBars)),
                          ],
                        ),
                      ),
                      if (_selectedRange == 'Theo tháng') ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.palette.card,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            boxShadow: context.palette.softShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chi tiêu lũy kế so với hạn mức', style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 2,
                                    color: AppColors.danger.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Hạn mức ngân sách', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500)),
                                  const SizedBox(width: 16),
                                  Container(
                                    width: 16,
                                    height: 3,
                                    color: AppColors.teal,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Lũy kế thực tế', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _CumulativeBudgetLineChart(points: _cumulativePoints, limit: _cumulativeLimit),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Donut chart — real API data
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.palette.card,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          boxShadow: context.palette.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chi tiêu theo danh mục', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 20),
                            _categoryStats.isEmpty
                                ? const Center(child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.muted))))
                                : _DonutChart(categories: _categoryStats),
                            if (_categoryStats.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _CategoryLegend(categories: _categoryStats),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Top category card — real API data
                      _TopCategoryCard(top: _categoryStats.isNotEmpty ? _categoryStats.first : null),
                      const SizedBox(height: 20),
                      // Trend chart (mock for now)
                      if (hasSavingsData) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.palette.card,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            boxShadow: context.palette.softShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Xu hướng tiết kiệm (3 tháng)', style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 16),
                              _TrendChart(points: _trendPoints),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      const SizedBox(height: 24),
                    ],
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

class _ReportHeader extends StatelessWidget {
  final String? selectedWalletId;
  final List<dynamic> wallets;
  final ValueChanged<String?> onWalletChanged;

  const _ReportHeader({
    required this.selectedWalletId,
    required this.wallets,
    required this.onWalletChanged,
  });

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return AppColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Báo cáo',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Phân tích và theo dõi thói quen chi tiêu',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedWalletId,
                dropdownColor: context.palette.card,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                onChanged: onWalletChanged,
                selectedItemBuilder: (BuildContext context) {
                  return [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.all_inclusive, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Tất cả ví cá nhân',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    ...wallets.map((w) {
                      final isGroup = w['type'] == 'group';
                      final colorHex = w['color'] as String? ?? '#3B82F6';
                      final color = _parseColor(colorHex);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGroup ? Icons.group : Icons.account_balance_wallet,
                            color: color,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            w['name'] as String? ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }),
                  ];
                },
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        const Icon(Icons.all_inclusive, color: AppColors.teal, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Tất cả ví cá nhân',
                          style: TextStyle(color: context.palette.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  ...wallets.map((w) {
                    final isGroup = w['type'] == 'group';
                    final colorHex = w['color'] as String? ?? '#3B82F6';
                    final color = _parseColor(colorHex);
                    return DropdownMenuItem<String?>(
                      value: w['id'] as String,
                      child: Row(
                        children: [
                          Icon(
                            isGroup ? Icons.group : Icons.account_balance_wallet,
                            color: color,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            w['name'] as String? ?? 'Ví không tên',
                            style: TextStyle(color: context.palette.textPrimary),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _RangeTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = ['7 ngày', '30 ngày', 'Theo tháng'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: options.map((label) => Expanded(
            child: GestureDetector(
              onTap: () => onChanged(label),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected == label ? context.palette.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  boxShadow: selected == label ? context.palette.softShadow : null,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected == label ? AppColors.teal : AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final int totalExpense;
  final int totalIncome;
  final bool loading;

  const _TotalCard({required this.totalExpense, required this.totalIncome, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng chi tiêu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              if (totalIncome > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: totalExpense < totalIncome ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(children: [
                    Icon(
                      totalExpense < totalIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 12,
                      color: totalExpense < totalIncome ? const Color(0xFF10B981) : AppColors.danger,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      totalIncome > 0 ? '${((totalExpense / totalIncome) * 100).toStringAsFixed(1)}% thu nhập' : '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: totalExpense < totalIncome ? const Color(0xFF10B981) : AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 6),
          loading
              ? Text('...', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 28))
              : Text(formatVnd(totalExpense), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 28)),
          const SizedBox(height: 4),
          Text('Thu nhập: ${loading ? '...' : formatVnd(totalIncome)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<ReportBar> bars;

  const _BarChart({required this.bars});

  @override
  Widget build(BuildContext context) {
    final maxAmount = bars.map((b) => b.amount).fold<int>(0, (a, b) => a > b ? a : b);
    final interval = _niceInterval(maxAmount.toDouble());

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAmount > 0 ? (maxAmount * 1.2) : 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  formatVnd(rod.toY.toInt()),
                  TextStyle(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
                  final idx = value.toInt();
                  if (idx < 0 || idx >= bars.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      bars[idx].label,
                      style: TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  );
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: interval > 0 ? interval : null,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _shortAmount(value),
                    style: const TextStyle(color: AppColors.muted, fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 12,
                getTitlesWidget: (value, meta) => const SizedBox.shrink(),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval > 0 ? interval : null,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.muted.withValues(alpha: 0.15),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(bars.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bars[i].amount.toDouble(),
                  width: bars.length > 15 ? 8 : 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5EEAD4), AppColors.teal],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  static double _niceInterval(double max) {
    if (max <= 0) return 100000;
    final rough = max / 4;
    final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor());
    return (rough / magnitude).ceil() * magnitude.toDouble();
  }

  static String _shortAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toInt().toString();
  }
}

class _DonutChart extends StatefulWidget {
  final List<ReportCategory> categories;

  const _DonutChart({required this.categories});

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.categories.fold<int>(0, (s, c) => s + c.amount);
    return Center(
      child: SizedBox(
        height: 200,
        width: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: List.generate(widget.categories.length, (i) {
                  final cat = widget.categories[i];
                  final isTouched = i == _touchedIndex;
                  return PieChartSectionData(
                    color: Color(cat.color),
                    value: cat.percent,
                    title: isTouched ? '${cat.percent.toStringAsFixed(1)}%' : '',
                    radius: isTouched ? 44 : 36,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    titlePositionPercentageOffset: 0.55,
                  );
                }),
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),
            // Center total
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tổng',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  formatVnd(totalAmount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.palette.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  final List<ReportCategory> categories;

  const _CategoryLegend({required this.categories});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: categories.map((cat) => Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color(cat.color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: CategoryTheme.iconOf(cat.code, size: 18)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${cat.label}\n${cat.percent.toStringAsFixed(1)}% · ${formatVnd(cat.amount)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        ],
      )).toList(),
    );
  }
}

class _TopCategoryCard extends StatelessWidget {
  final ReportCategory? top;
  const _TopCategoryCard({this.top});

  @override
  Widget build(BuildContext context) {
    if (top == null) return const SizedBox.shrink();
    final catColor = Color(top!.color);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Danh mục chi nhiều nhất', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Center(child: CategoryTheme.iconOf(top!.code, size: 32)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(top!.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(formatVnd(top!.amount), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: catColor, fontWeight: FontWeight.w700, fontSize: 20)),
                  Text('${top!.percent.toStringAsFixed(0)}% tổng chi tiêu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<TrendPoint> points;

  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxAmt = points.map((p) => p.amount.toDouble()).fold<double>(0, (a, b) => a > b ? a : b);
    final minAmt = points.map((p) => p.amount.toDouble()).fold<double>(double.infinity, (a, b) => a < b ? a : b);
    final range = maxAmt - minAmt;
    final yMax = maxAmt + (range * 0.2).clamp(100000, double.infinity);
    final yMin = (minAmt - (range * 0.2)).clamp(0, double.infinity).toDouble();

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: yMin,
          maxY: yMax > yMin ? yMax : yMin + 100000,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    formatVnd(spot.y.toInt()),
                    TextStyle(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: range > 0 ? range / 3 : null,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.muted.withValues(alpha: 0.12),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      points[idx].label,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _shortAmount(value),
                    style: const TextStyle(color: AppColors.muted, fontSize: 9),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 12,
                getTitlesWidget: (value, meta) => const SizedBox.shrink(),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(points.length, (i) {
                return FlSpot(i.toDouble(), points[i].amount.toDouble());
              }),
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.teal,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: AppColors.teal,
                    strokeWidth: 2.5,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.teal.withValues(alpha: 0.25),
                    AppColors.teal.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  static String _shortAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toInt().toString();
  }
}

class _MoMGroupedBarChart extends StatelessWidget {
  final List<ReportMoM> stats;

  const _MoMGroupedBarChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Chưa có dữ liệu so sánh',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    double maxVal = 100;
    for (final s in stats) {
      if (s.thisMonth > maxVal) maxVal = s.thisMonth.toDouble();
      if (s.lastMonth > maxVal) maxVal = s.lastMonth.toDouble();
    }
    final interval = _niceInterval(maxVal);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final isThisMonth = rodIndex == 1;
                final monthStr = isThisMonth ? 'Tháng này' : 'Tháng trước';
                return BarTooltipItem(
                  '$monthStr\n${formatVnd(rod.toY.toInt())}',
                  TextStyle(
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
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
                  final idx = value.toInt();
                  if (idx < 0 || idx >= stats.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      stats[idx].emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
                reservedSize: 24,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: interval > 0 ? interval : null,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _shortAmount(value),
                    style: const TextStyle(color: AppColors.muted, fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 12,
                getTitlesWidget: (value, meta) => const SizedBox.shrink(),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval > 0 ? interval : null,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.muted.withValues(alpha: 0.12),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(stats.length, (i) {
            final item = stats[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: item.lastMonth.toDouble(),
                  color: const Color(0xFFCBD5E1),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: item.thisMonth.toDouble(),
                  color: Color(item.color),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  static double _niceInterval(double max) {
    if (max <= 0) return 100000;
    final rough = max / 4;
    final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor());
    return (rough / magnitude).ceil() * magnitude.toDouble();
  }

  static String _shortAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toInt().toString();
  }
}

class _CumulativeBudgetLineChart extends StatelessWidget {
  final List<CumulativePoint> points;
  final int limit;

  const _CumulativeBudgetLineChart({required this.points, required this.limit});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Chưa có dữ liệu hạn mức tháng',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    final maxCumulative = points.map((p) => p.cumulativeAmount.toDouble()).fold<double>(0, (a, b) => a > b ? a : b);
    final maxLimit = limit.toDouble();
    final yMax = (maxCumulative > maxLimit ? maxCumulative : maxLimit) * 1.15;
    final double interval = yMax > 0 ? yMax / 4 : 100000;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: yMax > 0 ? yMax : 100000,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final isLimit = spot.barIndex == 0;
                  final label = isLimit ? 'Hạn mức tuyến tính' : 'Lũy kế thực tế';
                  return LineTooltipItem(
                    '$label\n${formatVnd(spot.y.toInt())}',
                    TextStyle(
                      color: isLimit ? AppColors.danger : AppColors.teal,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval > 0 ? interval : null,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.muted.withValues(alpha: 0.12),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: points.length > 15 ? 5 : 2,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      points[idx].dayLabel,
                      style: const TextStyle(color: AppColors.muted, fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _shortAmount(value),
                    style: const TextStyle(color: AppColors.muted, fontSize: 9),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 12,
                getTitlesWidget: (value, meta) => const SizedBox.shrink(),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(points.length, (i) {
                return FlSpot(i.toDouble(), points[i].budgetLimitLine);
              }),
              isCurved: false,
              color: AppColors.danger.withValues(alpha: 0.7),
              barWidth: 2,
              dashArray: [5, 5],
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: List.generate(points.length, (i) {
                return FlSpot(i.toDouble(), points[i].cumulativeAmount.toDouble());
              }),
              isCurved: true,
              curveSmoothness: 0.2,
              color: AppColors.teal,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.teal.withValues(alpha: 0.15),
                    AppColors.teal.withValues(alpha: 0.01),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shortAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toInt().toString();
  }
}