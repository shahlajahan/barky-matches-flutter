import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class DashboardSection extends StatelessWidget {
  const DashboardSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.spacing = 12,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppTheme.h3())),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
        SizedBox(height: spacing),
        child,
      ],
    );
  }
}
