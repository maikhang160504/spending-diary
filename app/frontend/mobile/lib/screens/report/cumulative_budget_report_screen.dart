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
  List<dynamic> _wallets = [];
  String? _selectedWalletId;
  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId ?? ApiClient.lastSelectedWalletId;
    _loadWallets();
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

  Future<void> _loadWallets() async {
    try {
      final wallets = await _api.getWallets();
      if (mounted) {
        setState(() {
          _wallets = wallets.where((w) => w['type'] != 'group').toList();
          if (_selectedWalletId == null && _wallets.isNotEmpty) {
            _selectedWalletId = _wallets.first['id'] as String?;
            ApiClient.lastSelectedWalletId = _selectedWalletId;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _analyzeAI() async {
    setState(() => _isAnalyzingAI = true);
    try {
      final prompt = 'Phân tích tốc độ tiêu hao hạn mức ngân sách (Burn rate index) và đường chi tiêu lũy kế so với hạn mức lý tưởng trong kỳ $_selectedPeriod. Hãy đưa ra cảnh báo và đề xuất chi tiêu an toàn cho các ngày còn lại.';
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
          _aiInsight = 'Tốc độ chi tiêu lũy kế đang bám sát hạn mức an toàn. Hãy giữ mức chi tiêu ngày dưới 400,000 VNĐ để hoàn thành mục tiêu tháng!';
          _isAnalyzingAI = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const totalBudget = 15000000;
    const currentSpent = 9200000;
    const remaining = totalBudget - currentSpent;
    final pct = (currentSpent / totalBudget * 100).clamp(0, 100);

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
          'Chi tiêu mức lũy kế',
          style: TextStyle(color: context.palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bộ lọc Theo tuần / Theo tháng
              Row(
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
                          _buildPeriodBtn('Theo tuần', _selectedPeriod == 'Theo tuần', () {
                            setState(() { _selectedPeriod = 'Theo tuần'; _periodOffset = 0; });
                          }),
                          _buildPeriodBtn('Theo tháng', _selectedPeriod == 'Theo tháng', () {
                            setState(() { _selectedPeriod = 'Theo tháng'; _periodOffset = 0; });
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded, color: context.palette.textPrimary),
                      onPressed: () {
                        setState(() => _periodOffset++);
                      },
                    ),
                    Text(
                      _getPeriodLabel(),
                      style: TextStyle(color: context.palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, color: _periodOffset > 0 ? context.palette.textPrimary : AppColors.muted),
                      onPressed: _periodOffset > 0 ? () {
                        setState(() => _periodOffset--);
                      } : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildWalletSelectorBar(),
              const SizedBox(height: 20),

              // AI Advisor MiMo
              _buildAISection(),
              const SizedBox(height: 20),

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
                      formatVnd(totalBudget),
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
                        Expanded(child: _buildStatCol('Đã chi lũy kế', formatVnd(currentSpent), AppColors.danger, isRight: false)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCol('Còn lại an toàn', formatVnd(remaining), AppColors.teal, isRight: true)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Biểu đồ lũy kế vs Hạn mức lý tưởng
              _buildCumulativeChartCard(),
            ],
          ),
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

  Widget _buildWalletSelectorBar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildWalletChipItem('Tất cả ví', null),
            ..._wallets.map((w) {
              final id = w['id']?.toString();
              final name = w['name']?.toString() ?? 'Ví';
              return _buildWalletChipItem(name, id);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletChipItem(String label, String? walletId) {
    final isSelected = _selectedWalletId == walletId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedWalletId = walletId;
            ApiClient.lastSelectedWalletId = walletId;
          });
          // _loadReportData();
        },
        borderRadius: BorderRadius.circular(AppRadii.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.teal : context.palette.card,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(
              color: isSelected ? AppColors.teal : context.palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                walletId == null ? Icons.all_inclusive_rounded : Icons.account_balance_wallet_outlined,
                size: 12,
                color: isSelected ? Colors.white : context.palette.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.palette.textPrimary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : context.palette.textPrimary,
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
    final days = [1, 5, 10, 15, 20, 25, 30];
    final idealSpots = days.map((d) => FlSpot(d.toDouble(), d * 500000.0)).toList();
    final actualSpots = [
      const FlSpot(1, 400000),
      const FlSpot(5, 2200000),
      const FlSpot(10, 4500000),
      const FlSpot(15, 7100000),
      const FlSpot(20, 9200000),
    ];

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
            height: 240,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 16500000,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => context.palette.card,
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
                      interval: 5,
                      getTitlesWidget: (val, meta) {
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
                  // Đường lý tưởng (đứt đoạn / mờ hơn)
                  LineChartBarData(
                    spots: idealSpots,
                    isCurved: false,
                    color: AppColors.muted.withValues(alpha: 0.7),
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                  // Đường thực tế
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: true,
                    color: AppColors.danger,
                    barWidth: 3.5,
                    dotData: FlDotData(show: true),
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
