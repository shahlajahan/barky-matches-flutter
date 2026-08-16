import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart' show RenderParagraph;
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

  Widget app(
    double width, {
    double height = 900,
    double textScale = 1,
    double topPadding = 0,
    double bottomPadding = 0,
    bool missing = false,
    double? viewportWidth,
    Stream<SellerFinanceSummary?>? stream,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: Size(viewportWidth ?? width, height),
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SizedBox(
              width: width,
              height: height,
              child: PetTaxiRevenueSection(
                businessId: 'business-1',
                recordLabel: 'rides',
                summaryStream:
                    stream ??
                    Stream<SellerFinanceSummary?>.value(
                      missing ? null : summary,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpRevenue(
    WidgetTester tester, {
    required double width,
    required double height,
    double textScale = 1,
    double topPadding = 0,
    double bottomPadding = 0,
    bool missing = false,
    Stream<SellerFinanceSummary?>? stream,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        width,
        height: height,
        textScale: textScale,
        topPadding: topPadding,
        bottomPadding: bottomPadding,
        missing: missing,
        stream: stream,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  }

  int verticalScrollableCount(WidgetTester tester) {
    return tester
        .widgetList<Scrollable>(find.byType(Scrollable))
        .where(
          (scrollable) =>
              axisDirectionToAxis(scrollable.axisDirection) == Axis.vertical,
        )
        .length;
  }

  Future<void> expectPayoutHistoryReachable(WidgetTester tester) async {
    final scrollable = find.byType(ListView).first;
    await tester.dragUntilVisible(
      find.text('Payout history'),
      scrollable,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Payout history'), findsOneWidget);
    await tester.dragUntilVisible(
      find.textContaining('PAYOUT-1'),
      scrollable,
      const Offset(0, -300),
      maxIteration: 100,
    );
    await tester.pumpAndSettle();
    final payoutReference = find.textContaining('PAYOUT-1').first;
    expect(payoutReference, findsOneWidget);
    final rect = tester.getRect(payoutReference);
    final viewportHeight = tester.getRect(find.byType(Scaffold)).height;
    expect(rect.top, lessThan(viewportHeight));
    expect(rect.bottom, greaterThan(0));
    expect(tester.takeException(), isNull);
  }

  void expectValueBelowLabel(
    WidgetTester tester,
    String label,
    String valuePattern,
  ) {
    final labelFinder = find.text(label);
    final valueFinder = find.textContaining(valuePattern);
    expect(labelFinder, findsOneWidget);
    expect(valueFinder, findsWidgets);

    final labelRect = tester.getRect(labelFinder);
    final valueRect = tester.getRect(valueFinder.first);
    expect(valueRect.top, greaterThan(labelRect.bottom));
    expect(labelRect.width, greaterThan(120));
  }

  void expectValueBesideLabel(
    WidgetTester tester,
    String label,
    String valuePattern,
  ) {
    final labelRect = tester.getRect(find.text(label));
    final valueRect = tester.getRect(find.textContaining(valuePattern).first);
    expect((labelRect.center.dy - valueRect.center.dy).abs(), lessThan(8));
    expect(valueRect.left, greaterThan(labelRect.right));
  }

  /// Proves a label hasn't collapsed into an extremely narrow, fragmented
  /// column (e.g. "Availa/ble ba/lance" — the reported runtime defect).
  /// At large accessibility scales a long label may legitimately wrap onto
  /// two or three lines on a narrow phone; what must never happen is the
  /// label's box shrinking to a sliver a few characters wide. A collapsed
  /// column is both very narrow AND, as a result, very tall (many short
  /// wrapped lines); this checks both the width floor and the height
  /// ceiling relative to the label's single-line natural width, which is
  /// large enough to require wrapping at all only when the box is narrow.
  void expectLabelNotFragmented(WidgetTester tester, String label) {
    final labelFinder = find.text(label);
    expect(labelFinder, findsOneWidget);
    final renderParagraph = tester.renderObject<RenderParagraph>(labelFinder);
    final singleLine = TextPainter(
      text: TextSpan(text: label, style: renderParagraph.text.style),
      textDirection: TextDirection.ltr,
      textScaler: renderParagraph.textScaler,
    )..layout();
    final labelRect = tester.getRect(labelFinder);
    expect(
      labelRect.width,
      greaterThan(120),
      reason: '"$label" rendered in a box too narrow to be readable',
    );
    // A clean word-boundary wrap of a long label at extreme scale needs at
    // most a handful of lines; true character-level fragmentation (many
    // tiny pieces) blows well past that.
    expect(
      renderParagraph.size.height,
      lessThan(singleLine.height * 5),
      reason:
          '"$label" fragmented into many narrow lines instead of '
          'wrapping normally at word boundaries',
    );
  }

  testWidgets('native mobile revenue scrolls to the final section', (
    tester,
  ) async {
    if (kIsWeb) return;
    await pumpRevenue(tester, width: 390, height: 844);

    expect(find.text('Available balance'), findsOneWidget);
    expect(find.text('Waiting balance'), findsOneWidget);
    expect(find.text('Upcoming Payout'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(verticalScrollableCount(tester), 1);
    await expectPayoutHistoryReachable(tester);
  });

  testWidgets('native mobile summary keeps compact rows at normal scale', (
    tester,
  ) async {
    if (kIsWeb) return;
    await pumpRevenue(tester, width: 390, height: 844);

    expectValueBesideLabel(tester, 'Available balance', '1200.00 TRY');
    expectValueBesideLabel(tester, 'Waiting balance', '800.00 TRY');
    expectValueBesideLabel(tester, 'Upcoming Payout', 'Aug 10, 2026');
    expect(tester.takeException(), isNull);
  });

  testWidgets('native mobile revenue fits common phone constraints', (
    tester,
  ) async {
    if (kIsWeb) return;
    for (final size in [
      const Size(320, 568),
      const Size(375, 667),
      const Size(430, 932),
      const Size(844, 390),
    ]) {
      await pumpRevenue(tester, width: size.width, height: size.height);
      expect(find.text('Revenue trend'), findsOneWidget);
      expect(verticalScrollableCount(tester), 1);
      await expectPayoutHistoryReachable(tester);
    }
  });

  testWidgets('native mobile revenue tolerates text scaling', (tester) async {
    if (kIsWeb) return;
    for (final textScale in [1.3, 2.0, 3.2]) {
      await pumpRevenue(
        tester,
        width: 390,
        height: 844,
        textScale: textScale,
        topPadding: 47,
        bottomPadding: 34,
      );
      expect(find.text('Finance & Earnings'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Finance & Earnings')).dy,
        greaterThanOrEqualTo(47),
      );
      expectValueBelowLabel(tester, 'Available balance', '1200.00 TRY');
      expectValueBelowLabel(tester, 'Waiting balance', '800.00 TRY');
      expectValueBelowLabel(tester, 'Upcoming Payout', 'Aug 10, 2026');
      expectLabelNotFragmented(tester, 'Available balance');
      expectLabelNotFragmented(tester, 'Waiting balance');
      expectLabelNotFragmented(tester, 'Upcoming Payout');
      expect(find.textContaining('Aug 10, 2026'), findsOneWidget);
      expect(verticalScrollableCount(tester), 1);
      await expectPayoutHistoryReachable(tester);
    }
  });

  testWidgets('native mobile loading, empty, and error states fit safely', (
    tester,
  ) async {
    if (kIsWeb) return;
    final loading = StreamController<SellerFinanceSummary?>();
    addTearDown(loading.close);

    await pumpRevenue(tester, width: 320, height: 568, stream: loading.stream);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpRevenue(tester, width: 320, height: 568, missing: true);
    expect(find.text('No revenue data'), findsOneWidget);
    expect(find.text('Payout history'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Payout history'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpRevenue(
      tester,
      width: 320,
      height: 568,
      stream: Stream<SellerFinanceSummary?>.error(Exception('boom')),
    );
    expect(find.text('Payout data could not be loaded.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native mobile stream rebuild preserves one scroll owner', (
    tester,
  ) async {
    if (kIsWeb) return;
    final controller = StreamController<SellerFinanceSummary?>();
    addTearDown(controller.close);

    await pumpRevenue(
      tester,
      width: 390,
      height: 844,
      stream: controller.stream,
    );
    controller.add(summary);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Payout history'), findsOneWidget);
    final before = tester.getTopLeft(find.text('Payout history')).dy;

    controller.add(summary);
    await tester.pumpAndSettle();
    expect(verticalScrollableCount(tester), 1);
    expect(tester.getTopLeft(find.text('Payout history')).dy, before);
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

  // ─────────────────────────────────────────────────────────────────────
  // BusinessRevenueDetailPage: the UI_NAV_STANDARD "Detail Route" (Type D)
  // shell used when this widget is reached via Navigator.push (e.g. from
  // the finance_waiting_period_started notification), as opposed to being
  // embedded inside an existing dashboard tab shell. Pushes onto a real
  // Navigator with no ambient Scaffold/AppBar supplied by the test host,
  // matching the actual notification-push call site in app_state.dart.
  // ─────────────────────────────────────────────────────────────────────

  Future<void> pumpPushedDetailPage(
    WidgetTester tester, {
    required double width,
    required double height,
    double textScale = 1,
    double topPadding = 0,
    double bottomPadding = 0,
    Stream<SellerFinanceSummary?>? stream,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // A MediaQuery override placed inside `home` would only reach the
        // launcher page, not routes later pushed onto the Navigator (the
        // Navigator/Overlay sits above `home` in the tree). `builder` wraps
        // the Navigator itself, so every pushed route — including the
        // notification's MaterialPageRoute — inherits the same viewport,
        // text scale, and safe-area padding as the real app.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: Size(width, height),
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (launcherContext) => ElevatedButton(
                onPressed: () => Navigator.of(launcherContext).push(
                  MaterialPageRoute(
                    builder: (_) => BusinessRevenueDetailPage(
                      businessId: 'business-1',
                      recordLabel: 'rides',
                      summaryStream:
                          stream ??
                          Stream<SellerFinanceSummary?>.value(summary),
                    ),
                  ),
                ),
                child: const Text('Open finance notification'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open finance notification'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'notification-pushed finance route uses the standard Scaffold/AppBar shell',
    (tester) async {
      if (kIsWeb) return;
      await pumpPushedDetailPage(
        tester,
        width: 390,
        height: 844,
        topPadding: 59,
        bottomPadding: 34,
      );

      // Exactly one route-owning Scaffold (Type D: "Scaffold دارد").
      expect(find.byType(Scaffold), findsOneWidget);

      // A real AppBar owns the header (Type D: "AppBar دارد").
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);
      final appBar = tester.widget<AppBar>(appBarFinder);
      expect(appBar.title, isA<Text>());
      expect((appBar.title as Text).data, 'Finance & Earnings');

      // Standard back-navigation affordance is present because the route
      // was pushed onto a non-empty stack (canPop == true).
      expect(find.byType(BackButton), findsOneWidget);

      // The title sits inside the AppBar, below the safe-area/notch inset,
      // not crowded against the sensor area.
      final titleRect = tester.getTopLeft(find.text('Finance & Earnings'));
      expect(titleRect.dy, greaterThanOrEqualTo(59));

      // Exactly one primary vertical scroll owner in the body.
      expect(verticalScrollableCount(tester), 1);
      await expectPayoutHistoryReachable(tester);
    },
  );

  testWidgets(
    'notification-pushed finance route stays compact at normal scale and '
    'stacks safely at accessibility scale',
    (tester) async {
      if (kIsWeb) return;

      await pumpPushedDetailPage(
        tester,
        width: 390,
        height: 844,
        topPadding: 59,
        bottomPadding: 34,
      );
      expectValueBesideLabel(tester, 'Available balance', '1200.00 TRY');
      expectValueBesideLabel(tester, 'Waiting balance', '800.00 TRY');
      expectValueBesideLabel(tester, 'Upcoming Payout', 'Aug 10, 2026');

      await pumpPushedDetailPage(
        tester,
        width: 390,
        height: 844,
        textScale: 3.2,
        topPadding: 59,
        bottomPadding: 34,
      );
      expectValueBelowLabel(tester, 'Available balance', '1200.00 TRY');
      expectValueBelowLabel(tester, 'Waiting balance', '800.00 TRY');
      expectValueBelowLabel(tester, 'Upcoming Payout', 'Aug 10, 2026');
      expectLabelNotFragmented(tester, 'Available balance');
      expectLabelNotFragmented(tester, 'Waiting balance');
      expectLabelNotFragmented(tester, 'Upcoming Payout');
      expect(verticalScrollableCount(tester), 1);
      await expectPayoutHistoryReachable(tester);
    },
  );
}
