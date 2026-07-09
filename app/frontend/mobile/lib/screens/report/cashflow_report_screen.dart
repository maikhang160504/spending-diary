import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../services/ai_advisor_service.dart';

class CashflowReportScreen extends StatefulWidget {
  final String? initialWalletId;
  const CashflowReportScreen({super.key, this.initialWalletId});

  @override
  State<CashflowReportScreen> createState() => _CashflowReportScreenState();
}

class _CashflowReportScreenState extends State<CashflowReportScreen> {
  String? _selectedWalletId;
  String _selectedPeriod = 'Theo tháng'; // 'Theo tuần', 'Theo tháng'
  bool _compareYoY = false; // "So với cùng kỳ"
  String _selectedTab = 'Chi'; // 'Chi', 'Thu', 'Chênh lệch'
  bool _isAnalyzingAI = false;
  String? _aiInsight;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
  }

  Future<void> _analyzeAI() async {
    setState(() => _isAnalyzingAI = true);
    try {
      final walletNote = _selectedWalletId != null ? ' trên ví $_selectedWalletId' : '';
      final prompt = 'Phân tích biến động dòng tiền ($_selectedTab)$walletNote chế độ so cùng kỳ ($_compareYoY) theo thời gian kỳ $_selectedPeriod. Hãy đưa ra nhận xét ngắn gọn và dễ hiểu cho người dùng.';
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
          _aiInsight = 'Dòng tiền đang có sự dao động qua các chu kỳ. Hãy theo dõi sát mức chênh lệch Thu - Chi để duy trì tích lũy dương!';
          _isAnalyzingAI = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Biến động thu chi',
          style: TextStyle(color: context.palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bộ lọc thời gian & toggle So với cùng kỳ
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
                            setState(() => _selectedPeriod = 'Theo tuần');
                          }),
                          _buildPeriodBtn('Theo tháng', _selectedPeriod == 'Theo tháng', () {
                            setState(() => _selectedPeriod = 'Theo tháng');
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Header switch So với cùng kỳ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.palette.card,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  boxShadow: context.palette.softShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'So với cùng kỳ',
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Switch.adaptive(
                      value: _compareYoY,
                      activeTrackColor: AppColors.teal,
                      onChanged: (val) => setState(() => _compareYoY = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tabs Chi / Thu / Chênh lệch
              Row(
                children: [
                  _buildTab('Chi'),
                  const SizedBox(width: 8),
                  _buildTab('Thu'),
                  const SizedBox(width: 8),
                  _buildTab('Chênh lệch'),
                ],
              ),
              const SizedBox(height: 20),

              // Box Phân tích AI từ MiMo
              _buildAISection(),
              const SizedBox(height: 20),

              // Biểu đồ Biến động thu chi
              _buildChartCard(),
              const SizedBox(height: 20),

              // Ghi chú giải thích màu cột
              if (_compareYoY)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendDot(AppColors.teal, 'Kỳ hiện tại'),
                    const SizedBox(width: 24),
                    _buildLegendDot(AppColors.tealDark.withValues(alpha: 0.65), 'Cùng kỳ trước'),
                  ],
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

  Widget _buildTab(String label) {
    final active = _selectedTab == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = label),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.teal.withValues(alpha: 0.15) : context.palette.card,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: active ? AppColors.teal : context.palette.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.teal : context.palette.textPrimary,
              fontSize: 13,
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
                  decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
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
                            ? 'MiMo đang phân tích dòng tiền...'
                            : 'Nhấn để MiMo phân tích xu hướng thu chi',
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

  Widget _buildChartCard() {
    final labels = _selectedPeriod == 'Theo tuần'
        ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
        : ['T1', 'T2', 'T3', 'T4', 'T5', 'T6'];
    final currentValues = _selectedPeriod == 'Theo tuần'
        ? [350000.0, 1200000.0, 600000.0, 1300000.0, 200000.0, 1850000.0, 800000.0]
        : [2100000.0, 3200000.0, 1900000.0, 4100000.0, 2800000.0, 3500000.0];
    final prevValues = _selectedPeriod == 'Theo tuần'
        ? [400000.0, 950000.0, 800000.0, 1100000.0, 300000.0, 1500000.0, 700000.0]
        : [1900000.0, 3500000.0, 2100000.0, 3800000.0, 3100000.0, 3200000.0];

    final maxVal = currentValues.fold<double>(0, (a, b) => a > b ? a : b);

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
            style: TextStyle(color: context.palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.25,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIdx, rod, rodIdx) {
                      return BarTooltipItem(
                        formatVnd(rod.toY.toInt()),
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      );
                    },
                  ),
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
                        if (val == 0) return const SizedBox();
                        final compact = val >= 1000000 ? '${(val / 1000000).toStringAsFixed(1)}M' : '${(val / 1000).toStringAsFixed(0)}K';
                        return Text(compact, style: const TextStyle(color: AppColors.muted, fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= labels.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[idx], style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(color: context.palette.border.withValues(alpha: 0.5), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(labels.length, (idx) {
                  final cur = currentValues[idx];
                  final prev = prevValues[idx];
                  if (!_compareYoY) {
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: cur,
                          color: AppColors.teal,
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }
                  final higher = cur >= prev ? cur : prev;
                  final higherColor = cur >= prev ? AppColors.teal : AppColors.tealDark.withValues(alpha: 0.65);
                  final lower = cur >= prev ? prev : cur;
                  final lowerColor = cur >= prev ? AppColors.tealDark.withValues(alpha: 0.65) : AppColors.teal;

                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: higher,
                        color: higherColor,
                        width: 20,
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
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}
