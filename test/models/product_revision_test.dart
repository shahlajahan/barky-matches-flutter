import 'dart:io';

import 'package:barky_matches_fixed/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

// Marketplace P1-A Slice 4.8 Phase A (docs/plans/marketplace_p1a_
// compliance_review_implementation_plan_2026-08-21.md §0.14/§0.15,
// §15 items 403-421): productInputRevision/sellerRelationship
// serialization coverage.
void main() {
  Product buildProduct({
    int productInputRevision = 0,
    String? sellerRelationship,
  }) {
    return Product(
      id: 'business-1_TEST',
      businessId: 'business-1',
      name: 'Test Product',
      description: 'desc',
      price: 10,
      currency: 'TRY',
      media: const [],
      stock: 1,
      category: 'Health > Vitamins',
      isActive: false,
      productInputRevision: productInputRevision,
      sellerRelationship: sellerRelationship,
    );
  }

  group('productInputRevision', () {
    test('defaults to exactly 0 (an int) when not supplied', () {
      final product = buildProduct();
      expect(product.productInputRevision, 0);
      expect(product.productInputRevision, isA<int>());
    });

    test('a legacy document missing the field parses as baseline 0', () {
      final json = <String, dynamic>{
        'businessId': 'business-1',
        'name': 'Legacy Product',
        'description': 'desc',
        'price': 10,
        'category': 'Food > Dry Food',
        'isActive': true,
      };

      final product = Product.fromJson('business-1_LEGACY', json);

      expect(product.productInputRevision, 0);
    });

    test('a stored int value round-trips through fromJson', () {
      final json = buildProduct(productInputRevision: 3).toJson();
      final parsed = Product.fromJson('business-1_TEST', json);

      expect(parsed.productInputRevision, 3);
    });

    test('a malformed stored value (non-int) parses as baseline 0', () {
      final json = <String, dynamic>{
        'businessId': 'business-1',
        'name': 'Malformed',
        'description': 'desc',
        'price': 10,
        'category': 'Food > Dry Food',
        'isActive': true,
        'productInputRevision': 'not-an-int',
      };

      final product = Product.fromJson('business-1_MALFORMED', json);

      expect(product.productInputRevision, 0);
    });

    test('toJson always emits the field, exactly as an int', () {
      final json = buildProduct(productInputRevision: 5).toJson();

      expect(json['productInputRevision'], 5);
      expect(json['productInputRevision'], isA<int>());
    });
  });

  group('sellerRelationship', () {
    test('defaults to null ("not yet declared") when not supplied', () {
      final product = buildProduct();
      expect(product.sellerRelationship, isNull);
    });

    test('a legacy document missing the field parses as null', () {
      final json = <String, dynamic>{
        'businessId': 'business-1',
        'name': 'Legacy Product',
        'description': 'desc',
        'price': 10,
        'category': 'Food > Dry Food',
        'isActive': true,
      };

      final product = Product.fromJson('business-1_LEGACY', json);

      expect(product.sellerRelationship, isNull);
    });

    test('each of the six enum values round-trips through fromJson', () {
      const values = [
        'brand_owner',
        'manufacturer',
        'authorized_distributor',
        'authorized_dealer',
        'importer',
        'reseller',
      ];

      for (final value in values) {
        final json = buildProduct(sellerRelationship: value).toJson();
        final parsed = Product.fromJson('business-1_TEST', json);
        expect(parsed.sellerRelationship, value);
      }
    });

    test('a malformed stored value (non-string) parses as null', () {
      final json = <String, dynamic>{
        'businessId': 'business-1',
        'name': 'Malformed',
        'description': 'desc',
        'price': 10,
        'category': 'Food > Dry Food',
        'isActive': true,
        'sellerRelationship': 42,
      };

      final product = Product.fromJson('business-1_MALFORMED', json);

      expect(product.sellerRelationship, isNull);
    });

    test('toJson always emits the field, exactly as the stored string', () {
      final json = buildProduct(sellerRelationship: 'manufacturer').toJson();

      expect(json['sellerRelationship'], 'manufacturer');
    });
  });

  group('no reserved compliance fields', () {
    // §0.14: the five Rules-reserved names are never Dart domain-model
    // fields, never populated by any current backend writer, and never a
    // source of compliance truth — Product must not expose them.
    const reservedNames = [
      'complianceEffectiveStatus',
      'complianceValidUntil',
      'evidenceRevision',
      'complianceUpdatedAt',
      'complianceReasonCode',
    ];

    test('toJson never emits any of the five reserved names', () {
      final json = buildProduct(sellerRelationship: 'reseller').toJson();

      for (final name in reservedNames) {
        expect(json.containsKey(name), isFalse, reason: name);
      }
    });

    test(
      'Product.dart source declares none of the five reserved names as a field',
      () {
        final source = File('lib/models/product.dart').readAsStringSync();

        for (final name in reservedNames) {
          expect(
            source.contains("final $name") ||
                source.contains('String? $name') ||
                source.contains('"$name"') ||
                source.contains("'$name'"),
            isFalse,
            reason: name,
          );
        }
      },
    );

    test('Product does not expose any productComplianceDecisions data', () {
      final source = File('lib/models/product.dart').readAsStringSync();

      expect(source, isNot(contains('productComplianceDecisions')));
      expect(source, isNot(contains('decisionHash')));
      expect(source, isNot(contains('effectiveStatus')));
      expect(source, isNot(contains('activeEvidenceRefs')));
    });
  });

  group('compatibility with existing Product behavior', () {
    test('a legacy document without either field loads without throwing', () {
      final json = <String, dynamic>{
        'businessId': 'business-1',
        'name': 'Legacy Product',
        'description': 'desc',
        'price': 10,
        'category': 'Food > Dry Food',
        'isActive': true,
        'moderationStatus': 'approved',
      };

      expect(
        () => Product.fromJson('business-1_LEGACY', json),
        returnsNormally,
      );
    });

    test('unrelated existing fields are unaffected', () {
      final product = buildProduct();

      expect(product.name, 'Test Product');
      expect(product.price, 10);
      expect(product.category, 'Health > Vitamins');
      expect(product.moderationStatus, 'pending_review');
    });
  });
}
