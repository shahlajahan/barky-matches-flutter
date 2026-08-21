import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

typedef CampaignDetailsLogger = Future<void> Function(InitialUtmCampaign utm);
typedef PartnerLandingLogger =
    Future<void> Function(Map<String, Object> parameters);

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

class WebCampaignAttribution {
  WebCampaignAttribution._();

  static bool _initialCampaignLogged = false;

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
    bool isWeb = kIsWeb,
  }) async {
    if (!isWeb || _initialCampaignLogged) {
      return false;
    }

    final utm = extractInitialUtm(initialUri);
    if (utm == null) {
      return false;
    }

    _initialCampaignLogged = true;
    await logCampaignDetails(utm);

    if (utm.source == 'partner_email') {
      await logPartnerLanding({
        'campaign': utm.campaign,
        'medium': utm.medium,
        if (utm.content != null) 'content': utm.content!,
      });
    }

    return true;
  }

  static Future<bool> recordInitialUtmCampaignWithFirebase(Uri initialUri) {
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
    );
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
    _initialCampaignLogged = false;
  }
}
