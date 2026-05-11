import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

/// Share Wallet Screen - Ví chung (Gia đình / Nhóm bạn)
class ShareWalletScreen extends StatefulWidget {
  const ShareWalletScreen({super.key});

  @override
  State<ShareWalletScreen> createState() => _ShareWalletScreenState();
}

class _ShareWalletScreenState extends State<ShareWalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: AppGradients.teal,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadii.xl),
                  bottomRight: Radius.circular(AppRadii.xl),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ví chung', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                          Text('Quản lý chi tiêu cùng nhau', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: const [
                      Tab(text: '👨‍👩‍👧‍👦 Gia đình'),
                      Tab(text: '👥 Nhóm bạn'),
                    ],
                  ),
                ],
              ),
            ),
            // Tab body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _WalletTabContent(
                    walletName: 'Gia đình',
                    balance: 12850000,
                    income: 5200000,
                    expense: 3150000,
                    members: ['An', 'Lan', 'Minh', 'Khánh'],
                    activities: [
                      _ActivityItem('Lan', 'Vừa thêm chi tiêu mua sắm', 180000, '10:30', '🛍️'),
                      _ActivityItem('Minh', 'Đã chuyển vào ví chung', 500000, 'Hôm qua', '💰'),
                      _ActivityItem('An', 'Thanh toán ăn uống', 95000, 'Hôm qua', '🍔'),
                      _ActivityItem('Khánh', 'Tiền điện tháng 5', 350000, '2 ngày trước', '⚡'),
                    ],
                  ),
                  _WalletTabContent(
                    walletName: 'Nhóm bạn',
                    balance: 4200000,
                    income: 2100000,
                    expense: 960000,
                    members: ['Bình', 'Hoa', 'Long'],
                    activities: [
                      _ActivityItem('Bình', 'Chi tiền xăng chung', 120000, '14:20', '⛽'),
                      _ActivityItem('Hoa', 'Đặt bàn nhà hàng', 450000, 'Hôm qua', '🍽️'),
                      _ActivityItem('Long', 'Mua vé phim', 225000, '3 ngày trước', '🎬'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTabContent extends StatelessWidget {
  final String walletName;
  final int balance;
  final int income;
  final int expense;
  final List<String> members;
  final List<_ActivityItem> activities;

  const _WalletTabContent({
    required this.walletName,
    required this.balance,
    required this.income,
    required this.expense,
    required this.members,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Số dư ví chung', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text(formatVnd(balance), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(color: const Color(0xFFF0FDFB), borderRadius: BorderRadius.circular(AppRadii.md)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Đã nạp', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(formatVnd(income), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(AppRadii.md)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Đã chi', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(formatVnd(expense), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Members
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thành viên (${members.length})', style: Theme.of(context).textTheme.titleSmall),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt_1, size: 16, color: AppColors.teal),
                label: const Text('Mời thêm', style: TextStyle(color: AppColors.teal, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ...members.map((name) => Container(
                margin: const EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                      child: Text(name.substring(0, 1), style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    const SizedBox(height: 4),
                    Text(name, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
              )),
            ],
          ),
          const SizedBox(height: 20),
          // Invite link
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.link, color: AppColors.teal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Liên kết mời thành viên', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text('mimo.app/invite/${walletName.toLowerCase()}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.copy_outlined, color: AppColors.teal, size: 20)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Recent activities
          Text('Hoạt động gần đây', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          ...activities.map((item) => _ActivityCard(item: item)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final String user;
  final String note;
  final int amount;
  final String time;
  final String emoji;

  const _ActivityItem(this.user, this.note, this.amount, this.time, this.emoji);
}

class _ActivityCard extends StatelessWidget {
  final _ActivityItem item;

  const _ActivityCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: item.user, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.teal)),
                      TextSpan(text: ' • ${item.note}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(item.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '-${formatVnd(item.amount)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}