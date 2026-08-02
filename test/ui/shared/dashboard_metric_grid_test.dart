import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_card.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_grid.dart';

void main() {
  testWidgets('compact metrics fit a narrow mobile viewport', (tester) async {
    final errors = <FlutterError>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exception as FlutterError);
    };

    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: DashboardMetricGrid(
              columns: 3,
              compact: true,
              items: [
                DashboardMetricData(
                  label: 'Pending',
                  value: '1',
                  icon: Icons.timer,
                ),
                DashboardMetricData(
                  label: 'Active',
                  value: '2',
                  icon: Icons.navigation,
                ),
                DashboardMetricData(
                  label: 'Done',
                  value: '3',
                  icon: Icons.check,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      errors.where((error) => error.toString().contains('overflowed')),
      isEmpty,
    );
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
