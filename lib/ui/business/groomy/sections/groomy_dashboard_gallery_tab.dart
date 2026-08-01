import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class GroomyDashboardGalleryTab extends StatelessWidget {
  final String businessId;

  const GroomyDashboardGalleryTab({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.galleryComingSoon,
        style: AppTheme.body(color: AppTheme.muted),
      ),
    );
  }
}
