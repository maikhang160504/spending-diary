import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../services/ai_advisor_service.dart';
import '../../services/app_queries.dart';
import '../../widgets/report_filter_bar.dart';

class CashflowReportScreen extends StatefulWidget {
  final String? initialWalletId;
  const CashflowReportScreen({super.key, this.initialWalletId});

  @override
  State<CashflowReportScreen> createState() => _CashflowReportScreenState();
}

class _CashflowReportScreenState extends State<CashflowReportScreen> {
  String? _selectedWalletId;
  String _selectedPeriod =
      'Theo tháng'; // 'Theo tuần', 'Theo tháng', 'Theo năm'
  bool _compareYoY = false;
  String _selectedTab = 'Chi'; // 'Chi', 'Thu', 'Chênh lệch'
  bool _isAnalyzingAI = false;
  int _periodOffset = 0;
  String? _aiInsight;

  bool _isLoading = true;
  List<Map<String, dynamic>> _walletsList = [];

  // Dữ liệu biểu đồ & chi tiết thực tế
  List<String> _chartLabels = [];
  List<double> _currentValues = [];
  List<double> _prevValues = [];
  List<Map<String, dynamic>> _breakdownItems = [];
  List<Map<String, dynamic>> _categoryItems = [];
  int _totalCategoryAmount = 0;

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

      // 1. Tải danh sách ví nếu chưa có
      final walletsRes = await AppQueries.wallets().result;
      final rawWallets = walletsRes.data ?? [];
      final wallets = <Map<String, dynamic>>[];
      for (final w in rawWallets) {
        if (w is Map<String, dynamic> && w['type'] != 'group') wallets.add(w);
      }

      List<String> labels = [];
      List<double> curVals = [];
      List<double> prevVals = [];
      List<Map<String, dynamic>> breakdown = [];
      List<Map<String, dynamic>> cats = [];
      int totalCatAmt = 0;

      final isIncome = _selectedTab == 'Thu';
      final isDiff = _selectedTab == 'Chênh lệch';
      final typeParam = isIncome ? 'income' : 'expense';

