import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
import 'package:barky_matches_fixed/ui/checkout/checkout_order_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single seller checkout remains one ordered group', () {
    final groups = groupCheckoutItemsBySeller([
      _item('product-1', 'shop-1', 'Seller One', 10, 2),
      _item('product-2', 'shop-1', 'Seller One', 5, 1),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.shopId, 'shop-1');
    expect(groups.single.sellerName, 'Seller One');
    expect(groups.single.items.map((item) => item.productId), [
      'product-1',
      'product-2',
    ]);
    expect(groups.single.productsTotal, 25);
  });

  test('multi seller checkout preserves seller and item order', () {
    final groups = groupCheckoutItemsBySeller([
      _item('a-1', 'shop-a', 'Seller A', 10, 1),
      _item('b-1', 'shop-b', 'Seller B', 20, 1),
      _item('a-2', 'shop-a', 'Seller A', 5, 2),
    ]);

    expect(groups.map((group) => group.shopId), ['shop-a', 'shop-b']);
    expect(groups.first.items.map((item) => item.productId), ['a-1', 'a-2']);
    expect(groups.first.productsTotal, 20);
    expect(groups.last.productsTotal, 20);
  });

  test('aggregates independent seller shipping into checkout totals', () {
    final totals = CheckoutPricingTotals.fromSellerPricing(const [
      SellerCheckoutPricing(
        productsTotal: 20,
        shippingTotal: 4,
        taxTotal: 2,
        grandTotal: 26,
      ),
      SellerCheckoutPricing(
        productsTotal: 15,
        shippingTotal: 7,
        taxTotal: 1.5,
        grandTotal: 23.5,
      ),
    ]);

    expect(totals.productsTotal, 35);
    expect(totals.shippingTotal, 11);
    expect(totals.grandTotal, 49.5);
  });

  testWidgets('grouped checkout renders all products and seller totals', (
    tester,
  ) async {
    final items = [
      _item(
        'a-1',
        'shop-a',
        'Seller A',
        10,
        2,
        carriers: const ['YURTICI', 'ARAS'],
        maxDeliveryDays: 3,
      ),
      _item('b-1', 'shop-b', 'Seller B', 7.5, 2, carriers: const ['ARAS']),
    ];
    final groups = groupCheckoutItemsBySeller(items);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CheckoutOrderSummary(
              groups: groups,
              selectedCarriers: const {'shop-a': 'YURTICI', 'shop-b': 'ARAS'},
              pricingByShop: const {
                'shop-a': SellerCheckoutPricing(
                  productsTotal: 20,
                  shippingTotal: 4,
                  taxTotal: 0,
                  grandTotal: 24,
                ),
                'shop-b': SellerCheckoutPricing(
                  productsTotal: 15,
                  shippingTotal: 7,
                  taxTotal: 0,
                  grandTotal: 22,
                ),
              },
              pricingLoading: false,
              onCarrierChanged: (shopId, carrier) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('checkout-seller-order-sections')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('checkout-seller-shop-a')), findsOneWidget);
    expect(find.byKey(const Key('checkout-seller-shop-b')), findsOneWidget);
    expect(find.byKey(const Key('seller-carrier-shop-a')), findsOneWidget);
    expect(find.byKey(const Key('seller-carrier-shop-b')), findsOneWidget);
    expect(find.text('a-1'), findsOneWidget);
    expect(find.text('b-1'), findsOneWidget);
    expect(find.text('20.00 ₺'), findsWidgets);
    expect(find.text('15.00 ₺'), findsWidgets);
    expect(find.text('4.00 ₺'), findsOneWidget);
    expect(find.text('7.00 ₺'), findsOneWidget);
    expect(find.text('24.00 ₺'), findsOneWidget);
    expect(find.text('22.00 ₺'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
  });

  testWidgets('multi-seller payment information is localized and visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: MultiSellerCheckoutInfoCard()),
      ),
    );

    expect(find.byKey(const Key('multi-seller-checkout-info')), findsOneWidget);
    expect(find.text('One payment, separate orders'), findsOneWidget);
  });
}

CartItem _item(
  String productId,
  String shopId,
  String sellerName,
  double price,
  int quantity, {
  List<String> carriers = const [],
  int? maxDeliveryDays,
}) {
  return CartItem(
    productId: productId,
    shopId: shopId,
    name: productId,
    price: price,
    quantity: quantity,
    product: Product.fromJson(productId, {
      'businessId': shopId,
      'businessName': sellerName,
      'name': productId,
      'price': price,
      'allowedCarrierCodes': carriers,
      'maxDeliveryDays': maxDeliveryDays,
    }),
  );
}
