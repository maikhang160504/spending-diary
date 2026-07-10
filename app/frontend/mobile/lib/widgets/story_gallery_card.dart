import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/categories.dart';
import '../theme/app_radii.dart';
import '../theme/app_palette.dart';
import '../utils/formatters.dart';
import '../utils/mimo_emotion.dart';
import '../routes/app_routes.dart';
import '../services/api_client.dart';

class StoryGalleryCard extends StatelessWidget {
  final Map<String, dynamic> story;

  /// Danh sách id để lướt qua trong màn hình chi tiết.
  final List<String>? allStoryIds;

  /// Vị trí của story hiện tại trong [allStoryIds].
  final int initialIndex;
  const StoryGalleryCard({
    required this.story,
    this.allStoryIds,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final id = story['id'] as String? ?? '';
    final title = story['title'] as String? ?? '';
    final imageUrl =
        story['cover_image_url'] as String? ??
        story['coverImageUrl'] as String? ??
        '';
    final occurredOn =
        story['latest_occurred_at'] as String? ??
        story['latestOccurredAt'] as String? ??
        story['occurred_on'] as String? ??
        story['occurredOn'] as String? ??
        story['created_at'] as String? ??
        story['createdAt'] as String? ??
        '';
    String dateStr = '';
    if (occurredOn.isNotEmpty) {
      final dt = parseStoryDisplayDateTime(
        occurredOn,
        timeSourceIso: story['created_at'] ?? story['createdAt'],
      );
      if (dt != null) {
        dateStr = formatDateTimeShort(dt);
      }
    }
    return GestureDetector(
      onTap: id.isNotEmpty
          ? () {
              final ids = allStoryIds;
              if (ids != null && ids.isNotEmpty) {
                final idx = ids.indexOf(id);
                context.push(
                  AppRoutes.storyDetailOf(id),
                  extra: {
                    'storyIds': ids,
                    'initialIndex': idx < 0 ? initialIndex : idx,
                  },
                );
              } else {
                context.push(AppRoutes.storyDetailOf(id));
              }
            }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 600,
                    errorWidget: (ctx, url, e) => Container(
                      color: const Color(0xFFCBD5E1),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        color: Colors.white54,
                        size: 24,
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFFCBD5E1),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
            if (dateStr.isNotEmpty)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            // Category Icon Badge at top-right
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconTheme(
                  data: const IconThemeData(color: Colors.white),
                  child: CategoryTheme.iconOf(
                    story['category_code'] as String? ??
                    story['categoryCode'] as String? ??
                    'Other',
                    size: 12,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Text(
                title.isNotEmpty ? title : 'Story',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Inline Calendar View ─────────────────────────────────────────────────────

