import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/promotion/models/promotion_campaign_stats.dart';
import 'package:barky_matches_fixed/promotion/services/promotion_analytics_service.dart';

void main() {
  test('Promotion placements and event wire values are target-agnostic', () {
    expect(PromotionAnalyticsEvent.impression.value, 'IMPRESSION');
    expect(PromotionAnalyticsEvent.click.value, 'CLICK');
    expect(PromotionAnalyticsEvent.detailView.value, 'DETAIL_VIEW');
    expect(
      PromotionAnalyticsService.impressionKey(
        campaignId: 'campaign-1',
        targetId: 'pet-1',
        placement: 'playmate_discovery',
        now: DateTime.utc(2026, 8, 8, 10),
      ),
      contains('campaign-1|pet-1|playmate_discovery'),
    );
  });

  test('stats preserve null semantics for non-applicable ROAS', () {
    final stats = PromotionCampaignStats.fromJson({
      'campaignId': 'pet-campaign',
      'targetType': 'PET',
      'targetId': 'pet-1',
      'impressions': 10,
      'clicks': 2,
      'detailViews': 1,
      'spend': 29,
      'refundedRevenue': 0,
      'currency': 'TRY',
      'revenueCapability': 'not_applicable',
      'financialMetricsStatus': 'UNAVAILABLE',
      'reconciliationStatus': 'PENDING',
      'roas': null,
    });
    expect(stats.ctr, isNull);
    expect(stats.roas, isNull);
    expect(stats.hasRevenueAttribution, isFalse);
    expect(stats.financialMetricsStatus, 'UNAVAILABLE');
  });

  test('stats calculate safe funnel values when server provides them', () {
    final stats = PromotionCampaignStats.fromJson({
      'campaignId': 'product-campaign',
      'targetType': 'PRODUCT',
      'targetId': 'product-1',
      'impressions': 10,
      'clicks': 2,
      'detailViews': 1,
      'qualifiedConversions': 1,
      'financialConversions': 1,
      'attributedRevenue': 100,
      'spend': 39,
      'refundedRevenue': 0,
      'currency': 'TRY',
      'revenueCapability': 'server_attributed',
      'financialMetricsStatus': 'AVAILABLE',
      'reconciliationStatus': 'CONVERGED',
      'ctr': 0.2,
      'conversionRate': 0.5,
      'roas': 100 / 39,
    });
    expect(stats.ctr, 0.2);
    expect(stats.conversionRate, 0.5);
    expect(stats.roas, closeTo(100 / 39, 0.0001));
    expect(stats.reconciliationStatus, 'CONVERGED');
  });
}
