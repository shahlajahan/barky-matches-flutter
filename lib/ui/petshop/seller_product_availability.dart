import 'package:cloud_firestore/cloud_firestore.dart';

/// Whether a seller currently has at least one product a customer can actually
/// see.
///
/// The Pet Shop profile previously offered "Buy Now" unconditionally, so a
/// shop with no published products routed every visitor into a guaranteed-empty
/// catalogue. This resolves the same authoritative visibility contract the
/// customer catalogue itself uses — `all_products_page.dart`'s seller-scoped
/// query — rather than a weaker "any product exists" check:
///
///   businesses/{sellerId}/products
///     where isActive == true
///     where moderationStatus == 'approved'
///
/// Those are exactly the two conditions `firestore.rules` requires for a
/// non-owner to read a product, so a customer who cannot see a product cannot
/// make this query report one either. Drafts, pending, rejected, revoked and
/// inactive products all fail at least one condition and are excluded.
///
/// The query is bounded with `limit(1)` — it answers "any?" and never reads the
/// catalogue. Both filters are equality on a single collection, so Firestore's
/// automatic single-field indexes cover it; no composite index is required and
/// no Rules change is involved.
enum SellerProductAvailability {
  /// Still resolving. Callers must not expose an actionable buy control yet.
  unknown,

  /// Resolved: nothing is customer-visible. Also used for a failed read, so
  /// the control fails closed rather than misleading the customer.
  none,

  /// Resolved: at least one customer-visible product exists.
  available,
}

/// Resolves [SellerProductAvailability] for [sellerId].
///
/// Returns [SellerProductAvailability.none] for a blank seller id and for any
/// query failure (permission, offline, transient) — failing closed, never
/// throwing into the widget tree.
Future<SellerProductAvailability> resolveSellerProductAvailability(
  String? sellerId, {
  FirebaseFirestore? firestore,
}) async {
  final id = sellerId?.trim();
  if (id == null || id.isEmpty) return SellerProductAvailability.none;

  try {
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('businesses')
        .doc(id)
        .collection('products')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved')
        .limit(1)
        .get();
    return snapshot.docs.isEmpty
        ? SellerProductAvailability.none
        : SellerProductAvailability.available;
  } catch (_) {
    return SellerProductAvailability.none;
  }
}
