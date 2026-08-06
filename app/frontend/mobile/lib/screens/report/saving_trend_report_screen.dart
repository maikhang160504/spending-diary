import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../services/app_queries.dart';
import '../../services/ai_advisor_service.dart';
import '../../widgets/report_filter_bar.dart';

class SavingTrendReportScreen extends StatefulWidget {
  final String? initialWalletId;
  const SavingTrendReportScreen({super.key, this.initialWalletId});

  @override
  State<SavingTrendReportScreen> createState() =>
      _SavingTrendReportScreenState();
}

class _SavingTrendReportScreenState extends State<SavingTrendReportScreen> {
  String _selectedPeriod =
      'Theo tháng'; // 'Theo tuần', 'Theo tháng', 'Theo năm'
  bool _isAnalyzingAI = false;
  int _periodOffset = 0;
  String? _aiInsight;
  List<Map<String, dynamic>> _wallets = [];
  String? _selectedWalletId;
  bool _isLoading = true;

  // Dữ liệu thực tế
  List<String> _chartLabels = [];
  List<double> _chartValues = [];
  List<Map<String, dynamic>> _detailList = [];
  int _totalIncome = 0;
  int _totalExpense = 0;
  int _netSaving = 0;
  double _savingRate = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
    _loadReportData();
  }

  String _getPeriodLabel() {
    final now = DateTime.now();
    if (_selectedPeriod == 'Theo tuần') {
      if (_periodOffset == 0) return 'Tuần hiện tại';
      final startOfWeek = now
          .subtract(Duration(days: now.weekday - 1))
          .subtract(Duration(days: 7 * _periodOffset));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return '${DateFormat('dd/MM').format(startOfWeek)} - ${DateFormat('dd/MM').format(endOfWeek)}';
    } else if (_selectedPeriod == 'Theo tháng') {
      if (_periodOffset == 0) return 'Tháng hiện tại';
      final targetMonth = DateTime(now.year, now.month - _periodOffset, 1);
      return 'Tháng ${targetMonth.month}/${targetMonth.year}';
    } else {
      final targetYear = now.year - _periodOffset;
      if (_periodOffset == 0) return 'Năm $targetYear (Hiện tại)';
      return 'Năm $targetYear';
    }
  }

  Future<void> _loadReportData() async {
    _aiInsight = null;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();

      // 1. Tải danh sách ví
      final walletsRes = await AppQueries.wallets().result;
      final rawWallets = walletsRes.data ?? [];
      final wallets = <Map<String, dynamic>>[];
      for (final w in rawWallets) {
        if (w is Map<String, dynamic> && w['type'] != 'group') wallets.add(w);
      }

      List<String> labels = [];
      List<double> values = [];
      List<Map<String, dynamic>> details = [];
      int totalInc = 0;
      int totalExp = 0;

      if (_selectedPeriod == 'Theo tuần') {
        final startOfWeek = now
            .subtract(Duration(days: now.weekday - 1))
            .subtract(Duration(days: 7 * _periodOffset));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final fromStr = DateFormat('yyyy-MM-dd').format(startOfWeek);
        final toStr = DateFormat('yyyy-MM-dd').format(endOfWeek);

        final dashRes = await AppQueries.dashboard(
          _selectedWalletId,
          from: fromStr,
          to: toStr,
        ).result;
        final dashData = dashRes.data ?? {};
        final byDay = (dashData['byDay'] as List<dynamic>?) ?? [];

        labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

        for (int i = 0; i < 7; i++) {
          final dayData = i < byDay.length
              ? (byDay[i] as Map<String, dynamic>)
              : null;
          final inc = (dayData?['income'] as num?)?.toInt() ?? 0;
          final exp = (dayData?['expense'] as num?)?.toInt() ?? 0;
          final net = inc - exp;

          totalInc += inc;
          totalExp += exp;
          values.add(net.toDouble());

          final dayDate = startOfWeek.add(Duration(days: i));
          details.add({
            'title': '${labels[i]} (${DateFormat('dd/MM').format(dayDate)})',
            'income': inc,
            'expense': exp,
            'net': net,
          });
        }
      } else if (_selectedPeriod == 'Theo tháng') {
        final targetMonth = DateTime(now.year, now.month - _periodOffset, 1);
        final targetMonthEnd = DateTime(
          now.year,
          now.month - _periodOffset + 1,
          0,
        );
        final fromStr = DateFormat('yyyy-MM-dd').format(targetMonth);
        final toStr = DateFormat('yyyy-MM-dd').format(targetMonthEnd);

        final dashRes = await AppQueries.dashboard(
          _selectedWalletId,
          from: fromStr,
          to: toStr,
        ).result;
        final dashData = dashRes.data ?? {};
        final byDay = (dashData['byDay'] as List<dynamic>?) ?? [];

        final daysInMonth = targetMonthEnd.day;
        final List<Map<String, int>> weeks = [
          {'income': 0, 'expense': 0},
          {'income': 0, 'expense': 0},
          {'income': 0, 'expense': 0},
          {'income': 0, 'expense': 0},
          if (daysInMonth > 28) {'income': 0, 'expense': 0},
        ];

        for (final d in byDay) {
          final map = d as Map<String, dynamic>;
          final dayStr = map['day']?.toString() ?? '';
          if (dayStr.length >= 10) {
            final dayNum = int.tryParse(dayStr.substring(8, 10)) ?? 1;
            int weekIdx = (dayNum - 1) ~/ 7;
            if (weekIdx >= weeks.length) weekIdx = weeks.length - 1;
            weeks[weekIdx]['income'] =
                (weeks[weekIdx]['income'] ?? 0) +
                ((map['income'] as num?)?.toInt() ?? 0);
            weeks[weekIdx]['expense'] =
                (weeks[weekIdx]['expense'] ?? 0) +
                ((map['expense'] as num?)?.toInt() ?? 0);
          }
        }

        for (int i = 0; i < weeks.length; i++) {
          final label = 'Tuần ${i + 1}';
          labels.add(label);

          final inc = weeks[i]['income'] ?? 0;
          final exp = weeks[i]['expense'] ?? 0;
          final net = inc - exp;

          totalInc += inc;
          totalExp += exp;
          values.add(net.toDouble());

          final startDay = i * 7 + 1;
          final endDay = (i == weeks.length - 1) ? daysInMonth : (i + 1) * 7;
          details.add({
            'title': 'Tuần ${i + 1} (Ngày $startDay - $endDay)',
            'income': inc,
            'expense': exp,
            'net': net,
          });
        }
      } else {
        // Theo năm
        final targetYear = now.year - _periodOffset;
        final monthsRes = await AppQueries.statsByMonth(
          targetYear,
          _selectedWalletId,
        ).result;
        final monthsData = monthsRes.data ?? [];

        labels = [
          'T1',
          'T2',
          'T3',
          'T4',
          'T5',
          'T6',
          'T7',
          'T8',
          'T9',
          'T10',
          'T11',
          'T12',
        ];

        for (int i = 0; i < 12; i++) {
          final m = i < monthsData.length
              ? (monthsData[i] as Map<String, dynamic>)
              : null;
          final inc = (m?['income'] as num?)?.toInt() ?? 0;
          final exp = (m?['expense'] as num?)?.toInt() ?? 0;
          final net = inc - exp;

          totalInc += inc;
          totalExp += exp;
          values.add(net.toDouble());

          details.add({
            'title': 'Tháng ${i + 1}',
            'income': inc,
            'expense': exp,
            'net': net,
          });
        }
      }

      final netSav = totalInc - totalExp;
      final savRate = totalInc > 0
          ? (netSav > 0 ? (netSav * 100 / totalInc) : 0.0)
          : 0.0;

      if (mounted) {
        setState(() {
          _wallets = wallets;
          _chartLabels = labels;
          _chartValues = values;
          _detailList = details;
          _totalIncome = totalInc;
          _totalExpense = totalExp;
          _netSaving = netSav;
          _savingRate = savRate;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _analyzeAI() async {
    setState(() => _isAnalyzingAI = true);
    await Future.delayed(const Duration(milliseconds: 400));
    final insight = AIAdvisorService.analyzeSavingTrend(
      totalIncome: _totalIncome,
      totalExpense: _totalExpense,
      netSaving: _netSaving,
      savingRate: _savingRate,
      periodLabel: _getPeriodLabel(),
      chartValues: _chartValues,
    );
    if (mounted) {
      setState(() {
        _aiInsight = insight;
        _isAnalyzingAI = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        backgroundColor: context.palette.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.palette.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Xu hướng tiết kiệm',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscapePhone =
                constraints.maxWidth > constraints.maxHeight &&
                constraints.maxHeight < 500;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 4,
                      ),
                      child: ReportFilterBar(
                        isLandscapePhone: isLandscapePhone,
                        children: [
                          FilterSegmentCompact(
                            labels: const [
                              'Theo tuần',
                              'Theo tháng',
                              'Theo năm',
                            ],
                            selected: _selectedPeriod,
                            onChanged: (val) {
                              if (val != _selectedPeriod) {
                                setState(() {
                                  _selectedPeriod = val;
                                  _periodOffset = 0;
                                });
                                _loadReportData();
                              }
                            },
                          ),
                          FilterPeriodNavCompact(
                            label: _getPeriodLabel(),
                            onPrev: () {
                              setState(() => _periodOffset++);
                              _loadReportData();
                            },
                            onNext: _periodOffset > 0
                                ? () {
                                    setState(() => _periodOffset--);
                                    _loadReportData();
                                  }
                                : null,
                          ),
                          FilterWalletSelector(
                            wallets: _wallets,
                            selectedWalletId: _selectedWalletId,
                            isLandscape: isLandscapePhone,
                            onWalletSelected: (id) {
                              if (_selectedWalletId != id) {
                                setState(() => _selectedWalletId = id);
                                _loadReportData();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                8,
                                AppSpacing.lg,
                                AppSpacing.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryOverviewCard(),
                                  const SizedBox(height: 16),
                                  _buildAISection(),
                                  const SizedBox(height: 16),
                                  _buildSavingChartCard(),
                                  const SizedBox(height: 16),
                                  _buildDetailListSection(),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryOverviewCard() {
    final isPos = _netSaving >= 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tích lũy ròng trong kỳ',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPos
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tỷ lệ: ${_savingRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isPos ? AppColors.success : AppColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${isPos ? "+" : ""}${formatVnd(_netSaving)}',
            style: TextStyle(
              color: isPos ? AppColors.success : AppColors.danger,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng thu',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatVnd(_totalIncome),
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Tổng chi',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatVnd(_totalExpense),
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAISection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isAnalyzingAI ? null : _analyzeAI,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.teal.withValues(alpha: 0.15),
                  AppColors.tealDark.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      _isAnalyzingAI
                          ? 'assets/MiMo/emotions/Thinking.png'
                          : 'assets/MiMo/emotions/Working.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân tích AI từ MiMo Mascot',
                        style: TextStyle(
                          color: AppColors.teal,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isAnalyzingAI
                            ? 'MiMo đang phân tích tích lũy tiết kiệm...'
                            : 'Nhấn để MiMo phân tích xu hướng tích lũy ròng',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAnalyzingAI)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.teal,
                  ),
              ],
            ),
          ),
        ),
        if (_aiInsight != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
              boxShadow: context.palette.softShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/MiMo/emotions/Working.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MiMo khuyên bạn:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _aiInsight!,
                        style: TextStyle(
                          color: context.palette.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSavingChartCard() {
    final values = _chartValues.isEmpty ? [0.0] : _chartValues;
    final labels = _chartLabels.isEmpty ? [''] : _chartLabels;

    double minVal = values.fold<double>(0, (a, b) => a < b ? a : b);
    double maxVal = values.fold<double>(0, (a, b) => a > b ? a : b);

    if (minVal == 0 && maxVal == 0) {
      maxVal = 1000000;
      minVal = -500000;
    } else {
      final pad = (maxVal - minVal).abs() * 0.2;
      maxVal += (pad > 0 ? pad : 500000);
      minVal -= (pad > 0 ? pad : 500000);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Biểu đồ biến động tích lũy (Thu - Chi)',
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: MediaQuery.of(context).orientation == Orientation.landscape
                ? 180
                : 240,
            child: LineChart(
              LineChartData(
                minY: minVal,
                maxY: maxVal,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final idx = spot.x.toInt();
                        final lbl = idx >= 0 && idx < labels.length
                            ? labels[idx]
                            : '';
                        return LineTooltipItem(
                          '$lbl\n${formatVnd(spot.y.toInt())}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.palette.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) {
                          return const Text(
                            '0',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          );
                        }
                        final absVal = val.abs();
                        final prefix = val < 0 ? '-' : '';
                        String formatted;
                        if (absVal >= 1000000) {
                          formatted =
                              '$prefix${(absVal / 1000000).toStringAsFixed(1)}Tr';
                        } else if (absVal >= 1000) {
                          formatted =
                              '$prefix${(absVal / 1000).toStringAsFixed(0)}K';
                        } else {
                          formatted = '$prefix${absVal.toInt()}';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            formatted,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= labels.length)
                          return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[idx],
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(labels.length, (idx) {
                      final v = idx < values.length ? values[idx] : 0.0;
                      return FlSpot(idx.toDouble(), v);
                    }),
                    isCurved: true,
                    color: AppColors.teal,
                    barWidth: 3.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4.5,
                          color: Colors.white,
                          strokeWidth: 2.5,
                          strokeColor: spot.y >= 0
                              ? AppColors.teal
                              : AppColors.danger,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.teal.withValues(alpha: 0.3),
                          AppColors.teal.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailListSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi tiết tích lũy ($_selectedPeriod)',
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (_detailList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Chưa có dữ liệu trong kỳ này',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ..._detailList.map((item) {
              final inc = item['income'] as int;
              final exp = item['expense'] as int;
              final net = item['net'] as int;
              final isPos = net >= 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.palette.bg,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: context.palette.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            style: TextStyle(
                              color: context.palette.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPos
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Text(
                            '${isPos ? "+" : ""}${formatVnd(net)}',
                            style: TextStyle(
                              color: isPos
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_downward_rounded,
                                size: 14,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Thu: ${formatVnd(inc)}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.arrow_upward_rounded,
                                size: 14,
                                color: AppColors.danger,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Chi: ${formatVnd(exp)}',
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
