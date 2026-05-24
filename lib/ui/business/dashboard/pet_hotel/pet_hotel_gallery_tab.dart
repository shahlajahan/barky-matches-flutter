import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class PetHotelGalleryTab extends StatelessWidget {
  final String businessId;

  const PetHotelGalleryTab({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Gallery coming soon',
        style: AppTheme.body(color: AppTheme.muted),
      ),
    );
  }
}
