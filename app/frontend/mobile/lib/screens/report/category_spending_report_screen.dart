import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
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
  String _selectedPeriod = 'Tháng này';
  String _recordType = 'expense'; // 'expense' or 'income'
  bool _isAnalyzingAI = false;
  String? _aiInsight;
  int _touchedIndex = -1;

  bool _isLoading = true;
  List<Map<String, dynamic>> _cats = [];
  int _totalAmt = 0;
  List<Map<String, dynamic>> _walletsList = [];

  int _periodOffset = 0;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
    _loadReportData();
  }

  String _getPeriodLabel() {
    final now = DateTime.now();
    if (_selectedPeriod == 'Tuần này') {
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

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      String fromStr, toStr;
      if (_selectedPeriod == 'Tuần này') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1)).subtract(Duration(days: 7 * _periodOffset));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        fromStr = startOfWeek.toIso8601String().substring(0, 10);
        toStr = endOfWeek.toIso8601String().substring(0, 10);
      } else {
        final targetMonth = DateTime(now.year, now.month - _periodOffset, 1);
        final targetMonthEnd = DateTime(now.year, now.month - _periodOffset + 1, 0);
        fromStr = targetMonth.toIso8601String().substring(0, 10);
        toStr = targetMonthEnd.toIso8601String().substring(0, 10);
      }

      String prevFromStr, prevToStr;
      if (_selectedPeriod == 'Tuần này') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1)).subtract(Duration(days: 7 * _periodOffset));
        final prevStart = startOfWeek.subtract(const Duration(days: 7));
        final prevEnd = startOfWeek.subtract(const Duration(days: 1));
        prevFromStr = prevStart.toIso8601String().substring(0, 10);
        prevToStr = prevEnd.toIso8601String().substring(0, 10);
      } else {
        final prevMonth = DateTime(now.year, now.month - _periodOffset - 1, 1);
        final prevMonthEnd = DateTime(now.year, now.month - _periodOffset, 0);
        prevFromStr = prevMonth.toIso8601String().substring(0, 10);
        prevToStr = prevMonthEnd.toIso8601String().substring(0, 10);
      }

      final results = await Future.wait([
        AppQueries.statsByCategory('custom', _selectedWalletId, from: fromStr, to: toStr, type: _recordType).result,
        AppQueries.statsByCategory('custom', _selectedWalletId, from: prevFromStr, to: prevToStr, type: _recordType).result,
        AppQueries.wallets().result,
      ]);

      final rawCats = ((results[0] as dynamic)?.data as List<dynamic>?) ?? [];
      final rawPrev = ((results[1] as dynamic)?.data as List<dynamic>?) ?? [];
      final rawWallets = ((results[2] as dynamic)?.data as List<dynamic>?) ?? [];

      final wallets = <Map<String, dynamic>>[];
      for (final w in rawWallets) {
        if (w is Map<String, dynamic> && w['type'] != 'group') wallets.add(w);
      }

      final Map<String, Map<String, dynamic>> mergedMap = {};
      final Map<String, int> prevMap = {};
      int totalAmt = 0;

      for (final c in rawPrev) {
        final map = c as Map<String, dynamic>;
        final code = map['categoryCode']?.toString() ?? 'Other';
        final label = CategoryTheme.of(code).label;
        final amt = (map['amount'] as num?)?.toInt() ?? (map['total'] as num?)?.toInt() ?? 0;
        prevMap[label] = (prevMap[label] ?? 0) + amt;
      }

      for (final c in rawCats) {
        final map = c as Map<String, dynamic>;
        final code = map['categoryCode']?.toString() ?? 'Other';
        final amt = (map['amount'] as num?)?.toInt() ?? (map['total'] as num?)?.toInt() ?? 0;
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
        final amount = (c['amount'] as num?)?.toDouble() ?? 0.0;
        c['percent'] = totalAmt > 0 ? (amount * 100 / totalAmt) : 0.0;
        final label = c['categoryLabel']?.toString() ?? '';
        final prevAmt = prevMap[label] ?? 0;
        if (prevAmt > 0) {
          c['momChange'] = ((amount - prevAmt) / prevAmt * 100).roundToDouble();
        } else {
          c['momChange'] = null;
        }
      }
      cats.sort((a, b) => ((b['amount'] as num?) ?? 0).compareTo((a['amount'] as num?) ?? 0));

      if (mounted) {
        setState(() {
          _cats = cats;
          _totalAmt = totalAmt;
          _walletsList = wallets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _analyzeAI(List<dynamic> cats) async {
    setState(() { _isAnalyzingAI = true; });
    try {
      final summaryStr = cats.map((c) => '${c['categoryLabel']}: ${formatVnd(c['amount'] ?? 0)} (${c['percent']}%)').join(', ');
      final typeLabel = _recordType == 'expense' ? 'chi tiêu' : 'thu nhập';
      final prompt = 'Phân tích nhanh $typeLabel theo danh mục kỳ $_selectedPeriod: $summaryStr';
      final res = await AIAdvisorService.askFinancialQuestion(prompt);
      if (mounted) setState(() { _aiInsight = res; _isAnalyzingAI = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiInsight = 'MiMo nhận thấy bạn có sự phân bổ tài chính rất chú ý. Hãy theo dõi sát các danh mục lớn nhé!';
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
          _recordType == 'expense' ? 'Chi tiêu theo danh mục' : 'Thu nhập theo danh mục',
          style: TextStyle(color: context.palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
              child: Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(children: [
                      _buildTypeBtn('Chi tiêu', _recordType == 'expense', () {
                        if (_recordType != 'expense') {
                          setState(() => _recordType = 'expense');
                          _loadReportData();
                        }
                      }),
                      _buildTypeBtn('Thu nhập', _recordType == 'income', () {
                        if (_recordType != 'income') {
                          setState(() => _recordType = 'income');
                          _loadReportData();
                        }
                      }),
                    ]),
                  ),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
              child: Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(children: [
                      _buildPeriodBtn('Theo tuần', _selectedPeriod == 'Tuần này', () {
                        if (_selectedPeriod != 'Tuần này') {
                          setState(() { _selectedPeriod = 'Tuần này'; _periodOffset = 0; });
                          _loadReportData();
                        }
                      }),
                      _buildPeriodBtn('Theo tháng', _selectedPeriod == 'Tháng này', () {
                        if (_selectedPeriod != 'Tháng này') {
                          setState(() { _selectedPeriod = 'Tháng này'; _periodOffset = 0; });
                          _loadReportData();
                        }
                      }),
                    ]),
                  ),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: context.palette.textPrimary),
                    onPressed: () {
                      setState(() => _periodOffset++);
                      _loadReportData();
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
                      _loadReportData();
                    } : null,
                  ),
                ],
              ),
            ),
            _buildWalletSelectorBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAISection(_cats),
                          const SizedBox(height: 16),
                          _buildMinimalistDonutSection(_cats, _totalAmt),
                          const SizedBox(height: 24),
                          Text('Chi tiết danh mục',
                            style: TextStyle(color: context.palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          if (_cats.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              alignment: Alignment.center,
                              child: const Text('Chưa có dữ liệu giao dịch', style: TextStyle(color: AppColors.muted)),
                            )
                          else
                            ..._cats.map((cat) => _buildCategoryTile(cat)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBtn(String label, bool active, VoidCallback onTap) {
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
          child: Text(label,
            style: TextStyle(
              color: active ? Colors.white : context.palette.textPrimary,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            )),
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
          child: Text(label,
            style: TextStyle(
              color: active ? Colors.white : context.palette.textPrimary,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            )),
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
              gradient: LinearGradient(colors: [AppColors.teal.withValues(alpha: 0.15), AppColors.tealDark.withValues(alpha: 0.15)]),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Phân tích AI từ MiMo Mascot',
                  style: TextStyle(color: AppColors.teal, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  _isAnalyzingAI ? 'MiMo đang phân tích cấu trúc tài chính...' : 'Nhấn để MiMo phân tích & đưa ra lời khuyên cho bạn',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
              if (_isAnalyzingAI)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.teal),
            ]),
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
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('MiMo khuyên bạn:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.teal)),
                const SizedBox(height: 4),
                Text(_aiInsight!, style: TextStyle(color: context.palette.textPrimary, fontSize: 13, height: 1.4)),
              ])),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildWalletSelectorBar() {
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildWalletChipItem('Tất cả ví', null),
            ..._walletsList.map((w) {
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
          setState(() => _selectedWalletId = walletId);
          _loadReportData();
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

  Widget _buildMinimalistDonutSection(List<dynamic> cats, int totalAmt) {
    const chartSize = 180.0;
    const donutThickness = 26.0;
    const holeRadius = 52.0;

    final displayCats = cats.take(8).toList();
    final leftCats = <Map<String, dynamic>>[];
    final rightCats = <Map<String, dynamic>>[];

    for (int i = 0; i < displayCats.length; i++) {
      if (i % 2 == 0) {
        leftCats.add(displayCats[i] as Map<String, dynamic>);
      } else {
        rightCats.add(displayCats[i] as Map<String, dynamic>);
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Phân bổ chi tiêu',
            style: TextStyle(color: context.palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          Text(_selectedPeriod,
            style: const TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 20),

        cats.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('Chưa có chi tiêu', style: TextStyle(color: AppColors.muted)),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildSideLabels(leftCats, isLeft: true)),
                SizedBox(
                  width: chartSize,
                  height: chartSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: chartSize,
                        height: chartSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.teal.withValues(alpha: 0.1),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: holeRadius,
                          startDegreeOffset: -90,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                _touchedIndex = response?.touchedSection?.touchedSectionIndex ?? -1;
                              });
                            },
                          ),
                          sections: displayCats.asMap().entries.map((entry) {
                            final i = entry.key;
                            final cat = entry.value;
                            final pct = (cat['percent'] as double?) ?? 0.0;
                            final color = Color(cat['color'] as int? ?? AppColors.teal.toARGB32());
                            final isTouched = i == _touchedIndex;

                            return PieChartSectionData(
                              color: color,
                              value: pct > 0 ? pct : 0.1,
                              title: '',
                              radius: isTouched ? donutThickness + 6 : donutThickness,
                              borderSide: BorderSide(color: Colors.white, width: isTouched ? 2.5 : 1.5),
                            );
                          }).toList(),
                        ),
                      ),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Tổng chi', style: TextStyle(color: AppColors.muted, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(
                          formatVndCompact(totalAmt),
                          style: TextStyle(
                            color: context.palette.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                Expanded(child: _buildSideLabels(rightCats, isLeft: false)),
              ],
            ),

        if (cats.length > 8) ...[
          const SizedBox(height: 12),
          Text('+${cats.length - 8} danh mục khác',
            style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      ]),
    );
  }

  Widget _buildSideLabels(List<Map<String, dynamic>> catList, {required bool isLeft}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: catList.map((cat) {
        final color = Color(cat['color'] as int? ?? AppColors.teal.toARGB32());
        final code = cat['categoryCode']?.toString() ?? 'Other';
        final label = cat['categoryLabel']?.toString() ?? '';
        final pct = (cat['percent'] as double?) ?? 0.0;
        final momChange = cat['momChange'] as double?;
        final shortLabel = label.length > 8 ? '${label.substring(0, 7)}…' : label;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isLeft ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (isLeft) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CategoryTheme.iconOf(code, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (momChange != null) ...[
                              const SizedBox(width: 3),
                              _buildMomBadge(momChange),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        shortLabel,
                        style: TextStyle(
                          color: context.palette.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ] else ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CategoryTheme.iconOf(code, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (momChange != null) ...[
                              const SizedBox(width: 3),
                              _buildMomBadge(momChange),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        shortLabel,
                        style: TextStyle(
                          color: context.palette.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMomBadge(double momChange) {
    final isUp = momChange > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: isUp ? AppColors.danger.withValues(alpha: 0.12) : AppColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '${isUp ? '+' : ''}${momChange.toStringAsFixed(0)}%',
        style: TextStyle(
          color: isUp ? AppColors.danger : AppColors.teal,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> cat) {
    final code = cat['categoryCode']?.toString() ?? 'Other';
    final label = cat['categoryLabel']?.toString() ?? 'Khác';
    final amount = (cat['amount'] as num?)?.toInt() ?? 0;
    final percent = (cat['percent'] as num?)?.toDouble() ?? 0.0;
    final color = Color(cat['color'] as int? ?? AppColors.teal.toARGB32());
    final momChange = cat['momChange'] as double?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context, rootNavigator: false).push(MaterialPageRoute(
            builder: (_) => CategoryDetailReportScreen(
              categoryCode: code,
              categoryName: label,
              totalAmount: amount,
              percentage: percent,
              dateRangeLabel: _selectedPeriod,
              walletId: _selectedWalletId,
              recordType: _recordType,
            ),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
            boxShadow: context.palette.softShadow,
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Center(child: CategoryTheme.iconOf(code, size: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                if (momChange != null)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: momChange > 0 ? AppColors.danger.withValues(alpha: 0.1) : AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        momChange > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 10,
                        color: momChange > 0 ? AppColors.danger : AppColors.teal,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${momChange.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: momChange > 0 ? AppColors.danger : AppColors.teal,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                  ),
              ]),
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
            ])),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatVnd(amount),
                style: TextStyle(color: context.palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${percent.toStringAsFixed(1)}%',
                style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
}
