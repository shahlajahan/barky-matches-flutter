import 'package:cloud_functions/cloud_functions.dart';

import '../../services/analytics/analytics_events.dart';
import '../../services/analytics/analytics_parameters.dart';
import '../../services/analytics/analytics_service.dart';
import '../models/promotion_campaign_stats.dart';

enum PromotionAnalyticsEvent { impression, click, detailView }

extension PromotionAnalyticsEventWire on PromotionAnalyticsEvent {
  String get value => switch (this) {
    PromotionAnalyticsEvent.impression => 'IMPRESSION',
    PromotionAnalyticsEvent.click => 'CLICK',
    PromotionAnalyticsEvent.detailView => 'DETAIL_VIEW',
  };
}

/// Generic, best-effort Promotion telemetry transport.
///
/// The service receives campaign identity from an already-loaded
/// `promotion_active` projection. It never reads campaigns, accepts money, or
/// treats a client event as conversion truth.
class PromotionAnalyticsService {
  PromotionAnalyticsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;
  static final Set<String> _localDedupe = <String>{};
  static final String _sessionId =
      'session_${DateTime.now().microsecondsSinceEpoch}';

  static String impressionKey({
    required String campaignId,
    required String targetId,
    required String placement,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    final window = time.millisecondsSinceEpoch ~/ (10 * 60 * 1000);
    return 'IMPRESSION|$campaignId|$targetId|$placement|$_sessionId|$window';
  }

  Future<bool> recordImpression({
    required String campaignId,
    required String targetType,
    required String targetId,
    required String placement,
    String? sector,
    String? eventId,
  }) => _record(
    event: PromotionAnalyticsEvent.impression,
    campaignId: campaignId,
    targetType: targetType,
    targetId: targetId,
    placement: placement,
    sector: sector,
    eventId:
        eventId ??
        impressionKey(
          campaignId: campaignId,
          targetId: targetId,
          placement: placement,
        ),
  );

  Future<bool> recordClick({
    required String campaignId,
    required String targetType,
    required String targetId,
    required String placement,
    String? sector,
  }) => _record(
    event: PromotionAnalyticsEvent.click,
    campaignId: campaignId,
    targetType: targetType,
    targetId: targetId,
    placement: placement,
    sector: sector,
    eventId: 'CLICK|$campaignId|$targetId|$placement|$_sessionId',
  );

  Future<bool> recordDetailView({
    required String campaignId,
    required String targetType,
    required String targetId,
    required String placement,
    String? sector,
  }) => _record(
    event: PromotionAnalyticsEvent.detailView,
    campaignId: campaignId,
    targetType: targetType,
    targetId: targetId,
    placement: placement,
    sector: sector,
    eventId: 'DETAIL_VIEW|$campaignId|$targetId|$placement|$_sessionId',
  );

  Future<bool> _record({
    required PromotionAnalyticsEvent event,
    required String campaignId,
    required String targetType,
    required String targetId,
    required String placement,
    required String eventId,
    String? sector,
  }) async {
    final localKey = '$eventId|${event.value}';
    if (!_localDedupe.add(localKey)) return false;
    try {
      final analyticsEvent = switch (event) {
        PromotionAnalyticsEvent.impression =>
          AnalyticsEvents.promotionImpression,
        PromotionAnalyticsEvent.click => AnalyticsEvents.promotionClick,
        PromotionAnalyticsEvent.detailView =>
          AnalyticsEvents.promotionDetailView,
      };
      // Firebase Analytics is useful product telemetry, but the callable is
      // the validated source for Promotion aggregates.
      AnalyticsService.logEvent(
        analyticsEvent,
        parameters: {
          AnalyticsParameters.campaignId: campaignId,
          AnalyticsParameters.targetType: targetType,
          AnalyticsParameters.targetId: targetId,
          AnalyticsParameters.placement: placement,
          if (sector != null) AnalyticsParameters.sector: sector,
        },
      );
      await _functions.httpsCallable('recordPromotionEvent').call({
        'eventId': eventId,
        'eventType': event.value,
        'campaignId': campaignId,
        'targetType': targetType,
        'targetId': targetId,
        'placement': placement,
        'sector': sector,
        'sessionId': _sessionId,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      // Analytics must never block discovery, navigation, or payment UX.
      return false;
    }
  }

  Future<PromotionCampaignStats> readCampaignStats(String campaignId) async {
    final result = await _functions
        .httpsCallable('readPromotionCampaignStats')
        .call({'campaignId': campaignId});
    if (result.data is! Map) {
      throw StateError('Promotion campaign stats response is not a map');
    }
    return PromotionCampaignStats.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }
}
