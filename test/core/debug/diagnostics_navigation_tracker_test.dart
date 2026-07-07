import 'package:barky_matches_fixed/core/debug/diagnostics_navigation_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AdminDashboardPage.buildCount = 0;
  });

  testWidgets(
    'diagnostics route metadata updates during didPush before page build',
    (WidgetTester tester) async {
      final DiagnosticsNavigationTracker tracker =
          DiagnosticsNavigationTracker();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: <NavigatorObserver>[tracker],
          home: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    DiagnosticsPageRoute<void>(
                      page: const AdminDashboardPage(),
                      metadata: const DiagnosticsRouteMetadata(
                        feature: 'admin',
                        screenName: 'admin_dashboard',
                        routeName: '/admin/dashboard',
                        widgetName: 'AdminDashboardPage',
                      ),
                    ),
                  );
                },
                child: const Text('Open admin'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open admin'));

      expect(AdminDashboardPage.buildCount, 0);
      expect(tracker.currentScreen.feature, 'admin');
      expect(tracker.currentScreen.screenName, 'admin_dashboard');
      expect(tracker.currentScreen.route, '/admin/dashboard');
      expect(tracker.currentTrackedScreen.widgetName, 'AdminDashboardPage');

      await tester.pumpAndSettle();
    },
  );
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  static int buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildCount++;

    return const Scaffold(body: Text('Admin Dashboard'));
  }
}
