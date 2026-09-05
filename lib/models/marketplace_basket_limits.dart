/// Marketplace Revision 47 §0.45 (Slice 7F-2) — UX mirror of the frozen
/// server-owned basket bounds.
///
/// THESE VALUES ARE NOT AUTHORITATIVE. The authority is
/// `functions/src/marketplace/orders/basketLimits.js`, which enforces the
/// same bounds inside the trusted callable before any database read. This
/// mirror exists only so the cart can refuse an over-large basket at the
/// point the customer creates it, instead of letting them reach checkout and
/// be rejected by the server.
///
/// A client that ignores, patches or predates these constants gains nothing:
/// the server rejects the same basket with a stable reason code either way.
///
/// Kept byte-identical to the backend by a drift test
/// (`test/marketplace/basket_limits_drift_test.dart`), which parses the
/// JavaScript contract and compares every value — so changing one side alone
/// fails the build rather than silently diverging.
abstract final class MarketplaceBasketLimits {
  /// Maximum raw line entries a single checkout request may submit.
  static const int maxSubmittedLines = 50;

  /// Maximum distinct canonical products after duplicate merging.
  ///
  /// Deliberately equal to `maxBatchProducts` in
  /// `marketplace_catalog_service.dart`: a cart must never hold more products
  /// than the batch-hydration callable can serve in one request.
  static const int maxDistinctProducts = 20;

  /// Maximum units of any one product.
  static const int maxQuantityPerProduct = 20;

  /// Maximum units across the whole basket.
  static const int maxTotalUnits = 100;

  /// Maximum distinct businesses (Pet Shops) in a single checkout.
  static const int maxBusinesses = 5;
}
