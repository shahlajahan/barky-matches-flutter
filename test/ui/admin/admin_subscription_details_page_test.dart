import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/admin/subscriptions/admin_subscription_details_page.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  testWidgets(
    'missing subscription document displays No subscription and can grant Gold',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final calls = <Map<String, String>>[];

      await tester.pumpWidget(
        _app(
          AdminSubscriptionDetailsPage(
            subscriptionId: 'user-without-sub',
            firestore: firestore,
            updateSubscription: (uid, action) async {
              calls.add({'uid': uid, 'action': action});
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No subscription'), findsOneWidget);
      expect(find.textContaining('Partner'), findsOneWidget);

      await tester.tap(find.textContaining('Partner'));
      await tester.pumpAndSettle();

      expect(calls, [
        {'uid': 'user-without-sub', 'action': 'grant_gold'},
      ]);
      expect(find.text('Subscription updated successfully'), findsOneWidget);
    },
  );

  testWidgets('permission denied mutation shows a clear state', (tester) async {
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(
      _app(
        AdminSubscriptionDetailsPage(
          subscriptionId: 'user-without-sub',
          firestore: firestore,
          updateSubscription: (_, _) async {
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'Admin only',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Premium'));
    await tester.pumpAndSettle();

    expect(find.text('Permission denied'), findsOneWidget);
  });
}
