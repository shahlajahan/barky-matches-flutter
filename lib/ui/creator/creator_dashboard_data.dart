import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/app_state.dart';

/// Shared data model for both the lightweight mobile Creator Dashboard and
/// the full Web Creator Dashboard, so the two surfaces always agree on the
/// same numbers and formatting.
///
/// There is no Creator Program backend yet (no Cloud Function equivalent to
/// `readPaymentStatusByOrderId` / the payout-engine used elsewhere in this
/// app), so everything except the identity fields sourced from AppState
/// (level, referral code/link, current campaign — populated from the
/// `users/{uid}.creator` map, same as `business`) is realistic placeholder
/// data. Wiring this to a real backend is a separate, explicitly
/// out-of-scope task — see the TODO below.
class CreatorDashboardData {
  const CreatorDashboardData({
    required this.level,
    required this.currentCampaign,
    required this.qualifiedUsers,
    required this.verifiedPartners,
    required this.pendingRewards,
    required this.paidRewards,
    required this.estimatedPayout,
    required this.payoutDate,
    required this.recentActivity,
    required this.totalClicks,
    required this.registrations,
    required this.conversionRate,
    required this.rewardBreakdown,
    required this.performanceSeries,
  });

  final String level;
  final String currentCampaign;
  final int qualifiedUsers;
  final int verifiedPartners;
  final double pendingRewards;
  final double paidRewards;
  final double estimatedPayout;
  final DateTime payoutDate;
  final List<CreatorActivityItem> recentActivity;

  // Web-only fields (performance/analytics section).
  final int totalClicks;
  final int registrations;
  final double conversionRate;
  final List<CreatorRewardSlice> rewardBreakdown;
  final List<CreatorPerformancePoint> performanceSeries;

  String get formattedPendingRewards => _currency(pendingRewards);
  String get formattedPaidRewards => _currency(paidRewards);
  String get formattedEstimatedPayout => _currency(estimatedPayout);

  String get formattedPayoutDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
    ];
    return '${months[payoutDate.month - 1]} ${payoutDate.day}, ${payoutDate.year}';
  }

  static String _currency(double value) {
    final rounded = value.round();
    final text = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final fromEnd = text.length - i;
      buffer.write(text[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
    }
    return '\$$buffer';
  }

  // TODO(creator-backend): replace with a real callable (mirroring
  // PetshopCheckoutService.readPaymentStatusByOrderId's pattern) once the
  // Creator Program backend exists. Kept as a single factory so swapping
  // the data source later only touches this one place.
  factory CreatorDashboardData.mock(AppState appState) {
    final now = DateTime.now();
    final nextPayout = DateTime(now.year, now.month + 1, 15);

    return CreatorDashboardData(
      level: appState.creatorLevel ?? 'Pro',
      currentCampaign:
          appState.creatorCampaign ?? 'Summer Tail Wagger Challenge',
      qualifiedUsers: 3489,
      verifiedPartners: 42,
      pendingRewards: 842,
      paidRewards: 12480,
      estimatedPayout: 1842,
      payoutDate: nextPayout,
      totalClicks: 48213,
      registrations: 6124,
      conversionRate: 12.7,
      recentActivity: [
        CreatorActivityItem(
          title: 'Payout completed',
          subtitle: '\$1,240 paid to your connected account',
          icon: Icons.credit_card,
          color: const Color(0xFF9E1B4F),
          timestamp: now.subtract(const Duration(minutes: 42)),
        ),
        CreatorActivityItem(
          title: 'Partner verified',
          subtitle: 'Whiskers & Wags Grooming Studio',
          icon: Icons.verified,
          color: const Color(0xFF2E7D32),
          timestamp: now.subtract(const Duration(hours: 3)),
        ),
        CreatorActivityItem(
          title: '3 new users joined',
          subtitle: 'Referred through your Instagram story',
          icon: Icons.person_add,
          color: const Color(0xFF0277BD),
          timestamp: now.subtract(const Duration(hours: 6)),
        ),
        CreatorActivityItem(
          title: 'Reward generated',
          subtitle: '\$18 from a qualified user milestone',
          icon: Icons.card_giftcard,
          color: const Color(0xFFDE911D),
          timestamp: now.subtract(const Duration(hours: 9)),
        ),
      ],
      rewardBreakdown: const [
        CreatorRewardSlice('Qualified Users', 6840, Color(0xFF9E1B4F)),
        CreatorRewardSlice('Partner Leads', 4120, Color(0xFFE83E8C)),
        CreatorRewardSlice('Bonuses', 1520, Color(0xFFF0B429)),
      ],
      performanceSeries: generateSeries(30),
    );
  }

  /// Generates a deterministic mock series for any day count, used by the
  /// Web dashboard's 7d/30d/90d/12mo filter. Kept separate from the factory
  /// above so the range filter doesn't need to re-derive AppState.
  static List<CreatorPerformancePoint> generateSeries(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final date = now.subtract(Duration(days: days - 1 - i));
      final seed = (i * 928371) % 97;
      return CreatorPerformancePoint(
        date: date,
        clicks: 900 + seed * 12,
        registrations: 90 + (seed % 20),
      );
    });
  }
}

class CreatorActivityItem {
  const CreatorActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.timestamp,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final DateTime timestamp;

  String get relativeTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class CreatorRewardSlice {
  const CreatorRewardSlice(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class CreatorPerformancePoint {
  const CreatorPerformancePoint({
    required this.date,
    required this.clicks,
    required this.registrations,
  });

  final DateTime date;
  final int clicks;
  final int registrations;
}
