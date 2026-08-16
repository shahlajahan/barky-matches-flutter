import 'dart:io';

import 'package:barky_matches_fixed/services/marketplace_order_notification_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marketplace order type set includes every backend return type', () {
    const returnTypes = [
      'order_return_requested',
      'order_return_approved',
      'order_return_rejected',
      'order_return_cancelled',
      'order_return_shipped_back',
      'order_return_received',
      'order_return_disputed',
      'order_return_auto_received',
      'order_return_refund_rejected',
      'order_return_refund_failed',
      'order_return_refunded',
    ];

    for (final type in returnTypes) {
      expect(isMarketplaceOrderNotificationType(type), isTrue, reason: type);
    }
    expect(
      isMarketplaceOrderNotificationType('order_return_refund_processing'),
      isFalse,
    );
    expect(
      isMarketplaceOrderNotificationType('order_cancelled_before_shipment'),
      isTrue,
    );
    expect(
      isSellerReturnNotificationType('order_cancelled_before_shipment'),
      isTrue,
    );
  });

  test('in-app NotificationsPage forwards cancellation refund payloads', () {
    final source = File('lib/notifications_page.dart').readAsStringSync();

    expect(source, contains("case 'order_cancellation_refund_processing':"));
    expect(source, contains("case 'order_cancellation_refunded':"));
    expect(source, contains("case 'order_cancelled_before_shipment':"));
    expect(source, contains("case 'order_return_requested':"));
    expect(source, contains("case 'order_return_refunded':"));
    expect(source, contains("'rootOrderId':"));
    expect(source, contains("'sellerOrderId': data['sellerOrderId']"));
    expect(source, contains("'returnId': data['returnId']"));
    expect(source, contains("'refundStatus': data['refundStatus']"));
  });

  test('AppState routes cancellation refund types through order router', () {
    final source = File('lib/app_state.dart').readAsStringSync();

    expect(source, contains('isMarketplaceOrderNotificationType(type)'));
    expect(source, contains("payload['rootOrderId']"));
    expect(source, contains("payload['orderId']"));
    expect(
      source,
      contains('openOrderSmart(sellerOrderId, rootOrderId, returnId:'),
    );
    expect(source, contains("payload['returnId']"));
    expect(source, contains('returnId: returnId'));
    expect(source, contains('isSellerReturnNotificationType(type)'));
    expect(
      File(
        'lib/services/marketplace_order_notification_types.dart',
      ).readAsStringSync(),
      contains("'order_cancelled_before_shipment'"),
    );
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
  });

  test(
    'return focus is carried into order detail and consumed by My Orders',
    () {
      final detail = File(
        'lib/ui/orders/order_detail_page.dart',
      ).readAsStringSync();
      final orders = File(
        'lib/ui/orders/my_orders_page.dart',
      ).readAsStringSync();

      expect(detail, contains('final String? returnId;'));
      expect(detail, contains('_focusedReturnId'));
      expect(
        detail,
        contains('highlighted: record.returnId == _focusedReturnId'),
      );
      expect(orders, contains('takePendingBuyerOrdersReturnId()'));
      expect(orders, contains('returnId: _focusedReturnId'));
    },
  );

  test('return routing remains navigation-only and errors are user-safe', () {
    final appState = File('lib/app_state.dart').readAsStringSync();
    final detail = File(
      'lib/ui/orders/order_detail_page.dart',
    ).readAsStringSync();

    expect(appState, isNot(contains('triggerOrderReturnRefund')));
    expect(detail, contains('child: Text(l10n.orderNotFound)'));
    expect(detail, isNot(contains('snapshot.error.toString()')));
  });

  test('foreground local and background-open paths forward order types', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('FirebaseMessaging.onMessageOpenedApp.listen'));
    expect(source, contains('onDidReceiveNotificationResponse'));
    expect(source, contains('isMarketplaceOrderNotificationType(type)'));
    expect(
      source,
      contains(
        'appState.handleNotificationTap(Map<String, dynamic>.from(payload))',
      ),
    );
    expect(
      source,
      contains(
        'appState.handleNotificationTap(Map<String, dynamic>.from(data))',
      ),
    );
    expect(source, contains('_initialNotificationCoordinator.retrieveOnce'));
    expect(source, contains('handle: _handleRemoteMessageData'));
  });

  test(
    'seller cancellation notification uses seller fallback without a global query',
    () {
      final appState = File('lib/app_state.dart').readAsStringSync();
      expect(appState, contains('setCurrentTab(NavTab.petShop)'));
      expect(appState, contains('openPetShopOrders()'));
      expect(
        appState,
        isNot(
          matches(
            RegExp(
              r'where\("rootOrderId", isEqualTo: rootOrderId\)[\s\S]*?limit\(1\)',
            ),
          ),
        ),
      );
    },
  );
}
