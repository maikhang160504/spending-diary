import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_radii.dart';

/// Shimmer skeleton placeholders for loading states (X-11).

class SkeletonCard extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 120,
    this.width,
    this.borderRadius = AppRadii.lg,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF1F5F9),
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonLine({super.key, this.width = double.infinity, this.height = 14});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF1F5F9),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(children: [
        Shimmer.fromColors(
          baseColor: const Color(0xFFE2E8F0),
          highlightColor: const Color(0xFFF1F5F9),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            SkeletonLine(width: 140),
            SizedBox(height: 6),
            SkeletonLine(width: 80, height: 10),
          ]),
        ),
        const SkeletonLine(width: 60),
      ]),
    );
  }
}
