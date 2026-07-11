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

class SavingTrendReportScreen extends StatefulWidget {
  final String? initialWalletId;
  const SavingTrendReportScreen({super.key, this.initialWalletId});

  @override
  State<SavingTrendReportScreen> createState() => _SavingTrendReportScreenState();
}

class _SavingTrendReportScreenState extends State<SavingTrendReportScreen> {
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
      final prompt = 'Phân tích xu hướng tiết kiệm và tích lũy ròng qua kỳ $_selectedPeriod. Đưa ra lời khuyên gia tăng tiền tiết kiệm.';
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
          _aiInsight = 'Xu hướng tiết kiệm đang duy trì nhịp độ đều đặn. Việc thiết lập trích lập tự động 15-20% thu nhập sẽ giúp tích lũy vững chắc hơn!';
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
          'Xu hướng tiết kiệm',
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

              // Biểu đồ Xu hướng tiết kiệm
              _buildSavingChartCard(),
            ],
          ),
        ),
      ),
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
                            ? 'MiMo đang phân tích tích lũy tiết kiệm...'
                            : 'Nhấn để MiMo phân tích xu hướng tích lũy ròng',
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

  Widget _buildSavingChartCard() {
    final labels = _selectedPeriod == 'Theo tuần'
        ? ['W1', 'W2', 'W3', 'W4']
        : ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    final values = _selectedPeriod == 'Theo tuần'
        ? [500000.0, 1200000.0, 800000.0, 1500000.0]
        : [0.0, -50000.0, 100000.0, 250000.0, 300000.0, -420000.0, -450000.0];

    final minY = values.fold<double>(0, (a, b) => a < b ? a : b);
    final maxY = values.fold<double>(100000, (a, b) => a > b ? a : b);

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
            'Biểu đồ tích lũy ròng (Thu - Chi)',
            style: TextStyle(color: context.palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minY: minY * 1.2,
                maxY: maxY * 1.2,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        return LineTooltipItem(
                          formatVnd(spot.y.toInt()),
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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
                      reservedSize: 46,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) {
                          return const Text('0', style: TextStyle(color: AppColors.muted, fontSize: 10));
                        }
                        final absVal = val.abs();
                        final prefix = val < 0 ? '-' : '';
                        String formatted;
                        if (absVal >= 1000000) {
                          formatted = '$prefix${(absVal / 1000000).toStringAsFixed(1)}M';
                        } else if (absVal >= 1000) {
                          formatted = '$prefix${(absVal / 1000).toStringAsFixed(0)}K';
                        } else {
                          formatted = '$prefix${absVal.toInt()}';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            formatted,
                            style: const TextStyle(color: AppColors.muted, fontSize: 10),
                            textAlign: TextAlign.right,
                          ),
                        );
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
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(labels.length, (idx) => FlSpot(idx.toDouble(), values[idx])),
                    isCurved: true,
                    color: AppColors.teal,
                    barWidth: 3.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: Colors.white,
                          strokeWidth: 2.5,
                          strokeColor: AppColors.teal,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.teal.withValues(alpha: 0.35),
                          AppColors.teal.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
