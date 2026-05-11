// lib/widgets/common/segment_tabs.dart
// Shared 3-tab segmented control (Story / Gallery / Calendar)
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class SegmentTabs extends StatelessWidget {
  final String selected; // 'Story' | 'Gallery' | 'Calendar'
  final ValueChanged<String> onChanged;

  static const _tabs = [
    _Tab('Story', Icons.article_outlined),
    _Tab('Gallery', Icons.grid_view_rounded),
    _Tab('Calendar', Icons.calendar_month_outlined),
  ];

  const SegmentTabs({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final isSelected = selected == tab.label;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  boxShadow: isSelected
                      ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 3))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab.icon, size: 15, color: isSelected ? AppColors.teal : AppColors.muted),
                    const SizedBox(width: 5),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.teal : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Tab {
  final String label;
  final IconData icon;
  const _Tab(this.label, this.icon);
}
