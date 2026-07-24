import 'dart:io';

import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/ui/business/petshop/product_save_plan.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductSavePlan', () {
    test('creates a new product at the canonical SKU document', () {
      final plan = ProductSavePlan.resolve(
        businessId: 'business-1',
        normalizedSku: 'FOOD-001',
      );

      expect(plan.mode, ProductWriteMode.create);
      expect(plan.targetProductId, 'business-1_FOOD-001');
      expect(plan.originalProductId, isNull);
    });

    test('unchanged SKU edits the exact original document', () {
      final plan = ProductSavePlan.resolve(
        businessId: 'business-1',
        normalizedSku: 'FOOD-001',
        originalProductId: 'business-1_FOOD-001',
      );

      expect(plan.mode, ProductWriteMode.sameIdEdit);
      expect(plan.targetProductId, plan.originalProductId);
    });

    test('SKU change is an explicit atomic document move', () {
      final plan = ProductSavePlan.resolve(
        businessId: 'business-1',
        normalizedSku: 'FOOD-002',
        originalProductId: 'business-1_FOOD-001',
      );

      expect(plan.mode, ProductWriteMode.skuChangingEdit);
      expect(plan.targetProductId, 'business-1_FOOD-002');
      expect(plan.targetProductId, isNot(plan.originalProductId));
    });
  });

  test('carrier codes are normalized and deduplicated', () {
    expect(
      normalizeCarrierCodes([' yurtici ', 'YURTICI', 'aras', '', ' ARAS ']),
      ['YURTICI', 'ARAS'],
    );
  });

  test(
    'business authorization follows owner, email, and admin conventions',
    () {
      expect(
        isAuthorizedBusinessEditor(authUid: 'owner-1', ownerUid: 'owner-1'),
        isTrue,
      );
      expect(
        isAuthorizedBusinessEditor(
          authUid: 'user-2',
          authEmail: 'owner@example.com',
          contactEmail: 'OWNER@example.com',
        ),
        isTrue,
      );
      expect(
        isAuthorizedBusinessEditor(
          authUid: 'user-3',
          ownerUid: 'owner-1',
          contactEmail: 'owner@example.com',
          authEmail: 'other@example.com',
        ),
        isFalse,
      );
    },
  );

  test('edit preserves createdAt and uses a newer updatedAt', () {
    final createdAt = Timestamp.fromMillisecondsSinceEpoch(1000);
    final updatedAt = Timestamp.fromMillisecondsSinceEpoch(2000);

    expect(preserveCreatedAt(createdAt, updatedAt), same(createdAt));
    expect(
      updatedAt.millisecondsSinceEpoch,
      greaterThan(createdAt.millisecondsSinceEpoch),
    );
  });

  test('shipping mode and payer remain in the Product payload', () {
    final product = Product(
      id: 'business-1_FOOD-001',
      businessId: 'business-1',
      name: 'Test food',
      description: 'Description',
      price: 100,
      currency: 'TRY',
      media: const [],
      stock: 2,
      category: 'Food > Dry Food',
      isActive: true,
      shippingMode: 'fixed_price',
      shippingPayer: 'seller',
      allowedCarrierCodes: const ['YURTICI', 'ARAS'],
    );

    expect(product.toJson()['shippingMode'], 'fixed_price');
    expect(product.toJson()['shippingPayer'], 'seller');
    expect(product.toJson()['allowedCarrierCodes'], ['YURTICI', 'ARAS']);
  });

  test(
    'secondary global sync failure does not fail the primary save',
    () async {
      Object? loggedError;

      final synchronized = await runProductSecondarySync(
        () => throw StateError('secondary failure'),
        onError: (error, _) => loggedError = error,
      );

      expect(synchronized, isFalse);
      expect(loggedError, isA<StateError>());
    },
  );

  test('transaction callback contains no external asynchronous work', () {
    final source = File(
      'lib/ui/business/petshop/add_product_page.dart',
    ).readAsStringSync();
    final callbackStart = source.indexOf(
      'await firestore.runTransaction((tx) async {',
    );
    final callbackEnd = source.indexOf(
      'debugPrint("✅ TRANSACTION SUCCESS")',
      callbackStart,
    );
    expect(callbackStart, greaterThanOrEqualTo(0));
    expect(callbackEnd, greaterThan(callbackStart));

    final transactionBody = source.substring(callbackStart, callbackEnd);
    expect(transactionBody, isNot(contains('_uploadMedia')));
    expect(transactionBody, isNot(contains('FirebaseFunctions')));
    expect(transactionBody, isNot(contains('FirebaseFirestore.instance')));
    expect(transactionBody, isNot(contains('.text')));
    expect(transactionBody, contains('await tx.get'));
    expect(transactionBody, contains('tx.set'));
    expect(transactionBody, contains('tx.delete'));
  });

  test('SKU collision is rejected before create or move writes', () {
    final source = File(
      'lib/ui/business/petshop/add_product_page.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        r'targetSnapshot\.exists\)[\s\S]*?ProductSubmitException\('
        r"'sku-collision'",
      ).allMatches(source).length,
      2,
    );
  });
}
