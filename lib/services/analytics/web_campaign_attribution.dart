import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:barky_matches_fixed/ui/business/partner_intake_context.dart';

typedef CampaignDetailsLogger = Future<void> Function(InitialUtmCampaign utm);
typedef PartnerLandingLogger =
    Future<void> Function(Map<String, Object> parameters);
typedef WebLandingLogger =
    Future<void> Function(Map<String, Object> parameters);

const String partnerOutreachCampaign = 'partner_outreach_2026';
const String partnerOutreachContent = 'welcome_email';

const Map<String, String> businessPartnerPathCategories = {
  '/isletme': 'general',
  '/isletme/veteriner': 'veteriner',
  '/isletme/pet-otel': 'pet_otel',
  '/isletme/pet-taksi': 'pet_taksi',
  '/isletme/groomer': 'groomer',
  '/isletme/pet-shop': 'pet_shop',
  '/isletme/sahiplendirme': 'sahiplendirme',
};

const Map<String, String> businessPartnerCategorySectors = {
  'veteriner': 'veterinary',
  'pet_otel': 'pet_hotel',
  'pet_taksi': 'pet_taxi',
  'groomer': 'groomer',
  'pet_shop': 'pet_shop',
  'sahiplendirme': 'adoption_center',
};

class InitialUtmCampaign {
  const InitialUtmCampaign({
    required this.source,
    required this.medium,
    required this.campaign,
    this.content,
  });

  final String source;
  final String medium;
  final String campaign;
  final String? content;
}

class InitialWebLanding {
  const InitialWebLanding({
    required this.entryChannel,
    this.source,
    this.medium,
    this.campaign,
    this.content,
    this.partnerCategory,
    this.initialSector,
  });

  final String entryChannel;
  final String? source;
  final String? medium;
  final String? campaign;
  final String? content;
  final String? partnerCategory;
  final String? initialSector;

  bool get isBusinessPartner => entryChannel == 'partner_email';

  Map<String, Object> webLandingParameters() {
    final parameters = <String, Object>{'entry_channel': entryChannel};
    final category = partnerCategory;
    final campaignValue = campaign;
    final contentValue = content;
    if (category != null) parameters['partner_category'] = category;
    if (campaignValue != null) parameters['campaign'] = campaignValue;
    if (contentValue != null) parameters['content'] = contentValue;
    return parameters;
  }

  Map<String, Object> partnerLandingParameters() {
    final parameters = <String, Object>{};
    final category = partnerCategory;
    final campaignValue = campaign;
    final contentValue = content;
    if (category != null) parameters['partner_category'] = category;
    if (campaignValue != null) parameters['campaign'] = campaignValue;
    if (contentValue != null) parameters['content'] = contentValue;
    return parameters;
  }

  InitialUtmCampaign? campaignDetails() {
    if (source == null || medium == null || campaign == null) {
      return null;
    }
    return InitialUtmCampaign(
      source: source!,
      medium: medium!,
      campaign: campaign!,
      content: content,
    );
  }
}

class WebCampaignAttribution {
  WebCampaignAttribution._();

  static bool _initialLandingLogged = false;

  static InitialWebLanding classifyInitialLanding(Uri uri, {String? referrer}) {
    final partnerCategory = businessPartnerPathCategories[_normalizePath(uri)];
    if (partnerCategory != null) {
      return InitialWebLanding(
        entryChannel: 'partner_email',
        source: 'partner_email',
        medium: 'email',
        campaign: partnerOutreachCampaign,
        content: partnerOutreachContent,
        partnerCategory: partnerCategory,
        initialSector: businessPartnerCategorySectors[partnerCategory],
      );
    }

    final utm = extractInitialUtm(uri);
    if (utm != null) {
      return const InitialWebLanding(entryChannel: 'tagged_campaign');
    }

    if (_hasExternalReferrer(referrer, uri.origin)) {
      return const InitialWebLanding(entryChannel: 'referral');
    }

    return const InitialWebLanding(entryChannel: 'direct');
  }

  static InitialUtmCampaign? extractInitialUtm(Uri uri) {
    final params = uri.queryParameters;
    final source = _clean(params['utm_source']);
    final medium = _clean(params['utm_medium']);
    final campaign = _clean(params['utm_campaign']);
    final content = _clean(params['utm_content']);

    if (source == null || medium == null || campaign == null) {
      return null;
    }

    return InitialUtmCampaign(
      source: source,
      medium: medium,
      campaign: campaign,
      content: content,
    );
  }

  static Future<bool> recordInitialUtmCampaign({
    required Uri initialUri,
    required CampaignDetailsLogger logCampaignDetails,
    required PartnerLandingLogger logPartnerLanding,
    WebLandingLogger? logWebLanding,
    String? referrer,
    bool isWeb = kIsWeb,
  }) async {
    if (!isWeb || _initialLandingLogged) {
      return false;
    }

    _initialLandingLogged = true;

    final landing = classifyInitialLanding(initialUri, referrer: referrer);
    await logWebLanding?.call(landing.webLandingParameters());

    final campaign = landing.campaignDetails();
    if (campaign != null) {
      await logCampaignDetails(campaign);
    }

    if (landing.isBusinessPartner) {
      await logPartnerLanding(landing.partnerLandingParameters());
    }

    return true;
  }

  static Future<bool> recordInitialUtmCampaignWithFirebase(
    Uri initialUri, {
    String? referrer,
  }) {
    final analytics = FirebaseAnalytics.instance;
    return recordInitialUtmCampaign(
      initialUri: initialUri,
      logCampaignDetails: (utm) {
        return analytics.logCampaignDetails(
          source: utm.source,
          medium: utm.medium,
          campaign: utm.campaign,
          content: utm.content,
        );
      },
      logPartnerLanding: (parameters) {
        return analytics.logEvent(
          name: 'partner_email_landing',
          parameters: parameters,
        );
      },
      logWebLanding: (parameters) {
        return analytics.logEvent(name: 'web_landing', parameters: parameters);
      },
      referrer: referrer,
    );
  }

  static String? partnerCategoryForPath(String path) {
    return businessPartnerPathCategories[_normalizeRawPath(path)];
  }

  static String? initialSectorForPartnerCategory(String? partnerCategory) {
    if (partnerCategory == null) return null;
    return businessPartnerCategorySectors[partnerCategory];
  }

  static String? initialSectorForPath(String path) {
    return initialSectorForPartnerCategory(partnerCategoryForPath(path));
  }

  static PartnerIntakeContext? partnerIntakeContextForPath(String path) {
    final category = partnerCategoryForPath(path);
    if (category == null) return null;
    return PartnerIntakeContext.forCategory(category);
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  @visibleForTesting
  static void resetForTesting() {
    _initialLandingLogged = false;
  }

  static String _normalizePath(Uri uri) => _normalizeRawPath(uri.path);

  static String _normalizeRawPath(String path) {
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path.isEmpty ? '/' : path;
  }

  static bool _hasExternalReferrer(String? referrer, String origin) {
    final value = referrer?.trim();
    if (value == null || value.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }
    return uri.origin != origin;
  }
}
