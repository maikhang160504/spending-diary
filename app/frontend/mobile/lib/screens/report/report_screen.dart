import 'dart:math' as math;
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
                      // Bar chart (mock for now)
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
                            Text('Chi tiêu theo ngày', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 16),
                            _reportBars.isEmpty
                                ? const Center(child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.muted))))
                                : _BarChart(bars: _reportBars),
                          ],
                        ),
                      ),
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
                    color: const Color(0xFFECFDF5),
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
    final labels = ['0k', '100k', '200k', '300k', '400k'];

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Y-axis labels
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: labels.reversed.map((l) => Text(l, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontSize: 10))).toList(),
          ),
          const SizedBox(width: 8),
          // Bars
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((bar) {
                final double h = maxAmount > 0 ? 120.0 * (bar.amount / maxAmount) : 0.0;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(bar.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  final List<ReportCategory> categories;

  const _DonutChart({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 180,
        width: 180,
        child: CustomPaint(
          painter: _DonutPainter(categories: categories),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<ReportCategory> categories;

  _DonutPainter({required this.categories});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final strokeWidth = 36.0;
    double startAngle = -math.pi / 2;
    const total = 100.0;

    for (final cat in categories) {
      final sweep = (cat.percent / total) * 2 * math.pi;
      final paint = Paint()
        ..color = Color(cat.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep - 0.04,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => false;
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
    final maxAmt = points.map((p) => p.amount.toDouble()).fold<double>(0.001, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _TrendPainter(points: points, maxAmt: maxAmt),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 30),
              ...points.map((p) => Text(p.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted))),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> points;
  final double maxAmt;

  _TrendPainter({required this.points, required this.maxAmt});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = AppColors.teal
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.teal.withValues(alpha: 0.2), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final usableH = size.height - 30;
    final double divisor = maxAmt <= 0 ? 1.0 : maxAmt;
    final double stepX = points.length > 1 ? (size.width - 40) / (points.length - 1) : (size.width - 40);
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = 20 + i * stepX;
      final y = usableH - (points[i].amount / divisor) * (usableH - 10);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, usableH);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      // Dot
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = AppColors.teal);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.white);
    }
    fillPath.lineTo(20 + (points.length - 1) * stepX, usableH);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Y-axis labels
    final yLabels = ['0M', '0.45M', '0.9M', '1.35M', '1.8M'];
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < yLabels.length; i++) {
      tp.text = TextSpan(text: yLabels[i], style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9));
      tp.layout();
      final y = usableH - (i / (yLabels.length - 1)) * (usableH - 10);
      tp.paint(canvas, Offset(0, y - 6));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) => false;
}