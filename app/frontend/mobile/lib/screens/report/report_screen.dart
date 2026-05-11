import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _selectedRange = '7 ngày';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ReportHeader(),
              const SizedBox(height: 16),
              _RangeTabs(
                selected: _selectedRange,
                onChanged: (v) => setState(() => _selectedRange = v),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total card
                    _TotalCard(),
                    const SizedBox(height: 20),
                    // Bar chart
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chi tiêu theo ngày', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 16),
                          _BarChart(bars: MockData.reportBars),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Donut chart
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chi tiêu theo danh mục', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 20),
                          _DonutChart(categories: MockData.reportCategories),
                          const SizedBox(height: 16),
                          _CategoryLegend(categories: MockData.reportCategories),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Top category card
                    _TopCategoryCard(),
                    const SizedBox(height: 20),
                    // Trend card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Xu hướng tiết kiệm (3 tháng)', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 16),
                          _TrendChart(points: MockData.reportTrend),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Báo cáo chi tiêu', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Phân tích và theo dõi thói quen chi tiêu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
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
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: options.map((label) => Expanded(
            child: GestureDetector(
              onTap: () => onChanged(label),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected == label ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  boxShadow: selected == label ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 3))] : null,
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
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng chi tiêu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_downward, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 2),
                    Text('28.4%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('680.000 đ', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 28)),
          const SizedBox(height: 4),
          Text('So với kỳ trước: 950.000 đ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
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
    final maxAmount = bars.map((b) => b.amount).reduce((a, b) => a > b ? a : b);
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
                final h = 120 * (bar.amount / maxAmount);
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
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: Color(cat.color), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${cat.emoji} ${cat.label}\n${cat.percent.toStringAsFixed(1)}% · ${formatVnd(cat.amount)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        ],
      )).toList(),
    );
  }
}

class _TopCategoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
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
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: const Center(child: Text('🍔', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ăn uống', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('220.000 đ', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFFEC4899), fontWeight: FontWeight.w700, fontSize: 20)),
                ],
              ),
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
    final maxAmt = points.map((p) => p.amount).reduce((a, b) => a > b ? a : b).toDouble();
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
    final stepX = (size.width - 40) / (points.length - 1);
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = 20 + i * stepX;
      final y = usableH - (points[i].amount / maxAmt) * (usableH - 10);
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