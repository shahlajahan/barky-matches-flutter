import 'dart:io';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/ui/petshop/widgets/product_card_dashboard.dart';
import 'package:barky_matches_fixed/ui/petshop/widgets/product_card_shared.dart'
    show DeleteProductButton;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// Marketplace P1-A Slice 4.10 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §0.17 Phase 13, committed
// Revision 19) — proves ProductCardDashboard correctly wires the shared
// DeleteProductButton with the exact businessId/productId, replacing the
// retired direct-Firestore-delete call site. The full delete-flow
// behavior (confirmation, loading, success/error mapping,
// double-submit) is already covered once, exhaustively, against
// DeleteProductButton directly in product_card_shared_test.dart — not
// duplicated here. No prior test file exists for
// product_card_dashboard.dart (confirmed by direct search of test/).
// §15 items 518-520.

Product _buildProduct({
  String id = 'business-1_TEST',
  String businessId = 'business-1',
}) {
  return Product(
    id: id,
    businessId: businessId,
    name: 'Test Product',
    description: 'desc',
    price: 10,
    currency: 'TRY',
    media: const [],
    stock: 1,
    category: 'Health > Vitamins',
    isActive: false,
  );
}

Widget _testApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets(
    'renders exactly one DeleteProductButton, wired with the exact product/business IDs',
    (tester) async {
      final product = _buildProduct(
        id: 'business-1_SKU-1',
        businessId: 'business-1',
      );
      await tester.pumpWidget(
        _testApp(
          ProductCardDashboard(product: product, businessId: 'business-1'),
        ),
      );

      final finder = find.byType(DeleteProductButton);
      expect(finder, findsOneWidget);
      final widget = tester.widget<DeleteProductButton>(finder);
      expect(widget.businessId, 'business-1');
      expect(widget.productId, 'business-1_SKU-1');
    },
  );

  testWidgets('a different product/business pair is wired through unchanged', (
    tester,
  ) async {
    final product = _buildProduct(
      id: 'business-2_SKU-9',
      businessId: 'business-2',
    );
    await tester.pumpWidget(
      _testApp(
        ProductCardDashboard(product: product, businessId: 'business-2'),
      ),
    );

    final widget = tester.widget<DeleteProductButton>(
      find.byType(DeleteProductButton),
    );
    expect(widget.businessId, 'business-2');
    expect(widget.productId, 'business-2_SKU-9');
  });

  group('dormancy/security statics', () {
    final source = File(
      'lib/ui/petshop/widgets/product_card_dashboard.dart',
    ).readAsStringSync();

    test('no direct Firestore product delete call remains in this file', () {
      expect(source, isNot(contains('.deleteProduct(')));
      expect(source, contains('DeleteProductButton'));
    });

    test(
      'no local ProductService instance is constructed for deletion in this file',
      () {
        // DeleteProductButton owns its own ProductService construction —
        // this file no longer needs (and must not carry) its own.
        expect(source, isNot(contains('ProductService()')));
      },
    );
  });
}
