import 'dart:io';

import 'package:barky_matches_fixed/services/business_finance_notification_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finance waiting notification has a dedicated canonical type', () {
    expect(
      isBusinessFinanceNotificationType('finance_waiting_period_started'),
      isTrue,
    );
    expect(
      isBusinessFinanceNotificationType('marketplace_business_delayed'),
      isFalse,
    );
  });

  test('finance notification forwards businessId from the in-app tap', () {
    final source = File('lib/notifications_page.dart').readAsStringSync();
    expect(source, contains('isBusinessFinanceNotificationType(rawType)'));
    expect(source, contains("'businessId': data['businessId']"));
    expect(source, contains(".update({'isRead': true})"));
  });

  test(
    'finance notification opens the existing authorized revenue surface',
    () {
      final appState = File('lib/app_state.dart').readAsStringSync();
      final revenue = File(
        'lib/ui/business/finance/seller_finance_repository.dart',
      ).readAsStringSync();

      expect(appState, contains('isBusinessFinanceNotificationType(type)'));
      expect(appState, contains('BusinessRevenueDetailPage('));
      expect(appState, contains('businessId: ownedBusinessId'));
      expect(appState, contains('requestedBusinessId != ownedBusinessId'));
      expect(revenue, contains('class SellerFinanceRepository'));
      expect(
        appState,
        isNot(contains('businessId == FirebaseAuth.instance.currentUser?.uid')),
      );
    },
  );

  test(
    'finance entry paths share the canonical helper and remain navigation-only',
    () {
      final main = File('lib/main.dart').readAsStringSync();
      final appState = File('lib/app_state.dart').readAsStringSync();

      expect(main, contains('isBusinessFinanceNotificationType(type)'));
      expect(main, contains('_initialNotificationCoordinator.retrieveOnce'));
      expect(appState, contains('navigatorKey.currentState?.push'));
      expect(appState, isNot(contains('releasePayout')));
      expect(appState, isNot(contains('updatePayout')));
      expect(appState, isNot(contains('httpsCallable')));
    },
  );

  test(
    'missing or unauthorized business IDs use the business dashboard fallback',
    () {
      final appState = File('lib/app_state.dart').readAsStringSync();
      expect(appState, contains('ProfileSubPage.businessDashboard'));
      expect(appState, contains('requestedBusinessId == null'));
      expect(appState, contains('ownedBusinessId == null'));
      expect(appState, contains('isGuestUser'));
    },
  );
}
