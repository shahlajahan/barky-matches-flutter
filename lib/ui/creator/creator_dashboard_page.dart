import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'creator_dashboard_data.dart';
import 'creator_placeholder_badge.dart';
import 'creator_status_pill.dart';

/// The lightweight, native Flutter Creator Dashboard shown inside the
/// Profile page (ProfileSubPage.creatorDashboard). Intentionally limited —
/// no charts, no heavy tables — with an "Open Full Dashboard" hand-off to
/// the richer Web experience at the same domain the rest of the app's
/// browser-based flows already use (see web_subscription checkout / İş
/// Bank return handling in main.dart).
class CreatorDashboardPage extends StatelessWidget {
  const CreatorDashboardPage({super.key});

  static const String fullDashboardUrl =
      'https://app.petsupo.com/creator/dashboard';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final stats = CreatorDashboardData.mock(appState);

    return Container(
      color: AppTheme.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _WelcomeCard(appState: appState, stats: stats),
          const SizedBox(height: 16),
          _ReferralCard(appState: appState, l10n: l10n),
          const SizedBox(height: 16),
          _StatsGrid(stats: stats, l10n: l10n),
          const SizedBox(height: 16),
          _RecentActivityCard(stats: stats, l10n: l10n),
          const SizedBox(height: 16),
          _UpcomingPayoutCard(stats: stats, l10n: l10n),
          const SizedBox(height: 20),
          _OpenFullDashboardButton(l10n: l10n),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.appState, required this.stats});

  final AppState appState;
  final CreatorDashboardData stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = appState.username?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9E1B4F), Color(0xFFE83E8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow(opacity: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (name != null && name.isNotEmpty)
                      ? '${l10n.creatorWelcomeBack}, $name'
                      : l10n.creatorWelcomeBack,
                  style: AppTheme.h1(color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: AppTheme.accent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      stats.level,
                      style: AppTheme.caption(
                        color: Colors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${l10n.creatorCurrentCampaign} · ${stats.currentCampaign}',
            style: AppTheme.body(color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: 10),
          CreatorStatusPill(status: appState.creatorStatus),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.appState, required this.l10n});

  final AppState appState;
  final AppLocalizations l10n;

  void _copy(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = appState.creatorReferralCode ?? '—';
    final link = appState.creatorReferralLink ?? '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CopyRow(
            label: l10n.creatorReferralCodeLabel,
            value: code,
            buttonLabel: l10n.creatorCopyCode,
            onCopy: () => _copy(context, code, l10n.creatorReferralCodeCopied),
          ),
          const Divider(height: 24),
          _CopyRow(
            label: l10n.creatorReferralLinkLabel,
            value: link,
            buttonLabel: l10n.creatorCopyLink,
            onCopy: () => _copy(context, link, l10n.creatorReferralLinkCopied),
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.buttonLabel,
    required this.onCopy,
  });

  final String label;
  final String value;
  final String buttonLabel;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.caption()),
              const SizedBox(height: 2),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy, size: 16),
          label: Text(
            buttonLabel,
            style: AppTheme.caption(color: AppTheme.card),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.card,
            side: const BorderSide(color: AppTheme.card),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.l10n});

  final CreatorDashboardData stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final items = [
      (l10n.creatorQualifiedUsers, '${stats.qualifiedUsers}', Icons.groups),
      (
        l10n.creatorVerifiedPartners,
        '${stats.verifiedPartners}',
        Icons.verified,
      ),
      (
        l10n.creatorPendingRewards,
        stats.formattedPendingRewards,
        Icons.hourglass_top,
      ),
      (l10n.creatorPaidRewards, stats.formattedPaidRewards, Icons.payments),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: CreatorPlaceholderBadge(),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            for (final item in items)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  boxShadow: AppTheme.cardShadow(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.$3, size: 18, color: AppTheme.card),
                    const Spacer(),
                    Text(item.$2, style: AppTheme.h2(weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      item.$1,
                      style: AppTheme.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.stats, required this.l10n});

  final CreatorDashboardData stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final items = stats.recentActivity.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.creatorRecentActivity, style: AppTheme.h3()),
              ),
              const CreatorPlaceholderBadge(),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(Icons.timeline, color: Colors.black26, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    l10n.creatorNoActivityYet,
                    style: AppTheme.body(weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.creatorNoActivityMessage,
                    textAlign: TextAlign.center,
                    style: AppTheme.caption(),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              _ActivityRow(item: items[i]),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final CreatorActivityItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(item.icon, size: 16, color: item.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: AppTheme.body(weight: FontWeight.w600)),
              Text(item.subtitle, style: AppTheme.caption()),
            ],
          ),
        ),
        Text(item.relativeTime, style: AppTheme.caption()),
      ],
    );
  }
}

class _UpcomingPayoutCard extends StatelessWidget {
  const _UpcomingPayoutCard({required this.stats, required this.l10n});

  final CreatorDashboardData stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.creatorUpcomingPayout, style: AppTheme.h3()),
              ),
              const CreatorPlaceholderBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.card,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.creatorEstimatedPayout, style: AppTheme.caption()),
                  Text(
                    stats.formattedEstimatedPayout,
                    style: AppTheme.h2(weight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.creatorPayoutDate, style: AppTheme.caption()),
              Text(
                stats.formattedPayoutDate,
                style: AppTheme.body(weight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpenFullDashboardButton extends StatelessWidget {
  const _OpenFullDashboardButton({required this.l10n});

  final AppLocalizations l10n;

  Future<void> _open() async {
    final uri = Uri.parse(CreatorDashboardPage.fullDashboardUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _open,
            icon: const Icon(Icons.open_in_new),
            label: Text(
              l10n.creatorOpenFullDashboard,
              style: AppTheme.button(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.creatorOpenFullDashboardHint,
          textAlign: TextAlign.center,
          style: AppTheme.caption(),
        ),
      ],
    );
  }
}
