import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../services/ai_advisor_service.dart';
import '../../services/app_queries.dart';

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
  int _periodOffset = 0;
  String? _aiInsight;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left_rounded, color: context.palette.textPrimary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() => _periodOffset++);
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Text(
                                _getPeriodLabel(),
                                style: TextStyle(color: context.palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.chevron_right_rounded, color: _periodOffset > 0 ? context.palette.textPrimary : AppColors.muted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _periodOffset > 0 ? () {
                              setState(() => _periodOffset--);
                            } : null,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Text('So cùng kỳ', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.7,
                          child: Switch.adaptive(
                            value: _compareYoY,
                            activeTrackColor: AppColors.teal,
                            onChanged: (val) => setState(() => _compareYoY = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildWalletSelectorBar(),
              const SizedBox(height: 12),

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
              const SizedBox(height: 16),

              // Ghi chú giải thích màu cột
              if (_compareYoY)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendDot(AppColors.teal, 'Kỳ hiện tại'),
                    const SizedBox(width: 24),
                    _buildLegendDot(AppColors.warning, 'Cùng kỳ trước'),
                  ],
                ),
              const SizedBox(height: 24),

              // Danh sách danh mục (Thu/Chi) hoặc Bảng chênh lệch Thu - Chi theo tuần/tháng
              _buildBottomDetailSection(),
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

  Widget _buildTab(String label) {
    final active = _selectedTab == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = label),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.teal.withValues(alpha: 0.15) : context.palette.card,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: active ? AppColors.teal : context.palette.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.teal : context.palette.textPrimary,
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

  Widget _buildWalletSelectorBar() {
    return FutureBuilder(
      future: AppQueries.wallets().result,
      builder: (context, snapshot) {
        final rawList = snapshot.data?.data ?? [];
        final wallets = <Map<String, dynamic>>[];
        if (snapshot.hasData) {
          for (var item in rawList) {
            if (item is Map<String, dynamic> && item['type'] != 'group') wallets.add(item);
          }
        }
        return Container(
          padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, bottom: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildWalletChipItem('Tất cả ví', null),
                ...wallets.map((w) {
                  final id = w['id']?.toString();
                  final name = w['name']?.toString() ?? 'Ví';
                  return _buildWalletChipItem(name, id);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalletChipItem(String label, String? walletId) {
    final isSelected = _selectedWalletId == walletId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedWalletId = walletId),
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
                      reservedSize: 54,
                      interval: maxVal > 0 ? (maxVal / 3) : 1000000,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox();
                        final compact = val >= 1000000 ? '${(val / 1000000).toStringAsFixed(1)}Tr' : '${(val / 1000).toStringAsFixed(0)}K';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(compact, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
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
                  final higherColor = cur >= prev ? AppColors.teal : AppColors.warning;
                  final lower = cur >= prev ? prev : cur;
                  final lowerColor = cur >= prev ? AppColors.warning : AppColors.teal;

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

  Widget _buildBottomDetailSection() {
    if (_selectedTab == 'Chênh lệch') {
      return _buildNetCashflowBreakdown();
    }
    return _buildCategoryBreakdownList();
  }

  Widget _buildCategoryBreakdownList() {
    final isIncome = _selectedTab == 'Thu';
    final typeParam = isIncome ? 'income' : 'expense';
    final title = isIncome ? 'Danh mục Thu nhập' : 'Danh mục Chi tiêu';

    return FutureBuilder(
      future: AppQueries.statsByCategory('custom', _selectedWalletId, type: typeParam).result,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        final rawList = snapshot.data?.data ?? [];
        int totalAmt = 0;
        final List<Map<String, dynamic>> cats = [];
        for (final item in rawList) {
          final map = item as Map<String, dynamic>;
          final amt = (map['amount'] as num?)?.toInt() ?? (map['total'] as num?)?.toInt() ?? 0;
          final code = map['categoryCode']?.toString() ?? 'Other';
          final label = CategoryTheme.of(code).label;
          totalAmt += amt;
          cats.add({
            'code': code,
            'label': label,
            'amount': amt,
            'color': CategoryTheme.of(code).color,
          });
        }
        cats.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));

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
                title,
                style: TextStyle(color: context.palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (cats.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('Chưa có dữ liệu $_selectedTab trong kỳ này', style: const TextStyle(color: AppColors.muted)),
                  ),
                )
              else
                ...cats.map((cat) {
                  final amt = cat['amount'] as int;
                  final pct = totalAmt > 0 ? (amt / totalAmt) : 0.0;
                  final color = cat['color'] as Color;
                  final label = cat['label'] as String;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: CategoryTheme.iconOf(cat['code'] as String, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(color: context.palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              formatVnd(amt),
                              style: TextStyle(color: context.palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: context.palette.border.withValues(alpha: 0.4),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNetCashflowBreakdown() {
    final isWeekly = _selectedPeriod == 'Theo tuần';
    final items = isWeekly
        ? [
            {'title': 'Tuần 1 (Ngày 1 - 7)', 'income': 4200000, 'expense': 3100000},
            {'title': 'Tuần 2 (Ngày 8 - 14)', 'income': 3500000, 'expense': 2800000},
            {'title': 'Tuần 3 (Ngày 15 - 21)', 'income': 5000000, 'expense': 4200000},
            {'title': 'Tuần 4 (Ngày 22 - 31)', 'income': 6100000, 'expense': 3900000},
          ]
        : [
            {'title': 'Tháng 1', 'income': 18500000, 'expense': 14200000},
            {'title': 'Tháng 2', 'income': 19200000, 'expense': 16500000},
            {'title': 'Tháng 3', 'income': 21000000, 'expense': 15800000},
            {'title': 'Tháng 4', 'income': 22500000, 'expense': 17100000},
            {'title': 'Tháng 5', 'income': 20800000, 'expense': 18300000},
            {'title': 'Tháng 6', 'income': 24000000, 'expense': 16900000},
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
          Text(
            'Chi tiết độ chênh lệch Thu - Chi ($_selectedPeriod)',
            style: TextStyle(color: context.palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            final income = item['income'] as int;
            final expense = item['expense'] as int;
            final diff = income - expense;
            final isPos = diff >= 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.palette.bg,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: context.palette.border.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title'] as String,
                          style: TextStyle(color: context.palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPos ? AppColors.success.withValues(alpha: 0.15) : AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Text(
                          '${isPos ? "+" : ""}${formatVnd(diff)}',
                          style: TextStyle(
                            color: isPos ? AppColors.success : AppColors.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Expanded(child: Text('Thu: ${formatVnd(income)}', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.danger),
                            const SizedBox(width: 4),
                            Flexible(child: Text('Chi: ${formatVnd(expense)}', style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
