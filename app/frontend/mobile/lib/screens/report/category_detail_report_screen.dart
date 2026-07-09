import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../services/app_queries.dart';

class CategoryDetailReportScreen extends StatefulWidget {
  final String categoryCode;
  final String categoryName;
  final int totalAmount;
  final double percentage;
  final String dateRangeLabel;
  final String? walletId;
  final List<dynamic> transactions;

  const CategoryDetailReportScreen({
    super.key,
    required this.categoryCode,
    required this.categoryName,
    required this.totalAmount,
    required this.percentage,
    required this.dateRangeLabel,
    this.walletId,
    this.transactions = const [],
  });

  @override
  State<CategoryDetailReportScreen> createState() => _CategoryDetailReportScreenState();
}

class _CategoryDetailReportScreenState extends State<CategoryDetailReportScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (widget.transactions.isNotEmpty) {
      setState(() {
        _items = widget.transactions;
        _isLoading = false;
      });
      return;
    }
    try {
      final res = await AppQueries.transactions(widget.walletId, pageSize: 200).result;
      final rawList = res.data?['items'] as List<dynamic>? ?? [];
      final filtered = rawList.where((t) {
        if (t is! Map<String, dynamic>) return false;
        final type = t['type']?.toString() ?? 'expense';
        if (type != 'expense') return false;
        final tCode = t['categoryCode']?.toString() ?? t['category_code']?.toString() ?? '';
        final tName = t['categoryName']?.toString() ?? t['category_name']?.toString() ?? '';
        final isOther = widget.categoryCode.toLowerCase() == 'other' || widget.categoryCode.toLowerCase() == 'others';
        if (isOther) {
          return tCode.isEmpty || tCode.toLowerCase() == 'other' || tCode.toLowerCase() == 'others';
        }
        return tCode.toLowerCase() == widget.categoryCode.toLowerCase() ||
               tName.toLowerCase() == widget.categoryName.toLowerCase();
      }).toList();

      if (mounted) {
        setState(() {
          _items = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _items = widget.transactions;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = CategoryTheme.of(widget.categoryCode);

    // Chuẩn bị dữ liệu biểu đồ phân bố theo ngày hoặc khoản chi
    final List<int> barValues = [];
    final Map<String, int> dailySums = {};
    for (final t in _items) {
      if (t is Map<String, dynamic>) {
        final dateStr = t['occurredAt']?.toString() ?? t['occurred_at']?.toString() ?? '';
        final day = dateStr.length >= 10 ? dateStr.substring(5, 10) : 'Khác';
        final amt = (t['amount'] as num?)?.toInt() ?? 0;
        dailySums[day] = (dailySums[day] ?? 0) + amt;
      }
    }
    barValues.addAll(dailySums.values);

    final actualTotal = _items.fold<int>(0, (sum, t) {
      if (t is Map<String, dynamic>) {
        return sum + ((t['amount'] as num?)?.toInt() ?? 0);
      }
      return sum;
    });
    final displayTotal = actualTotal > 0 ? actualTotal : widget.totalAmount;

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        backgroundColor: context.palette.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CategoryTheme.iconOf(widget.categoryCode, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.categoryName,
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thẻ tổng quan
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        boxShadow: context.palette.softShadow,
                        border: Border.all(color: style.color.withValues(alpha: 0.25), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Chi tiêu kỳ: ${widget.dateRangeLabel}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: style.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Chiếm ${widget.percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: style.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            formatVnd(displayTotal),
                            style: TextStyle(
                              color: context.palette.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Biểu đồ phân bổ chi tiêu
                    Container(
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
                            'Phân bổ chi tiêu danh mục',
                            style: TextStyle(
                              color: context.palette.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 160,
                            child: barValues.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Chưa có đủ dữ liệu phân bổ chi tiết',
                                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                                    ),
                                  )
                                : _CategoryDetailBarChart(values: barValues, color: style.color),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Danh sách giao dịch thuộc danh mục
                    Text(
                      'Các khoản chi (${_items.length})',
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          color: context.palette.card,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        child: const Center(
                          child: Text(
                            'Chưa có giao dịch nào trong danh mục này',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ..._items.map((t) {
                        final map = t as Map<String, dynamic>;
                        final note = map['note']?.toString() ?? widget.categoryName;
                        final amt = (map['amount'] as num?)?.toInt() ?? 0;
                        final date = map['occurredAt']?.toString() ?? map['occurred_at']?.toString() ?? '';
                        final displayDate = date.length >= 10 ? date.substring(0, 10) : date;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.palette.card,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            boxShadow: context.palette.softShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: style.color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: CategoryTheme.iconOf(widget.categoryCode, size: 20),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note.isEmpty ? widget.categoryName : note,
                                      style: TextStyle(
                                        color: context.palette.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      displayDate,
                                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '-${formatVnd(amt)}',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CategoryDetailBarChart extends StatelessWidget {
  final List<int> values;
  final Color color;

  const _CategoryDetailBarChart({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxVal = values.fold<int>(0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal > 0 ? (maxVal * 1.2) : 100,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                formatVnd(rod.toY.toInt()),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: const FlTitlesData(
          show: true,
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(values.length, (idx) {
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: values[idx].toDouble(),
                color: color,
                width: 14,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }),
      ),
    );
  }
}
