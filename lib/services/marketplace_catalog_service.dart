import 'package:cloud_functions/cloud_functions.dart';

import '../models/public_marketplace_product.dart';

// Marketplace P1-A Slice 4.8 Phase A (docs/plans/marketplace_p1a_
// compliance_review_implementation_plan_2026-08-21.md §0.14 "Exact
// Dart/API model contracts, frozen" — `lib/services/marketplace_catalog_
// service.dart (new)"): the dormant callable data-source layer wrapping
// `getMarketplaceProductList`/`getMarketplaceProductDetail`
// (`functions/src/marketplace/publicCatalog/marketplaceListing.js`).
//
// Dormant in Phase A: no production UI call site invokes this service
// yet — `all_products_page.dart`/`product_detail_page.dart`'s own
// migration to it is Phase B, not this slice, and cannot be safely
// activated or end-to-end verified before Slice 4.5's own §17 activation
// sequence completes in the target environment. This service performs no
// client-side feature-flag check of its own — `MARKETPLACE_LISTING_ENABLED`
// is enforced server-side only; while the flag is off, every call
// receives the server's own `failed-precondition` response, mapped below
// to [MarketplaceCatalogFailureKind.generic] like any other unrecognized
// code.
//
// Testability note: `cloud_functions`' own `FirebaseFunctions`/
// `HttpsCallable` classes both have library-private constructors
// (confirmed by direct source inspection of the installed package), so no
// fake/mock of either real SDK type is constructible from outside that
// package — this is a genuine, current constraint of this project's
// Firebase Functions callable-service convention, not a design choice
// made here. [_callableInvoker] is the resulting, narrow seam: production
// code leaves it unset and gets the real
// `FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable(name)
// .call(data)` path (below); a test supplies a plain Dart function in its
// place — "a fake callable" — without needing to construct either SDK
// type.
typedef MarketplaceFunctionCaller =
    Future<Object?> Function(String name, Map<String, dynamic> data);

/// A typed classification of why a catalog call did not return a usable
/// result — never a raw, generic exception string (§0.14 "Error mapping").
enum MarketplaceCatalogFailureKind {
  /// The server's own uniform `not-found` outcome (absent, ineligible,
  /// inactive, or unapproved product — the server never distinguishes
  /// these to the caller).
  notFound,

  /// The server's own `internal` outcome (a genuine query/read failure),
  /// or a response missing `items`/`nextCursor`/`item` — the live server
  /// contract never actually produces this, but a malformed/mocked
  /// response could; never silently coerced to an empty list.
  unavailableRetry,

  /// Any other `FirebaseFunctionsException` code, or any other
  /// unexpected failure.
  generic,
}

/// Thrown by every [MarketplaceCatalogService] method on any non-success
/// outcome — a typed result, never a bare/generic exception.
class MarketplaceCatalogException implements Exception {
  final MarketplaceCatalogFailureKind kind;

  const MarketplaceCatalogException(this.kind);

  @override
  String toString() => 'MarketplaceCatalogException($kind)';
}

/// A single page of [PublicProductListItem]s plus the opaque cursor for
/// the next page. The cursor is treated as an opaque string throughout —
/// never decoded, validated, or reconstructed client-side (§0.14 "No
/// cursor model class").
typedef MarketplaceProductPage = ({
  List<PublicProductListItem> items,
  String? nextCursor,
});

/// europe-west3 — matches the live, committed `functions/index.js` export
/// of `getMarketplaceProductList`/`getMarketplaceProductDetail` exactly.
const String marketplaceFunctionsRegion = 'europe-west3';

class MarketplaceCatalogService {
  MarketplaceCatalogService({
    FirebaseFunctions? functions,
    MarketplaceFunctionCaller? callableInvoker,
  }) : _callableInvoker = callableInvoker ?? _defaultInvoker(functions);

  static MarketplaceFunctionCaller _defaultInvoker(
    FirebaseFunctions? functions,
  ) {
    final resolved =
        functions ??
        FirebaseFunctions.instanceFor(region: marketplaceFunctionsRegion);
    return (name, data) async {
      final result = await resolved.httpsCallable(name).call(data);
      return result.data;
    };
  }

  final MarketplaceFunctionCaller _callableInvoker;

  MarketplaceCatalogFailureKind _mapFailureCode(String code) {
    switch (code) {
      case 'not-found':
        return MarketplaceCatalogFailureKind.notFound;
      case 'internal':
        return MarketplaceCatalogFailureKind.unavailableRetry;
      default:
        return MarketplaceCatalogFailureKind.generic;
    }
  }

  Future<MarketplaceProductPage> fetchProductList({
    int pageSize = 20,
    String? cursor,
  }) async {
    final Object? data;
    try {
      data = await _callableInvoker('getMarketplaceProductList', {
        'pageSize': pageSize,
        'cursor': ?cursor,
      });
    } on FirebaseFunctionsException catch (e) {
      throw MarketplaceCatalogException(_mapFailureCode(e.code));
    }

    if (data is! Map) {
      throw const MarketplaceCatalogException(
        MarketplaceCatalogFailureKind.unavailableRetry,
      );
    }
    final map = Map<String, dynamic>.from(data);
    final rawItems = map['items'];
    if (rawItems is! List) {
      throw const MarketplaceCatalogException(
        MarketplaceCatalogFailureKind.unavailableRetry,
      );
    }
    // items/nextCursor missing is a parse failure (above); nextCursor
    // itself being absent/null is the ordinary, valid "exhausted" signal
    // and is not an error condition.
    if (!map.containsKey('nextCursor')) {
      throw const MarketplaceCatalogException(
        MarketplaceCatalogFailureKind.unavailableRetry,
      );
    }

    final List<PublicProductListItem> items;
    try {
      items = rawItems
          .map(
            (e) => PublicProductListItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false);
    } catch (_) {
      throw const MarketplaceCatalogException(
        MarketplaceCatalogFailureKind.unavailableRetry,
      );
    }

    final nextCursor = map['nextCursor'];
    return (items: items, nextCursor: nextCursor is String ? nextCursor : null);
  }

  Future<PublicProductDetail> fetchProductDetail({
    required String businessId,
    required String productId,
  }) async {
    final Object? data;
    try {
      data = await _callableInvoker('getMarketplaceProductDetail', {
        'businessId': businessId,
        'productId': productId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw MarketplaceCatalogException(_mapFailureCode(e.code));
    }

    if (data is! Map) {
      throw const MarketplaceCatalogException(
        MarketplaceCatalogFailureKind.unavailableRetry,
      );
    }
    final map = Map<String, dynamic>.from(data);
    final rawItem = map['item'];
    if (rawItem is! Map) {
      throw const MarketplaceCatalogException(
        MarketplaceCatalogFailureKind.unavailableRetry,
      );
    }

    try {
      return PublicProductDetail.fromJson(Map<String, dynamic>.from(rawItem));
    } catch (_) {
      throw const MarketplaceCatalogException(
        MarketplaceCatalogFailureKind.unavailableRetry,
      );
    }
  }
}
