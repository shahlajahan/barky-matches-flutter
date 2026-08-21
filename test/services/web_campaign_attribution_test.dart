import 'package:barky_matches_fixed/services/analytics/web_campaign_attribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(WebCampaignAttribution.resetForTesting);

  test('maps every supported business partner path to bounded category', () {
    expect(
      WebCampaignAttribution.partnerCategoryForPath('/isletme'),
      'general',
    );
    expect(
      WebCampaignAttribution.partnerCategoryForPath('/isletme/veteriner'),
      'veteriner',
    );
    expect(
      WebCampaignAttribution.partnerCategoryForPath('/isletme/pet-otel'),
      'pet_otel',
    );
    expect(
      WebCampaignAttribution.partnerCategoryForPath('/isletme/pet-taksi'),
      'pet_taksi',
    );
    expect(
      WebCampaignAttribution.partnerCategoryForPath('/isletme/groomer'),
      'groomer',
    );
    expect(
      WebCampaignAttribution.partnerCategoryForPath('/isletme/pet-shop'),
      'pet_shop',
    );
    expect(
      WebCampaignAttribution.partnerCategoryForPath('/isletme/sahiplendirme'),
      'sahiplendirme',
    );
  });

  test('rejects unknown business partner category paths', () {
    expect(
      WebCampaignAttribution.partnerCategoryForPath('/isletme/unknown'),
      isNull,
    );

    final landing = WebCampaignAttribution.classifyInitialLanding(
      Uri.parse('https://app.petsupo.com/isletme/unknown'),
    );

    expect(landing.entryChannel, 'direct');
    expect(landing.partnerCategory, isNull);
  });

  test('classifies supported business partner path as partner email', () {
    final landing = WebCampaignAttribution.classifyInitialLanding(
      Uri.parse('https://app.petsupo.com/isletme/pet-shop'),
    );
    final intake = WebCampaignAttribution.partnerIntakeContextForPath(
      '/isletme/pet-shop',
    );

    expect(landing.entryChannel, 'partner_email');
    expect(landing.partnerCategory, 'pet_shop');
    expect(landing.initialSector, 'pet_shop');
    expect(landing.campaign, partnerOutreachCampaign);
    expect(landing.content, partnerOutreachContent);
    expect(intake, isNotNull);
    expect(intake!.partnerCategory, 'pet_shop');
    expect(intake.initialSector, 'pet_shop');
  });

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

  test('classifies direct referral and tagged campaign landings', () {
    expect(
      WebCampaignAttribution.classifyInitialLanding(
        Uri.parse('https://app.petsupo.com/'),
      ).entryChannel,
      'direct',
    );
    expect(
      WebCampaignAttribution.classifyInitialLanding(
        Uri.parse('https://app.petsupo.com/'),
        referrer: 'https://example.com/page',
      ).entryChannel,
      'referral',
    );
    expect(
      WebCampaignAttribution.classifyInitialLanding(
        Uri.parse(
          'https://app.petsupo.com/?utm_source=newsletter'
          '&utm_medium=email&utm_campaign=launch',
        ),
      ).entryChannel,
      'tagged_campaign',
    );
  });

  test(
    'logs web landing without partner event for non-partner source',
    () async {
      final campaignCalls = <InitialUtmCampaign>[];
      final partnerCalls = <Map<String, Object>>[];
      final webLandingCalls = <Map<String, Object>>[];

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
        logWebLanding: (parameters) async => webLandingCalls.add(parameters),
      );

      expect(logged, isTrue);
      expect(campaignCalls, isEmpty);
      expect(partnerCalls, isEmpty);
      expect(webLandingCalls, [
        {'entry_channel': 'tagged_campaign'},
      ]);
    },
  );

  test('logs web and partner landing once for clean business link', () async {
    final campaignCalls = <InitialUtmCampaign>[];
    final partnerCalls = <Map<String, Object>>[];
    final webLandingCalls = <Map<String, Object>>[];
    final uri = Uri.parse('https://app.petsupo.com/isletme/veteriner');

    final first = await WebCampaignAttribution.recordInitialUtmCampaign(
      isWeb: true,
      initialUri: uri,
      logCampaignDetails: (utm) async => campaignCalls.add(utm),
      logPartnerLanding: (parameters) async => partnerCalls.add(parameters),
      logWebLanding: (parameters) async => webLandingCalls.add(parameters),
    );
    final second = await WebCampaignAttribution.recordInitialUtmCampaign(
      isWeb: true,
      initialUri: uri,
      logCampaignDetails: (utm) async => campaignCalls.add(utm),
      logPartnerLanding: (parameters) async => partnerCalls.add(parameters),
      logWebLanding: (parameters) async => webLandingCalls.add(parameters),
    );

    expect(first, isTrue);
    expect(second, isFalse);
    expect(campaignCalls, hasLength(1));
    expect(campaignCalls.single.source, 'partner_email');
    expect(campaignCalls.single.medium, 'email');
    expect(campaignCalls.single.campaign, partnerOutreachCampaign);
    expect(campaignCalls.single.content, partnerOutreachContent);
    expect(webLandingCalls, [
      {
        'entry_channel': 'partner_email',
        'partner_category': 'veteriner',
        'campaign': partnerOutreachCampaign,
        'content': partnerOutreachContent,
      },
    ]);
    expect(partnerCalls, [
      {
        'partner_category': 'veteriner',
        'campaign': partnerOutreachCampaign,
        'content': partnerOutreachContent,
      },
    ]);
  });

  test('does not log on mobile', () async {
    final logged = await WebCampaignAttribution.recordInitialUtmCampaign(
      isWeb: false,
      initialUri: Uri.parse('https://app.petsupo.com/isletme'),
      logCampaignDetails: (_) async => fail('campaign should not log'),
      logPartnerLanding: (_) async => fail('partner should not log'),
      logWebLanding: (_) async => fail('web landing should not log'),
    );

    expect(logged, isFalse);
  });
}
