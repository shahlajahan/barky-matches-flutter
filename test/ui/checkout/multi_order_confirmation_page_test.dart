import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/home_gate.dart';
import 'package:barky_matches_fixed/ui/checkout/multi_order_confirmation_page.dart';
import 'package:barky_matches_fixed/ui/orders/order_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows every real seller name after a multi-seller payment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiOrderConfirmationPage(
          sellerOrderIds: const ['seller-order-a', 'seller-order-b'],
          sellerNames: const ['Happy Paws', 'Pet Market'],
        ),
      ),
    );

    expect(
      find.byKey(const Key('seller-order-seller-order-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('seller-order-seller-order-b')),
      findsOneWidget,
    );
    expect(find.text('seller-order-a'), findsOneWidget);
    expect(find.text('seller-order-b'), findsOneWidget);
    expect(find.text('Happy Paws'), findsOneWidget);
    expect(find.text('Pet Market'), findsOneWidget);
    expect(find.text('Seller order 1'), findsNothing);
    expect(find.byKey(const Key('multi-order-exit')), findsOneWidget);
  });

  testWidgets('view order opens the existing OrderDetailPage', (tester) async {
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiOrderConfirmationPage(
          sellerOrderIds: const ['seller-order-a', 'seller-order-b'],
          sellerNames: const ['Happy Paws', 'Pet Market'],
        ),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('seller-order-seller-order-a')),
        matching: find.text('View order'),
      ),
    );

    final route = observer.pushedRoutes.last as MaterialPageRoute<void>;
    final destination = route.builder(
      tester.element(find.byType(MultiOrderConfirmationPage)),
    );
    expect(destination, isA<OrderDetailPage>());
    expect((destination as OrderDetailPage).sellerOrderId, 'seller-order-a');
  });

  testWidgets('back to home resets navigation to HomeGate', (tester) async {
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiOrderConfirmationPage(
          sellerOrderIds: const ['seller-order-a', 'seller-order-b'],
          sellerNames: const ['Happy Paws', 'Pet Market'],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('multi-order-exit')));

    expect(tester.takeException(), isNull);
    final route = observer.pushedRoutes.last as MaterialPageRoute<void>;
    final destination = route.builder(
      tester.element(find.byType(MultiOrderConfirmationPage)),
    );
    expect(destination, isA<HomeGate>());
    expect(route.settings.name, isNot('/home'));
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}
