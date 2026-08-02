import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/welcome_page.dart';
import 'package:barky_matches_fixed/services/creator_ledger_service.dart';
import 'creator_dashboard_data.dart';
import 'creator_placeholder_badge.dart';
import 'web/creator_performance_chart.dart';
import 'web/creator_reward_donut.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_chart_card.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_donut_card.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_header.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_history.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_card.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_grid.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_panel.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_status_pill.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_timeline.dart';

/// Full Web Creator Dashboard — reached at https://app.petsupo.com/creator/dashboard
/// (see main.dart's `_webPaymentReturnPage`-style top-level routing). This
/// is a *richer native Flutter Web page*, not a separate app: same
/// AppState/Provider tree, same AppTheme design tokens, same fl_chart
/// package already used by the Business Dashboard's web-only revenue
/// section (lib/ui/business/dashboard/vet/web/revenue). The lightweight
/// mobile page (CreatorDashboardPage) hands off here for anything this
/// page has that the native page deliberately omits: charts, filters,
/// full reporting.
class CreatorDashboardWebPage extends StatelessWidget {
  const CreatorDashboardWebPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: AppTheme.bg, body: _CreatorGate());
  }
}

class _CreatorGate extends StatelessWidget {
  const _CreatorGate();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // BUG FIX: this page previously wrapped its content in its own
    // independent StreamBuilder<User?> on FirebaseAuth.instance.authStateChanges(),
    // treating any null emission as "not signed in" and showing a sign-in
    // screen whose only action navigated to WelcomePage (Login). That
    // duplicated — and bypassed — this app's own already-hardened auth
    // tracking: AppState.startAuthListener() (wired unconditionally at
    // runApp() time in main.dart, independent of whichever page ends up
    // as `home`) has explicit, already-shipped protection against exactly
    // this failure mode — a transient/spurious null from Firebase's auth
    // stream while FirebaseAuth.instance.currentUser is still genuinely
    // non-null (see the "Ignoring false auth null state" branch in
    // AppState.startAuthListener). This page's local StreamBuilder had
    // none of that protection, so a still-authenticated user opening the
    // Creator Dashboard could hit that transient null and get bounced to
    // Login even though Firebase still considered them signed in.
    //
    // The fix: don't re-derive auth state independently at all. Trust
    // AppState the same way Business Dashboard already does —
    // user_profile_page.dart's businessDashboard branch waits on
    // appState.businessId the exact same way this waits on
    // appState.currentUserId, and never re-checks Firebase Auth itself.
    if (appState.currentUserId == null || appState.currentUserId!.isEmpty) {
      return const _CenteredSpinner();
    }

    // AppState has settled — currentUserId is either a real uid or the
    // 'guest' sentinel (see AppState.setGuestUser). Only now, after
    // AppState's own hardened listener has had its say, is it safe to
    // treat "no real user" as a genuine sign-in requirement rather than a
    // startup race.
    if (appState.isGuestUser) {
      return const _SignInRequired();
    }

    if (!appState.creatorEnabled) {
      return const _AccessDenied();
    }
    return const _CreatorDashboardWebContent();
  }
}

class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: AppTheme.card));
  }
}

class _SignInRequired extends StatelessWidget {
  const _SignInRequired();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _MessageScreen(
      icon: Icons.lock_outline,
      title: l10n.creatorSignInRequiredTitle,
      message: l10n.creatorSignInRequiredMessage,
      actionLabel: l10n.creatorGoToSignIn,
      onAction: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const WelcomePage()),
          (route) => false,
        );
      },
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _MessageScreen(
      icon: Icons.campaign_outlined,
      title: l10n.creatorAccessDeniedTitle,
      message: l10n.creatorAccessDeniedMessage,
    );
  }
}

