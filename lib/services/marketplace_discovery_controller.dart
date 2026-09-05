import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/public_marketplace_product_adapter.dart';
import 'marketplace_catalog_service.dart';

// Marketplace Revision 43 §0.41 (Slice 7D) — the ONE paged loader every
// customer-facing discovery surface uses.
//
// It exists so that pagination, request-race handling, deduplication and
// fail-closed error handling are written once and proven once, instead of
// being re-implemented (and re-broken) on each of the storefront, catalogue
// and preview screens.
//
// It performs NO Firestore access of any kind and has no fallback that
// could. Its only data source is [MarketplaceCatalogService], whose only
// data source is the trusted callable. If the callable fails, this reports
// a failure state — it never serves a cached or locally-derived product in
// its place.

/// What a discovery surface should currently render. Kept distinct so a
/// screen can tell "still loading" from "loaded, genuinely empty" from
/// "could not load" — collapsing those is how an empty catalogue silently
/// looks the same as an outage.
enum DiscoveryStatus { idle, loading, loaded, empty, failed }

class MarketplaceDiscoveryController extends ChangeNotifier {
  MarketplaceDiscoveryController({
    MarketplaceCatalogService? catalogService,
    this.pageSize = 20,
  }) : _service = catalogService ?? MarketplaceCatalogService();

  final MarketplaceCatalogService _service;
  final int pageSize;

  /// Scope for a single Pet Shop storefront; null is the whole catalogue.
  String? _businessId;

  final List<Product> _products = <Product>[];
  final Set<String> _seenKeys = <String>{};

  DiscoveryStatus _status = DiscoveryStatus.idle;
  MarketplaceCatalogFailureKind? _failure;
  String? _nextCursor;
  bool _loadingMore = false;
  bool _disposed = false;

  /// Monotonic request generation. Every load captures the value current at
  /// its start and discards its own result if the generation has moved on —
  /// this is what stops a slow first page from overwriting the results of a
  /// newer scope, refresh or filter change.
  int _generation = 0;

  List<Product> get products => List.unmodifiable(_products);
  DiscoveryStatus get status => _status;
  MarketplaceCatalogFailureKind? get failure => _failure;
  bool get hasMore => _nextCursor != null;
  bool get isLoadingMore => _loadingMore;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _emit() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Loads the first page, discarding anything previously loaded.
  ///
  /// Calling this again — a pull-to-refresh, a scope change, a retry — bumps
  /// the generation, so any in-flight older request becomes a no-op.
  Future<void> load({String? businessId}) async {
    _businessId = businessId;
    final generation = ++_generation;

    _products.clear();
    _seenKeys.clear();
    _nextCursor = null;
    _loadingMore = false;
    _failure = null;
    _status = DiscoveryStatus.loading;
    _emit();

    await _fetch(generation: generation, cursor: null);
  }

  /// Appends the next page. Ignored while a page is already in flight, when
  /// the server reported exhaustion, or before a first successful load.
  Future<void> loadMore() async {
    if (_loadingMore || _nextCursor == null) return;
    if (_status != DiscoveryStatus.loaded) return;
    _loadingMore = true;
    _emit();
    await _fetch(generation: _generation, cursor: _nextCursor);
  }

  Future<void> _fetch({required int generation, required String? cursor}) async {
    try {
      final page = await _service.fetchProductList(
        pageSize: pageSize,
        cursor: cursor,
        businessId: _businessId,
      );
      // A superseded request must not touch state, not even to report its
      // own failure.
      if (_disposed || generation != _generation) return;

      for (final item in page.items) {
        // Deduplicate on the canonical (businessId, productId) identity, so
        // a cursor overlap or a server retry cannot render a product twice,
        // and a bare productId cannot collide across two businesses.
        final key = publicProductKey(item.businessId, item.productId);
        if (!_seenKeys.add(key)) continue;
        _products.add(item.toProduct());
      }

      _nextCursor = page.nextCursor;
      _loadingMore = false;
      _status = _products.isEmpty && _nextCursor == null
          ? DiscoveryStatus.empty
          : DiscoveryStatus.loaded;
      _failure = null;
      _emit();
    } on MarketplaceCatalogException catch (e) {
      if (_disposed || generation != _generation) return;
      _loadingMore = false;
      // Fail closed and visibly. Whatever was already loaded is discarded
      // rather than left on screen as if it were current: the callable is
      // the only authority on what a customer may see, and it has just
      // declined to answer.
      _products.clear();
      _seenKeys.clear();
      _nextCursor = null;
      _failure = e.kind;
      _status = DiscoveryStatus.failed;
      _emit();
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _loadingMore = false;
      _products.clear();
      _seenKeys.clear();
      _nextCursor = null;
      _failure = MarketplaceCatalogFailureKind.generic;
      _status = DiscoveryStatus.failed;
      _emit();
    }
  }
}
