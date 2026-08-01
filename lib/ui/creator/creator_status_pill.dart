import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

/// Real data (Sprint 1): reads `AppState.creatorStatus`, sourced from
/// `users/{uid}.creator.status`. Shared between the mobile and Web
/// dashboards so status is presented identically on both.
class CreatorStatusPill extends StatelessWidget {
  const CreatorStatusPill({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isActive = status == 'active';
    final label = isActive
        ? l10n.creatorStatusActive
        : (status ?? l10n.creatorStatusInactive);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${l10n.creatorStatusLabel}: ',
          style: AppTheme.caption(color: Colors.white.withValues(alpha: 0.7)),
        ),
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: isActive ? Colors.greenAccent : Colors.white54,
            shape: BoxShape.circle,
          ),
        ),
        Text(
          label,
          style: AppTheme.caption(
            color: Colors.white,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
