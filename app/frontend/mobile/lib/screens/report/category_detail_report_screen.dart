import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../services/app_queries.dart';
import '../../services/api_client.dart';

class CategoryDetailReportScreen extends StatefulWidget {
  final String categoryCode;
  final String categoryName;
  final int totalAmount;
  final double percentage;
  final String dateRangeLabel;
  final String? walletId;
  final String recordType;
  final List<dynamic> transactions;

  const CategoryDetailReportScreen({
    super.key,
    required this.categoryCode,
    required this.categoryName,
    required this.totalAmount,
    required this.percentage,
    required this.dateRangeLabel,
    this.walletId,
    this.recordType = 'expense',
    this.transactions = const [],
  });

  @override
  State<CategoryDetailReportScreen> createState() => _CategoryDetailReportScreenState();
}

class _CategoryDetailReportScreenState extends State<CategoryDetailReportScreen> {
  List<dynamic> _allItems = [];
  bool _isLoading = true;
  bool _showAllMonths = true;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      List<dynamic> rawList = [];
      try {
        final res = await AppQueries.transactions(widget.walletId, pageSize: 500).result;
        final payload = res.data?['data'] ?? res.data;
        if (payload is Map<String, dynamic>) {
          rawList = (payload['items'] as List<dynamic>?) ?? [];
        } else if (payload is List<dynamic>) {
          rawList = payload;
        }
      } catch (_) {}

      if (rawList.isEmpty) {
        try {
          final apiRes = await ApiClient().getTransactions(walletId: widget.walletId, pageSize: 500);
          final dataObj = apiRes['data'];
          if (dataObj is Map<String, dynamic>) {
            rawList = (dataObj['items'] as List<dynamic>?) ?? [];
          } else if (dataObj is List<dynamic>) {
            rawList = dataObj;
          } else if (apiRes['items'] is List<dynamic>) {
            rawList = apiRes['items'] as List<dynamic>;
          }
        } catch (_) {}
      }

      if (rawList.isEmpty && widget.transactions.isNotEmpty) {
        rawList = widget.transactions;
      }

      final targetCanonical = CategoryTheme.canonicalCodeOf(widget.categoryCode).toLowerCase();
      final targetLabel = CategoryTheme.of(widget.categoryCode).label.toLowerCase();

      final filtered = rawList.where((t) {
        if (t is! Map<String, dynamic>) return false;
        final type = t['type']?.toString() ?? 'expense';
        if (type.toLowerCase() != widget.recordType.toLowerCase()) return false;

        final tCode = t['categoryCode']?.toString() ?? t['category_code']?.toString() ?? '';
        final tName = t['categoryName']?.toString() ?? t['category_name']?.toString() ?? t['category']?.toString() ?? '';
        final isOther = targetCanonical == 'other' || targetCanonical == 'others';
        if (isOther) {
          return tCode.isEmpty ||
                 tCode.toLowerCase() == 'other' ||
                 tCode.toLowerCase() == 'others' ||
                 CategoryTheme.canonicalCodeOf(tCode).toLowerCase() == 'other';
        }

        final tCanonical = CategoryTheme.canonicalCodeOf(tCode).toLowerCase();
        final tLabel = CategoryTheme.of(tCode).label.toLowerCase();
        return tCode.toLowerCase() == widget.categoryCode.toLowerCase() ||
               tCanonical == targetCanonical ||
               tLabel == targetLabel ||
               tName.toLowerCase() == widget.categoryName.toLowerCase() ||
               tName.toLowerCase() == targetLabel;
      }).toList();

