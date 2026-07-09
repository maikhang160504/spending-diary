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
import 'category_detail_report_screen.dart';
import '../chat/chat_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _selectedRange = 'Theo tháng';
  bool _showComparison = true;
  int _selectedTab = 0; // 0 = Chi tiêu, 1 = Thu nhập
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
    _loadStats(forceRefetch: true);
  }

  Future<void> _loadStats({bool forceRefetch = false}) async {
    final rangeParam = _selectedRange == 'Theo tuần' ? 'week' : 'month';

    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    if (_selectedRange == 'Theo tuần') {
      startDate = now.subtract(const Duration(days: 6));
    } else {
      startDate = DateTime(now.year, now.month, 1);
    }

    final fromStr = startDate.toIso8601String();
    final toStr = endDate.toIso8601String();

    final hasCache = AppQueries.statsByCategory(rangeParam, _selectedWalletId, from: fromStr, to: toStr).state.data != null;
    setState(() => _loading = !hasCache);
    try {
      final walletsResult = forceRefetch
          ? await AppQueries.wallets().refetch()
          : await AppQueries.wallets().result;
      final wallets = walletsResult.data ?? [];

      final dashF = forceRefetch
          ? AppQueries.dashboard(_selectedWalletId, from: fromStr, to: toStr).refetch()
          : AppQueries.dashboard(_selectedWalletId, from: fromStr, to: toStr).result;
      final catsF = forceRefetch
          ? AppQueries.statsByCategory(rangeParam, _selectedWalletId, from: fromStr, to: toStr).refetch()
          : AppQueries.statsByCategory(rangeParam, _selectedWalletId, from: fromStr, to: toStr).result;
      final monthlyF = forceRefetch
          ? AppQueries.statsByMonth(now.year, _selectedWalletId).refetch()
          : AppQueries.statsByMonth(now.year, _selectedWalletId).result;

      final dashboard = (await dashF).data ?? <String, dynamic>{};
      final cats = (await catsF).data ?? <dynamic>[];
      final monthly = (await monthlyF).data ?? <dynamic>[];

      List<dynamic>? momData;
      Map<String, dynamic>? cumulativeData;
      if (_selectedRange == 'Theo tháng') {
        final momRes = forceRefetch
            ? await AppQueries.statsMoM(_selectedWalletId).refetch()
            : await AppQueries.statsMoM(_selectedWalletId).result;
        final cumRes = forceRefetch
            ? await AppQueries.statsCumulativeVsBudget(_selectedWalletId).refetch()
            : await AppQueries.statsCumulativeVsBudget(_selectedWalletId).result;
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
        final rawCats = cats.map((c) => _toCat(c as Map<String, dynamic>)).toList();
        final Map<String, ReportCategory> mergedMap = {};
        int totalCatAmt = 0;
        for (final cat in rawCats) {
          totalCatAmt += cat.amount;
          if (mergedMap.containsKey(cat.label)) {
            final existing = mergedMap[cat.label]!;
            mergedMap[cat.label] = ReportCategory(
              code: existing.code,
              label: existing.label,
              emoji: existing.emoji,
              percent: 0,
              amount: existing.amount + cat.amount,
              color: existing.color,
            );
          } else {
            mergedMap[cat.label] = cat;
          }
        }
        final mergedList = mergedMap.values.toList();
        for (int i = 0; i < mergedList.length; i++) {
          final c = mergedList[i];
          mergedList[i] = ReportCategory(
            code: c.code,
            label: c.label,
            emoji: c.emoji,
            percent: totalCatAmt > 0 ? (c.amount / totalCatAmt) * 100 : c.percent,
            amount: c.amount,
            color: c.color,
          );
        }
        mergedList.sort((a, b) => b.amount.compareTo(a.amount));
        _categoryStats = mergedList;
        _reportBars = byDay.map((d) {
          final e = d as Map<String, dynamic>;
          final dayStr = e['day'] as String? ?? '';
          final label = dayStr.length >= 10 ? dayStr.substring(8, 10) : '';
          return ReportBar(label: label, amount: (e['expense'] as num?)?.toInt() ?? 0);
        }).toList();

        final Map<int, int> monthlyNetMap = {};
        for (final m in monthly) {
          final e = m as Map<String, dynamic>;
          final monthStr = e['month'] as String? ?? '';
          final parts = monthStr.split('-');
          final monthNum = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          if (monthNum > 0) {
            final income = (e['income'] as num?)?.toInt() ?? 0;
            final expense = (e['expense'] as num?)?.toInt() ?? 0;
            monthlyNetMap[monthNum] = income - expense;
          }
        }
        final currentMonth = now.month;
        _trendPoints = List.generate(currentMonth, (idx) {
          final mNum = idx + 1;
          return TrendPoint(label: 'T$mNum', amount: monthlyNetMap[mNum] ?? 0);
        });

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 768;

            Widget leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TotalCard(
                  totalExpense: _totalExpense,
                  totalIncome: _totalIncome,
                  loading: _loading,
                  selectedTab: _selectedTab,
                  onTabChanged: (val) => setState(() => _selectedTab = val),
                  momStats: _momStats,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.palette.card,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: context.palette.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiêu theo danh mục',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _categoryStats.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 36),
                                child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.muted)),
                              ),
                            )
                          : _DonutChart(categories: _categoryStats),
                      if (_categoryStats.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _CategoryBreakdownSection(
                          categories: _categoryStats,
                          momStats: _momStats,
                          selectedRange: _selectedRange,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _MimoInsightCard(
                  totalExpense: _totalExpense,
                  totalIncome: _totalIncome,
                  topCategory: _categoryStats.isNotEmpty ? _categoryStats.first : null,
                  selectedRange: _selectedRange,
                ),
                if (hasSavingsData) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      boxShadow: context.palette.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xu hướng tiết kiệm',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _TrendChart(points: _trendPoints),
                      ],
                    ),
                  ),
                ],
              ],
            );

            Widget rightColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
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
                          Expanded(
                            child: Text(
                              'Biến động thu chi',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'So với cùng kỳ',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 42,
                                height: 24,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Switch(
                                    value: _showComparison,
                                    activeThumbColor: const Color(0xFF10B981),
                                    onChanged: (val) => setState(() => _showComparison = val),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '(Triệu)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (_showComparison && _momStats.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF93C5FD),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Chi tiêu cùng kỳ',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 20),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Tổng chi trong kỳ',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      (_showComparison && _momStats.isNotEmpty)
                          ? _MoMGroupedBarChart(stats: _momStats)
                          : (_reportBars.isEmpty
                              ? const Center(
                                  child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 36),
                                  child: Text('Chưa có dữ liệu',
                                      style: TextStyle(color: AppColors.muted)),
                                ))
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
              ],
            );

            Widget mainContent;
            if (isWide) {
              mainContent = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: leftColumn),
                  const SizedBox(width: 32),
                  Expanded(flex: 1, child: rightColumn),
                ],
              );
            } else {
              mainContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leftColumn,
                  const SizedBox(height: 20),
                  rightColumn,
                ],
              );
            }

            return RefreshIndicator(
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
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChatScreen(forceNew: true),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('🤖', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text(
                                'AI Phân tích Biểu đồ & Đưa ra lời khuyên',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                      child: mainContent,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
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
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selectedWalletId,
                  focusColor: Colors.transparent,
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
    final options = ['Theo tuần', 'Theo tháng'];
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
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final List<ReportMoM> momStats;

  const _TotalCard({
    required this.totalExpense,
    required this.totalIncome,
    required this.loading,
    required this.selectedTab,
    required this.onTabChanged,
    required this.momStats,
  });

  @override
  Widget build(BuildContext context) {
    int thisPeriodSum = 0;
    int lastPeriodSum = 0;
    for (final m in momStats) {
      thisPeriodSum += m.thisMonth;
      lastPeriodSum += m.lastMonth;
    }
    final int diff = thisPeriodSum - lastPeriodSum;
    final bool hasMom = momStats.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onTabChanged(0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selectedTab == 0
                        ? context.palette.card
                        : context.palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(
                      color: selectedTab == 0
                          ? const Color(0xFFF43F5E)
                          : context.palette.border,
                      width: 1.5,
                    ),
                    boxShadow: selectedTab == 0 ? context.palette.softShadow : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward, size: 12, color: Color(0xFFF43F5E)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Chi tiêu',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loading ? '...' : formatVnd(totalExpense),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => onTabChanged(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selectedTab == 1
                        ? context.palette.card
                        : context.palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(
                      color: selectedTab == 1
                          ? AppColors.teal
                          : context.palette.border,
                      width: 1.5,
                    ),
                    boxShadow: selectedTab == 1 ? context.palette.softShadow : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.muted.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.remove, size: 12, color: AppColors.muted),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Thu nhập',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loading ? '...' : formatVnd(totalIncome),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: !hasMom
                ? context.palette.surfaceAlt
                : diff > 0
                    ? const Color(0xFFFFF7ED)
                    : diff < 0
                        ? const Color(0xFFECFDF5)
                        : context.palette.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: !hasMom
                  ? context.palette.border
                  : diff > 0
                      ? const Color(0xFFFDE68A)
                      : diff < 0
                          ? const Color(0xFFA7F3D0)
                          : context.palette.border,
            ),
          ),
          child: Row(
            children: [
              Text(
                !hasMom
                    ? 'ℹ️'
                    : diff > 0
                        ? '🔥'
                        : diff < 0
                            ? '↓'
                            : '✨',
                style: TextStyle(
                  fontSize: 15,
                  color: diff < 0 ? const Color(0xFF10B981) : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  !hasMom
                      ? 'Đang so sánh dữ liệu với cùng kỳ trước'
                      : diff > 0
                          ? 'Tăng bất thường ${formatVnd(diff)} so với cùng kỳ trước'
                          : diff < 0
                              ? 'Giảm ${formatVnd(diff.abs())} so với cùng kỳ trước'
                              : 'Chi tiêu ổn định so với cùng kỳ trước',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: !hasMom
                            ? AppColors.textSecondary
                            : diff > 0
                                ? const Color(0xFFC2410C)
                                : diff < 0
                                    ? const Color(0xFF047857)
                                    : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<ReportBar> bars;

  const _BarChart({required this.bars});

  List<ReportBar> _aggregateIntoWeeks(List<ReportBar> raw) {
    final int chunkSize = (raw.length / 4).ceil();
    if (chunkSize <= 0) return raw;
    final List<ReportBar> result = [];
    for (int i = 0; i < raw.length; i += chunkSize) {
      final end = (i + chunkSize > raw.length) ? raw.length : i + chunkSize;
      final sub = raw.sublist(i, end);
      final sum = sub.fold<int>(0, (a, b) => a + b.amount);
      result.add(ReportBar(label: 'T${(i ~/ chunkSize) + 1}', amount: sum));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final displayBars = bars.length > 12 ? _aggregateIntoWeeks(bars) : bars;
    final maxAmount = displayBars.map((b) => b.amount).fold<int>(0, (a, b) => a > b ? a : b);
    final interval = _niceInterval(maxAmount.toDouble());

    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAmount > 0 ? (maxAmount * 1.25) : 100,
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
                  if (idx < 0 || idx >= displayBars.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      displayBars[idx].label,
                      style: const TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  );
                },
                reservedSize: 24,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
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
          barGroups: List.generate(displayBars.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: displayBars[i].amount.toDouble(),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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

  Widget _buildCategoryCalloutBadge(ReportCategory cat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(cat.color).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CategoryTheme.iconOf(cat.code, size: 14),
          const SizedBox(width: 4),
          Text(
            '${cat.percent.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(cat.color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final touchedCat = _touchedIndex >= 0 && _touchedIndex < widget.categories.length
        ? widget.categories[_touchedIndex]
        : null;

    return Center(
      child: SizedBox(
        height: 240,
        width: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  touchedCat != null ? touchedCat.label : 'Chi tiêu',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  touchedCat != null
                      ? '${touchedCat.percent.toStringAsFixed(1)}%'
                      : '100%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
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
                sectionsSpace: 3,
                centerSpaceRadius: 60,
                sections: List.generate(widget.categories.length, (i) {
                  final cat = widget.categories[i];
                  final isTouched = i == _touchedIndex;
                  return PieChartSectionData(
                    color: Color(cat.color),
                    value: cat.percent,
                    title: '',
                    radius: isTouched ? 34 : 28,
                    badgeWidget: cat.percent >= 3
                        ? _buildCategoryCalloutBadge(cat)
                        : null,
                    badgePositionPercentageOffset: 1.48,
                  );
                }),
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownSection extends StatelessWidget {
  final List<ReportCategory> categories;
  final List<ReportMoM> momStats;
  final String selectedRange;

  const _CategoryBreakdownSection({
    required this.categories,
    required this.momStats,
    this.selectedRange = 'Theo tháng',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...categories.map((cat) {
          final mom = momStats.where((m) => m.code == cat.code).firstOrNull;
          final diff = mom != null ? (mom.thisMonth - mom.lastMonth) : 0;
          final catColor = Color(cat.color);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CategoryDetailReportScreen(
                      categoryCode: cat.code,
                      categoryName: cat.label,
                      totalAmount: cat.amount,
                      percentage: cat.percent,
                      dateRangeLabel: selectedRange,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.palette.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: catColor.withValues(alpha: 0.15), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: CategoryTheme.iconOf(cat.code, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        cat.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: context.palette.textPrimary,
                            ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatVnd(cat.amount),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
                          ],
                        ),
                        if (diff != 0) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                diff < 0 ? Icons.arrow_downward : Icons.arrow_upward,
                                size: 11,
                                color: diff < 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                formatVnd(diff.abs()),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: diff < 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
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
    final minAmt = points.map((p) => p.amount.toDouble()).fold<double>(0, (a, b) => a < b ? a : b);
    final yMax = maxAmt > 0 ? (maxAmt * 1.25) : 1000000.0;
    final yMin = minAmt < 0 ? (minAmt * 1.25) : 0.0;
    final range = yMax - yMin;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: yMin,
          maxY: yMax > yMin ? yMax : (yMin + 100000.0),
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
                  color: const Color(0xFF93C5FD),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                ),
                BarChartRodData(
                  toY: item.thisMonth.toDouble(),
                  color: const Color(0xFF3B82F6),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
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
    final yMax = (maxCumulative > maxLimit ? maxCumulative : maxLimit) * 1.3;
    final double interval = yMax > 0 ? yMax / 4 : 100000;

    return SizedBox(
      height: 220,
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
                reservedSize: 48,
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

class _MimoInsightCard extends StatelessWidget {
  final int totalExpense;
  final int totalIncome;
  final ReportCategory? topCategory;
  final String selectedRange;

  const _MimoInsightCard({
    required this.totalExpense,
    required this.totalIncome,
    required this.topCategory,
    required this.selectedRange,
  });

  String _buildInsight() {
    final ratio = totalIncome > 0 ? totalExpense / totalIncome : 0.0;
    final topName = topCategory?.label;
    final rangeLbl = selectedRange == '7 ngày' ? 'tuần này' : selectedRange == '30 ngày' ? '30 ngày qua' : 'tháng này';

    if (totalIncome == 0) {
      return 'Bạn đã chi ${formatVnd(totalExpense)} $rangeLbl. Hãy thêm thu nhập để Mimo tính tỷ lệ tiết kiệm cho bạn! 💡';
    } else if (ratio > 0.9) {
      final topPart = topName != null ? ' Danh mục "$topName" chiếm tỷ trọng lớn nhất.' : '';
      return 'Chi tiêu của bạn đang ở mức ${(ratio * 100).toStringAsFixed(0)}% thu nhập — khá cao.$topPart Hãy xem xét cắt giảm chi tiêu không cần thiết.';
    } else if (ratio > 0.7) {
      return 'Chi tiêu $rangeLbl khá ổn. Hãy cố gắng duy trì nhé!';
    }
    return 'Tuyệt vời! Bạn đang kiểm soát chi tiêu rất tốt. Hãy tiếp tục phát huy! 🎉';
  }

  String _getEmotionImage() {
    final ratio = totalIncome > 0 ? totalExpense / totalIncome : 0.0;
    if (totalIncome == 0) return 'assets/MiMo/emotions/Thinking.png';
    if (ratio > 0.9) return 'assets/MiMo/emotions/Worried.png';
    if (ratio > 0.7) return 'assets/MiMo/emotions/Alert.png';
    return 'assets/MiMo/emotions/Celebrate.png';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: context.palette.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            _getEmotionImage(),
            width: 48,
            height: 48,
            errorBuilder: (c, e, s) => const Icon(Icons.psychology, size: 48, color: AppColors.teal),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mimo nhận xét',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.teal),
                ),
                const SizedBox(height: 6),
                Text(
                  _buildInsight(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