      if (_selectedPeriod == 'Theo tuần') {
        final startOfWeek = now
            .subtract(Duration(days: now.weekday - 1))
            .subtract(Duration(days: 7 * _periodOffset));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final fromStr = DateFormat('yyyy-MM-dd').format(startOfWeek);
        final toStr = DateFormat('yyyy-MM-dd').format(endOfWeek);

        final prevStart = startOfWeek.subtract(const Duration(days: 7));
        final prevEnd = startOfWeek.subtract(const Duration(days: 1));
        final prevFromStr = DateFormat('yyyy-MM-dd').format(prevStart);
        final prevToStr = DateFormat('yyyy-MM-dd').format(prevEnd);

        final curDashRes = await AppQueries.dashboard(
          _selectedWalletId,
          from: fromStr,
          to: toStr,
        ).result;
        final prevDashRes = await AppQueries.dashboard(
          _selectedWalletId,
          from: prevFromStr,
          to: prevToStr,
        ).result;
        final catRes = await AppQueries.statsByCategory(
          'custom',
          _selectedWalletId,
          from: fromStr,
          to: toStr,
          type: typeParam,
        ).result;

        final curDash = curDashRes.data ?? {};
        final prevDash = prevDashRes.data ?? {};
        final curByDay = (curDash['byDay'] as List<dynamic>?) ?? [];
        final prevByDay = (prevDash['byDay'] as List<dynamic>?) ?? [];
        final rawCats = catRes.data ?? [];

        labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

        for (int i = 0; i < 7; i++) {
          final curDayData = i < curByDay.length
              ? (curByDay[i] as Map<String, dynamic>)
              : null;
          final prevDayData = i < prevByDay.length
              ? (prevByDay[i] as Map<String, dynamic>)
              : null;

          final curExp = (curDayData?['expense'] as num?)?.toDouble() ?? 0.0;
          final curInc = (curDayData?['income'] as num?)?.toDouble() ?? 0.0;
          final prevExp = (prevDayData?['expense'] as num?)?.toDouble() ?? 0.0;
          final prevInc = (prevDayData?['income'] as num?)?.toDouble() ?? 0.0;

          if (isIncome) {
            curVals.add(curInc);
            prevVals.add(prevInc);
          } else if (isDiff) {
            curVals.add(curInc - curExp);
            prevVals.add(prevInc - prevExp);
          } else {
            curVals.add(curExp);
            prevVals.add(prevExp);
          }

          final dayDate = startOfWeek.add(Duration(days: i));
          breakdown.add({
            'title': '${labels[i]} (${DateFormat('dd/MM').format(dayDate)})',
            'income': curInc.toInt(),
            'expense': curExp.toInt(),
          });
        }

        for (final c in rawCats) {
          final map = c as Map<String, dynamic>;
          final amt =
              (map['amount'] as num?)?.toInt() ??
              (map['total'] as num?)?.toInt() ??
              0;
          final code = map['categoryCode']?.toString() ?? 'Other';
          totalCatAmt += amt;
          cats.add({
            'code': code,
            'label': CategoryTheme.of(code).label,
            'amount': amt,
            'color': CategoryTheme.of(code).color,
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

        final prevMonth = DateTime(now.year, now.month - _periodOffset - 1, 1);
        final prevMonthEnd = DateTime(now.year, now.month - _periodOffset, 0);
        final prevFromStr = DateFormat('yyyy-MM-dd').format(prevMonth);
        final prevToStr = DateFormat('yyyy-MM-dd').format(prevMonthEnd);

        final curDashRes = await AppQueries.dashboard(
          _selectedWalletId,
          from: fromStr,
          to: toStr,
        ).result;
        final prevDashRes = await AppQueries.dashboard(
          _selectedWalletId,
          from: prevFromStr,
          to: prevToStr,
        ).result;
        final catRes = await AppQueries.statsByCategory(
          'custom',
          _selectedWalletId,
          from: fromStr,
          to: toStr,
          type: typeParam,
        ).result;

        final curDash = curDashRes.data ?? {};
        final prevDash = prevDashRes.data ?? {};
        final curByDay = (curDash['byDay'] as List<dynamic>?) ?? [];
        final prevByDay = (prevDash['byDay'] as List<dynamic>?) ?? [];
        final rawCats = catRes.data ?? [];

        // Gom theo 4 hoặc 5 tuần trong tháng
        final daysInMonth = targetMonthEnd.day;
        final List<Map<String, int>> curWeeks = [
          {'income': 0, 'expense': 0},
          {'income': 0, 'expense': 0},
          {'income': 0, 'expense': 0},
          {'income': 0, 'expense': 0},
          if (daysInMonth > 28) {'income': 0, 'expense': 0},
        ];

        final List<Map<String, int>> prevWeeks = [
          {'income': 0, 'expense': 0},
          {'income': 0, 'expense': 0},
          {'income': 0, 'expense': 0},
          {'income': 0, 'expense': 0},
          if (daysInMonth > 28) {'income': 0, 'expense': 0},
        ];

        for (final d in curByDay) {
          final map = d as Map<String, dynamic>;
          final dayStr = map['day']?.toString() ?? '';
          if (dayStr.length >= 10) {
            final dayNum = int.tryParse(dayStr.substring(8, 10)) ?? 1;
            int weekIdx = (dayNum - 1) ~/ 7;
            if (weekIdx >= curWeeks.length) weekIdx = curWeeks.length - 1;
            curWeeks[weekIdx]['income'] =
                (curWeeks[weekIdx]['income'] ?? 0) +
                ((map['income'] as num?)?.toInt() ?? 0);
            curWeeks[weekIdx]['expense'] =
                (curWeeks[weekIdx]['expense'] ?? 0) +
                ((map['expense'] as num?)?.toInt() ?? 0);
          }
        }

        for (final d in prevByDay) {
          final map = d as Map<String, dynamic>;
          final dayStr = map['day']?.toString() ?? '';
          if (dayStr.length >= 10) {
            final dayNum = int.tryParse(dayStr.substring(8, 10)) ?? 1;
            int weekIdx = (dayNum - 1) ~/ 7;
            if (weekIdx >= prevWeeks.length) weekIdx = prevWeeks.length - 1;
            prevWeeks[weekIdx]['income'] =
                (prevWeeks[weekIdx]['income'] ?? 0) +
                ((map['income'] as num?)?.toInt() ?? 0);
            prevWeeks[weekIdx]['expense'] =
                (prevWeeks[weekIdx]['expense'] ?? 0) +
                ((map['expense'] as num?)?.toInt() ?? 0);
          }
        }

        for (int i = 0; i < curWeeks.length; i++) {
          final label = 'Tuần ${i + 1}';
          labels.add(label);

          final curInc = (curWeeks[i]['income'] ?? 0).toDouble();
          final curExp = (curWeeks[i]['expense'] ?? 0).toDouble();
          final prevInc = (prevWeeks[i]['income'] ?? 0).toDouble();
          final prevExp = (prevWeeks[i]['expense'] ?? 0).toDouble();

          if (isIncome) {
            curVals.add(curInc);
            prevVals.add(prevInc);
          } else if (isDiff) {
            curVals.add(curInc - curExp);
            prevVals.add(prevInc - prevExp);
          } else {
            curVals.add(curExp);
            prevVals.add(prevExp);
          }

          final startDay = i * 7 + 1;
          final endDay = (i == curWeeks.length - 1) ? daysInMonth : (i + 1) * 7;
          breakdown.add({
            'title': 'Tuần ${i + 1} (Ngày $startDay - $endDay)',
            'income': curInc.toInt(),
            'expense': curExp.toInt(),
          });
        }

        for (final c in rawCats) {
          final map = c as Map<String, dynamic>;
          final amt =
              (map['amount'] as num?)?.toInt() ??
              (map['total'] as num?)?.toInt() ??
              0;
          final code = map['categoryCode']?.toString() ?? 'Other';
          totalCatAmt += amt;
          cats.add({
            'code': code,
            'label': CategoryTheme.of(code).label,
            'amount': amt,
            'color': CategoryTheme.of(code).color,
          });
        }
      } else {
        // Theo năm
        final targetYear = now.year - _periodOffset;
        final fromStr = '$targetYear-01-01';
        final toStr = '$targetYear-12-31';

        final curRes = await AppQueries.statsByMonth(
          targetYear,
          _selectedWalletId,
        ).result;
        final prevRes = await AppQueries.statsByMonth(
          targetYear - 1,
          _selectedWalletId,
        ).result;
        final catRes = await AppQueries.statsByCategory(
          'custom',
          _selectedWalletId,
          from: fromStr,
          to: toStr,
          type: typeParam,
        ).result;

        final curMonths = curRes.data ?? [];
        final prevMonths = prevRes.data ?? [];
        final rawCats = catRes.data ?? [];

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
          final curM = i < curMonths.length
              ? (curMonths[i] as Map<String, dynamic>)
              : null;
          final prevM = i < prevMonths.length
              ? (prevMonths[i] as Map<String, dynamic>)
              : null;

          final curExp = (curM?['expense'] as num?)?.toDouble() ?? 0.0;
          final curInc = (curM?['income'] as num?)?.toDouble() ?? 0.0;
          final prevExp = (prevM?['expense'] as num?)?.toDouble() ?? 0.0;
          final prevInc = (prevM?['income'] as num?)?.toDouble() ?? 0.0;

          if (isIncome) {
            curVals.add(curInc);
            prevVals.add(prevInc);
          } else if (isDiff) {
            curVals.add(curInc - curExp);
            prevVals.add(prevInc - prevExp);
          } else {
            curVals.add(curExp);
            prevVals.add(prevExp);
          }

          breakdown.add({
            'title': 'Tháng ${i + 1}',
            'income': curInc.toInt(),
            'expense': curExp.toInt(),
          });
        }

        for (final c in rawCats) {
          final map = c as Map<String, dynamic>;
          final amt =
              (map['amount'] as num?)?.toInt() ??
              (map['total'] as num?)?.toInt() ??
              0;
          final code = map['categoryCode']?.toString() ?? 'Other';
          totalCatAmt += amt;
          cats.add({
            'code': code,
            'label': CategoryTheme.of(code).label,
            'amount': amt,
            'color': CategoryTheme.of(code).color,
          });
        }
      }

      cats.sort(
        (a, b) =>
            ((b['amount'] as num?) ?? 0).compareTo((a['amount'] as num?) ?? 0),
      );

      if (mounted) {
        setState(() {
          _walletsList = wallets;
          _chartLabels = labels;
          _currentValues = curVals;
          _prevValues = prevVals;
          _breakdownItems = breakdown;
          _categoryItems = cats;
          _totalCategoryAmount = totalCatAmt;
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
    final totalIncome = _breakdownItems.fold<int>(
      0,
      (sum, item) => sum + ((item['income'] as num?)?.toInt() ?? 0),
    );
    final totalExpense = _breakdownItems.fold<int>(
      0,
      (sum, item) => sum + ((item['expense'] as num?)?.toInt() ?? 0),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    final insight = AIAdvisorService.analyzeCashflow(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      periodLabel: _getPeriodLabel(),
      breakdownValues: _breakdownItems,
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
          'Biến động thu chi',
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
                  children: [
                    // ── Responsive filter bar ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 4,
                      ),
                      child: ReportFilterBar(
                        isLandscapePhone: isLandscapePhone,
                        children: [
                          // Filter 1: Kỳ (Tuần / Tháng / Năm)
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
                          // Filter 3: Toggle So cùng kỳ
                          FilterToggleCompact(
                            label: 'So cùng kỳ',
                            value: _compareYoY,
                            onChanged: (val) {
                              setState(() => _compareYoY = val);
                              _loadReportData();
                            },
                          ),
                          // Filter 4: Ví chips
                          FilterWalletSelector(
                            wallets: _walletsList,
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
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                8,
                                AppSpacing.lg,
                                AppSpacing.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tabs Chi / Thu / Chênh lệch
                                  Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 400,
                                      ),
                                      child: Row(
                                        children: [
                                          _buildTab('Chi'),
                                          const SizedBox(width: 8),
                                          _buildTab('Thu'),
                                          const SizedBox(width: 8),
                                          _buildTab('Chênh lệch'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildAISection(),
                                  const SizedBox(height: 16),
                                  _buildChartCard(),
                                  const SizedBox(height: 12),
                                  if (_compareYoY)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _buildLegendDot(
                                          AppColors.teal,
                                          'Kỳ hiện tại',
                                        ),
                                        const SizedBox(width: 24),
                                        _buildLegendDot(
                                          AppColors.warning,
                                          'Cùng kỳ trước',
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 20),
                                  _buildBottomDetailSection(),
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

  Widget _buildTab(String label) {
    final active = _selectedTab == label;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedTab != label) {
            setState(() => _selectedTab = label);
            _loadReportData();
          }
        },
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? AppColors.teal.withValues(alpha: 0.15)
                : context.palette.card,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: active ? AppColors.teal : context.palette.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.teal : context.palette.textPrimary,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
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
                            ? 'MiMo đang phân tích dòng tiền...'
                            : 'Nhấn để MiMo phân tích xu hướng thu chi',
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

  Widget _buildChartCard() {
    final maxCur = _currentValues.isEmpty
        ? 0.0
        : _currentValues.fold<double>(0, (a, b) => a > b.abs() ? a : b.abs());
    final maxPrev = _prevValues.isEmpty
        ? 0.0
        : _prevValues.fold<double>(0, (a, b) => a > b.abs() ? a : b.abs());
    final maxVal = maxCur > maxPrev ? maxCur : maxPrev;

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
            'Biểu đồ $_selectedTab (${_compareYoY ? "So cùng kỳ" : "Kỳ hiện tại"})',
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
                : 230,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? maxVal * 1.25 : 1000000,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIdx, rod, rodIdx) {
                      final label = groupIdx < _chartLabels.length
                          ? _chartLabels[groupIdx]
                          : '';
                      return BarTooltipItem(
                        '$label\n${formatVnd(rod.toY.toInt())}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      );
                    },
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
                      reservedSize: 54,
                      interval: maxVal > 0 ? (maxVal / 3) : 1000000,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox();
                        final compact = val >= 1000000
                            ? '${(val / 1000000).toStringAsFixed(1)}Tr'
                            : '${(val / 1000).toStringAsFixed(0)}K';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            compact,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
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
                        if (idx < 0 || idx >= _chartLabels.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _chartLabels[idx],
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: context.palette.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_chartLabels.length, (idx) {
                  final cur = idx < _currentValues.length
                      ? _currentValues[idx]
                      : 0.0;
                  final prev = idx < _prevValues.length
                      ? _prevValues[idx]
                      : 0.0;
                  final displayCur = cur > 0 ? cur : 0.0;
                  final displayPrev = prev > 0 ? prev : 0.0;

                  if (!_compareYoY) {
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: displayCur,
                          color: _selectedTab == 'Thu'
                              ? AppColors.teal
                              : (_selectedTab == 'Chi'
                                    ? AppColors.danger
                                    : AppColors.teal),
                          width: _selectedPeriod == 'Theo năm' ? 12 : 18,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }

                  final higher = displayCur >= displayPrev
                      ? displayCur
                      : displayPrev;
                  final higherColor = displayCur >= displayPrev
                      ? AppColors.teal
                      : AppColors.warning;
                  final lower = displayCur >= displayPrev
                      ? displayPrev
                      : displayCur;
                  final lowerColor = displayCur >= displayPrev
                      ? AppColors.warning
                      : AppColors.teal;

                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: higher,
                        color: higherColor,
                        width: _selectedPeriod == 'Theo năm' ? 14 : 20,
                        borderRadius: BorderRadius.circular(6),
                        rodStackItems: [
                          BarChartRodStackItem(0, lower, lowerColor),
                          BarChartRodStackItem(lower, higher, higherColor),
                        ],
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

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBottomDetailSection() {
    if (_selectedTab == 'Chênh lệch') {
      return _buildNetCashflowBreakdown();
    }
    return _buildCategoryBreakdownList();
  }

  Widget _buildCategoryBreakdownList() {
    final isIncome = _selectedTab == 'Thu';
    final title = isIncome ? 'Danh mục Thu nhập' : 'Danh mục Chi tiêu';

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
            title,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (_categoryItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Chưa có dữ liệu $_selectedTab trong kỳ này',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ..._categoryItems.map((cat) {
              final amt = cat['amount'] as int;
              final pct = _totalCategoryAmount > 0
                  ? (amt / _totalCategoryAmount)
                  : 0.0;
              final color = cat['color'] as Color;
              final label = cat['label'] as String;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: CategoryTheme.iconOf(
                            cat['code'] as String,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: context.palette.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          formatVnd(amt),
                          style: TextStyle(
                            color: context.palette.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: context.palette.border.withValues(
                          alpha: 0.4,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 5,
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

  Widget _buildNetCashflowBreakdown() {
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
            'Chi tiết độ chênh lệch Thu - Chi ($_selectedPeriod)',
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (_breakdownItems.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Chưa có dữ liệu giao dịch trong kỳ này',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ..._breakdownItems.map((item) {
              final income = item['income'] as int;
              final expense = item['expense'] as int;
              final diff = income - expense;
              final isPos = diff >= 0;

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
                            '${isPos ? "+" : ""}${formatVnd(diff)}',
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
                                  'Thu: ${formatVnd(income)}',
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
                                  'Chi: ${formatVnd(expense)}',
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
