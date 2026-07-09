import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../services/app_queries.dart';
import 'category_spending_report_screen.dart';
import 'cashflow_report_screen.dart';
import 'saving_trend_report_screen.dart';
import 'cumulative_budget_report_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _selectedWalletId;

  @override
  void initState() {
    super.initState();
    AppQueries.invalidateWalletData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ReportHeader(),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner tóm tắt lời chào / gợi ý từ MiMo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.teal.withValues(alpha: 0.15),
                      AppColors.tealDark.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.25), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.teal.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trung tâm Phân tích Tài chính',
                            style: TextStyle(
                              color: context.palette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Chọn báo cáo bên dưới để xem biểu đồ chi tiết & phân tích chuyên sâu cùng AI MiMo Mascot.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'DANH MỤC BÁO CÁO',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 14),

              // Card 1: Chi tiêu theo danh mục
              _buildReportMenuCard(
                icon: Icons.pie_chart_rounded,
                iconColor: const Color(0xFFE91E63),
                iconBgColor: const Color(0xFFFCE4EC),
                title: 'Chi tiêu theo danh mục',
                subtitle: 'Phân tích tỷ trọng chi tiêu & cơ cấu dòng tiền từng nhóm',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CategorySpendingReportScreen(initialWalletId: _selectedWalletId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Card 2: Biến động thu chi
              _buildReportMenuCard(
                icon: Icons.bar_chart_rounded,
                iconColor: const Color(0xFF2196F3),
                iconBgColor: const Color(0xFFE3F2FD),
                title: 'Biến động thu chi',
                subtitle: 'So sánh dòng tiền Thu - Chi & chế độ cột chồng so với cùng kỳ',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CashflowReportScreen(initialWalletId: _selectedWalletId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Card 3: Xu hướng tiết kiệm
              _buildReportMenuCard(
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF4CAF50),
                iconBgColor: const Color(0xFFE8F5E9),
                title: 'Xu hướng tiết kiệm',
                subtitle: 'Theo dõi tích lũy ròng qua các kỳ & tối ưu gia tăng tài sản',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SavingTrendReportScreen(initialWalletId: _selectedWalletId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Card 4: Chi tiêu lũy kế so với hạn mức
              _buildReportMenuCard(
                icon: Icons.speed_rounded,
                iconColor: const Color(0xFFFF9800),
                iconBgColor: const Color(0xFFFFF3E0),
                title: 'Chi tiêu lũy kế so với hạn mức',
                subtitle: 'Kiểm soát tốc độ đốt hạn mức & cảnh báo vượt ngân sách',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CumulativeBudgetReportScreen(initialWalletId: _selectedWalletId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportMenuCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.palette.softShadow,
        border: Border.all(color: context.palette.border.withValues(alpha: 0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Bên trái: Icon trong vòng tròn màu nhạt sinh động
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),

                // Ở giữa: Tiêu đề 16px đậm + Mô tả sub-text 12px xám
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.palette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Bên phải ngoài cùng: Mũi tên >
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.palette.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: context.palette.textPrimary,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Báo cáo & Thống kê',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 21,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Phân tích chi tiêu & xu hướng tài chính cùng AI',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
