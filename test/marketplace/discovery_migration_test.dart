import 'dart:async';

import 'package:barky_matches_fixed/models/public_marketplace_product_adapter.dart';
import 'package:barky_matches_fixed/services/marketplace_catalog_service.dart';
import 'package:barky_matches_fixed/services/marketplace_discovery_controller.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

// Marketplace Revision 43 §0.41 (Slice 7D) — behavioural coverage for the
// Flutter discovery migration.
//
// Every test here drives the REAL production classes
// (MarketplaceCatalogService, MarketplaceDiscoveryController, the public
// product adapter) against a fake CALLABLE — the same seam the pre-existing
// service tests use, and the only one available because the cloud_functions
// SDK types have library-private constructors.
//
// The point being proven throughout: the client never decides what is
// visible. It asks, and renders exactly what comes back. Anything the server
// omits, rejects or fails to return is unavailable — never resurrected from
// a cache, a stored id, or a locally-derived predicate.

Map<String, dynamic> mediaFixture() => {
  'type': 'image',
  'originalUrl': 'https://example.com/a.jpg',
  'playbackUrl': null,
  'thumbnailUrl': null,
};

/// Exactly the projection the server emits.
Map<String, dynamic> productFixture({
  String businessId = 'biz-1',
  String productId = 'biz-1_SKU-1',
  String name = 'Dog food',
  double price = 100.0,
  int stock = 5,
}) => {
  'businessId': businessId,
  'productId': productId,
  'name': name,
  'description': 'desc',
  'category': 'Food > Dry Food',
  'brand': 'Acme',
  'media': [mediaFixture()],
  'price': price,
  'salePrice': null,
  'currency': 'TRY',
  'kdvRate': 10.0,
  'taxIncluded': true,
  'stock': stock,
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

MarketplaceCatalogService serviceWith(
  Future<Object?> Function(String name, Map<String, dynamic> data) invoke,
) => MarketplaceCatalogService(callableInvoker: invoke);

void main() {
  // ===================================================================
  // 1-4, 22 — the catalogue serves exactly what the server returns
  // ===================================================================

  group('listing reflects the server decision only', () {
    test('1/22. eligible products the server returns are rendered', () async {
      final controller = MarketplaceDiscoveryController(
        catalogService: serviceWith((name, data) async {
          expect(name, 'getMarketplaceProductList');
          return {
            'items': [
              productFixture(productId: 'p1'),
              productFixture(productId: 'p2'),
            ],
            'nextCursor': null,
          };
        }),
      );
      await controller.load();
      expect(controller.status, DiscoveryStatus.loaded);
      expect(controller.products.map((p) => p.id), ['p1', 'p2']);
      // A ten-class product parses and displays; the class itself is never
      // projected, and the client never inspects one.
      expect(controller.products.first.name, 'Dog food');
    });

    test(
      '2/3/4. anything the server withholds simply is not there — the client '
      'has no way to add it back',
      () async {
        // Unpublished, unclassified, unknown-class, evidence-expired,
        // stale-decision, approval-missing, reclassified, generation-changed
        // and disabled-business products are all indistinguishable to the
        // client: the server just does not return them.
        final controller = MarketplaceDiscoveryController(
          catalogService: serviceWith(
            (name, data) async => {'items': const [], 'nextCursor': null},
          ),
        );
        await controller.load();
        expect(controller.status, DiscoveryStatus.empty);
        expect(controller.products, isEmpty);
      },
    );

    test('23. the client never derives eligibility from seller category', () async {
      // A product whose merchandising category looks excluded is still shown
      // when the server returns it — the category is descriptive, and the
      // client must not second-guess the server in either direction.
      final controller = MarketplaceDiscoveryController(
        catalogService: serviceWith(
          (name, data) async => {
            'items': [
              {...productFixture(productId: 'p1'), 'category': 'Health > Vitamins'},
            ],
            'nextCursor': null,
          },
        ),
      );
      await controller.load();
      expect(controller.products.single.id, 'p1');
      expect(controller.products.single.category, 'Health > Vitamins');
    });
  });

  // ===================================================================
  // 19, 20 — races and pagination
  // ===================================================================

  group('pagination and request races', () {
    test('20. pagination never duplicates a product across pages', () async {
      var call = 0;
      final controller = MarketplaceDiscoveryController(
        pageSize: 2,
        catalogService: serviceWith((name, data) async {
          call += 1;
          if (call == 1) {
            return {
              'items': [
                productFixture(productId: 'p1'),
                productFixture(productId: 'p2'),
              ],
              'nextCursor': 'c1',
            };
          }
          // A server retry or cursor overlap re-sends p2.
          return {
            'items': [
              productFixture(productId: 'p2'),
              productFixture(productId: 'p3'),
            ],
            'nextCursor': null,
          };
        }),
      );
      await controller.load();
      await controller.loadMore();
      expect(controller.products.map((p) => p.id), ['p1', 'p2', 'p3']);
      expect(controller.hasMore, isFalse);
    });

    test('18. deduplication is on canonical identity, not bare product id', () async {
      // The same productId under two different businesses is two products.
      final controller = MarketplaceDiscoveryController(
        catalogService: serviceWith(
          (name, data) async => {
            'items': [
              productFixture(businessId: 'biz-1', productId: 'same'),
              productFixture(businessId: 'biz-2', productId: 'same'),
            ],
            'nextCursor': null,
          },
        ),
      );
      await controller.load();
      expect(controller.products.length, 2);
      expect(
        controller.products.map((p) => p.businessId).toList(),
        ['biz-1', 'biz-2'],
      );
    });

    test('19. a slow older request cannot overwrite a newer one', () async {
      final gate = Completer<void>();
      var call = 0;
      final controller = MarketplaceDiscoveryController(
        catalogService: serviceWith((name, data) async {
          call += 1;
          if (call == 1) {
            await gate.future; // the stale, slow first request
            return {
              'items': [productFixture(productId: 'STALE')],
              'nextCursor': null,
            };
          }
          return {
            'items': [productFixture(productId: 'FRESH')],
            'nextCursor': null,
          };
        }),
      );

      final first = controller.load(businessId: 'biz-old');
      final second = controller.load(businessId: 'biz-new');
      await second;
      expect(controller.products.single.id, 'FRESH');

      gate.complete();
      await first;
      // The superseded response must not touch state at all.
      expect(controller.products.single.id, 'FRESH');
      expect(controller.status, DiscoveryStatus.loaded);
    });

    test('a scope change discards the previous scope\'s products', () async {
      var call = 0;
      final controller = MarketplaceDiscoveryController(
        catalogService: serviceWith((name, data) async {
          call += 1;
          return {
            'items': [productFixture(productId: call == 1 ? 'shopA' : 'shopB')],
            'nextCursor': null,
          };
        }),
      );
      await controller.load(businessId: 'A');
      await controller.load(businessId: 'B');
      expect(controller.products.map((p) => p.id), ['shopB']);
    });

    test('the scope is sent to the server, never applied locally', () async {
      Map<String, dynamic>? sent;
      final controller = MarketplaceDiscoveryController(
        catalogService: serviceWith((name, data) async {
          sent = data;
          return {'items': const [], 'nextCursor': null};
        }),
      );
      await controller.load(businessId: 'shop-7');
      expect(sent!['businessId'], 'shop-7');
    });
  });

  // ===================================================================
  // 15, 17, 21 — failure is fail-closed, with no direct-read fallback
  // ===================================================================

  group('failures fail closed', () {
    test('21/15. a callable failure clears results rather than showing stale ones', () async {
      var call = 0;
      final controller = MarketplaceDiscoveryController(
        catalogService: serviceWith((name, data) async {
          call += 1;
          if (call == 1) {
            return {
              'items': [productFixture(productId: 'p1')],
              'nextCursor': null,
            };
          }
          throw FirebaseFunctionsException(code: 'internal', message: 'boom');
        }),
      );
      await controller.load();
      expect(controller.products, isNotEmpty);

      await controller.load();
      expect(controller.status, DiscoveryStatus.failed);
      expect(
        controller.products,
        isEmpty,
        reason: 'previously loaded products must not linger as if current',
      );
      expect(controller.failure, MarketplaceCatalogFailureKind.unavailableRetry);
    });

    test('17. a malformed payload fails closed, never partially rendered', () async {
      for (final payload in <Object?>[
        null,
        'nope',
        <String, dynamic>{},
        {'items': 'not-a-list', 'nextCursor': null},
        {'items': <dynamic>[], /* nextCursor missing */},
        {
          'items': [
            {'businessId': 'b'},
          ],
          'nextCursor': null,
        },
      ]) {
        final controller = MarketplaceDiscoveryController(
          catalogService: serviceWith((name, data) async => payload),
        );
        await controller.load();
        expect(controller.status, DiscoveryStatus.failed, reason: '$payload');
        expect(controller.products, isEmpty);
      }
    });

    test('every transport failure kind fails closed', () async {
      for (final code in [
        'not-found',
        'internal',
        'permission-denied',
        'unauthenticated',
        'failed-precondition',
        'resource-exhausted',
      ]) {
        final controller = MarketplaceDiscoveryController(
          catalogService: serviceWith(
            (name, data) async =>
                throw FirebaseFunctionsException(code: code, message: 'x'),
          ),
        );
        await controller.load();
        expect(controller.status, DiscoveryStatus.failed, reason: code);
        expect(controller.products, isEmpty);
      }
    });
  });

  // ===================================================================
  // 11-16 — batch hydration: stored ids are never proof of visibility
  // ===================================================================

  group('batch hydration', () {
    test('16. only eligible requested products come back hydrated', () async {
      final service = serviceWith((name, data) async {
        expect(name, 'getMarketplaceProductBatch');
        return {
          'results': [
            {
              'businessId': 'biz-1',
              'productId': 'ok',
              'available': true,
              'product': productFixture(productId: 'ok'),
            },
            {
              'businessId': 'biz-1',
              'productId': 'gone',
              'available': false,
              'product': null,
            },
          ],
        };
      });
      final out = await service.fetchProductBatch(
        refs: const [
          PublicProductRef('biz-1', 'ok'),
          PublicProductRef('biz-1', 'gone'),
        ],
      );
      expect(out[publicProductKey('biz-1', 'ok')], isNotNull);
      expect(out[publicProductKey('biz-1', 'gone')], isNull);
    });

    test(
      '12/13/14. a stored favourite, recent item or cart row cannot resurrect '
      'an ineligible product',
      () async {
        // The server simply omits it from the response entirely.
        final service = serviceWith(
          (name, data) async => {'results': const []},
        );
        final out = await service.fetchProductBatch(
          refs: const [PublicProductRef('biz-1', 'unpublished-since')],
        );
        expect(out.length, 1, reason: 'the request is still accounted for');
        expect(
          out[publicProductKey('biz-1', 'unpublished-since')],
          isNull,
          reason: 'an omitted product is unavailable, never resurrected',
        );
      },
    );

    test('15. an unavailable result evicts rather than keeps prior data', () async {
      // Two calls for the same product: available, then not.
      var call = 0;
      final service = serviceWith((name, data) async {
        call += 1;
        return {
          'results': [
            {
              'businessId': 'biz-1',
              'productId': 'p1',
              'available': call == 1,
              'product': call == 1 ? productFixture(productId: 'p1') : null,
            },
          ],
        };
      });
      const refs = [PublicProductRef('biz-1', 'p1')];
      expect((await service.fetchProductBatch(refs: refs)).values.single, isNotNull);
      expect(
        (await service.fetchProductBatch(refs: refs)).values.single,
        isNull,
        reason: 'the second answer is authoritative; there is no cache to fall back on',
      );
    });

    test('18. duplicate refs are deduplicated into one request slot', () async {
      List<dynamic>? sent;
      final service = serviceWith((name, data) async {
        sent = data['products'] as List<dynamic>;
        return {
          'results': [
            {
              'businessId': 'biz-1',
              'productId': 'p1',
              'available': true,
              'product': productFixture(productId: 'p1'),
            },
          ],
        };
      });
      await service.fetchProductBatch(
        refs: const [
          PublicProductRef('biz-1', 'p1'),
          PublicProductRef('biz-1', 'p1'),
          PublicProductRef('biz-1', 'p1'),
        ],
      );
      expect(sent!.length, 1);
    });

    test('a result never requested is ignored, not rendered', () async {
      final service = serviceWith(
        (name, data) async => {
          'results': [
            {
              'businessId': 'biz-9',
              'productId': 'smuggled',
              'available': true,
              'product': productFixture(businessId: 'biz-9', productId: 'smuggled'),
            },
          ],
        },
      );
      final out = await service.fetchProductBatch(
        refs: const [PublicProductRef('biz-1', 'p1')],
      );
      expect(out.containsKey(publicProductKey('biz-9', 'smuggled')), isFalse);
      expect(out[publicProductKey('biz-1', 'p1')], isNull);
    });

    test('17. a malformed batch payload fails closed', () async {
      for (final payload in <Object?>[
        null,
        'nope',
        <String, dynamic>{},
        {'results': 'x'},
        {
          'results': [
            {'businessId': 1, 'productId': 'p'},
          ],
        },
      ]) {
        final service = serviceWith((name, data) async => payload);
        await expectLater(
          service.fetchProductBatch(
            refs: const [PublicProductRef('biz-1', 'p1')],
          ),
          throwsA(isA<MarketplaceCatalogException>()),
          reason: '$payload',
        );
      }
    });

    test('an oversized batch is refused client-side before the call', () async {
      var called = false;
      final service = serviceWith((name, data) async {
        called = true;
        return {'results': const []};
      });
      final refs = List.generate(
        maxBatchProducts + 1,
        (i) => PublicProductRef('biz-1', 'p$i'),
      );
      await expectLater(
        service.fetchProductBatch(refs: refs),
        throwsA(isA<MarketplaceCatalogException>()),
      );
      expect(called, isFalse);
    });

    test('empty and malformed refs are dropped without a call', () async {
      var called = false;
      final service = serviceWith((name, data) async {
        called = true;
        return {'results': const []};
      });
      final out = await service.fetchProductBatch(
        refs: const [
          PublicProductRef('', 'p1'),
          PublicProductRef('biz-1', ''),
        ],
      );
      expect(out, isEmpty);
      expect(called, isFalse);
    });
  });

  // ===================================================================
  // 11 — a raw id from any origin is not proof of visibility
  // ===================================================================

  test('11. a deep-link style raw product id is refused when the server says no', () async {
    final service = serviceWith(
      (name, data) async =>
          throw FirebaseFunctionsException(code: 'not-found', message: 'x'),
    );
    await expectLater(
      service.fetchProductDetail(businessId: 'biz-1', productId: 'guessed'),
      throwsA(
        predicate(
          (e) =>
              e is MarketplaceCatalogException &&
              e.kind == MarketplaceCatalogFailureKind.notFound,
        ),
      ),
    );
  });

  // ===================================================================
  // The adapter never invents a publication decision
  // ===================================================================

  test('the adapter marks products available only because the server returned them', () async {
    final service = serviceWith(
      (name, data) async => {'item': productFixture(productId: 'p1')},
    );
    final detail = await service.fetchProductDetail(
      businessId: 'biz-1',
      productId: 'p1',
    );
    final product = detail.toProduct();
    // Identity is preserved exactly — the canonical productId, not a
    // Firestore document id.
    expect(product.id, 'p1');
    expect(product.businessId, 'biz-1');
    // These are pinned, not copied from any client-visible field.
    expect(product.isActive, isTrue);
    expect(product.moderationStatus, 'approved');
    expect(product.customerPrice, closeTo(110.0, 0.001));
  });
}
