import 'package:barky_matches_fixed/services/analytics/web_campaign_attribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(WebCampaignAttribution.resetForTesting);

  test('extracts UTM parameters from the initial URL', () {
    final utm = WebCampaignAttribution.extractInitialUtm(
      Uri.parse(
        'https://app.petsupo.com/?utm_source=partner_email'
        '&utm_medium=email'
        '&utm_campaign=petsupo_ga4_test_20260821'
        '&utm_content=test_click',
      ),
    );

    expect(utm, isNotNull);
    expect(utm!.source, 'partner_email');
    expect(utm.medium, 'email');
    expect(utm.campaign, 'petsupo_ga4_test_20260821');
    expect(utm.content, 'test_click');
  });

  test('returns null when required UTM parameters are missing', () {
    final utm = WebCampaignAttribution.extractInitialUtm(
      Uri.parse(
        'https://app.petsupo.com/?utm_source=partner_email'
        '&utm_medium=email',
      ),
    );

    expect(utm, isNull);
  });

  test(
    'logs campaign details without partner event for non-partner source',
    () async {
      final campaignCalls = <InitialUtmCampaign>[];
      final partnerCalls = <Map<String, Object>>[];

      final logged = await WebCampaignAttribution.recordInitialUtmCampaign(
        isWeb: true,
        initialUri: Uri.parse(
          'https://app.petsupo.com/?utm_source=organic_partner'
          '&utm_medium=email'
          '&utm_campaign=petsupo_ga4_test_20260821'
          '&utm_content=test_click',
        ),
        logCampaignDetails: (utm) async => campaignCalls.add(utm),
        logPartnerLanding: (parameters) async => partnerCalls.add(parameters),
      );

      expect(logged, isTrue);
      expect(campaignCalls, hasLength(1));
      expect(campaignCalls.single.source, 'organic_partner');
      expect(partnerCalls, isEmpty);
    },
  );

  test('prevents duplicate campaign and partner logging', () async {
    final campaignCalls = <InitialUtmCampaign>[];
    final partnerCalls = <Map<String, Object>>[];
    final uri = Uri.parse(
      'https://app.petsupo.com/?utm_source=partner_email'
      '&utm_medium=email'
      '&utm_campaign=petsupo_ga4_test_20260821'
      '&utm_content=test_click',
    );

    final first = await WebCampaignAttribution.recordInitialUtmCampaign(
      isWeb: true,
      initialUri: uri,
      logCampaignDetails: (utm) async => campaignCalls.add(utm),
      logPartnerLanding: (parameters) async => partnerCalls.add(parameters),
    );
    final second = await WebCampaignAttribution.recordInitialUtmCampaign(
      isWeb: true,
      initialUri: uri,
      logCampaignDetails: (utm) async => campaignCalls.add(utm),
      logPartnerLanding: (parameters) async => partnerCalls.add(parameters),
    );

    expect(first, isTrue);
    expect(second, isFalse);
    expect(campaignCalls, hasLength(1));
    expect(partnerCalls, [
      {
        'campaign': 'petsupo_ga4_test_20260821',
        'medium': 'email',
        'content': 'test_click',
      },
    ]);
  });
}
