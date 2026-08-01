import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

/// Sprint 1 explicitly wires only identity fields (name, status, referral
/// code/link) to real Firestore data — see docs/SPRINT1_REPORT.md. Every
/// other section (stats, activity, payout, charts) still renders
/// `CreatorDashboardData.mock()`. This badge is the *visible*, user-facing
/// half of "clearly mark placeholder sections" (the `TODO(creator-backend)`
/// comment in creator_dashboard_data.dart is the code-facing half) — it
/// must be removed from a section the same moment that section's data
/// source is swapped for a real one, not left in place indefinitely.
class CreatorPlaceholderBadge extends StatelessWidget {
  const CreatorPlaceholderBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        l10n.creatorSampleData,
        style: AppTheme.overline(color: const Color(0xFF8D6B0B)),
      ),
    );
  }
}
