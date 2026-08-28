import 'dart:io';

import 'package:barky_matches_fixed/services/marketplace_catalog_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

// Marketplace P1-A Slice 4.8 Phase A (docs/plans/marketplace_p1a_
// compliance_review_implementation_plan_2026-08-21.md §0.14, §15 items
// 431-461): service-layer coverage against a fake callable. See
// marketplace_catalog_service.dart's own top-of-file comment for why a
// fake callable is a plain injected function rather than a mock of the
// real FirebaseFunctions/HttpsCallable SDK types (both have
// library-private constructors).
Map<String, dynamic> mediaFixture() => {
  'type': 'image',
  'originalUrl': 'https://example.com/a.jpg',
  'playbackUrl': null,
  'thumbnailUrl': null,
};

Map<String, dynamic> productFixture({String productId = 'business-1_SKU-1'}) {
  return {
    'businessId': 'business-1',
    'productId': productId,
    'name': 'Dog food',
    'description': 'desc',
    'category': 'Food > Dry Food',
    'brand': 'Acme',
    'media': [mediaFixture()],
    'price': 100.0,
    'salePrice': null,
    'currency': 'TRY',
    'kdvRate': 10.0,
    'taxIncluded': true,
    'stock': 5,
    'shippingMode': 'fixed_price',
    'shippingPayer': 'seller',
    'shippingFee': 20.0,
    'freeShippingThreshold': 200.0,
    'allowFreeShipping': false,
    'allowedCarrierCodes': ['YURTICI'],
    'originCity': 'Istanbul',
    'maxDeliveryDays': 3,
    'deliveryType': 'cargo',
    'weightKg': 1.5,
    'lengthCm': 10.0,
    'widthCm': 10.0,
    'heightCm': 10.0,
    'fixedDesi': 2.0,
    'businessName': 'Acme',
    'businessLogo': null,
  };
}

