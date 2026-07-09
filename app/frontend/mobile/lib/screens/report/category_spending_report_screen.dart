import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../services/app_queries.dart';
import '../../services/ai_advisor_service.dart';
import 'category_detail_report_screen.dart';

class CategorySpendingReportScreen extends StatefulWidget {
  final String? initialWalletId;
  const CategorySpendingReportScreen({super.key, this.initialWalletId});

  @override
  State<CategorySpendingReportScreen> createState() => _CategorySpendingReportScreenState();
}

class _CategorySpendingReportScreenState extends State<CategorySpendingReportScreen> {
  String? _selectedWalletId;
  String _selectedPeriod = 'Tháng này'; // 'Tuần này', 'Tháng này'
  bool _isAnalyzingAI = false;
  String? _aiInsight;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
  }

  Future<void> _analyzeAI(List<dynamic> cats) async {
    setState(() {
      _isAnalyzingAI = true;
    });
    try {
      final summaryStr = cats.map((c) => '${c['categoryLabel']}: ${formatVnd(c['amount'] ?? 0)} (${c['percent']}%)').join(', ');
      final prompt = 'Phân tích nhanh chi tiêu theo danh mục kỳ $_selectedPeriod: $summaryStr';
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
          _aiInsight = 'MiMo nhận thấy bạn có sự phân bổ chi tiêu đa dạng. Hãy chú ý tối ưu các khoản chi lớn nhất nhé!';
          _isAnalyzingAI = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String fromStr;
    String toStr;
    if (_selectedPeriod == 'Tuần này') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      fromStr = startOfWeek.toIso8601String().substring(0, 10);
      toStr = now.toIso8601String().substring(0, 10);
    } else {
      fromStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      toStr = now.toIso8601String().substring(0, 10);
    }

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        backgroundColor: context.palette.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chi tiêu theo danh mục',
          style: TextStyle(color: context.palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Bộ lọc: Ví & Thời gian (Theo tuần / Theo tháng)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Row(
                        children: [
                          _buildPeriodBtn('Theo tuần', _selectedPeriod == 'Tuần này', () {
                            setState(() => _selectedPeriod = 'Tuần này');
                          }),
                          _buildPeriodBtn('Theo tháng', _selectedPeriod == 'Tháng này', () {
                            setState(() => _selectedPeriod = 'Tháng này');
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: FutureBuilder(
                future: AppQueries.statsByCategory('custom', _selectedWalletId, from: fromStr, to: toStr).result,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rawCats = snapshot.data?.data ?? [];
                  final Map<String, Map<String, dynamic>> mergedMap = {};
                  int totalAmt = 0;
                  for (final c in rawCats) {
                    final map = c as Map<String, dynamic>;
                    final code = map['categoryCode']?.toString() ?? 'Other';
                    final amt = (map['amount'] as num?)?.toInt() ?? 0;
                    final label = CategoryTheme.of(code).label;
                    totalAmt += amt;
                    if (mergedMap.containsKey(label)) {
                      mergedMap[label]!['amount'] = (mergedMap[label]!['amount'] as int) + amt;
                    } else {
                      mergedMap[label] = {
                        'categoryCode': code,
                        'categoryLabel': label,
                        'amount': amt,
                        'color': CategoryTheme.of(code).color.toARGB32(),
                      };
                    }
                  }
                  final cats = mergedMap.values.toList();
                  for (final c in cats) {
                    c['percent'] = totalAmt > 0 ? ((c['amount'] as int) * 100 / totalAmt) : 0.0;
                  }
                  cats.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAISection(cats),
                        const SizedBox(height: 16),
                        _buildSoftDonutChartSection(cats, totalAmt),
                        const SizedBox(height: 24),
                        Text(
                          'Chi tiết danh mục',
                          style: TextStyle(
                            color: context.palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (cats.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            child: const Text('Chưa có dữ liệu chi tiêu', style: TextStyle(color: AppColors.muted)),
                          )
                        else
                          ...cats.map((cat) => _buildCategoryTile(cat)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : context.palette.textPrimary,
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAISection(List<dynamic> cats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isAnalyzingAI ? null : () => _analyzeAI(cats),
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
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
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
                            ? 'MiMo đang phân tích cấu trúc chi tiêu...'
                            : 'Nhấn để MiMo phân tích & đưa ra lời khuyên cho bạn',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.teal,
                  child: Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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

  Widget _buildSoftDonutChartSection(List<dynamic> cats, int totalAmt) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: cats.isEmpty
                ? const Center(child: Text('Chưa có chi tiêu', style: TextStyle(color: AppColors.muted)))
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 65,
                          sections: cats.map((cat) {
                            final pct = (cat['percent'] as double?) ?? 0.0;
                            final color = Color(cat['color'] as int? ?? AppColors.teal.toARGB32());
                            return PieChartSectionData(
                              color: color,
                              value: pct > 0 ? pct : 0.1,
                              title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                              radius: 28,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Tổng chi', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            formatVnd(totalAmt),
                            style: TextStyle(
                              color: context.palette.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: cats.take(6).map((cat) {
              final color = Color(cat['color'] as int? ?? AppColors.teal.toARGB32());
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat['categoryLabel']?.toString() ?? '',
                    style: TextStyle(color: context.palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> cat) {
    final code = cat['categoryCode']?.toString() ?? 'Other';
    final label = cat['categoryLabel']?.toString() ?? 'Khác';
    final amount = (cat['amount'] as num?)?.toInt() ?? 0;
    final percent = (cat['percent'] as num?)?.toDouble() ?? 0.0;
    final color = Color(cat['color'] as int? ?? AppColors.teal.toARGB32());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CategoryDetailReportScreen(
                categoryCode: code,
                categoryName: label,
                totalAmount: amount,
                percentage: percent,
                dateRangeLabel: _selectedPeriod,
                walletId: _selectedWalletId,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
            boxShadow: context.palette.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(child: CategoryTheme.iconOf(code, size: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        backgroundColor: color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatVnd(amount),
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
