import 'package:cloud_functions/cloud_functions.dart';

/// Client transport for the M3 Promotion Engine.
///
/// The request intentionally carries no amount, currency, duration, or rank
/// value. Those terms are resolved and snapshotted by the trusted backend.
class PromotionCheckoutService {
  PromotionCheckoutService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> createCheckout({
    required String targetType,
    required String targetId,
    required String planId,
    required String idempotencyKey,
    String? businessId,
    String? sector,
  }) async {
    final response = await _functions
        .httpsCallable('createPromotionCheckout')
        .call({
          'targetType': targetType,
          'targetId': targetId,
          'planId': planId,
          'idempotencyKey': idempotencyKey,
          ...?businessId == null ? null : {'businessId': businessId},
          ...?sector == null ? null : {'sector': sector},
        });
    final data = response.data;
    if (data is! Map) {
      throw StateError('Promotion checkout response is not a map');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> verifyPayment(String campaignId) async {
    final response = await _functions
        .httpsCallable('verifyPromotionPayment')
        .call({'campaignId': campaignId});
    final data = response.data;
    if (data is! Map) {
      throw StateError('Promotion verification response is not a map');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> readPaymentStatus(String campaignId) async {
    final response = await _functions
        .httpsCallable('readPromotionPaymentStatus')
        .call({'campaignId': campaignId});
    final data = response.data;
    if (data is! Map) {
      throw StateError('Promotion status response is not a map');
    }
    return Map<String, dynamic>.from(data);
  }

  /// Reconciles a hosted payment result with server state. A redirect is
  /// never treated as proof of activation by this client.
  Future<Map<String, dynamic>> waitForPaymentStatus(
    String campaignId, {
    Duration timeout = const Duration(seconds: 20),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Map<String, dynamic>? last;
    do {
      last = await readPaymentStatus(campaignId);
      final status = last['campaignStatus']?.toString().toLowerCase();
      if (status == 'active' || status == 'failed' || status == 'cancelled') {
        return last;
      }
      if (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(pollInterval);
      }
    } while (DateTime.now().isBefore(deadline));
    return last ?? <String, dynamic>{'campaignId': campaignId};
  }
}