void main() {
  group('fetchProductList', () {
    test(
      'calls the exact callable name and request map (first page)',
      () async {
        String? calledName;
        Map<String, dynamic>? calledData;
        final service = MarketplaceCatalogService(
          callableInvoker: (name, data) async {
            calledName = name;
            calledData = data;
            return {'items': [], 'nextCursor': null};
          },
        );

        await service.fetchProductList(pageSize: 20);

        expect(calledName, 'getMarketplaceProductList');
        expect(calledData, {'pageSize': 20});
      },
    );

    test('includes cursor only when supplied', () async {
      Map<String, dynamic>? calledData;
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async {
          calledData = data;
          return {'items': [], 'nextCursor': null};
        },
      );

      await service.fetchProductList(pageSize: 20, cursor: 'opaque-cursor');

      expect(calledData, {'pageSize': 20, 'cursor': 'opaque-cursor'});
    });

    // Failed independent audit correction: §15 item 431, strengthened — a
    // literal two-call pagination composition, not two independent
    // single-call tests. The first call's own returned nextCursor is
    // captured and passed back, verbatim, as the second call's own cursor
    // argument — exactly the real caller-driven chaining pattern
    // §0.14's own "Pagination behavior" paragraph describes — proving no
    // transformation, decoding, or staleness occurs across the boundary,
    // and that each page's own items remain independently correct.
    test('item 431: a nextCursor returned by one fetchProductList call is '
        'passed back, verbatim, as the cursor argument of the next call — '
        'a literal two-call chained proof, not merely two independent '
        'single-call tests', () async {
      final requestedCursors = <String?>[];
      var callCount = 0;
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async {
          callCount += 1;
          requestedCursors.add(data['cursor'] as String?);
          if (callCount == 1) {
            return {
              'items': [productFixture(productId: 'business-1_SKU-1')],
              'nextCursor': 'page-2-token',
            };
          }
          return {
            'items': [productFixture(productId: 'business-1_SKU-2')],
            'nextCursor': null,
          };
        },
      );

      final firstPage = await service.fetchProductList(pageSize: 20);
      expect(firstPage.nextCursor, 'page-2-token');
      expect(firstPage.items, hasLength(1));
      expect(firstPage.items.first.productId, 'business-1_SKU-1');

      final secondPage = await service.fetchProductList(
        pageSize: 20,
        cursor: firstPage.nextCursor,
      );
      expect(secondPage.items, hasLength(1));
      expect(secondPage.items.first.productId, 'business-1_SKU-2');
      expect(secondPage.nextCursor, isNull);

      // The exact chaining assertion: the second call's own cursor
      // argument is byte-for-byte the first call's own returned
      // nextCursor — no transformation, and no stale/cached value.
      expect(requestedCursors, [null, 'page-2-token']);
    });

    test('parses items and nextCursor from a well-formed response', () async {
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async {
          return {
            'items': [productFixture()],
            'nextCursor': 'next-page-token',
          };
        },
      );

      final page = await service.fetchProductList();

      expect(page.items, hasLength(1));
      expect(page.items.first.productId, 'business-1_SKU-1');
      expect(page.nextCursor, 'next-page-token');
    });

    test('a null nextCursor means the list is exhausted', () async {
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async {
          return {'items': [], 'nextCursor': null};
        },
      );

      final page = await service.fetchProductList();

      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('an empty result page parses correctly, never an error', () async {
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async {
          return {'items': <dynamic>[], 'nextCursor': null};
        },
      );

      final page = await service.fetchProductList();

      expect(page.items, isEmpty);
    });

    test(
      'maps FirebaseFunctionsException("internal") to unavailableRetry',
      () async {
        final service = MarketplaceCatalogService(
          callableInvoker: (name, data) async {
            throw FirebaseFunctionsException(code: 'internal', message: 'boom');
          },
        );

        await expectLater(
          service.fetchProductList(),
          throwsA(
            isA<MarketplaceCatalogException>().having(
              (e) => e.kind,
              'kind',
              MarketplaceCatalogFailureKind.unavailableRetry,
            ),
          ),
        );
      },
    );

    test(
      'maps an unrecognized FirebaseFunctionsException code to generic',
      () async {
        final service = MarketplaceCatalogService(
          callableInvoker: (name, data) async {
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'nope',
            );
          },
        );

        await expectLater(
          service.fetchProductList(),
          throwsA(
            isA<MarketplaceCatalogException>().having(
              (e) => e.kind,
              'kind',
              MarketplaceCatalogFailureKind.generic,
            ),
          ),
        );
      },
    );

    test('a response missing "items" is a parse failure (unavailableRetry), '
        'never a silently-empty list', () async {
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async {
          return {'nextCursor': null};
        },
      );

      await expectLater(
        service.fetchProductList(),
        throwsA(
          isA<MarketplaceCatalogException>().having(
            (e) => e.kind,
            'kind',
            MarketplaceCatalogFailureKind.unavailableRetry,
          ),
        ),
      );
    });

    test(
      'a response missing "nextCursor" is a parse failure (unavailableRetry)',
      () async {
        final service = MarketplaceCatalogService(
          callableInvoker: (name, data) async {
            return {'items': <dynamic>[]};
          },
        );

        await expectLater(
          service.fetchProductList(),
          throwsA(isA<MarketplaceCatalogException>()),
        );
      },
    );

    test(
      'a non-map response is a parse failure, never an uncaught type error',
      () async {
        final service = MarketplaceCatalogService(
          callableInvoker: (name, data) async => 'unexpected-string',
        );

        await expectLater(
          service.fetchProductList(),
          throwsA(isA<MarketplaceCatalogException>()),
        );
      },
    );
  });

  group('fetchProductDetail', () {
    test('calls the exact callable name and request map', () async {
      String? calledName;
      Map<String, dynamic>? calledData;
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async {
          calledName = name;
          calledData = data;
          return {'item': productFixture()};
        },
      );

      await service.fetchProductDetail(
        businessId: 'business-1',
        productId: 'p-1',
      );

      expect(calledName, 'getMarketplaceProductDetail');
      expect(calledData, {'businessId': 'business-1', 'productId': 'p-1'});
    });

    test('parses the detail item from a well-formed response', () async {
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async {
          return {'item': productFixture()};
        },
      );

      final detail = await service.fetchProductDetail(
        businessId: 'business-1',
        productId: 'business-1_SKU-1',
      );

      expect(detail.productId, 'business-1_SKU-1');
    });

    test('maps FirebaseFunctionsException("not-found") to notFound '
        '(absent/ineligible/inactive/unapproved, uniformly)', () async {
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async {
          throw FirebaseFunctionsException(
            code: 'not-found',
            message: 'Product not found',
          );
        },
      );

      await expectLater(
        service.fetchProductDetail(
          businessId: 'business-1',
          productId: 'missing',
        ),
        throwsA(
          isA<MarketplaceCatalogException>().having(
            (e) => e.kind,
            'kind',
            MarketplaceCatalogFailureKind.notFound,
          ),
        ),
      );
    });

    test('a response missing "item" is a parse failure', () async {
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async => <String, dynamic>{},
      );

      await expectLater(
        service.fetchProductDetail(businessId: 'b', productId: 'p'),
        throwsA(isA<MarketplaceCatalogException>()),
      );
    });

    test('a malformed item map (missing a required field) is a parse failure, '
        'never an uncaught FormatException', () async {
      final service = MarketplaceCatalogService(
        callableInvoker: (name, data) async {
          final malformed = productFixture()..remove('name');
          return {'item': malformed};
        },
      );

      await expectLater(
        service.fetchProductDetail(businessId: 'b', productId: 'p'),
        throwsA(
          isA<MarketplaceCatalogException>().having(
            (e) => e.kind,
            'kind',
            MarketplaceCatalogFailureKind.unavailableRetry,
          ),
        ),
      );
    });
  });

  group('dormancy/security statics', () {
    final source = File(
      'lib/services/marketplace_catalog_service.dart',
    ).readAsStringSync();

    test('uses the exact europe-west3 region', () {
      expect(source, contains("region: marketplaceFunctionsRegion"));
      expect(source, contains("'europe-west3'"));
    });

    test('performs no direct Firestore read/fallback of any kind', () {
      expect(source, isNot(contains('FirebaseFirestore')));
      expect(source, isNot(contains('cloud_firestore')));
    });

    test('never logs public payloads, cursors, or raw exception content', () {
      expect(source, isNot(contains('print(')));
      expect(source, isNot(contains('debugPrint(')));
      expect(source, isNot(contains('log(')));
    });

    test('performs no client-side feature-flag check of its own', () {
      // The flag is enforced server-side only (§0.14) — this service may
      // document that fact in prose (as it does, above), but must never
      // import a remote-config mechanism or call a flag-check API itself.
      expect(source, isNot(contains('RemoteConfig')));
      expect(source, isNot(contains('firebase_remote_config')));
      expect(source, isNot(contains('.getBool(')));
    });
  });
}
