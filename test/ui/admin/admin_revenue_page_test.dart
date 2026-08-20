import 'package:barky_matches_fixed/ui/admin/pages/admin_revenue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  Map<String, dynamic> revenueData({
    Map<String, dynamic>? byCurrency,
    List<Map<String, Object?>> incompleteSources = const [],
  }) {
    return {
      'schemaVersion': 2,
      'calculatedAt': DateTime.now().toIso8601String(),
      'timezone': 'Europe/Istanbul',
      'financial': {
        'byCurrency':
            byCurrency ??
            {
              'TRY': {
                'currency': 'TRY',
                'grossMinor': 2000,
                'refundMinor': 0,
                'netMinor': 2000,
                'monthlyNetMinor': 2000,
                'pendingMinor': 19900,
                'arppuMinor': 1000,
              },
            },
      },
      'payments': {'successfulCount': 2, 'pendingCount': 1, 'failedCount': 1},
      'customers': {'payingCount': 2},
      'entitlements': {
        'premiumActive': 1,
        'goldActive': 8,
        'paidActive': 2,
        'unverifiedPaidPlanActive': 2,
        'freeActive': 2,
        'adminGrantActive': 5,
        'expiringSoon': 1,
      },
      'businesses': {'approvedCount': 2, 'paidSubscriptionCount': 0},
      'coverage': {
        'includedSources': ['orders:web_subscription'],
        'incompleteSources': incompleteSources,
      },
    };
  }

  testWidgets('renders TRY without hardcoded dollar symbol', (tester) async {
    await tester.pumpWidget(app(AdminRevenueView(data: revenueData())));

    expect(find.text('TRY 20.00'), findsNWidgets(3));
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('Gross Revenue'), findsOneWidget);
    expect(find.text('ARPPU'), findsOneWidget);
  });

  testWidgets('renders multiple currencies separately', (tester) async {
    await tester.pumpWidget(
      app(
        AdminRevenueView(
          data: revenueData(
            byCurrency: {
              'TRY': {
                'currency': 'TRY',
                'grossMinor': 2000,
                'refundMinor': 0,
                'netMinor': 2000,
                'monthlyNetMinor': 2000,
                'pendingMinor': 0,
                'arppuMinor': 1000,
              },
              'USD': {
                'currency': 'USD',
                'grossMinor': 0,
                'refundMinor': 0,
                'netMinor': 0,
                'monthlyNetMinor': 0,
                'pendingMinor': 0,
                'arppuMinor': 0,
              },
            },
          ),
        ),
      ),
    );

    expect(find.text('TRY'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('USD 0.00'), findsNWidgets(6));
  });

  testWidgets('renders error state without zero substitution', (tester) async {
    await tester.pumpWidget(
      app(const AdminRevenueView(error: 'permission-denied')),
    );

    expect(find.text('Revenue data is unavailable'), findsOneWidget);
    expect(
      find.textContaining('No values were replaced with zero'),
      findsOneWidget,
    );
  });

  testWidgets('renders loading state', (tester) async {
    await tester.pumpWidget(app(const AdminRevenueView(isLoading: true)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders incomplete coverage warning', (tester) async {
    await tester.pumpWidget(
      app(
        AdminRevenueView(
          data: revenueData(
            incompleteSources: const [
              {
                'source': 'mobile_store_subscriptions',
                'reason': 'authoritative_revenue_unavailable',
                'count': 2,
              },
            ],
          ),
        ),
      ),
    );

    expect(
      find.textContaining('Some source groups are unavailable'),
      findsOneWidget,
    );
    expect(find.textContaining('mobile_store_subscriptions'), findsOneWidget);
  });

  testWidgets('distinguishes zero revenue from unavailable v2 data', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        AdminRevenueView(
          data: revenueData(
            byCurrency: {
              'TRY': {
                'currency': 'TRY',
                'grossMinor': 0,
                'refundMinor': 0,
                'netMinor': 0,
                'monthlyNetMinor': 0,
                'pendingMinor': 0,
                'arppuMinor': 0,
              },
            },
          ),
        ),
      ),
    );

    expect(find.text('TRY 0.00'), findsNWidgets(6));

    await tester.pumpWidget(app(const AdminRevenueView()));
    expect(find.text('Revenue v2 has not been calculated'), findsOneWidget);
  });

  testWidgets('uses clear business labels', (tester) async {
    await tester.pumpWidget(app(AdminRevenueView(data: revenueData())));

    expect(find.text('Approved Businesses'), findsOneWidget);
    expect(find.text('Paid Business Subscriptions'), findsOneWidget);
    expect(find.text('Unverified Paid-Plan Entitlements'), findsOneWidget);
    expect(find.text('Business Subs'), findsNothing);
  });

  testWidgets('desktop layout remains responsive', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(AdminRevenueView(data: revenueData())));

    expect(find.text('Financial Overview'), findsOneWidget);
    expect(find.text('Subscription & Business Overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
