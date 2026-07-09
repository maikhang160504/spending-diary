import os

file_path = "d:/Luan-Van/Project/app/frontend/mobile/lib/screens/report/report_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

start = content.find("  Widget build(BuildContext context) {")
end = content.find("class _ReportHeader extends StatelessWidget {")

original_build = content[start:end]

new_build = """  Widget build(BuildContext context) {
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
                ),
                const SizedBox(height: 20),
                _MimoInsightCard(
                  totalExpense: _totalExpense,
                  totalIncome: _totalIncome,
                  topCategory: _categoryStats.isNotEmpty ? _categoryStats.first : null,
                  selectedRange: _selectedRange,
                ),
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
              ],
            );

            Widget rightColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      Text(
                        _selectedRange == 'Theo tháng'
                            ? 'So sánh tháng này vs tháng trước'
                            : 'Chi tiêu theo ngày',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (_selectedRange == 'Theo tháng') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('Tháng trước', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 16),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.teal,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('Tháng này', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      _selectedRange == 'Theo tháng'
                          ? _MoMGroupedBarChart(stats: _momStats)
                          : (_reportBars.isEmpty
                              ? const Center(child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.muted))))
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
"""

mimo_insight = """
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
    if (totalIncome == 0) return 'assets/images/mimo/thinking.png';
    if (ratio > 0.9) return 'assets/images/mimo/sad.png';
    if (ratio > 0.7) return 'assets/images/mimo/happy.png';
    return 'assets/images/mimo/happy.png';
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
"""

content = content.replace(original_build, new_build)
content = content + "\n" + mimo_insight

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Report screen updated successfully")
