import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class GradientHeader extends StatelessWidget {
  final Widget child;
  final double height;

  const GradientHeader({
    super.key,
    required this.child,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}
