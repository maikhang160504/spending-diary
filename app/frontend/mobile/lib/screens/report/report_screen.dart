import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ReportHeader(),
              const SizedBox(height: 16),
              const _RangeTabs(selected: '7 ngay'),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TotalCard(),
                    const SizedBox(height: 20),
                    Text('Bieu do chi tieu', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    _BarChart(bars: MockData.reportBars),
                    const SizedBox(height: 20),
                    Text('Danh muc noi bat', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    ...MockData.reportCategories.map((item) => _CategoryRow(category: item)),
                    const SizedBox(height: 20),
                    Text('Xu huong chi tieu', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    _TrendCard(points: MockData.reportTrend),
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
          Text('Bao cao chi tieu', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Phan tich va theo doi thoi quen chi tieu',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(label: 'Tong chi', value: formatVnd(1620000)),
              const SizedBox(width: 12),
              _StatChip(label: 'Vuot ngan sach', value: '12%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RangeTabs extends StatelessWidget {
  final String selected;

  const _RangeTabs({required this.selected});

  @override
  Widget build(BuildContext context) {
    const options = ['7 ngay', '30 ngay', '90 ngay'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: options
              .map(
                (label) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected == label ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      boxShadow: selected == label
                          ? const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ]
                          : null,
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
              )
              .toList(),
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Center(child: Text('📊', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tong chi tuan nay', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text(formatVnd(1620000), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text('Vuot 12%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
                    ),
                    const SizedBox(width: 8),
                    Text('So voi tuan truoc', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
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
    final maxAmount = bars.map((bar) => bar.amount).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars
            .map(
              (bar) => Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 110 * (bar.amount / maxAmount),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(bar.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final ReportCategory category;

  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(category.color).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Center(child: Text(category.emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: category.percent / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(category.color)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${category.percent.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 4),
              Text(formatVnd(category.amount), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<TrendPoint> points;

  const _TrendCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: points
                .map(
                  (point) => Expanded(
                    child: Column(
                      children: [
                        Text(formatVnd(point.amount), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 24,
                              decoration: BoxDecoration(
                                color: AppColors.teal,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(point.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}