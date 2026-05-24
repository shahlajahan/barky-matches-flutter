import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class GroomyDashboardGalleryTab extends StatelessWidget {
  final String businessId;

  const GroomyDashboardGalleryTab({
    super.key,
    required this.businessId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Gallery coming soon",
        style: AppTheme.body(
          color: AppTheme.muted,
        ),
      ),
    );
  }
}