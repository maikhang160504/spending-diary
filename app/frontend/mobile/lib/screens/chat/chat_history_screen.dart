import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// Chat History Screen - matches /chat-history route
class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  static const _threads = [
    _Thread(title: 'Phân tích chi tiêu tuần này', preview: 'Tuần này bạn chi 680k, tập trung vào ăn uống và mua sắm...', time: '2 giờ trước', count: '5 tin nhắn', emoji: '📊'),
    _Thread(title: 'Tư vấn tiết kiệm tháng 3', preview: 'Mimo đề xuất giảm 20% ngân sách mua sắm để đạt mục tiêu...', time: 'Hôm qua', count: '12 tin nhắn', emoji: '💡'),
    _Thread(title: 'Xem lại giao dịch cà phê', preview: 'Bạn đã tiêu 45k cho cà phê sáng, đây là lần thứ 3 trong tuần...', time: '2 ngày trước', count: '3 tin nhắn', emoji: '☕'),
    _Thread(title: 'Kế hoạch mua iPhone', preview: 'Với thu nhập 8M/tháng, bạn cần 18 tháng để đạt mục tiêu 25M...', time: '3 ngày trước', count: '8 tin nhắn', emoji: '📱'),
    _Thread(title: 'Nhắc nhở vượt ngân sách', preview: 'Bạn đã vượt giới hạn mua sắm 90%, hãy cẩn thận chi tiêu...', time: '1 tuần trước', count: '4 tin nhắn', emoji: '⚠️'),
  ];

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
              padding: const EdgeInsets.fromLTRB(8, 14, 16, 24),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lịch sử trò chuyện', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      Text('${_threads.length} cuộc trò chuyện', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.search, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // New chat
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: GestureDetector(
                onTap: () {
                  context.pop();
                  context.push(AppRoutes.chat);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppGradients.teal,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: const [BoxShadow(color: Color(0x2014B8A6), blurRadius: 12, offset: Offset(0, 6))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(child: Text('✨', style: TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trò chuyện mới với Mimo', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                            Text('Bắt đầu cuộc trò chuyện mới', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Thread list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                itemCount: _threads.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _ThreadCard(thread: _threads[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thread {
  final String title;
  final String preview;
  final String time;
  final String count;
  final String emoji;

  const _Thread({required this.title, required this.preview, required this.time, required this.count, required this.emoji});
}

class _ThreadCard extends StatelessWidget {
  final _Thread thread;

  const _ThreadCard({required this.thread});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Center(child: Text(thread.emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(thread.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(thread.preview, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(thread.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontSize: 11)),
                    const SizedBox(width: 10),
                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(thread.count, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
        ],
      ),
    );
  }
}