      if (mounted) {
        setState(() {
          _allItems = filtered.isNotEmpty ? filtered : widget.transactions;
          if (_allItems.isNotEmpty) {
            final first = _allItems.first as Map<String, dynamic>;
            final dateStr = first['occurredAt']?.toString() ?? first['occurred_at']?.toString() ?? '';
            if (dateStr.length >= 7) {
              final y = int.tryParse(dateStr.substring(0, 4));
              final m = int.tryParse(dateStr.substring(5, 7));
              if (y != null && m != null && _monthItems.isEmpty) {
                _selectedMonth = DateTime(y, m);
              }
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _allItems = widget.transactions; _isLoading = false; });
    }
  }

  List<dynamic> get _monthItems {
    return _allItems.where((t) {
      if (t is! Map<String, dynamic>) return false;
      final dateStr = t['occurredAt']?.toString() ?? t['occurred_at']?.toString() ?? '';
      if (dateStr.length < 7) return false;
      final txYear = int.tryParse(dateStr.substring(0, 4)) ?? 0;
      final txMonth = int.tryParse(dateStr.substring(5, 7)) ?? 0;
      return txYear == _selectedMonth.year && txMonth == _selectedMonth.month;
    }).toList();
  }

  int get _monthTotal => _monthItems.fold<int>(0, (sum, t) {
    final map = t as Map<String, dynamic>;
    return sum + ((map['amount'] as num?)?.toInt() ?? 0);
  });

  // Tính chi tiêu từng tháng cho bar chart (6 tháng gần nhất)
  List<Map<String, dynamic>> get _monthlyTrend {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthItems = _allItems.where((t) {
        if (t is! Map<String, dynamic>) return false;
        final dateStr = t['occurredAt']?.toString() ?? t['occurred_at']?.toString() ?? '';
        if (dateStr.length < 7) return false;
        final txYear = int.tryParse(dateStr.substring(0, 4)) ?? 0;
        final txMonth = int.tryParse(dateStr.substring(5, 7)) ?? 0;
        return txYear == month.year && txMonth == month.month;
      });
      final total = monthItems.fold<int>(0, (sum, t) {
        return sum + (((t as Map<String, dynamic>)['amount'] as num?)?.toInt() ?? 0);
      });
      result.add({'month': month, 'total': total});
    }
    return result;
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = CategoryTheme.of(widget.categoryCode);
    final items = _showAllMonths ? _allItems : _monthItems;
    final displayTotal = _showAllMonths
        ? _allItems.fold<int>(0, (s, t) => s + (((t as Map<String, dynamic>)['amount'] as num?)?.toInt() ?? 0))
        : _monthTotal;
    final trend = _monthlyTrend;

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        backgroundColor: context.palette.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(children: [
          CategoryTheme.iconOf(widget.categoryCode, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.categoryName,
              style: TextStyle(color: context.palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle Tất cả / Theo tháng
                  Container(
                    padding: const EdgeInsets.all(4),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showAllMonths = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _showAllMonths ? AppColors.teal : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                            child: Text('Toàn bộ trong kỳ',
                              style: TextStyle(
                                color: _showAllMonths ? Colors.white : context.palette.textPrimary,
                                fontSize: 13,
                                fontWeight: _showAllMonths ? FontWeight.w700 : FontWeight.w500,
                              )),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showAllMonths = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !_showAllMonths ? AppColors.teal : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                            child: Text('Theo từng tháng',
                              style: TextStyle(
                                color: !_showAllMonths ? Colors.white : context.palette.textPrimary,
                                fontSize: 13,
                                fontWeight: !_showAllMonths ? FontWeight.w700 : FontWeight.w500,
                              )),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  if (!_showAllMonths) ...[
                    // ── Month picker ────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        boxShadow: context.palette.softShadow,
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 28),
                          color: context.palette.textPrimary,
                          onPressed: () => _changeMonth(-1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Column(children: [
                          Text(
                            'Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                            style: TextStyle(color: context.palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayTotal > 0 ? formatVnd(displayTotal) : 'Không có chi tiêu',
                            style: TextStyle(
                              color: displayTotal > 0 ? style.color : AppColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ]),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 28),
                          color: context.palette.textPrimary,
                          onPressed: () => _changeMonth(1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 6-month trend bar chart ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      boxShadow: context.palette.softShadow,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Xu hướng chi tiêu (6 tháng)',
                        style: TextStyle(color: context.palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 140,
                        child: _buildTrendChart(trend, style.color),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Summary card ────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      boxShadow: context.palette.softShadow,
                      border: Border.all(color: style.color.withValues(alpha: 0.25), width: 1.5),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: style.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: CategoryTheme.iconOf(widget.categoryCode, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Kỳ: ${widget.dateRangeLabel}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(formatVnd(widget.totalAmount),
                          style: TextStyle(color: context.palette.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: style.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(color: style.color, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Transaction list ────────────────────────────────────────
                  Row(children: [
                    Text('Các khoản ${widget.recordType == 'income' ? 'thu' : 'chi'}',
                      style: TextStyle(color: context.palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: style.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${items.length}',
                        style: TextStyle(color: style.color, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Column(children: [
                        Icon(Icons.receipt_long_rounded, size: 40, color: AppColors.muted.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          _showAllMonths
                              ? 'Chưa có giao dịch nào trong kỳ này'
                              : 'Chưa có giao dịch trong tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    )
                  else
                    ...items.map((t) {
                      final map = t as Map<String, dynamic>;
                      final note = map['note']?.toString() ?? '';
                      final amt = (map['amount'] as num?)?.toInt() ?? 0;
                      final date = map['occurredAt']?.toString() ?? map['occurred_at']?.toString() ?? '';
                      final displayDate = date.length >= 10 ? date.substring(0, 10) : date;
                      final isIncome = widget.recordType == 'income';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.palette.card,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          boxShadow: context.palette.softShadow,
                        ),
                        child: Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                            child: Center(child: CategoryTheme.iconOf(widget.categoryCode, size: 20)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              note.isNotEmpty ? note : widget.categoryName,
                              style: TextStyle(color: context.palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(displayDate, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ])),
                          Text(
                            isIncome ? '+${formatVnd(amt)}' : '-${formatVnd(amt)}',
                            style: TextStyle(
                              color: isIncome ? AppColors.teal : AppColors.danger,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
                      );
                    }),
                ],
              ),
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildTrendChart(List<Map<String, dynamic>> trend, Color color) {
    final maxVal = trend.fold<int>(0, (a, b) => (b['total'] as int) > a ? b['total'] as int : a);
    final now = DateTime.now();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal > 0 ? (maxVal * 1.25).toDouble() : 1000000,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final entry = trend[groupIndex];
              final m = entry['month'] as DateTime;
              return BarTooltipItem(
                'T${m.month}/${m.year}\n${formatVndCompact(rod.toY.toInt())}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= trend.length) return const SizedBox();
                final m = trend[idx]['month'] as DateTime;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('T${m.month}',
                    style: TextStyle(
                      color: m.year == _selectedMonth.year && m.month == _selectedMonth.month
                          ? color
                          : AppColors.muted,
                      fontSize: 11,
                      fontWeight: m.year == _selectedMonth.year && m.month == _selectedMonth.month
                          ? FontWeight.w700
                          : FontWeight.w500,
                    )),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: trend.asMap().entries.map((entry) {
          final idx = entry.key;
          final data = entry.value;
          final m = data['month'] as DateTime;
          final total = (data['total'] as int).toDouble();
          final isSelected = m.year == _selectedMonth.year && m.month == _selectedMonth.month;
          final isCurrent = m.year == now.year && m.month == now.month;
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: total > 0 ? total : 0,
                color: isSelected
                    ? color
                    : isCurrent
                        ? color.withValues(alpha: 0.6)
                        : color.withValues(alpha: 0.25),
                width: 20,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
