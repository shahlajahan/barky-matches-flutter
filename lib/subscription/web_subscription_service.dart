import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum WebSubscriptionCatalogFailure {
  unauthenticated,
  functionNotFound,
  configuration,
  network,
  malformedResponse,
}

class WebSubscriptionCatalogException implements Exception {
  const WebSubscriptionCatalogException(
    this.failure, {
    this.code,
    this.message,
  });

  final WebSubscriptionCatalogFailure failure;
  final String? code;
  final String? message;

  @override
  String toString() =>
      'WebSubscriptionCatalogException($failure, code: $code, message: $message)';
}

class WebSubscriptionPlanPresentation {
  const WebSubscriptionPlanPresentation({
    required this.planId,
    required this.amount,
    required this.currency,
    required this.termDays,
  });

  final String planId;
  final num amount;
  final String currency;
  final int termDays;

  String get formattedPrice {
    final value = amount.toDouble();
    final amountText = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    if (currency.toUpperCase() == 'TRY') {
      return '₺$amountText';
    }
    return '$amountText $currency';
  }
}

class WebSubscriptionCheckoutSession {
  const WebSubscriptionCheckoutSession({
    required this.orderId,
    required this.html,
  });

  final String orderId;
  final String html;
}

class WebSubscriptionPaymentStatus {
  const WebSubscriptionPaymentStatus({
    required this.status,
    required this.verified,
    this.planId,
  });

  final String status;
  final bool verified;
  final String? planId;

  bool get isFailed => const {'failed', 'cancelled'}.contains(status);
  bool get isPending => !verified && !isFailed;
}

class WebSubscriptionService {
  WebSubscriptionService({FirebaseFunctions? functions, FirebaseAuth? auth})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3'),
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<void> _requireAuthenticatedUser() async {
    var user = _auth.currentUser;
    if (user == null) {
      try {
        user = await _auth
            .authStateChanges()
            .where((candidate) => candidate != null)
            .cast<User>()
            .first
            .timeout(const Duration(seconds: 5));
      } on TimeoutException {
        throw const WebSubscriptionCatalogException(
          WebSubscriptionCatalogFailure.unauthenticated,
          code: 'unauthenticated',
          message: 'Firebase Authentication is not available',
        );
      }
    }
    await user.getIdToken();
  }

  Future<Map<String, WebSubscriptionPlanPresentation>> loadCatalog() async {
    try {
      await _requireAuthenticatedUser();
      final result = await _functions
          .httpsCallable('getWebSubscriptionCatalog')
          .call();
      return WebSubscriptionService.parseWebSubscriptionCatalog(result.data);
    } on FirebaseFunctionsException catch (error) {
      final failure = switch (error.code) {
        'unauthenticated' => WebSubscriptionCatalogFailure.unauthenticated,
        'not-found' ||
        'unimplemented' => WebSubscriptionCatalogFailure.functionNotFound,
        'failed-precondition' => WebSubscriptionCatalogFailure.configuration,
        'unavailable' ||
        'deadline-exceeded' => WebSubscriptionCatalogFailure.network,
        _ => WebSubscriptionCatalogFailure.network,
      };
      if (kDebugMode) {
        debugPrint(
          'Web subscription catalog callable failed: '
          'code=${error.code}, message=${error.message}',
        );
      }
      throw WebSubscriptionCatalogException(
        failure,
        code: error.code,
        message: error.message,
      );
    } on FirebaseAuthException catch (error) {
      final failure = error.code == 'network-request-failed'
          ? WebSubscriptionCatalogFailure.network
          : WebSubscriptionCatalogFailure.unauthenticated;
      if (kDebugMode) {
        debugPrint(
          'Web subscription catalog authentication failed: '
          'code=${error.code}, message=${error.message}',
        );
      }
      throw WebSubscriptionCatalogException(
        failure,
        code: error.code,
        message: error.message,
      );
    } on WebSubscriptionCatalogException {
      rethrow;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Web subscription catalog response is malformed: $error');
      }
      throw WebSubscriptionCatalogException(
        WebSubscriptionCatalogFailure.malformedResponse,
        code: 'malformed-response',
        message: error.toString(),
      );
    }
  }

  static Map<String, WebSubscriptionPlanPresentation>
  parseWebSubscriptionCatalog(Object? response) {
    final root = Map<String, dynamic>.from(response as Map);
    final plans = Map<String, dynamic>.from(root['plans'] as Map);
    final parsed = plans.map((planId, raw) {
      final data = Map<String, dynamic>.from(raw as Map);
      final amount = data['amount'] is num
          ? data['amount'] as num
          : num.parse(data['amount'].toString());
      final duration = data['durationDays'] ?? data['termDays'];
      return MapEntry(
        planId,
        WebSubscriptionPlanPresentation(
          planId: planId,
          amount: amount,
          currency: data['currency'].toString(),
          termDays: duration is num
              ? duration.toInt()
              : int.parse(duration.toString()),
        ),
      );
    });
    if (parsed.keys.toSet().difference(const {'premium', 'gold'}).isNotEmpty ||
        !parsed.containsKey('premium') ||
        !parsed.containsKey('gold') ||
        parsed.values.any(
          (plan) => plan.currency != 'TRY' || plan.termDays != 30,
        )) {
      throw const FormatException('Unexpected subscription catalog schema');
    }
    return parsed;
  }

  Future<WebSubscriptionCheckoutSession> createCheckout(String planId) async {
    // The backend validates this against a strict allowlist and stores it
    // on the pending order — it decides where the browser-return handler
    // sends the user back to after payment (production vs. an explicit
    // local dev server), never the client. kIsWeb is guaranteed true here:
    // this is only ever called from a kIsWeb-gated call site.
    final result = await _functions
        .httpsCallable('createWebSubscriptionCheckout')
        .call({'planId': planId, 'returnOrigin': Uri.base.origin});
    final data = Map<String, dynamic>.from(result.data as Map);
    final orderId = data['orderId']?.toString() ?? '';
    final html = data['html']?.toString() ?? '';
    if (orderId.isEmpty || html.isEmpty) {
      throw StateError('Subscription checkout response is incomplete');
    }
    return WebSubscriptionCheckoutSession(orderId: orderId, html: html);
  }

  Future<WebSubscriptionPaymentStatus> readStatus(String orderId) async {
    await _requireAuthenticatedUser();
    final result = await _functions
        .httpsCallable('readWebSubscriptionPaymentStatus')
        .call({'orderId': orderId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return WebSubscriptionPaymentStatus(
      status: data['status']?.toString().toLowerCase() ?? 'pending',
      verified: data['verified'] == true,
      planId: data['planId']?.toString(),
    );
  }
}
