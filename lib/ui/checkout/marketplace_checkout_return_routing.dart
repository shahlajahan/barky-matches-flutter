/// İş Bank's browser-return callback (`isbank3DSuccessReturn` /
/// `isbank3DFailReturn`) is shared by both Web subscription orders and
/// marketplace orders — see functions/index.js's `webSubscriptionBrowserReturn`
/// and `webSubscriptionOrderId`, which always prefixes subscription order
/// ids with `websub_`. Any other order id reaching that same callback is a
/// marketplace order. Extracted as a pure function so the routing decision
/// (main.dart's `_webPaymentReturnPage`) is unit-testable without a browser.
bool isWebSubscriptionOrderId(String orderId) => orderId.startsWith('websub_');
