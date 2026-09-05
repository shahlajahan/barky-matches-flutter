import '../../services/marketplace_catalog_service.dart';

/// Whether a seller currently has at least one product a customer can actually
/// see.
///
/// The Pet Shop profile previously offered "Buy Now" unconditionally, so a
/// shop with no published products routed every visitor into a guaranteed-empty
/// catalogue. This resolves the same authoritative visibility contract the
/// customer catalogue itself uses.
///
/// Marketplace Revision 43 §0.41 (Slice 7D): that contract is no longer a
/// direct Firestore query. Publishability is decided by the server's
/// `evaluateLiveProductEligibility`, which considers compliance decision,
/// approval, evidence, business generation and pilot class — none of which a
/// client query can see. Asking `getMarketplaceProductList` for a single
/// item scoped to this seller gives exactly the customer's own answer,
/// because it is served by exactly the code that serves the catalogue.
///
/// The request is bounded at `pageSize: 1` — it answers "any?" and never
/// reads the catalogue.
enum SellerProductAvailability {
  /// Still resolving. Callers must not expose an actionable buy control yet.
  unknown,

  /// Resolved: nothing is customer-visible. Also used for a failed call, so
  /// the control fails closed rather than misleading the customer.
  none,

  /// Resolved: at least one customer-visible product exists.
  available,
}

/// Resolves [SellerProductAvailability] for [sellerId].
///
/// Returns [SellerProductAvailability.none] for a blank seller id and for any
/// failure (permission, App Check, offline, transient, feature disabled) —
/// failing closed, never throwing into the widget tree, and never falling
/// back to a direct Firestore read.
Future<SellerProductAvailability> resolveSellerProductAvailability(
  String? sellerId, {
  MarketplaceCatalogService? catalogService,
}) async {
  final id = sellerId?.trim();
  if (id == null || id.isEmpty) return SellerProductAvailability.none;

  try {
    final page = await (catalogService ?? MarketplaceCatalogService())
        .fetchProductList(pageSize: 1, businessId: id);
    return page.items.isEmpty
        ? SellerProductAvailability.none
        : SellerProductAvailability.available;
  } catch (_) {
    return SellerProductAvailability.none;
  }
}
