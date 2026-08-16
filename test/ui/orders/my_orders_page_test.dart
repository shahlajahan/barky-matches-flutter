import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/ui/orders/buyer_order_list_item.dart';
import 'package:barky_matches_fixed/ui/orders/buyer_orders_repository.dart';
import 'package:barky_matches_fixed/ui/orders/my_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

  testWidgets('root order focus highlights every seller order in that root', (
    tester,
  ) async {
    final dataSource = _FakeBuyerOrdersDataSource([
      _order(
        id: 'seller-a',
        rootOrderId: 'root-1',
        product: 'Dentastik',
        seller: 'Koray pet',
        additionalItems: 0,
      ),
      _order(
        id: 'seller-b',
        rootOrderId: 'root-1',
        product: 'Pembe',
        seller: 'Pet Market',
        additionalItems: 0,
      ),
      _order(
        id: 'seller-c',
        rootOrderId: 'root-2',
        product: 'Mama',
        seller: 'Other Pet',
        additionalItems: 0,
      ),
    ]);

    await _pumpMyOrders(
      tester,
      MyOrdersPage(
        repository: dataSource,
        buyerUid: 'buyer-1',
        focusRootOrderId: 'root-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<BuyerOrderCard>(find.byKey(const Key('buyer-order-seller-a')))
          .highlighted,
      isTrue,
    );
    expect(
      tester
          .widget<BuyerOrderCard>(find.byKey(const Key('buyer-order-seller-b')))
          .highlighted,
      isTrue,
    );
    expect(
      tester
          .widget<BuyerOrderCard>(find.byKey(const Key('buyer-order-seller-c')))
          .highlighted,
      isFalse,
    );
  });

  testWidgets('missing root order shows controlled unavailable fallback', (
    tester,
  ) async {
    final dataSource = _FakeBuyerOrdersDataSource([
      _order(
        id: 'seller-a',
        rootOrderId: 'root-1',
        product: 'Dentastik',
        seller: 'Koray pet',
        additionalItems: 0,
      ),
    ]);

    await _pumpMyOrders(
      tester,
      MyOrdersPage(
        repository: dataSource,
        buyerUid: 'buyer-1',
        focusRootOrderId: 'missing-root',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('buyer-order-focus-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Order not found or unavailable.'), findsOneWidget);
  });

  testWidgets('inaccessible root order stream error is handled safely', (
    tester,
  ) async {
    final dataSource = _ErrorBuyerOrdersDataSource(
      Exception('[cloud_firestore/permission-denied] denied'),
    );

    await _pumpMyOrders(
      tester,
      MyOrdersPage(
        repository: dataSource,
        buyerUid: 'buyer-1',
        focusRootOrderId: 'root-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('buyer-order-focus-unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('permission-denied'), findsNothing);
  });

  testWidgets('pending AppState root focus is consumed once', (tester) async {
    final appState = _appState();
    await appState.openOrderSmart(null, 'root-1');
    final dataSource = _FakeBuyerOrdersDataSource([
      _order(
        id: 'seller-a',
        rootOrderId: 'root-1',
        product: 'Dentastik',
        seller: 'Koray pet',
        additionalItems: 0,
      ),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MyOrdersPage(repository: dataSource, buyerUid: 'buyer-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(appState.pendingBuyerOrdersRootOrderId, isNull);
    expect(
      tester
          .widget<BuyerOrderCard>(find.byKey(const Key('buyer-order-seller-a')))
          .highlighted,
      isTrue,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MyOrdersPage(repository: dataSource, buyerUid: 'buyer-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(appState.pendingBuyerOrdersRootOrderId, isNull);
  });
}

Future<void> _pumpMyOrders(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
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
  String rootOrderId = 'root-order',
  required String product,
  required String seller,
  required int additionalItems,
}) {
  return BuyerOrderListItem(
    sellerOrderId: id,
    canOpenDetail: true,
    rootOrderId: rootOrderId,
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

class _ErrorBuyerOrdersDataSource implements BuyerOrdersDataSource {
  _ErrorBuyerOrdersDataSource(this.error);

  final Object error;

  @override
  Stream<List<BuyerOrderListItem>> watchBuyerOrders(String buyerUid) {
    return Stream.error(error);
  }
}

AppState _appState() {
  return AppState(
    favoriteDogs: const <Dog>[],
    favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
    likesNotifier: ValueNotifier<Map<String, List<String>>>(
      <String, List<String>>{},
    ),
    onToggleFavorite: (_) async {},
    notificationService: NotificationService(),
    currentUserId: 'buyer-1',
  );
}
