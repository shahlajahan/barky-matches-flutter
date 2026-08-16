import 'dart:async';
import 'dart:io';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppState UID changes from User A to User B', () {
    final appState = _buildAppState(currentUserId: 'old-uid');

    final changed = appState.synchronizeAuthenticatedUid('new-uid');

    expect(changed, isTrue);
    expect(appState.currentUserId, 'new-uid');
  });

  test('a UID transition clears stale previous-user data', () {
    final appState = _buildAppState(
      currentUserId: 'old-uid',
      currentUserName: 'old-user-name',
    );
    appState.setSavedParks(['Old User Park']);

    appState.synchronizeAuthenticatedUid('new-uid');

    expect(appState.currentUserName, isNull);
    expect(appState.favoriteParks, isEmpty);
    expect(appState.favoriteDogs, isEmpty);
    expect(appState.cartItems, isEmpty);
  });

  test('User B session data is accepted after the transition', () {
    final appState = _buildAppState(currentUserId: 'user-a');

    appState.synchronizeAuthenticatedUid('user-b');
    final userBGeneration = appState.startupSessionGeneration;
    if (appState.isUserSessionCurrent('user-b', userBGeneration)) {
      appState.setSavedParks(['User B Park']);
    }

    expect(appState.currentUserId, 'user-b');
    expect(appState.favoriteParkNames, contains('User B Park'));
  });

  test('a stale User A callback cannot overwrite User B state', () async {
    final appState = _buildAppState(currentUserId: 'user-a');
    final userAGeneration = appState.startupSessionGeneration;
    final staleCallback = Completer<void>();

    final delayedUserAWrite = () async {
      await staleCallback.future;
      if (appState.isUserSessionCurrent('user-a', userAGeneration)) {
        appState.setSavedParks(['Stale User A Park']);
      }
    }();

    appState.synchronizeAuthenticatedUid('user-b');
    appState.setSavedParks(['User B Park']);
    staleCallback.complete();
    await delayedUserAWrite;

    expect(appState.favoriteParkNames, contains('User B Park'));
    expect(appState.favoriteParkNames, isNot(contains('Stale User A Park')));
  });

  test('disposing AppState invalidates the active session generation', () {
    final appState = _buildAppState(currentUserId: 'user-a');
    final generation = appState.startupSessionGeneration;

    appState.dispose();

    expect(appState.isDisposed, isTrue);
    expect(appState.isUserSessionCurrent('user-a', generation), isFalse);
  });

  test('late notifications are ignored after AppState is disposed', () {
    final appState = _buildAppState(currentUserId: 'user-a');
    var notifications = 0;
    appState.addListener(() => notifications++);

    appState.dispose();
    appState.notifyListeners();

    expect(notifications, 0);
  });

  test('order_paid with only root order opens My Orders focus', () async {
    final appState = _buildAppState(currentUserId: 'buyer-1');

    appState.handleNotificationTap({
      'type': 'order_paid',
      'orderId': 'root-order-1',
    });

    expect(appState.currentTab, NavTab.profile);
    expect(appState.profileSubPage, ProfileSubPage.myOrders);
    expect(appState.pendingBuyerOrdersRootOrderId, 'root-order-1');
  });

  test('order_created with only root order opens My Orders focus', () async {
    final appState = _buildAppState(currentUserId: 'buyer-1');

    appState.handleNotificationTap({
      'type': 'order_created',
      'orderId': 'root-order-2',
    });

    expect(appState.currentTab, NavTab.profile);
    expect(appState.profileSubPage, ProfileSubPage.myOrders);
    expect(appState.pendingBuyerOrdersRootOrderId, 'root-order-2');
  });

  test('return notification preserves root and return focus for My Orders', () {
    final appState = _buildAppState(currentUserId: 'buyer-1');

    appState.handleNotificationTap({
      'type': 'order_return_refunded',
      'orderId': 'root-return-order',
      'returnId': 'return-1',
    });

    expect(appState.pendingBuyerOrdersRootOrderId, 'root-return-order');
    expect(appState.pendingBuyerOrdersReturnId, 'return-1');
    expect(appState.takePendingBuyerOrdersReturnId(), 'return-1');
    expect(appState.takePendingBuyerOrdersReturnId(), isNull);
  });

  test(
    'seller return notification without seller order uses seller fallback',
    () {
      final appState = _buildAppState(currentUserId: 'seller-1');

      appState.handleNotificationTap({
        'type': 'order_return_requested',
        'orderId': 'root-return-order',
        'returnId': 'return-2',
      });

      expect(appState.currentTab, NavTab.petShop);
      expect(appState.pendingBuyerOrdersRootOrderId, isNull);
    },
  );

  test(
    'refund processing notification with seller order keeps direct route',
    () async {
      final appState = _buildAppState(currentUserId: 'buyer-1');

      appState.handleNotificationTap({
        'type': 'order_cancellation_refund_processing',
        'orderId': 'root-order-1',
        'sellerOrderId': 'seller-order-1',
        'refundStatus': 'refund_pending',
      });

      expect(appState.pendingBuyerOrdersRootOrderId, isNull);
      expect(appState.profileSubPage, isNot(ProfileSubPage.myOrders));
    },
  );

  test(
    'refund processing notification with only root order opens My Orders',
    () {
      final appState = _buildAppState(currentUserId: 'buyer-1');

      appState.handleNotificationTap({
        'type': 'order_cancellation_refund_processing',
        'orderId': 'root-order-processing',
        'refundStatus': 'refund_processing',
      });

      expect(appState.currentTab, NavTab.profile);
      expect(appState.profileSubPage, ProfileSubPage.myOrders);
      expect(appState.pendingBuyerOrdersRootOrderId, 'root-order-processing');
    },
  );

  test('refunded notification with seller order keeps direct route', () {
    final appState = _buildAppState(currentUserId: 'buyer-1');

    appState.handleNotificationTap({
      'type': 'order_cancellation_refunded',
      'orderId': 'root-order-refunded',
      'sellerOrderId': 'seller-order-refunded',
      'refundStatus': 'refunded',
    });

    expect(appState.pendingBuyerOrdersRootOrderId, isNull);
    expect(appState.profileSubPage, isNot(ProfileSubPage.myOrders));
  });

  test('refunded notification with only root order opens My Orders focus', () {
    final appState = _buildAppState(currentUserId: 'buyer-1');

    appState.handleNotificationTap({
      'type': 'order_cancellation_refunded',
      'orderId': 'root-order-3',
      'status': 'refunded',
    });

    expect(appState.currentTab, NavTab.profile);
    expect(appState.profileSubPage, ProfileSubPage.myOrders);
    expect(appState.pendingBuyerOrdersRootOrderId, 'root-order-3');
  });

  test('repeated refund notification tap remains stable', () {
    final appState = _buildAppState(currentUserId: 'buyer-1');
    final payload = {
      'type': 'order_cancellation_refunded',
      'orderId': 'root-order-4',
    };

    appState.handleNotificationTap(payload);
    appState.handleNotificationTap(payload);

    expect(appState.currentTab, NavTab.profile);
    expect(appState.profileSubPage, ProfileSubPage.myOrders);
    expect(appState.pendingBuyerOrdersRootOrderId, 'root-order-4');
  });

  test('seller order payload preserves direct detail path', () async {
    final appState = _buildAppState(currentUserId: 'buyer-1');

    await appState.openOrderSmart('seller-order-1', 'root-order-1');

    expect(appState.pendingBuyerOrdersRootOrderId, isNull);
    expect(appState.profileSubPage, isNot(ProfileSubPage.myOrders));
  });

  test('missing order ids do not throw or create pending focus', () async {
    final appState = _buildAppState(currentUserId: 'buyer-1');

    await appState.openOrderSmart(null, null);

    expect(appState.pendingBuyerOrdersRootOrderId, isNull);
    expect(appState.profileSubPage, ProfileSubPage.none);
  });

  test(
    'root-only notification path no longer has unscoped sellerOrders query',
    () {
      final source = File('lib/app_state.dart').readAsStringSync();

      expect(source, isNot(contains('FINDING sellerOrder FROM root')));
      expect(
        source,
        isNot(
          matches(
            RegExp(
              r'collection\("sellerOrders"\)[\s\S]*?'
              r'where\("rootOrderId", isEqualTo: rootOrderId\)[\s\S]*?'
              r'limit\(1\)',
            ),
          ),
        ),
      );
    },
  );

  test('a valid stored business reference is accepted directly', () {
    expect(
      isValidStoredBusinessReference('owner-1', 'business-1', {
        'ownerUid': 'owner-1',
        'status': 'approved',
      }),
      isTrue,
    );
  });

  test('a stale businessId equal to the user UID is rejected', () {
    expect(
      isValidStoredBusinessReference('owner-1', 'owner-1', {
        'ownerUid': 'owner-2',
        'status': 'approved',
      }),
      isFalse,
    );
  });

  test('one approved owned business is selected by its document ID', () {
    expect(
      selectCanonicalOwnedBusinessId('owner-1', [
        {
          '__documentId': 'business-1',
          'ownerUid': 'owner-1',
          'status': 'approved',
          'published': true,
        },
      ]),
      'business-1',
    );
  });

  test('no owned approved business preserves no-business behavior', () {
    expect(
      selectCanonicalOwnedBusinessId('owner-1', [
        {
          '__documentId': 'business-1',
          'ownerUid': 'owner-2',
          'status': 'approved',
        },
        {
          '__documentId': 'business-2',
          'ownerUid': 'owner-1',
          'status': 'pending',
        },
      ]),
      isNull,
    );
  });

  test('a stored business belonging to another owner is rejected', () {
    expect(
      isValidStoredBusinessReference('owner-1', 'business-1', {
        'ownerUid': 'owner-2',
        'status': 'approved',
      }),
      isFalse,
    );
  });

  test('ambiguous approved businesses are not selected silently', () {
    expect(
      selectCanonicalOwnedBusinessId('owner-1', [
        {
          '__documentId': 'business-1',
          'ownerUid': 'owner-1',
          'status': 'approved',
        },
        {
          '__documentId': 'business-2',
          'ownerUid': 'owner-1',
          'status': 'approved',
        },
      ]),
      isNull,
    );
  });
}

AppState _buildAppState({
  required String currentUserId,
  String? currentUserName,
}) {
  return AppState(
    favoriteDogs: <Dog>[],
    favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
    likesNotifier: ValueNotifier<Map<String, List<String>>>(
      <String, List<String>>{},
    ),
    onToggleFavorite: (_) async {},
    notificationService: NotificationService(),
    currentUserId: currentUserId,
    currentUserName: currentUserName,
  );
}
