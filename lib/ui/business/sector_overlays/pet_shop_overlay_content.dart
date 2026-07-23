import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';

class PetShopOverlayContent extends StatelessWidget {
  const PetShopOverlayContent({
    super.key,
    required this.data,
    required this.showInfo,
    required this.showServices,
    required this.showAction,
    required this.onOpenFullProfile,
    required this.onBuyNow,
  });

  final BusinessCardData data;
  final bool showInfo;
  final bool showServices;
  final bool showAction;
  final VoidCallback onOpenFullProfile;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (showInfo) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (data.description ?? '').trim().isEmpty
                  ? l10n.noShopDescriptionAvailable
                  : data.description!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyMedium(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onOpenFullProfile,
              child: Text(
                l10n.openFullProfile,
                style: AppTheme.caption(color: Colors.amber),
              ),
            ),
          ],
        ),
      );
    }

    if (showServices) {
      final categories = data.services ?? data.specialties;
      if (categories.isEmpty) {
        return Text(
          l10n.noShopCategoriesAvailable,
          style: AppTheme.bodyMedium(color: Colors.white70),
        );
      }
      return SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories
              .map(
                (category) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    category,
                    style: AppTheme.caption(color: Colors.white),
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    if (showAction) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.browseShopProductsDescription,
            style: AppTheme.bodyMedium(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBuyNow,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: Text(l10n.buyNowButton),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
