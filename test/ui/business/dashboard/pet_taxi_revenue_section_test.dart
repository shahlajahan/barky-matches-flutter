import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/business/finance/pet_taxi_revenue_section.dart';
import 'package:barky_matches_fixed/ui/business/finance/seller_finance_summary.dart';

void main() {
  final now = DateTime.now();
  final recentDate = now.subtract(const Duration(days: 1));
  final previousDate = now.subtract(const Duration(days: 2));
  final expectedRevenueMonths = {
    '${recentDate.year}-${recentDate.month}',
    '${previousDate.year}-${previousDate.month}',
  }.length;
  final summary = SellerFinanceSummary(
    businessId: 'business-1',
    currency: 'TRY',
    available: const SellerFinanceAmount(count: 1, amount: 1200),
    waiting: const SellerFinanceAmount(count: 2, amount: 800),
    batched: const SellerFinanceAmount(count: 0, amount: 0),
    paid: const SellerFinanceAmount(count: 1, amount: 500),
    blocked: const SellerFinanceAmount(count: 0, amount: 0),
    onHold: const SellerFinanceAmount(count: 0, amount: 0),
    paidThisMonth: 500,
    totalEarnings: 2500,
    nextEligibilityDate: DateTime(2026, 8, 10),
    daysRemaining: 9,
    amountBecomingEligibleNext: 800,
    countBecomingEligibleNext: 2,
    oldestWaitingPaymentAt: DateTime(2026, 8, 1),
    bankValidationStatus: 'valid',
    waitingSchedule: const [],
    lastPayout: null,
    eligibleRecords: const [],
    payoutHistory: const [
      {
        'amount': 500,
        'recordCount': 1,
        'reference': 'PAYOUT-1',
        'bankSuffix': '1234',
      },
    ],
    exceptions: const [],
    revenue: SellerRevenueSummary(
      grossSales: 3000,
      platformFee: 500,
      adjustments: 0,
      netRevenue: 2500,
      paidRecordCount: 3,
      averageTicket: 1000,
      trend: [
        SellerRevenueTrendPoint(
          date: recentDate,
          amount: 1000,
          count: 1,
          grossRevenue: 1000,
          platformFee: 100,
          netRevenue: 900,
          paymentCount: 1,
        ),
        SellerRevenueTrendPoint(
          date: previousDate,
          amount: 2000,
          count: 2,
          grossRevenue: 2000,
          platformFee: 200,
          netRevenue: 1800,
          paymentCount: 2,
        ),
      ],
    ),
  );

  Widget app(double width, {bool missing = false, double? viewportWidth}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: Size(viewportWidth ?? width, 900)),
          child: Scaffold(
            body: SizedBox(
              width: width,
              child: PetTaxiRevenueSection(
                businessId: 'business-1',
                recordLabel: 'rides',
                summaryStream: Stream<SellerFinanceSummary?>.value(
                  missing ? null : summary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('native mobile revenue is compact and contains no charts', (
    tester,
  ) async {
    if (kIsWeb) return;
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(390));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Available balance'), findsOneWidget);
    expect(find.text('Waiting balance'), findsOneWidget);
    expect(find.text('Upcoming Payout'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(find.byType(PieChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop revenue shows dashboard sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(1200));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pump();

    expect(find.text('Revenue trend'), findsOneWidget);
    expect(find.text('Revenue breakdown'), findsOneWidget);
    expect(find.text('Settlement timeline'), findsOneWidget);
    expect(find.text('Payout history'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Revenue Trend fills selected periods and preserves revenue days',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(1200));
      await tester.pump(const Duration(milliseconds: 100));

      BarChart chart() => tester.widget<BarChart>(find.byType(BarChart));

      var groups = chart().data.barGroups;
      expect(groups, hasLength(30));
      expect(
        groups.where((group) => group.barRods.single.toY > 0),
        hasLength(2),
      );
      expect(find.text('Selected period • 30 days'), findsOneWidget);
      expect(chart().data.minY, 0);
      expect(chart().data.maxY, greaterThan(2000));

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.tap(find.text('7 days').last);
      await tester.pump();
      groups = chart().data.barGroups;
      expect(groups, hasLength(7));
      expect(
        groups.where((group) => group.barRods.single.toY > 0),
        hasLength(2),
      );

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.tap(find.text('12 months').last);
      await tester.pump();
      groups = chart().data.barGroups;
      expect(groups, hasLength(12));
      expect(
        groups.where((group) => group.barRods.single.toY > 0),
        hasLength(expectedRevenueMonths),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native mobile missing finance summary shows zero state', (
    tester,
  ) async {
    if (kIsWeb) return;
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(390, missing: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No revenue data'), findsOneWidget);
    expect(find.text('Available balance'), findsOneWidget);
    expect(find.text('0.00 TRY'), findsWidgets);
    expect(find.byType(BarChart), findsNothing);
    expect(find.byType(PieChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop missing finance summary keeps full zero state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(1200, missing: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('No revenue data'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pump();

    expect(find.text('Revenue trend'), findsOneWidget);
    expect(find.text('Revenue breakdown'), findsOneWidget);
    expect(find.text('Settlement timeline'), findsOneWidget);
    expect(find.text('Payout history'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('web mobile viewport keeps the responsive desktop revenue view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(390, viewportWidth: 390));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pump();

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !kIsWeb);

  testWidgets('web Revenue KPI grid uses responsive desktop columns', (
    tester,
  ) async {
    if (!kIsWeb) return;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final widthAndColumns in [(390.0, 2), (700.0, 3), (1200.0, 5)]) {
      await tester.pumpWidget(app(widthAndColumns.$1));
      await tester.pump(const Duration(milliseconds: 100));
      final grid = tester.widget<GridView>(find.byType(GridView).first);
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, widthAndColumns.$2);
    }
    expect(tester.takeException(), isNull);
  });
}
