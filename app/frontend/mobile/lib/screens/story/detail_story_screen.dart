import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class DetailStoryScreen extends StatefulWidget {
  const DetailStoryScreen({super.key});

  @override
  State<DetailStoryScreen> createState() => _DetailStoryScreenState();
}

class _DetailStoryScreenState extends State<DetailStoryScreen> {
  int _currentIndex = 0;
  final _stories = MockData.homeStories;

  static const _catColors = {
    'Ăn uống': Color(0xFFEC4899),
    'Mua sắm': Color(0xFF8B5CF6),
    'Di chuyển': Color(0xFF3B82F6),
    'Giải trí': Color(0xFFF59E0B),
  };

  @override
  Widget build(BuildContext context) {
    final story = _stories[_currentIndex];
    final catColor = _catColors[story.category] ?? AppColors.teal;

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Image.network(
                story.imageUrl,
                key: ValueKey(_currentIndex),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xCC000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar: category badge + close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(999)),
                        child: Row(children: [
                          Text(story.categoryEmoji),
                          const SizedBox(width: 6),
                          Text(story.category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ],
                  ),

                  // Thumbnail strip (mới nhất → cũ nhất)
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _stories.length,
                      itemBuilder: (ctx, i) {
                        final isActive = i == _currentIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _currentIndex = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52,
                            height: 52,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(
                                color: isActive ? AppColors.teal : Colors.white38,
                                width: isActive ? 2.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadii.md - 2),
                              child: Image.network(_stories[i].imageUrl, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Spacer(),

                  // Transaction info
                  Center(
                    child: Column(children: [
                      Text(
                        '-${formatVnd(story.amount)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(story.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(story.time,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                    ]),
                  ),

                  // AI feedback
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                        child: const Center(child: Text('😎', style: TextStyle(fontSize: 14))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(story.aiMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),
                  // Bottom buttons
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        ),
                        onPressed: () => context.pop(),
                        child: const Text('Đóng'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('Chỉnh sửa'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}