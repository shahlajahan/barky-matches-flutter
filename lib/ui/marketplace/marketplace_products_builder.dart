import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/marketplace_discovery_controller.dart';

/// Marketplace Revision 43 §0.41 (Slice 7D) — a drop-in replacement for the
/// `StreamBuilder<QuerySnapshot>` that customer-facing surfaces used to build
/// over a direct `products` query.
///
/// It owns a [MarketplaceDiscoveryController], so every surface that uses it
/// inherits the same request-race handling, deduplication, pagination and
/// fail-closed error behaviour without restating them. It performs no
/// Firestore access and has no direct-read fallback.
///
/// [builder] receives the resolved status and the products the SERVER
/// returned. It is never handed a locally-filtered or cached list.
class MarketplaceProductsBuilder extends StatefulWidget {
  const MarketplaceProductsBuilder({
    super.key,
    this.businessId,
    this.pageSize = 20,
    required this.builder,
    this.controllerOverride,
  });

  /// Scopes the request to one Pet Shop storefront; null is the whole
  /// public catalogue.
  final String? businessId;
  final int pageSize;

  final Widget Function(
    BuildContext context,
    DiscoveryStatus status,
    List<Product> products,
  )
  builder;

  /// Test-only seam. Production leaves it unset and gets a controller backed
  /// by the real callable.
  @visibleForTesting
  final MarketplaceDiscoveryController? controllerOverride;

  @override
  State<MarketplaceProductsBuilder> createState() =>
      _MarketplaceProductsBuilderState();
}

class _MarketplaceProductsBuilderState
    extends State<MarketplaceProductsBuilder> {
  late final MarketplaceDiscoveryController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controllerOverride == null;
    _controller =
        widget.controllerOverride ??
        MarketplaceDiscoveryController(pageSize: widget.pageSize);
    _controller.addListener(_onChanged);
    _controller.load(businessId: widget.businessId);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MarketplaceProductsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A changed scope must reload rather than keep showing the previous
    // shop's products; the controller discards the superseded request.
    if (oldWidget.businessId != widget.businessId) {
      _controller.load(businessId: widget.businessId);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _controller.status, _controller.products);
}
