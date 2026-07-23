import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/widgets/business_quick_actions.dart';

Widget _harness({
  required double width,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 900),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: BusinessQuickActionsSection(
              title: 'Quick Actions',
              actions: const [
                BusinessQuickActionItem(
                  label: 'Schedule',
                  icon: Icons.calendar_today,
                  onTap: null,
                ),
                BusinessQuickActionItem(
                  label: 'Patients',
                  icon: Icons.people,
                  onTap: null,
                ),
                BusinessQuickActionItem(
                  label: 'Gallery',
                  icon: Icons.image,
                  onTap: null,
                ),
                BusinessQuickActionItem(
                  label: 'Settings',
                  icon: Icons.settings,
                  onTap: null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('uses two equal columns on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(width: 390));

    final schedule = tester.getRect(find.text('Schedule'));
    final patients = tester.getRect(find.text('Patients'));
    final gallery = tester.getRect(find.text('Gallery'));

    expect(schedule.top, patients.top);
    expect(gallery.top, greaterThan(schedule.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses three columns at medium width', (tester) async {
    tester.view.physicalSize = const Size(760, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(width: 760));

    final schedule = tester.getRect(find.text('Schedule'));
    final gallery = tester.getRect(find.text('Gallery'));
    final settings = tester.getRect(find.text('Settings'));

    expect(schedule.top, gallery.top);
    expect(settings.top, greaterThan(schedule.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses four columns at wide width', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(width: 1200));

    final topPositions = [
      'Schedule',
      'Patients',
      'Gallery',
      'Settings',
    ].map((label) => tester.getRect(find.text(label)).top).toSet();

    expect(topPositions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports RTL and large text without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(width: 390, textScale: 1.6, direction: TextDirection.rtl),
    );

    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
