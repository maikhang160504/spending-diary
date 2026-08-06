import 'package:flutter/material.dart';

/// A wrapper widget that constrains the max width of its child on large screens
/// (Tablets, Web, Desktop) and centers it. On smaller screens, it takes up
/// the full width available.
class ResponsiveMaxWidthContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveMaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