class _MessageScreen extends StatelessWidget {
  const _MessageScreen({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppTheme.card),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: AppTheme.h1()),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTheme.body(color: AppTheme.muted),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.card,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: AppTheme.button(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorDashboardWebContent extends StatefulWidget {
  const _CreatorDashboardWebContent();

  @override
  State<_CreatorDashboardWebContent> createState() =>
      _CreatorDashboardWebContentState();
}

class _CreatorDashboardWebContentState
    extends State<_CreatorDashboardWebContent> {
  CreatorLedgerSummary _ledgerSummary = const CreatorLedgerSummary(
    qualifiedUsers: 0,
    qualifiedPartners: 0,
    pendingRewards: 0,
  );

  @override
  void initState() {
    super.initState();
    final uid = context.read<AppState>().currentUserId;
    CreatorLedgerService.loadForCreator(uid).then((summary) {
      if (mounted) setState(() => _ledgerSummary = summary);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final stats = CreatorDashboardData.mock(
      appState,
      ledgerSummary: _ledgerSummary,
    );
    final width = MediaQuery.sizeOf(context).width;
    final kpiColumns = width >= 1100 ? 4 : (width >= 720 ? 2 : 1);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            children: [
              _Header(appState: appState, stats: stats, l10n: l10n),
              const SizedBox(height: 24),
              _KpiGrid(stats: stats, l10n: l10n, columns: kpiColumns),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final performance = DashboardChartCard(
                    child: CreatorPerformanceChart(),
                  );
                  final donut = DashboardDonutCard(
                    child: CreatorRewardDonut(slices: stats.rewardBreakdown),
                  );
                  if (!isWide) {
                    return Column(
                      children: [
                        performance,
                        const SizedBox(height: 24),
                        donut,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: performance),
                        const SizedBox(width: 24),
                        Expanded(child: donut),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final referral = DashboardPanel(
                    child: _ReferralShareSection(
                      appState: appState,
                      l10n: l10n,
                    ),
                  );
                  final progress = DashboardPanel(
                    child: _CreatorProgressSection(stats: stats, l10n: l10n),
                  );
                  if (!isWide) {
                    return Column(
                      children: [
                        referral,
                        const SizedBox(height: 24),
                        progress,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: referral),
                        const SizedBox(width: 24),
                        Expanded(child: progress),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final timeline = DashboardPanel(
                    child: _TimelineSection(stats: stats, l10n: l10n),
                  );
                  final payouts = DashboardPanel(
                    child: _PayoutHistorySection(stats: stats, l10n: l10n),
                  );
                  if (!isWide) {
                    return Column(
                      children: [timeline, const SizedBox(height: 24), payouts],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: timeline),
                        const SizedBox(width: 24),
                        Expanded(child: payouts),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.appState,
    required this.stats,
    required this.l10n,
  });

  final AppState appState;
  final CreatorDashboardData stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final name = appState.username?.trim();

    return DashboardHeader(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (name != null && name.isNotEmpty)
                        ? '${l10n.creatorWelcomeBack}, $name'
                        : l10n.creatorDashboardTitle,
                    style: AppTheme.h1(color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      stats.level,
                      style: AppTheme.caption(
                        color: Colors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${l10n.creatorCurrentCampaign} · ${stats.currentCampaign}',
                style: AppTheme.body(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 10),
              DashboardStatusPill(
                prefix: l10n.creatorStatusLabel,
                label: appState.creatorStatus == 'active'
                    ? l10n.creatorStatusActive
                    : (appState.creatorStatus ?? l10n.creatorStatusInactive),
                active: appState.creatorStatus == 'active',
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.creatorFiltersComingSoon)),
                  );
                },
                icon: const Icon(
                  Icons.filter_list,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  l10n.creatorFilters,
                  style: AppTheme.button(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.creatorExportComingSoon)),
                  );
                },
                icon: const Icon(Icons.download, color: Colors.white, size: 18),
                label: Text(
                  l10n.creatorExport,
                  style: AppTheme.button(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.stats,
    required this.l10n,
    required this.columns,
  });

  final CreatorDashboardData stats;
  final AppLocalizations l10n;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return DashboardMetricGrid(
      columns: columns,
      trailing: const CreatorPlaceholderBadge(),
      items: [
        DashboardMetricData(
          label: l10n.creatorTotalClicks,
          value: '${stats.totalClicks}',
          icon: Icons.mouse,
        ),
        DashboardMetricData(
          label: l10n.creatorRegistrations,
          value: '${stats.registrations}',
          icon: Icons.person_add_alt,
        ),
        DashboardMetricData(
          label: l10n.creatorQualifiedUsers,
          value: '${stats.qualifiedUsers}',
          icon: Icons.groups,
        ),
        DashboardMetricData(
          label: l10n.creatorVerifiedPartners,
          value: '${stats.verifiedPartners}',
          icon: Icons.verified,
        ),
        DashboardMetricData(
          label: l10n.creatorPendingRewards,
          value: stats.formattedPendingRewards,
          icon: Icons.hourglass_top,
        ),
        DashboardMetricData(
          label: l10n.creatorPaidRewards,
          value: stats.formattedPaidRewards,
          icon: Icons.payments,
        ),
        DashboardMetricData(
          label: l10n.creatorConversionRate,
          value: '${stats.conversionRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
        ),
      ],
    );
  }
}

class _ReferralShareSection extends StatelessWidget {
  const _ReferralShareSection({required this.appState, required this.l10n});

  final AppState appState;
  final AppLocalizations l10n;

  void _copy(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final link = appState.creatorReferralLink ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.creatorShareYourLink, style: AppTheme.h3()),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  link,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.robotoMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _copy(context, link, l10n.creatorReferralLinkCopied),
                icon: const Icon(Icons.copy, size: 15),
                label: Text(
                  l10n.creatorCopyLink,
                  style: AppTheme.caption(color: AppTheme.card),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.card,
                  side: const BorderSide(color: AppTheme.card),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ShareChip(
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () => Share.share(link),
            ),
            _ShareChip(
              label: 'Telegram',
              color: const Color(0xFF26A5E4),
              onTap: () => Share.share(link),
            ),
            _ShareChip(
              label: 'Facebook',
              color: const Color(0xFF1877F2),
              onTap: () => Share.share(link),
            ),
            _ShareChip(
              label: 'Instagram',
              color: const Color(0xFFE1306C),
              onTap: () => _copy(context, link, l10n.creatorReferralLinkCopied),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShareChip extends StatelessWidget {
  const _ShareChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(label, style: AppTheme.caption(weight: FontWeight.w600)),
    );
  }
}

class _CreatorProgressSection extends StatelessWidget {
  const _CreatorProgressSection({required this.stats, required this.l10n});

  final CreatorDashboardData stats;
  final AppLocalizations l10n;

  static const _levels = ['Starter', 'Rising', 'Pro', 'Elite', 'Legend'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _levels.indexOf(stats.level);
    final nextLevel = (currentIndex >= 0 && currentIndex < _levels.length - 1)
        ? _levels[currentIndex + 1]
        : null;
    // Placeholder progress — mirrors the rest of this file's mock data
    // until the Creator Program backend exists.
    const progress = 0.68;

    final badges = [
      ('Rocket', 'First Referral', true),
      ('Trophy', '100 Club', true),
      ('Handshake', 'Partner Scout', true),
      ('Crown', 'Elite Status', false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.creatorBadgesAchievements, style: AppTheme.h3()),
            ),
            const CreatorPlaceholderBadge(),
          ],
        ),
        const SizedBox(height: 12),
        if (nextLevel != null) ...[
          Text(
            '${l10n.creatorProgressToNextLevelPrefix} $nextLevel',
            style: AppTheme.caption(),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.bg,
              color: AppTheme.card,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final badge in badges)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: badge.$3
                          ? AppTheme.bg
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      badge.$3 ? Icons.emoji_events : Icons.lock_outline,
                      color: badge.$3 ? AppTheme.card : Colors.black26,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 64,
                    child: Text(
                      badge.$2,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTheme.caption(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.stats, required this.l10n});

  final CreatorDashboardData stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DashboardTimeline(
      title: l10n.creatorRecentActivity,
      trailing: const CreatorPlaceholderBadge(),
      items: [
        for (final item in stats.recentActivity)
          DashboardTimelineItem(
            title: item.title,
            subtitle: item.subtitle,
            trailing: item.relativeTime,
            icon: item.icon,
            color: item.color,
          ),
      ],
    );
  }
}

class _PayoutHistorySection extends StatelessWidget {
  const _PayoutHistorySection({required this.stats, required this.l10n});

  final CreatorDashboardData stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final history = [
      (DateTime(now.year, now.month - 1, 15), 1620.0, l10n.creatorStatusPaid),
      (DateTime(now.year, now.month - 2, 15), 1310.0, l10n.creatorStatusPaid),
      (stats.payoutDate, stats.estimatedPayout, l10n.creatorStatusScheduled),
    ];

    return DashboardHistory(
      title: l10n.creatorPayoutHistory,
      trailing: const CreatorPlaceholderBadge(),
      items: [
        for (final entry in history)
          DashboardHistoryItem(
            date: '${entry.$1.month}/${entry.$1.day}/${entry.$1.year}',
            amount: '\$${entry.$2.toStringAsFixed(0)}',
            status: entry.$3,
            statusColor: entry.$3 == l10n.creatorStatusPaid
                ? Colors.green[700]
                : null,
            statusBackgroundColor: entry.$3 == l10n.creatorStatusPaid
                ? Colors.green
                : null,
          ),
      ],
    );
  }
}
