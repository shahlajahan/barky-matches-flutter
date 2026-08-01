import 'package:barky_matches_fixed/ui/creator/creator_dashboard_data.dart';
import 'package:flutter_test/flutter_test.dart';

CreatorDashboardData _sample({
  double pendingRewards = 842,
  double paidRewards = 12480,
  double estimatedPayout = 1842,
  DateTime? payoutDate,
}) {
  return CreatorDashboardData(
    level: 'Pro',
    currentCampaign: 'Test Campaign',
    qualifiedUsers: 10,
    verifiedPartners: 2,
    pendingRewards: pendingRewards,
    paidRewards: paidRewards,
    estimatedPayout: estimatedPayout,
    payoutDate: payoutDate ?? DateTime(2026, 8, 15),
    recentActivity: const [],
    totalClicks: 100,
    registrations: 20,
    conversionRate: 20.0,
    rewardBreakdown: const [],
    performanceSeries: const [],
  );
}

void main() {
  test('formats currency amounts with thousands separators', () {
    final stats = _sample(pendingRewards: 842, paidRewards: 12480);

    expect(stats.formattedPendingRewards, r'$842');
    expect(stats.formattedPaidRewards, r'$12,480');
  });

  test('formats large payout amounts with multiple separators', () {
    final stats = _sample(estimatedPayout: 1234567);

    expect(stats.formattedEstimatedPayout, r'$1,234,567');
  });

  test('formats the payout date as a readable short date', () {
    final stats = _sample(payoutDate: DateTime(2026, 8, 15));

    expect(stats.formattedPayoutDate, 'Aug 15, 2026');
  });

  test('generateSeries always resolves dates up to today, never the past', () {
    final series = CreatorDashboardData.generateSeries(30);
    final today = DateTime.now();
    final lastPoint = series.last.date;

    expect(series, hasLength(30));
    expect(lastPoint.year, today.year);
    expect(lastPoint.month, today.month);
    expect(lastPoint.day, today.day);
  });

  test('generateSeries produces chronologically ordered points', () {
    final series = CreatorDashboardData.generateSeries(7);

    for (var i = 1; i < series.length; i++) {
      expect(series[i].date.isAfter(series[i - 1].date), isTrue);
    }
  });
}
