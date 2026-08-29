import 'dart:io';

import 'package:barky_matches_fixed/services/product_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

// Marketplace P1-A Slice 4.10 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §0.17 Phase 10, committed
// Revision 19): ProductService.deleteMarketplaceProduct coverage against
// a fake callable — no prior test file exists for product_service.dart
// (confirmed by direct search of test/). See marketplace_catalog_
// service_test.dart's own top-of-file comment for why a fake callable is
// a plain injected function rather than a mock of the real
// FirebaseFunctions/HttpsCallable SDK types (both have library-private
// constructors). §15 items 487-524 (proof types applicable to Flutter
// service-layer coverage: fake/mock callable tests).

void main() {
  group('deleteMarketplaceProduct', () {
    test('calls the exact callable name and request map', () async {
      String? calledName;
      Map<String, dynamic>? calledData;
      final service = ProductService(
        callableInvoker: (name, data) async {
          calledName = name;
          calledData = data;
          return {'status': 'deleted', 'productId': 'p-1'};
        },
      );

      await service.deleteMarketplaceProduct(
        businessId: 'business-1',
        productId: 'p-1',
        clientIdempotencyKey: 'key-1',
      );

      expect(calledName, 'deleteMarketplaceProduct');
      expect(calledData, {
        'businessId': 'business-1',
        'productId': 'p-1',
        'clientIdempotencyKey': 'key-1',
      });
    });

    test(
      'a {status: "deleted", productId} response parses as ProductDeletionOutcome.deleted',
      () async {
        final service = ProductService(
          callableInvoker: (name, data) async {
            return {'status': 'deleted', 'productId': 'p-1'};
          },
        );

        final result = await service.deleteMarketplaceProduct(
          businessId: 'b',
          productId: 'p-1',
          clientIdempotencyKey: 'k',
        );

        expect(result.outcome, ProductDeletionOutcome.deleted);
        expect(result.productId, 'p-1');
      },
    );

    test(
      'a {status: "replayed", productId} response parses as ProductDeletionOutcome.replayed',
      () async {
        final service = ProductService(
          callableInvoker: (name, data) async {
            return {'status': 'replayed', 'productId': 'p-1'};
          },
        );

        final result = await service.deleteMarketplaceProduct(
          businessId: 'b',
          productId: 'p-1',
          clientIdempotencyKey: 'k',
        );

        expect(result.outcome, ProductDeletionOutcome.replayed);
      },
    );

    test(
      'a response missing "status" is a parse failure (unavailableRetry), never a silent success',
      () async {
        final service = ProductService(
          callableInvoker: (name, data) async {
            return {'productId': 'p-1'};
          },
        );

        await expectLater(
          service.deleteMarketplaceProduct(
            businessId: 'b',
            productId: 'p-1',
            clientIdempotencyKey: 'k',
          ),
          throwsA(
            isA<ProductDeletionException>().having(
              (e) => e.kind,
              'kind',
              ProductDeletionFailureKind.unavailableRetry,
            ),
          ),
        );
      },
    );

    test('a response missing "productId" is a parse failure', () async {
      final service = ProductService(
        callableInvoker: (name, data) async {
          return {'status': 'deleted'};
        },
      );

      await expectLater(
        service.deleteMarketplaceProduct(
          businessId: 'b',
          productId: 'p-1',
          clientIdempotencyKey: 'k',
        ),
        throwsA(isA<ProductDeletionException>()),
      );
    });

    test(
      'an unrecognized "status" value is a parse failure, never silently treated as success',
      () async {
        final service = ProductService(
          callableInvoker: (name, data) async {
            return {'status': 'something-else', 'productId': 'p-1'};
          },
        );

        await expectLater(
          service.deleteMarketplaceProduct(
            businessId: 'b',
            productId: 'p-1',
            clientIdempotencyKey: 'k',
          ),
          throwsA(isA<ProductDeletionException>()),
        );
      },
    );

    test(
      'a non-map response is a parse failure, never an uncaught type error',
      () async {
        final service = ProductService(
          callableInvoker: (name, data) async => 'unexpected-string',
        );

        await expectLater(
          service.deleteMarketplaceProduct(
            businessId: 'b',
            productId: 'p-1',
            clientIdempotencyKey: 'k',
          ),
          throwsA(isA<ProductDeletionException>()),
        );
      },
    );

    final reasonCodeCases = <String, ProductDeletionFailureKind>{
      'unauthenticated': ProductDeletionFailureKind.unauthenticated,
      'invalid_request': ProductDeletionFailureKind.invalidRequest,
      'business_not_found': ProductDeletionFailureKind.businessNotFound,
      'product_not_found': ProductDeletionFailureKind.productNotFound,
      'not_business_owner': ProductDeletionFailureKind.notBusinessOwner,
      'business_id_mismatch': ProductDeletionFailureKind.businessIdMismatch,
      'idempotency_key_conflict':
          ProductDeletionFailureKind.idempotencyKeyConflict,
      'malformed_decision_state':
          ProductDeletionFailureKind.malformedDecisionState,
      'internal_error': ProductDeletionFailureKind.internalError,
    };

    for (final entry in reasonCodeCases.entries) {
      test(
        'maps FirebaseFunctionsException details.reasonCode "${entry.key}" to ${entry.value}',
        () async {
          final service = ProductService(
            callableInvoker: (name, data) async {
              throw FirebaseFunctionsException(
                code: 'internal',
                message: 'boom',
                details: {'reasonCode': entry.key},
              );
            },
          );

          await expectLater(
            service.deleteMarketplaceProduct(
              businessId: 'b',
              productId: 'p-1',
              clientIdempotencyKey: 'k',
            ),
            throwsA(
              isA<ProductDeletionException>().having(
                (e) => e.kind,
                'kind',
                entry.value,
              ),
            ),
          );
        },
      );
    }

    test(
      'falls back to mapping by HttpsError code alone when details.reasonCode is absent',
      () async {
        final service = ProductService(
          callableInvoker: (name, data) async {
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'nope',
            );
          },
        );

        await expectLater(
          service.deleteMarketplaceProduct(
            businessId: 'b',
            productId: 'p-1',
            clientIdempotencyKey: 'k',
          ),
          throwsA(
            isA<ProductDeletionException>().having(
              (e) => e.kind,
              'kind',
              ProductDeletionFailureKind.notBusinessOwner,
            ),
          ),
        );
      },
    );

    test('an unrecognized code with no reasonCode maps to generic', () async {
      final service = ProductService(
        callableInvoker: (name, data) async {
          throw FirebaseFunctionsException(code: 'cancelled', message: 'nope');
        },
      );

      await expectLater(
        service.deleteMarketplaceProduct(
          businessId: 'b',
          productId: 'p-1',
          clientIdempotencyKey: 'k',
        ),
        throwsA(
          isA<ProductDeletionException>().having(
            (e) => e.kind,
            'kind',
            ProductDeletionFailureKind.generic,
          ),
        ),
      );
    });
  });

  group('generateProductDeletionIdempotencyKey', () {
    test(
      'returns a non-empty string, ≤128 characters (matching the server-side bound)',
      () {
        final key = generateProductDeletionIdempotencyKey();
        expect(key, isNotEmpty);
        expect(key.length, lessThanOrEqualTo(128));
      },
    );

    test('returns a distinct value on each call', () {
      final a = generateProductDeletionIdempotencyKey();
      final b = generateProductDeletionIdempotencyKey();
      expect(a, isNot(equals(b)));
    });
  });

  group('dormancy/security statics', () {
    final source = File('lib/services/product_service.dart').readAsStringSync();

    test(
      'no remaining direct, non-transactional .delete() call against a products/{productId} document',
      () {
        expect(source, isNot(contains('.delete()')));
      },
    );

    test('the retired deleteProduct method name no longer exists', () {
      expect(source, isNot(contains('Future<void> deleteProduct(')));
    });

    test('never logs raw exception content', () {
      expect(source, isNot(contains('print(')));
    });
  });
}
