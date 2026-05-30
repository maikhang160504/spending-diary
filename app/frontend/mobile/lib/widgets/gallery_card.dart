import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../routes/app_routes.dart';
import '../theme/app_radii.dart';
import '../theme/categories.dart';
import '../utils/formatters.dart';
import 'package:go_router/go_router.dart';

/// Reusable gallery card for grid views (X-05).
/// Used in home_screen, home_gallery_screen, share_wallet_screen.
class GalleryCard extends StatelessWidget {
  final GalleryItem item;
  const GalleryCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isPositive = item.amount >= 0;
    return GestureDetector(
      onTap: () => context.push(AppRoutes.storyDetailOf('mock')),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, memCacheWidth: 600,
            errorWidget: (ctx, url, e) => Container(color: const Color(0xFFCBD5E1)),
          ),
          // Light gradient at top for badge
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.center,
              colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
            ),
          ))),
          // Category badge
          Positioned(left: 5, top: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: CategoryTheme.colorOf(item.category), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(item.categoryEmoji, style: const TextStyle(fontSize: 9)),
                const SizedBox(width: 3),
                Text(item.category, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          // Date + amount
          Positioned(left: 5, bottom: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                child: Text(item.date, style: const TextStyle(color: Colors.white70, fontSize: 8)),
              ),
              const SizedBox(height: 2),
              Text(
                '${isPositive ? '+' : '-'}${formatVnd(item.amount.abs())}',
                style: TextStyle(
                  color: isPositive ? const Color(0xFF4ADE80) : Colors.white,
                  fontSize: 10, fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
