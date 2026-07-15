import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../services/api_client.dart';
import '../settings/settings_screen.dart';

class PeerCompareReportScreen extends StatefulWidget {
  const PeerCompareReportScreen({super.key});

  @override
  State<PeerCompareReportScreen> createState() => _PeerCompareReportScreenState();
}

class _PeerCompareReportScreenState extends State<PeerCompareReportScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMsg;

  bool _hasProfile = false;
  String? _ageGroup;
  String? _jobTitle;
  int _peerCount = 0;
  bool _notEnoughPeers = false;
  List<Map<String, dynamic>> _compareData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMsg = null;
    });
    try {
      final res = await ApiClient().getPeerCompare();
      if (mounted) {
        setState(() {
          _hasProfile = res['hasProfile'] as bool? ?? false;
          _ageGroup = res['ageGroup'] as String?;
          _jobTitle = res['jobTitle'] as String?;
          _peerCount = (res['peerCount'] as num?)?.toInt() ?? 0;
          _notEnoughPeers = res['notEnoughPeers'] as bool? ?? false;

          final dataList = res['data'] as List<dynamic>? ?? [];
          _compareData = dataList.map((e) => e as Map<String, dynamic>).toList();

          if (!_hasProfile) {
            _errorMsg = res['message'] as String? ?? 'Vui lòng cập nhật thông tin cá nhân.';
          } else if (_notEnoughPeers) {
            _errorMsg = res['message'] as String? ?? 'Chưa đủ dữ liệu để so sánh.';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = 'Không thể tải dữ liệu so sánh. Vui lòng thử lại sau.';
          _isLoading = false;
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
          'So sánh cộng đồng',
          style: TextStyle(color: context.palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? _buildErrorState()
                    : _hasProfile == false
                        ? _buildUpdateProfileState()
                        : _notEnoughPeers
                            ? _buildNotEnoughDataState()
                            : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.danger),
            ),
            const SizedBox(height: 24),
            Text(
              'Đã xảy ra lỗi',
              style: TextStyle(color: context.palette.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMsg ?? 'Không thể kết nối đến máy chủ.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateProfileState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_search_rounded, size: 40, color: AppColors.teal),
            ),
            const SizedBox(height: 24),
            Text(
              'Cập nhật thông tin',
              style: TextStyle(color: context.palette.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Vào Cài đặt > Chọn "Thông tin cá nhân" để cập nhật đầy đủ Độ tuổi và Nghề nghiệp. Sau đó MiMo mới có thể so sánh chi tiêu của bạn với cộng đồng nhé!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                _loadData();
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Cập nhật hồ sơ ngay'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotEnoughDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.analytics_outlined, size: 40, color: AppColors.warning),
            ),
            const SizedBox(height: 24),
            Text(
              'Đang thu thập dữ liệu',
              style: TextStyle(color: context.palette.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMsg ?? 'Hiện tại chưa có đủ dữ liệu từ những người dùng có cùng nhóm tuổi và nghề nghiệp như bạn. Vui lòng quay lại sau.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final hasData = _compareData.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
              boxShadow: context.palette.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.groups_rounded, color: AppColors.teal, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhóm tương đồng',
                        style: TextStyle(color: context.palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Độ tuổi: ${_ageGroup ?? "Chưa rõ"} ${(_jobTitle != null && _jobTitle!.isNotEmpty) ? " • $_jobTitle" : ""}',
                        style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dữ liệu ẩn danh từ $_peerCount người dùng',
                        style: const TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text('Không có dữ liệu chi tiêu trong tháng này.', style: TextStyle(color: AppColors.muted)),
              ),
            )
          else ...[
            Text(
              'Biểu đồ chi tiêu (Radar)',
              style: TextStyle(color: context.palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _buildRadarChart(),
            const SizedBox(height: 32),
            Text(
              'Chi tiết so sánh',
              style: TextStyle(color: context.palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ..._compareData.map((d) => _buildCompareItem(d)),
          ],
        ],
      ),
    );
  }

  Widget _buildRadarChart() {
    return AspectRatio(
      aspectRatio: 1.2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: context.palette.softShadow,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Bạn', AppColors.teal),
                const SizedBox(width: 24),
                _buildLegendItem('Trung bình nhóm', AppColors.warning),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RadarChart(
                RadarChartData(
                  radarTouchData: RadarTouchData(
                    touchCallback: (FlTouchEvent event, response) {},
                  ),
                  dataSets: [
                    RadarDataSet(
                      fillColor: AppColors.teal.withValues(alpha: 0.2),
                      borderColor: AppColors.teal,
                      entryRadius: 4,
                      dataEntries: _compareData.map((d) {
                        final amt = (d['userAmount'] as num?)?.toDouble() ?? 0;
                        return RadarEntry(value: amt);
                      }).toList(),
                      borderWidth: 2,
                    ),
                    RadarDataSet(
                      fillColor: AppColors.warning.withValues(alpha: 0.2),
                      borderColor: AppColors.warning,
                      entryRadius: 4,
                      dataEntries: _compareData.map((d) {
                        final amt = (d['avgAmount'] as num?)?.toDouble() ?? 0;
                        return RadarEntry(value: amt);
                      }).toList(),
                      borderWidth: 2,
                    ),
                  ],
                  radarBackgroundColor: Colors.transparent,
                  borderData: FlBorderData(show: false),
                  radarBorderData: const BorderSide(color: Colors.transparent),
                  titlePositionPercentageOffset: 0.2,
                  titleTextStyle: TextStyle(color: context.palette.textSecondary, fontSize: 10),
                  getTitle: (index, angle) {
                    final catCode = _compareData[index]['categoryCode'] as String? ?? 'Other';
                    final label = CategoryTheme.of(catCode).label;
                    final shortLabel = label.length > 10 ? '${label.substring(0, 9)}…' : label;
                    return RadarChartTitle(
                      text: shortLabel,
                      angle: angle,
                    );
                  },
                  tickCount: 3,
                  ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
                  tickBorderData: BorderSide(color: context.palette.border.withValues(alpha: 0.5)),
                  gridBorderData: BorderSide(color: context.palette.border.withValues(alpha: 0.5), width: 1.5),
                ),
                swapAnimationDuration: const Duration(milliseconds: 400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: context.palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCompareItem(Map<String, dynamic> data) {
    final catCode = data['categoryCode'] as String? ?? 'Other';
    final userAmt = (data['userAmount'] as num?)?.toInt() ?? 0;
    final avgAmt = (data['avgAmount'] as num?)?.toInt() ?? 0;
    final diffPct = data['diffPercent'] as num?; // Positive means user spends MORE than average
    
    final catColor = CategoryTheme.of(catCode).color;
    final catLabel = CategoryTheme.of(catCode).label;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: CategoryTheme.iconOf(catCode, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  catLabel,
                  style: TextStyle(color: context.palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              if (diffPct != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: diffPct > 0 ? AppColors.danger.withValues(alpha: 0.1) : AppColors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        diffPct > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 14,
                        color: diffPct > 0 ? AppColors.danger : AppColors.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${diffPct > 0 ? "+" : ""}${diffPct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: diffPct > 0 ? AppColors.danger : AppColors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bạn chi', style: TextStyle(color: context.palette.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      formatVnd(userAmt),
                      style: TextStyle(color: context.palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: context.palette.border),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('TB Nhóm', style: TextStyle(color: context.palette.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      formatVnd(avgAmt),
                      style: TextStyle(color: context.palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar comparision
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: userAmt == 0 && avgAmt == 0 ? 1 : userAmt,
                    child: Container(color: AppColors.teal),
                  ),
                  Expanded(
                    flex: userAmt == 0 && avgAmt == 0 ? 1 : avgAmt,
                    child: Container(color: AppColors.warning),
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
