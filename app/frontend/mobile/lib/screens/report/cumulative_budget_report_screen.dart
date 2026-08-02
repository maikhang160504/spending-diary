import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../services/ai_advisor_service.dart';
import '../../services/api_client.dart';
import '../../services/app_queries.dart';
import '../../widgets/report_filter_bar.dart';

class CumulativeBudgetReportScreen extends StatefulWidget {
  final String? initialWalletId;
  const CumulativeBudgetReportScreen({super.key, this.initialWalletId});

  @override
  State<CumulativeBudgetReportScreen> createState() => _CumulativeBudgetReportScreenState();
}

class _CumulativeBudgetReportScreenState extends State<CumulativeBudgetReportScreen> {
  String _selectedPeriod = 'Theo tháng';
  bool _isAnalyzingAI = false;
  int _periodOffset = 0;
  String? _aiInsight;
  List<Map<String, dynamic>> _wallets = [];
  String? _selectedWalletId;
  final ApiClient _api = ApiClient();

  bool _isLoading = true;
  double _limit = 0;
  List<dynamic> _dailyCumulative = [];

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadWallets();
    await _loadReportData();
  }

  Future<void> _loadWallets() async {
    try {
      final res = await AppQueries.wallets().result;
      final raw = res.data ?? [];
      final list = <Map<String, dynamic>>[];
      for (final w in raw) {
        if (w is Map<String, dynamic> && w['type'] != 'group') list.add(w);
      }
      if (mounted) {
        setState(() {
          _wallets = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _aiInsight = null;
    });
    try {
      final timeRange = _selectedPeriod == 'Theo tuần' ? 'week' : 'month';
      final data = await _api.getStatsCumulativeVsBudget(
        walletId: _selectedWalletId,
        timeRange: timeRange,
        periodOffset: _periodOffset,
      );
      if (mounted) {
        setState(() {
          _limit = (data['limit'] as num?)?.toDouble() ?? 0;
          _dailyCumulative = data['dailyCumulative'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getPeriodLabel() {
    final now = DateTime.now();
    if (_selectedPeriod == 'Theo tuần') {
      if (_periodOffset == 0) return 'Tuần hiện tại';
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1)).subtract(Duration(days: 7 * _periodOffset));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return '${DateFormat('dd/MM').format(startOfWeek)} - ${DateFormat('dd/MM').format(endOfWeek)}';
    } else {
      if (_periodOffset == 0) return 'Tháng hiện tại';
      final targetMonth = DateTime(now.year, now.month - _periodOffset, 1);
      return 'Tháng ${targetMonth.month}/${targetMonth.year}';
    }
  }

  Future<void> _analyzeAI() async {
    setState(() => _isAnalyzingAI = true);
    try {
      double currentSpent = 0;
      if (_dailyCumulative.isNotEmpty) {
        currentSpent = (_dailyCumulative.last['cumulative'] as num?)?.toDouble() ?? 0;
      }
      final double pct = _limit > 0 ? (currentSpent / _limit * 100) : 0;
      final prompt = 'Phân tích tốc độ tiêu hao hạn mức ngân sách: Kỳ $_selectedPeriod (${_getPeriodLabel()}), hạn mức: ${formatVnd(_limit.toInt())}, đã chi lũy kế: ${formatVnd(currentSpent.toInt())} (${pct.toStringAsFixed(1)}%). Hãy đưa ra cảnh báo và đề xuất chi tiêu an toàn cho những ngày tiếp theo.';
      final res = await AIAdvisorService.askFinancialQuestion(prompt);
      if (mounted) {
        setState(() {
          _aiInsight = res;
          _isAnalyzingAI = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiInsight = 'Tốc độ chi tiêu lũy kế đang bám sát hạn mức an toàn. Hãy duy trì nhịp độ chi tiêu hợp lý để hoàn thành mục tiêu!';
          _isAnalyzingAI = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double currentSpent = 0;
    if (_dailyCumulative.isNotEmpty) {
      currentSpent = (_dailyCumulative.last['cumulative'] as num?)?.toDouble() ?? 0;
    }
    final double remaining = (_limit - currentSpent) > 0 ? (_limit - currentSpent) : 0;
    final double pct = _limit > 0 ? (currentSpent / _limit * 100).clamp(0, 100) : 0;

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        backgroundColor: context.palette.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Chi tiêu mức lũy kế',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscapePhone = constraints.maxWidth > constraints.maxHeight && constraints.maxHeight < 500;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    // ── Responsive filter bar ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                      child: ReportFilterBar(
                        isLandscapePhone: isLandscapePhone,
                        children: [
                          // Filter 1: Kỳ (Tuần / Tháng)
                          FilterSegmentCompact(
                            labels: const ['Theo tuần', 'Theo tháng'],
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
                          // Filter 2: Điều hướng kỳ
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
                          // Filter 3: Ví selector
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
                    // ── Content ───────────────────────────────────────────
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, AppSpacing.lg, AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAISection(),
                                  const SizedBox(height: 16),
                                  // Thẻ tổng quan Hạn mức
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.lg),
                                    decoration: BoxDecoration(
                                      color: context.palette.card,
                                      borderRadius: BorderRadius.circular(AppRadii.xl),
                                      boxShadow: context.palette.softShadow,
                                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Hạn mức ngân sách kỳ', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                                            Text(
                                              'Đã dùng ${pct.toStringAsFixed(1)}%',
                                              style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          formatVnd(_limit.toInt()),
                                          style: TextStyle(color: context.palette.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 14),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: pct / 100,
                                            minHeight: 10,
                                            backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                                            valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(child: _buildStatCol('Đã chi lũy kế', formatVnd(currentSpent.toInt()), AppColors.danger, isRight: false)),
                                            const SizedBox(width: 12),
                                            Expanded(child: _buildStatCol('Còn lại an toàn', formatVnd(remaining.toInt()), AppColors.teal, isRight: true)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildCumulativeChartCard(),
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

  Widget _buildStatCol(String label, String value, Color color, {bool isRight = false}) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
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
                      _isAnalyzingAI ? 'assets/MiMo/emotions/Thinking.png' : 'assets/MiMo/emotions/Working.png',
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
                        style: TextStyle(color: AppColors.teal, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isAnalyzingAI
                            ? 'MiMo đang tính toán tốc độ đốt hạn mức...'
                            : 'Nhấn để MiMo phân tích rủi ro vượt ngân sách',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_isAnalyzingAI)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(Icons.chevron_right_rounded, color: AppColors.teal),
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
                    child: Image.asset('assets/MiMo/emotions/Working.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MiMo khuyên bạn:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.teal),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _aiInsight!,
                        style: TextStyle(color: context.palette.textPrimary, fontSize: 13, height: 1.4),
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

  Widget _buildCumulativeChartCard() {
    final int totalDays = _dailyCumulative.isNotEmpty ? _dailyCumulative.length : 1;
    final double dailyIdeal = _limit / totalDays;

    final idealSpots = <FlSpot>[];
    final actualSpots = <FlSpot>[];
    double maxCumulative = 0;

    for (int i = 0; i < totalDays; i++) {
      final double dayNum = (i + 1).toDouble();
      idealSpots.add(FlSpot(dayNum, dailyIdeal * dayNum));
      
      final dayData = _dailyCumulative[i];
      final cumulative = (dayData['cumulative'] as num?)?.toDouble() ?? 0;
      if (cumulative > maxCumulative) maxCumulative = cumulative;
      
      if (dayData['day'] != null) {
        try {
          final date = DateTime.parse(dayData['day'].toString());
          if (date.isAfter(DateTime.now())) {
            continue;
          }
        } catch (_) {}
      }
      actualSpots.add(FlSpot(dayNum, cumulative));
    }
    
    if (actualSpots.isEmpty) {
      actualSpots.add(const FlSpot(1, 0));
    }

    final maxY = (_limit > maxCumulative ? _limit : maxCumulative) * 1.1;

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
                'Biểu đồ lũy kế vs Hạn mức lý tưởng',
                style: TextStyle(color: context.palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: MediaQuery.of(context).orientation == Orientation.landscape ? 180 : 240,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY > 0 ? maxY : 100000,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        return LineTooltipItem(
                          formatVnd(touchedSpot.y.toInt()),
                          TextStyle(
                            color: touchedSpot.bar.color ?? context.palette.textPrimary,
                            fontWeight: FontWeight.bold,
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
                  getDrawingHorizontalLine: (_) => FlLine(color: context.palette.border.withValues(alpha: 0.5), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const Text('0', style: TextStyle(color: AppColors.muted, fontSize: 10));
                        return Text('${(val / 1000000).toStringAsFixed(0)}M', style: const TextStyle(color: AppColors.muted, fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        if (val > totalDays || val < 1) return const SizedBox.shrink();
                        if (totalDays > 7) {
                          if (val != 1 && val != totalDays && val % 5 != 0) return const SizedBox.shrink();
                          if (val == totalDays && totalDays % 5 <= 2) return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('N${val.toInt()}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: idealSpots,
                    isCurved: false,
                    color: AppColors.muted.withValues(alpha: 0.7),
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: true,
                    color: AppColors.danger,
                    barWidth: 3.5,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              _buildLegendLine(AppColors.danger, 'Chi tiêu lũy kế thực tế', isDash: false),
              _buildLegendLine(AppColors.muted, 'Đường lý tưởng (I_k)', isDash: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendLine(Color color, String label, {required bool isDash}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}
