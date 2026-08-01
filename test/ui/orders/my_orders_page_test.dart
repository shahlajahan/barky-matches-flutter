import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/orders/buyer_order_list_item.dart';
import 'package:barky_matches_fixed/ui/orders/buyer_orders_repository.dart';
import 'package:barky_matches_fixed/ui/orders/my_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('multi-seller entries stay unique after pull-to-refresh', (
    tester,
  ) async {
    final dataSource = _FakeBuyerOrdersDataSource([
      _order(
        id: 'seller-a',
        product: 'Dentastik',
        seller: 'Koray pet',
        additionalItems: 0,
      ),
      _order(
        id: 'seller-b',
        product: 'Pembe',
        seller: 'Pet Market',
        additionalItems: 0,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MyOrdersPage(repository: dataSource, buyerUid: 'buyer-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('buyer-order-seller-a')), findsOneWidget);
    expect(find.byKey(const Key('buyer-order-seller-b')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('buyer-orders-list')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();

    expect(dataSource.watchCount, 2);
    expect(find.byKey(const Key('buyer-order-seller-a')), findsOneWidget);
    expect(find.byKey(const Key('buyer-order-seller-b')), findsOneWidget);
  });

  testWidgets('single-item card shows product and real seller names', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _order(product: 'Dentastik', seller: 'Koray pet', additionalItems: 0),
    );

    expect(find.text('Dentastik'), findsOneWidget);
    expect(find.text('Koray pet'), findsOneWidget);
    expect(find.text('1 item'), findsNothing);
  });

  testWidgets('multi-item card shows primary product plus additional count', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _order(product: 'Dentastik', seller: 'Koray pet', additionalItems: 2),
    );

    expect(find.text('Dentastik + 2 more'), findsOneWidget);
  });

  testWidgets('missing optional fields render localized fallbacks', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      BuyerOrderListItem(
        sellerOrderId: 'sparse',
        canOpenDetail: true,
        rootOrderId: null,
        orderNumber: null,
        sellerName: null,
        primaryProductName: null,
        additionalItemCount: 0,
        productImageUrl: null,
        createdAt: null,
        total: 0,
        currency: 'TRY',
        status: 'pending',
        carrier: null,
        trackingNumber: null,
      ),
    );

    expect(find.text('Product'), findsOneWidget);
    expect(find.text('Seller'), findsOneWidget);
    expect(find.text('Date unavailable'), findsOneWidget);
  });
}

Future<void> _pumpCard(WidgetTester tester, BuyerOrderListItem order) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: BuyerOrderCard(order: order, onTap: () {}),
        ),
      ),
    ),
  );
}

BuyerOrderListItem _order({
  String id = 'seller-order',
  required String product,
  required String seller,
  required int additionalItems,
}) {
  return BuyerOrderListItem(
    sellerOrderId: id,
    canOpenDetail: true,
    rootOrderId: 'root-order',
    orderNumber: 'SO-100',
    sellerName: seller,
    primaryProductName: product,
    additionalItemCount: additionalItems,
    productImageUrl: null,
    createdAt: DateTime(2026, 7, 29),
    total: 10.1,
    currency: 'TRY',
    status: 'paid',
    carrier: 'PTT',
    trackingNumber: 'TRACK-1',
  );
}

class _FakeBuyerOrdersDataSource implements BuyerOrdersDataSource {
  _FakeBuyerOrdersDataSource(this.orders);

  final List<BuyerOrderListItem> orders;
  int watchCount = 0;

  @override
  Stream<List<BuyerOrderListItem>> watchBuyerOrders(String buyerUid) {
    watchCount++;
    return Stream.value(orders);
  }
}
