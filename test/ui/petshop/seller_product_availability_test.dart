import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/services/marketplace_catalog_service.dart';
import 'package:barky_matches_fixed/ui/petshop/seller_product_availability.dart';

/// "Buy Now" previously navigated unconditionally, so a Pet Shop with no
/// published products sent every visitor into an empty catalogue.
///
/// Marketplace Revision 43 §0.41 (Slice 7D): availability is now the SERVER's
/// answer, obtained from the same `getMarketplaceProductList` code that serves
/// the catalogue, scoped to this seller. The client no longer evaluates
/// `isActive`/`moderationStatus` itself — it cannot, because publishability
/// also depends on the compliance decision, approval, evidence, business
/// generation and pilot class, none of which are client-readable.
void main() {
  /// A catalog service whose single callable is a plain Dart function, so no
  /// Firebase SDK type has to be constructed.
  MarketplaceCatalogService serviceReturning(
    Future<Object?> Function(String name, Map<String, dynamic> data) invoke,
  ) => MarketplaceCatalogService(callableInvoker: invoke);

  MarketplaceCatalogService listReturning(List<Map<String, dynamic>> items) =>
      serviceReturning((name, data) async {
        expect(name, 'getMarketplaceProductList');
        return {'items': items, 'nextCursor': null};
      });

  /// Exactly the projection `getMarketplaceProductList` emits — every field
  /// the parser requires, so a parse failure here would be a real contract
  /// break rather than a thin fixture.
  Map<String, dynamic> item(String id) => {
    'businessId': 'shop-1',
    'productId': id,
    'name': 'Product $id',
    'category': 'Accessories > Collar',
    'media': <Map<String, dynamic>>[],
    'price': 10.0,
    'currency': 'TRY',
    'stock': 3,
    'allowFreeShipping': false,
    'allowedCarrierCodes': <String>[],
  };

  test('no visible products resolves to none', () async {
    expect(
      await resolveSellerProductAvailability(
        'shop-1',
        catalogService: listReturning(const []),
      ),
      SellerProductAvailability.none,
    );
  });

  test('one server-visible product resolves to available', () async {
    expect(
      await resolveSellerProductAvailability(
        'shop-1',
        catalogService: listReturning([item('p1')]),
      ),
      SellerProductAvailability.available,
    );
  });

  test('the request is bounded and scoped to this seller', () async {
    Map<String, dynamic>? sent;
    final service = serviceReturning((name, data) async {
      sent = data;
      return {'items': const [], 'nextCursor': null};
    });
    await resolveSellerProductAvailability('shop-1', catalogService: service);
    expect(sent!['pageSize'], 1, reason: 'answers "any?", never reads the catalogue');
    expect(sent!['businessId'], 'shop-1');
  });

  test('a blank or whitespace seller id resolves to none without a call', () async {
    var called = false;
    final service = serviceReturning((name, data) async {
      called = true;
      return {'items': const [], 'nextCursor': null};
    });
    for (final id in <String?>[null, '', '   ']) {
      expect(
        await resolveSellerProductAvailability(id, catalogService: service),
        SellerProductAvailability.none,
      );
    }
    expect(called, isFalse);
  });

  test('every failure fails closed, and never falls back to a direct read', () async {
    final failures = <Object>[
      FirebaseFunctionsException(code: 'not-found', message: 'x'),
      FirebaseFunctionsException(code: 'internal', message: 'x'),
      FirebaseFunctionsException(code: 'permission-denied', message: 'x'),
      FirebaseFunctionsException(code: 'unauthenticated', message: 'x'),
      FirebaseFunctionsException(code: 'failed-precondition', message: 'flag off'),
      StateError('offline'),
    ];
    for (final failure in failures) {
      final service = serviceReturning((name, data) async => throw failure);
      expect(
        await resolveSellerProductAvailability('shop-1', catalogService: service),
        SellerProductAvailability.none,
        reason: '$failure must fail closed',
      );
    }
  });

  test('a malformed payload fails closed rather than reporting availability', () async {
    for (final payload in <Object?>[null, 'nope', <String, dynamic>{}, {'items': 'x'}]) {
      final service = serviceReturning((name, data) async => payload);
      expect(
        await resolveSellerProductAvailability('shop-1', catalogService: service),
        SellerProductAvailability.none,
      );
    }
  });
}
