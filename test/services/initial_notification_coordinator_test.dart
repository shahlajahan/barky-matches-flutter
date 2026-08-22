import 'dart:io';

import 'package:barky_matches_fixed/services/initial_notification_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

InitialNotificationReadiness readyFor(String uid) {
  return InitialNotificationReadiness(
    navigatorReady: true,
    appStateReady: true,
    authReady: true,
    isGuest: false,
    currentUserId: uid,
  );
}

const notReady = InitialNotificationReadiness(
  navigatorReady: false,
  appStateReady: false,
  authReady: false,
  isGuest: false,
  currentUserId: null,
);

void main() {
  test('production has one getInitialMessage owner', () {
    final productionFiles = [
      File('lib/main.dart'),
      File('lib/home_gate.dart'),
      File('lib/app_state.dart'),
    ];

    final ownerCount = productionFiles.fold<int>(0, (count, file) {
      return count +
          RegExp(
            r'FirebaseMessaging\.instance\.getInitialMessage\(',
          ).allMatches(file.readAsStringSync()).length;
    });

    expect(ownerCount, 1);
  });

  test('null initial message causes no navigation', () async {
    final coordinator = InitialNotificationCoordinator();
    var handled = 0;

    await coordinator.retrieveOnce(
      getInitialMessage: () async => null,
      readiness: readyFor('user-a'),
      handle: (_) async => handled++,
    );

    expect(handled, 0);
    expect(coordinator.hasPendingMessage, isFalse);
  });

  test('one valid initial message is processed once', () async {
    final coordinator = InitialNotificationCoordinator();
    var retrieveCount = 0;
    final handled = <Map<String, dynamic>>[];

    Future<InitialNotificationMessage?> getter() async {
      retrieveCount++;
      return const InitialNotificationMessage(
        messageId: 'message-1',
        data: {
          'type': 'chat_message',
          'chatId': 'chat-1',
          'senderId': 'user-b',
          'recipientUserId': 'user-a',
        },
      );
    }

    await coordinator.retrieveOnce(
      getInitialMessage: getter,
      readiness: readyFor('user-a'),
      handle: (data) async => handled.add(data),
    );
    await coordinator.retrieveOnce(
      getInitialMessage: getter,
      readiness: readyFor('user-a'),
      handle: (data) async => handled.add(data),
    );
    await coordinator.processPendingIfReady(
      readiness: readyFor('user-a'),
      handle: (data) async => handled.add(data),
    );

    expect(retrieveCount, 1);
    expect(handled, hasLength(1));
    expect(handled.single['chatId'], 'chat-1');
  });

  test('retryable handler failure keeps initial appointment pending', () async {
    final coordinator = InitialNotificationCoordinator();
    var attempts = 0;
    final handled = <String>[];

    await expectLater(
      coordinator.retrieveOnce(
        getInitialMessage: () async => const InitialNotificationMessage(
          messageId: 'appointment-message-1',
          data: {
            'type': 'pet_taxi_status_update',
            'bookingId': 'taxi-1',
            'recipientUserId': 'user-a',
          },
        ),
        readiness: readyFor('user-a'),
        handle: (data) async {
          attempts += 1;
          throw const InitialNotificationRetryableFailure(
            'appointment_lookup_unresolved',
          );
        },
      ),
      throwsA(isA<InitialNotificationRetryableFailure>()),
    );

    expect(coordinator.hasPendingMessage, isTrue);

    await coordinator.processPendingIfReady(
      readiness: readyFor('user-a'),
      handle: (data) async {
        attempts += 1;
        handled.add(data['bookingId'].toString());
      },
    );
    await coordinator.processPendingIfReady(
      readiness: readyFor('user-a'),
      handle: (data) async {
        attempts += 1;
        handled.add(data['bookingId'].toString());
      },
    );

    expect(attempts, 2);
    expect(handled, ['taxi-1']);
    expect(coordinator.hasPendingMessage, isFalse);
  });

  test('pending message waits until startup is ready', () async {
    final coordinator = InitialNotificationCoordinator();
    final handled = <String>[];

    await coordinator.retrieveOnce(
      getInitialMessage: () async => const InitialNotificationMessage(
        messageId: 'message-2',
        data: {
          'type': 'playdate_request',
          'requestId': 'request-1',
          'recipientUserId': 'user-a',
        },
      ),
      readiness: notReady,
      handle: (data) async => handled.add(data['requestId'].toString()),
    );

    expect(handled, isEmpty);
    expect(coordinator.hasPendingMessage, isTrue);

    await coordinator.processPendingIfReady(
      readiness: readyFor('user-a'),
      handle: (data) async => handled.add(data['requestId'].toString()),
    );
    await coordinator.processPendingIfReady(
      readiness: readyFor('user-a'),
      handle: (data) async => handled.add(data['requestId'].toString()),
    );

    expect(handled, ['request-1']);
    expect(coordinator.hasPendingMessage, isFalse);
  });

  test(
    'pending message is not delivered to the wrong authenticated user',
    () async {
      final coordinator = InitialNotificationCoordinator();
      var handled = 0;

      await coordinator.retrieveOnce(
        getInitialMessage: () async => const InitialNotificationMessage(
          messageId: 'message-3',
          data: {
            'type': 'order_paid',
            'orderId': 'order-1',
            'recipientUserId': 'user-a',
          },
        ),
        readiness: notReady,
        handle: (_) async => handled++,
      );

      await coordinator.processPendingIfReady(
        readiness: readyFor('user-b'),
        handle: (_) async => handled++,
      );

      expect(handled, 0);
      expect(coordinator.hasPendingMessage, isFalse);
    },
  );

  test(
    'unsupported notification types are still handed to the existing router',
    () async {
      final coordinator = InitialNotificationCoordinator();
      final handledTypes = <String>[];

      await coordinator.retrieveOnce(
        getInitialMessage: () async => const InitialNotificationMessage(
          data: {'type': 'unsupported_type', 'recipientUserId': 'user-a'},
        ),
        readiness: readyFor('user-a'),
        handle: (data) async => handledTypes.add(data['type'].toString()),
      );

      expect(handledTypes, ['unsupported_type']);
    },
  );

  test('terminated refund cancellation notification reaches router', () async {
    final coordinator = InitialNotificationCoordinator();
    final handled = <Map<String, dynamic>>[];

    await coordinator.retrieveOnce(
      getInitialMessage: () async => const InitialNotificationMessage(
        messageId: 'refund-message-1',
        data: {
          'type': 'order_cancellation_refunded',
          'orderId': 'root-order-1',
          'sellerOrderId': 'seller-order-1',
          'refundStatus': 'refunded',
          'recipientUserId': 'user-a',
        },
      ),
      readiness: readyFor('user-a'),
      handle: (data) async => handled.add(data),
    );

    expect(handled, hasLength(1));
    expect(handled.single['type'], 'order_cancellation_refunded');
    expect(handled.single['orderId'], 'root-order-1');
    expect(handled.single['sellerOrderId'], 'seller-order-1');
  });

  test('foreground and background-open handlers remain wired unchanged', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(main, contains('FirebaseMessaging.onMessage.listen'));
    expect(main, contains('_firebaseMessagingForegroundHandler'));
    expect(main, contains('FirebaseMessaging.onMessageOpenedApp.listen'));
    expect(main, contains('_handleRemoteMessage(message)'));
    expect(
      main,
      contains('AppointmentNotificationNavigationGuard.isAppointmentPayload'),
    );
    expect(main, contains('isMarketplaceOrderNotificationType(type)'));
    expect(main, contains("type == 'chat_message'"));
    expect(main, contains('ChatDetailPage('));
    expect(main, contains('chatId: chatId'));
    expect(main, contains('otherUserId: senderId'));
    expect(main, contains('otherUserName: senderName'));
  });
}
