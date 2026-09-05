import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/models/marketplace_basket_limits.dart';
import 'package:barky_matches_fixed/services/marketplace_catalog_service.dart';

/// Marketplace Revision 47 §0.45 (Slice 7F-2) — drift detection between the
/// Flutter UX mirror and the authoritative backend contract.
///
/// The Dart constants are a convenience for the cart; the server enforces the
/// same bounds before any database read. If the two ever disagree, a customer
/// either builds a basket the server will reject (bad UX) or, worse, the
/// client silently permits more than the server was sized for. This test
/// parses the JavaScript contract and compares every value, so changing one
/// side alone fails the build.
void main() {
  final backend = File(
    'functions/src/marketplace/orders/basketLimits.js',
  ).readAsStringSync();

  /// Reads one `KEY: <int>,` entry out of the frozen BASKET_LIMITS object.
  /// Scoped to that object so an unrelated number elsewhere in the file
  /// cannot satisfy the match.
  int backendLimit(String key) {
    final start = backend.indexOf('const BASKET_LIMITS = Object.freeze({');
    expect(start, greaterThan(-1), reason: 'BASKET_LIMITS must be declared');
    final end = backend.indexOf('});', start);
    expect(end, greaterThan(start));
    final block = backend.substring(start, end);
    final match = RegExp('$key:\\s*(\\d+)').firstMatch(block);
    expect(match, isNotNull, reason: '$key must be declared in BASKET_LIMITS');
    return int.parse(match!.group(1)!);
  }

  test('every Flutter mirror value equals the backend contract', () {
    expect(
      MarketplaceBasketLimits.maxSubmittedLines,
      backendLimit('MAX_SUBMITTED_LINES'),
    );
    expect(
      MarketplaceBasketLimits.maxDistinctProducts,
      backendLimit('MAX_DISTINCT_PRODUCTS'),
    );
    expect(
      MarketplaceBasketLimits.maxQuantityPerProduct,
      backendLimit('MAX_QUANTITY_PER_PRODUCT'),
    );
    expect(
      MarketplaceBasketLimits.maxTotalUnits,
      backendLimit('MAX_TOTAL_UNITS'),
    );
    expect(
      MarketplaceBasketLimits.maxBusinesses,
      backendLimit('MAX_BUSINESSES'),
    );
  });

  test('the Flutter mirror can never be MORE permissive than the backend', () {
    // Stated separately from equality: if a future edit relaxes only the
    // client, this fails with a message naming the risk rather than a bare
    // inequality.
    final pairs = <String, List<int>>{
      'maxSubmittedLines': [
        MarketplaceBasketLimits.maxSubmittedLines,
        backendLimit('MAX_SUBMITTED_LINES'),
      ],
      'maxDistinctProducts': [
        MarketplaceBasketLimits.maxDistinctProducts,
        backendLimit('MAX_DISTINCT_PRODUCTS'),
      ],
      'maxQuantityPerProduct': [
        MarketplaceBasketLimits.maxQuantityPerProduct,
        backendLimit('MAX_QUANTITY_PER_PRODUCT'),
      ],
      'maxTotalUnits': [
        MarketplaceBasketLimits.maxTotalUnits,
        backendLimit('MAX_TOTAL_UNITS'),
      ],
      'maxBusinesses': [
        MarketplaceBasketLimits.maxBusinesses,
        backendLimit('MAX_BUSINESSES'),
      ],
    };
    pairs.forEach((name, values) {
      expect(
        values[0],
        lessThanOrEqualTo(values[1]),
        reason:
            'Flutter $name (${values[0]}) exceeds the backend bound '
            '(${values[1]}); the client would permit a basket the server '
            'was not sized for',
      );
    });
  });

  test('the distinct-product bound matches the batch hydration bound', () {
    // The derivation recorded in the backend contract: a cart must never hold
    // more products than the batch-hydration callable can serve at once.
    expect(MarketplaceBasketLimits.maxDistinctProducts, maxBatchProducts);
  });

  test('the mirror is documented as non-authoritative', () {
    final mirror = File(
      'lib/models/marketplace_basket_limits.dart',
    ).readAsStringSync();
    expect(mirror, contains('NOT AUTHORITATIVE'));
    expect(mirror, contains('basketLimits.js'));
  });
}
