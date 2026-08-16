const Set<String> marketplaceOrderNotificationTypes = {
  'new_order',
  'order_paid',
  'order_update',
  'order_created',
  'new_paid_order',
  'order_cancellation_refund_processing',
  'order_cancellation_refunded',
  'order_cancelled_before_shipment',
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
};

const Set<String> sellerReturnNotificationTypes = {
  'order_cancelled_before_shipment',
  'order_return_requested',
  'order_return_cancelled',
  'order_return_shipped_back',
};

String normalizeNotificationType(Object? value) {
  return value
          ?.toString()
          .toLowerCase()
          .trim()
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .replaceAll(' ', '') ??
      '';
}

bool isMarketplaceOrderNotificationType(Object? value) {
  return marketplaceOrderNotificationTypes.contains(
    normalizeNotificationType(value),
  );
}

bool isSellerReturnNotificationType(Object? value) {
  return sellerReturnNotificationTypes.contains(
    normalizeNotificationType(value),
  );
}
