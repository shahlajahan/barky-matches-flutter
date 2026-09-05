import 'package:flutter/material.dart';

import '../../models/public_marketplace_product.dart';
import '../../models/public_marketplace_product_adapter.dart';
import '../../services/marketplace_catalog_service.dart';
import '../../services/marketplace_discovery_controller.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/models/product_media.dart';
import 'package:barky_matches_fixed/models/media_item.dart';
import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/common/gallery_viewer_page.dart';
import 'package:barky_matches_fixed/ui/common/smart_video_preview.dart';
import 'package:barky_matches_fixed/ui/checkout/checkout_page.dart';
import 'package:barky_matches_fixed/services/petshop_checkout_service.dart';

import 'package:barky_matches_fixed/ui/product/product_detail_page.dart';
import 'package:barky_matches_fixed/ui/product/seller_profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barky_matches_fixed/services/product_favorite_service.dart';
import 'package:barky_matches_fixed/ui/product/favorite_products_page.dart';
import 'package:barky_matches_fixed/promotion/models/promotion_enums.dart';
import 'package:barky_matches_fixed/promotion/ranking/promotion_ranking_engine.dart';
import 'package:barky_matches_fixed/promotion/ranking/promotion_ranking_state.dart';
import 'package:barky_matches_fixed/promotion/services/promotion_analytics_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

class AllProductsPage extends StatefulWidget {
  final String? initialSellerId;
  final String? initialSellerName;

  const AllProductsPage({
    super.key,
    this.initialSellerId,
    this.initialSellerName,
  });

  @override
  State<AllProductsPage> createState() => _AllProductsPageState();
}

class _AllProductsPageState extends State<AllProductsPage> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String? _selectedCategory;
  String? _selectedShippingMode;
  String _sort = 'recommended';
  String? _sellerIdFilter;
  Map<String, List<Map<String, dynamic>>> _productPromotionProjections = {};

  final List<CartItem> _cart = [];

  bool get _hasSellerScope => widget.initialSellerId != null;

  @override
  void initState() {
    super.initState();
    _sellerIdFilter = widget.initialSellerId;

    _controller = MarketplaceDiscoveryController()
      ..addListener(_onCatalogChanged);
    _startCatalogLoad();

    _loadCartFromFirestore(); // ✅ فقط اینجا
    _loadProductPromotionProjections();

    _searchController.addListener(() {
      if (_query != _searchController.text.trim()) {
        setState(() {
          _query = _searchController.text.trim();
        });
      }
    });
  }

  Future<void> _loadProductPromotionProjections() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('promotion_active')
          .where('targetType', isEqualTo: PromotionTargetType.product.value)
          .get();
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final targetId = data['targetId']?.toString();
        if (targetId == null || targetId.isEmpty) continue;
        grouped.putIfAbsent(targetId, () => []).add(data);
      }
      if (mounted) setState(() => _productPromotionProjections = grouped);
    } catch (_) {
      // A projection read failure must leave products organic, never promoted.
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onCatalogChanged);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _selectedCategory = null;
      _selectedShippingMode = null;
      _sort = 'recommended';
      _sellerIdFilter = widget.initialSellerId;
    });
  }

  /// Slice 7D — the single catalogue service used for both the product
  /// list and cart re-hydration.
  final MarketplaceCatalogService _catalogService = MarketplaceCatalogService();

  /// Slice 7D — the catalogue's only data source. Scoped to one shop when
  /// the page was opened from a storefront, otherwise the whole public
  /// catalogue. There is no Firestore fallback.
  late final MarketplaceDiscoveryController _controller;

  void _onCatalogChanged() {
    if (mounted) setState(() {});
  }

  void _startCatalogLoad() {
    final sellerId = widget.initialSellerId?.trim();
    _controller.load(
      businessId: _hasSellerScope && sellerId != null && sellerId.isNotEmpty
          ? sellerId
          : null,
    );
  }

  void _addToBasket(Product product) {
    final l10n = AppLocalizations.of(context)!;
    final index = _cart.indexWhere((e) => e.productId == product.id);

    setState(() {
      if (index >= 0) {
        final old = _cart[index];
        _cart[index] = CartItem(
          productId: old.productId,
          product: old.product,
          shopId: old.shopId,
          name: old.name,
          price: old.price,
          quantity: old.quantity + 1,
        );
      } else {
        _cart.add(
          CartItem(
            productId: product.id,
            product: product,
            shopId: product.businessId,
            name: product.name,
            price: product.customerPrice,
            quantity: 1,
          ),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.addedToBasket(product.name)),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _syncCartToFirestore();
  }

  void _changeQuantity(CartItem item, int delta) {
    final index = _cart.indexWhere((e) => e.productId == item.productId);
    if (index < 0) return;

    setState(() {
      final current = _cart[index];
      final newQty = current.quantity + delta;

      if (newQty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index] = CartItem(
          productId: current.productId,
          product: current.product,
          shopId: current.shopId,
          name: current.name,
          price: current.price,
          quantity: newQty,
        );
      }
    });
  }

  int get _cartCount {
    return _cart.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  Future<void> _loadCartFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || FirebaseAuth.instance.currentUser?.isAnonymous == true) {
      return;
    }

    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('reconcileVerifiedPaidCart').call();
    } catch (error, stackTrace) {
      debugPrint('Unable to reconcile verified paid cart: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart')
        .get();

    // Marketplace Revision 43 §0.41 (Slice 7D) — cart hydration.
    //
    // A stored cart row is a historical snapshot of what the customer once
    // added. It is NOT evidence that the product is still buyable, and its
    // cached `product`/`price` fields are NOT authoritative: since the row
    // was written the product may have been unpublished, reclassified, had
    // its evidence expire or its approval revoked, or had its business
    // generation rotated.
    //
    // Previously this read the live product document directly and, when that
    // read failed, fell back to the cached snapshot or synthesized a
    // `Product(isActive: true)` — presenting an unavailable product as ready
    // to buy. Now every row is re-hydrated through the trusted callable, and
    // ONLY rows the server still returns as available become cart items.
    // Anything else is dropped from the purchasable cart.
    //
    // This does NOT make order creation safe. The server-side order boundary
    // still does not evaluate live eligibility (Revision 39 §0.37 E); that
    // remains an open blocker and Atomic Checkout is a separate slice.
    final rows = snapshot.docs
        .map((doc) {
          final data = doc.data();
          return (
            data: data,
            productId: data['productId']?.toString() ?? doc.id,
            shopId: data['shopId']?.toString() ?? '',
          );
        })
        .where((r) => r.shopId.isNotEmpty && r.productId.isNotEmpty)
        .toList(growable: false);

    // Hydrate in server-bounded chunks; a failure of any chunk leaves that
    // chunk's rows unavailable rather than falling back to cached data.
    final hydrated = <String, PublicProductDetail?>{};
    for (var i = 0; i < rows.length; i += maxBatchProducts) {
      final slice = rows.skip(i).take(maxBatchProducts);
      final refs = slice
          .map((r) => PublicProductRef(r.shopId, r.productId))
          .toList(growable: false);
      try {
        hydrated.addAll(await _catalogService.fetchProductBatch(refs: refs));
      } on MarketplaceCatalogException {
        for (final ref in refs) {
          hydrated[publicProductKey(ref.businessId, ref.productId)] = null;
        }
      }
    }

    var droppedCount = 0;
    final restoredItems = <CartItem>[];
    for (final row in rows) {
      final detail = hydrated[publicProductKey(row.shopId, row.productId)];
      if (detail == null) {
        // Requested and not returned as available: the customer may no
        // longer see or buy this. It leaves the cart rather than lingering
        // as a stale, purchasable-looking row.
        droppedCount += 1;
        continue;
      }
      final product = detail.toProduct();
      restoredItems.add(
        CartItem(
          productId: row.productId,
          product: product,
          shopId: row.shopId,
          // Name and price come from the SERVER's current projection, never
          // from the stored row.
          name: product.name,
          price: product.customerPrice,
          quantity: (row.data['quantity'] as num?)?.toInt() ?? 1,
          allowedCarrierCodes: product.allowedCarrierCodes,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _cart
        ..clear()
        ..addAll(restoredItems);
    });

    // Tell the customer their cart changed. Items disappearing silently
    // would be worse than the stale-but-visible behaviour this replaces.
    if (droppedCount > 0 && mounted) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cartItemsNoLongerAvailable(droppedCount))),
        );
      }
    }
  }

  void _openBasket() {
    final l10n = AppLocalizations.of(context)!;
    Future<Map<String, dynamic>?> pricingFuture = _loadBasketPricing(
      List<CartItem>.from(_cart),
    );

    Future<Map<String, dynamic>?> refreshBasketPricing() {
      pricingFuture = _loadBasketPricing(List<CartItem>.from(_cart));
      return pricingFuture;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.78,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // HANDLE
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // HEADER
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(l10n.basketTitle, style: AppTheme.h2()),
                          const Spacer(),
                          Text(
                            l10n.basketItemsCount(_cartCount),
                            style: AppTheme.caption(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // LIST
                    Expanded(
                      child: _cart.isEmpty
                          ? Center(
                              child: Text(
                                l10n.yourBasketIsEmpty,
                                style: AppTheme.body(color: AppTheme.muted),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _cart.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, index) {
                                final item = _cart[index];
                                final p = item.product;

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 72,
                                          height: 72,
                                          child: _BasketThumb(product: p),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // INFO
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTheme.body(
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              p.businessName ??
                                                  l10n.sellerLabel,
                                              style: AppTheme.caption(
                                                color: AppTheme.muted,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "₺${(item.product.customerPrice * item.quantity).toStringAsFixed(2)}",
                                              style: AppTheme.h3(
                                                color: const Color(0xFF9E1B4F),
                                                weight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // QUANTITY
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              setModalState(() {
                                                _changeQuantity(item, -1);
                                                refreshBasketPricing();
                                                _syncCartToFirestore();
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                          ),
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            transitionBuilder:
                                                (child, animation) {
                                                  return ScaleTransition(
                                                    scale: animation,
                                                    child: FadeTransition(
                                                      opacity: animation,
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                            child: Text(
                                              item.quantity.toString(),
                                              key: ValueKey(
                                                item.quantity,
                                              ), // 🔥 مهم
                                              style: AppTheme.body(
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              setModalState(() {
                                                _changeQuantity(item, 1);
                                                refreshBasketPricing();
                                                _syncCartToFirestore();
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // FOOTER
                    if (_cart.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: Colors.black.withOpacity(0.06),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            FutureBuilder<Map<String, dynamic>?>(
                              future: pricingFuture,
                              builder: (context, snapshot) {
                                final rawTotal = snapshot.data?['grandTotal'];
                                final total = rawTotal is num
                                    ? rawTotal.toDouble()
                                    : null;
                                return Row(
                                  children: [
                                    Text(
                                      l10n.totalLabel,
                                      style: AppTheme.body(
                                        color: AppTheme.textDark,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (snapshot.connectionState ==
                                            ConnectionState.waiting ||
                                        total == null)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      Text(
                                        "₺${total.toStringAsFixed(2)}",
                                        style: AppTheme.h3(
                                          color: const Color(0xFF9E1B4F),
                                          weight: FontWeight.w900,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // CHECKOUT
                            ElevatedButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CheckoutPage(
                                      items: List<CartItem>.from(_cart),
                                      onPaymentVerified: _loadCartFromFirestore,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(l10n.checkoutButton),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _loadBasketPricing(List<CartItem> items) async {
    if (items.isEmpty) return null;
    try {
      final result = await PetshopCheckoutService().calculatePricing(
        items: items
            .map(
              (item) => {
                ...item.toJson(),
                'carrier': '',
                'selectedCarrier': '',
              },
            )
            .toList(),
        carrier: '',
      );
      final pricing = result['pricing'];
      return pricing is Map ? Map<String, dynamic>.from(pricing) : null;
    } catch (error, stackTrace) {
      debugPrint('Unable to load basket pricing: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _syncCartToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || FirebaseAuth.instance.currentUser?.isAnonymous == true) {
      return;
    }

    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart');

    final batch = FirebaseFirestore.instance.batch();

    // پاک کردن قبلی‌ها (ساده‌ترین روش)
    final existing = await cartRef.get();
    for (var doc in existing.docs) {
      batch.delete(doc.reference);
    }

    // اضافه کردن جدید
    for (var item in _cart) {
      final doc = cartRef.doc(item.productId);
      batch.set(doc, {
        "productId": item.productId,
        "name": item.name,
        "price": item.price,
        "quantity": item.quantity,
        "shopId": item.shopId,
        "shippingMode": item.product.shippingMode,
        "shippingPayer": item.product.shippingPayer,
        "shippingFee": item.product.shippingFee,
        "freeShippingThreshold": item.product.freeShippingThreshold,
        "allowFreeShipping": item.product.allowFreeShipping,
        "allowedCarrierCodes": item.product.allowedCarrierCodes,
        "weightKg": item.product.weightKg,
        "lengthCm": item.product.lengthCm,
        "widthCm": item.product.widthCm,
        "heightCm": item.product.heightCm,
        "fixedDesi": item.product.fixedDesi,
        "product": item.product.toJson(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  List<Product> _applyFilters(List<Product> products) {
    var result = products.where((p) {
      if (_sellerIdFilter != null && p.businessId != _sellerIdFilter) {
        return false;
      }

      if (_selectedCategory != null &&
          _selectedCategory!.isNotEmpty &&
          p.category.split(">").first.trim() != _selectedCategory) {
        return false;
      }

      if (_selectedShippingMode != null &&
          _selectedShippingMode!.isNotEmpty &&
          p.shippingMode != _selectedShippingMode) {
        return false;
      }

      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final haystack = [
          p.name,
          p.description,
          p.brand ?? '',
          p.businessName ?? '',
          p.category,
        ].join(' ').toLowerCase();

        if (!haystack.contains(q)) return false;
      }

      return true;
    }).toList();

    switch (_sort) {
      case 'price_low':
        result.sort((a, b) => a.finalPrice.compareTo(b.finalPrice));
        break;
      case 'price_high':
        result.sort((a, b) => b.finalPrice.compareTo(a.finalPrice));
        break;
      case 'discount':
        result.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
        break;
      case 'newest':
        result.sort((a, b) {
          final aa = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bb = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bb.compareTo(aa);
        });
        break;
      default:
        return _rankRecommendedProducts(result);
    }

    return result;
  }

  List<Product> _rankRecommendedProducts(List<Product> products) {
    int organicScore(Product p) {
      var score = 0;
      if (p.salePrice != null && p.salePrice! < p.price) score += 20;
      if (p.allowFreeShipping) score += 10;
      if (p.media.isNotEmpty) score += 8;
      if ((p.businessName ?? '').isNotEmpty) score += 5;
      if (p.stock > 0) score += 5;
      return score;
    }

    final now = DateTime.now();
    return const PromotionRankingEngine()
        .rank(
          products.map(
            (product) => PromotionRankingInput<Product>(
              item: product,
              targetType: PromotionTargetType.product,
              targetId: product.id,
              organicScore: organicScore(product),
              ownerId: product.businessId,
              promotionState: product.isActive && product.stock > 0
                  ? PromotionRankingState.resolve(
                      targetType: PromotionTargetType.product,
                      targetId: product.id,
                      projections:
                          _productPromotionProjections[product.id] ?? const [],
                      now: now,
                    )
                  : PromotionRankingState.organic(
                      targetType: PromotionTargetType.product,
                      targetId: product.id,
                    ),
            ),
          ),
        )
        .map((ranked) => ranked.item)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _sellerIdFilter != null
        ? (widget.initialSellerName?.trim().isNotEmpty == true
              ? widget.initialSellerName!
              : l10n.sellerProductsTitle)
        : l10n.allProductsTitle;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(title),
        actions: [
          /// FAVORITES
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseAuth.instance.currentUser == null ||
                    FirebaseAuth.instance.currentUser!.isAnonymous
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection('favoriteProducts')
                      .snapshots(),

            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;

              return IconButton(
                onPressed: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (_) =>
                          FavoriteProductsPage(onAddToBasket: _addToBasket),
                    ),
                  );
                },

                icon: Stack(
                  clipBehavior: Clip.none,

                  children: [
                    const Icon(Icons.favorite_border),

                    if (count > 0)
                      Positioned(
                        right: -6,
                        top: -6,

                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.red,

                            borderRadius: BorderRadius.circular(100),
                          ),

                          child: Text(
                            count.toString(),

                            style: const TextStyle(
                              color: Colors.white,

                              fontSize: 10,

                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          /// BASKET
          IconButton(
            onPressed: _cart.isEmpty ? null : _openBasket,

            icon: Stack(
              clipBehavior: Clip.none,

              children: [
                const Icon(LucideIcons.shoppingBag, color: Colors.white),

                Positioned(
                  right: -6,
                  top: -6,
                  child: AnimatedScale(
                    scale: _cartCount > 0 ? 1 : 0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                        child: child,
                      ),
                      child: Container(
                        key: ValueKey(_cartCount),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          _cartCount.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),
        ],
      ),
      body: Builder(
        builder: (context) {
          // Marketplace Revision 43 §0.41 (Slice 7D) — the customer
          // catalogue. Previously a direct `collectionGroup('products')`
          // stream (or a seller-scoped subcollection stream) filtered on
          // `isActive`/`moderationStatus`. Those two fields are not the
          // publication contract: eligibility also depends on the compliance
          // decision, the pilot approval, evidence validity, the business
          // generation and the pilot class, none of which a client can read
          // or evaluate. The server decides, and only what it returns is
          // rendered.
          //
          // Search, category and sort below are UNCHANGED — they were always
          // client-side refinements over the fetched set, and they remain
          // descriptive refinements over the server-returned set. They never
          // decide publishability.
          switch (_controller.status) {
            case DiscoveryStatus.idle:
            case DiscoveryStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case DiscoveryStatus.failed:
              return Center(child: Text(l10n.somethingWentWrong));
            case DiscoveryStatus.empty:
              return Center(
                child: Text(
                  _hasSellerScope
                      ? l10n.noProductsAvailableFromShop
                      : l10n.noActiveProductsFound,
                ),
              );
            case DiscoveryStatus.loaded:
              break;
          }

          final products = _controller.products;

          if (products.isEmpty) {
            return Center(
              child: Text(
                _hasSellerScope
                    ? l10n.noProductsAvailableFromShop
                    : l10n.noActiveProductsFound,
              ),
            );
          }

          final categories =
              products
                  .map((p) => p.category.split(">").first.trim())
                  .where((e) => e.isNotEmpty && e != 'general')
                  .toSet()
                  .toList()
                ..sort();

          final filtered = _applyFilters(products);

          return Column(
            children: [
              Container(
                color: AppTheme.bg,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.searchProductsHint,
                        hintStyle: const TextStyle(fontSize: 14),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.05),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: const Color(0xFF9E1B4F).withOpacity(0.18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 10.0;
                        final availableWidth = constraints.maxWidth;
                        final columns = availableWidth < 600
                            ? 1
                            : availableWidth < 900
                            ? 2
                            : 4;
                        final controlWidth =
                            (availableWidth - (spacing * (columns - 1))) /
                            columns;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            // =========================
                            // CATEGORY
                            // =========================
                            _TopDropDown<String?>(
                              width: controlWidth,
                              value: _selectedCategory,
                              hint: l10n.categoryLabel,
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(l10n.allCategoriesLabel),
                                ),
                                ...categories.map(
                                  (e) => DropdownMenuItem<String?>(
                                    value: e,
                                    child: Text(e),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedCategory = v);
                              },
                            ),

                            // =========================
                            // SHIPPING
                            // =========================
                            _TopDropDown<String?>(
                              width: controlWidth,
                              value: _selectedShippingMode,
                              hint: l10n.shippingLabel,
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(l10n.shippingLabel),
                                ),
                                DropdownMenuItem<String?>(
                                  value: "free_shipping",
                                  child: Text(l10n.freeShippingLabel),
                                ),
                                DropdownMenuItem<String?>(
                                  value: "seller_absorbs",
                                  child: Text(l10n.sellerPaysCargoLabel),
                                ),
                                DropdownMenuItem<String?>(
                                  value: "fixed_price",
                                  child: Text(l10n.fixedCargoLabel),
                                ),
                                DropdownMenuItem<String?>(
                                  value: "carrier_calculated",
                                  child: Text(l10n.calculatedCargoLabel),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedShippingMode = v);
                              },
                            ),

                            // =========================
                            // SORT
                            // =========================
                            _TopDropDown<String>(
                              width: controlWidth,
                              value: _sort,
                              hint: l10n.sortLabel,
                              items: [
                                DropdownMenuItem(
                                  value: "recommended",
                                  child: Text(l10n.recommendedLabel),
                                ),
                                DropdownMenuItem(
                                  value: "newest",
                                  child: Text(l10n.newest),
                                ),
                                DropdownMenuItem(
                                  value: "price_low",
                                  child: Text(l10n.priceLowLabel),
                                ),
                                DropdownMenuItem(
                                  value: "price_high",
                                  child: Text(l10n.priceHighLabel),
                                ),
                                DropdownMenuItem(
                                  value: "discount",
                                  child: Text(l10n.bestDiscountLabel),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _sort = v);
                                }
                              },
                            ),

                            // =========================
                            // CLEAR SELLER ONLY
                            // =========================
                            if (_sellerIdFilter != null && !_hasSellerScope)
                              _FilterActionButton(
                                width: controlWidth,
                                onPressed: () {
                                  setState(() {
                                    _sellerIdFilter = null;
                                  });
                                },
                                icon: const Icon(
                                  Icons.store_mall_directory_outlined,
                                  size: 18,
                                ),
                                label: Text(l10n.sellerLabel),
                              ),

                            // =========================
                            // 🔥 RESET ALL FILTERS
                            // =========================
                            _FilterActionButton(
                              width: controlWidth,
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(l10n.resetFiltersButton),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          l10n.productsCount(filtered.length),
                          style: AppTheme.caption(color: AppTheme.muted),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noProductsMatchFilters,
                          style: AppTheme.body(color: AppTheme.muted),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final desktop = constraints.maxWidth >= 900;
                          final columns = constraints.maxWidth >= 1400 ? 3 : 2;
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                            gridDelegate: desktop
                                ? SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisExtent: 320,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                  )
                                : const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.52,
                                  ),
                            itemCount: filtered.length,
                            itemBuilder: (_, index) {
                              final product = filtered[index];
                              final promotion = PromotionRankingState.resolve(
                                targetType: PromotionTargetType.product,
                                targetId: product.id,
                                projections:
                                    _productPromotionProjections[product.id] ??
                                    const [],
                              );

                              return GestureDetector(
                                onTap: () {
                                  if (promotion.isPromoted &&
                                      promotion.campaignId != null) {
                                    final analytics =
                                        PromotionAnalyticsService();
                                    analytics.recordClick(
                                      campaignId: promotion.campaignId!,
                                      targetType: 'PRODUCT',
                                      targetId: product.id,
                                      placement: 'marketplace_product_list',
                                    );
                                    analytics.recordDetailView(
                                      campaignId: promotion.campaignId!,
                                      targetType: 'PRODUCT',
                                      targetId: product.id,
                                      placement: 'marketplace_product_list',
                                    );
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailPage(
                                        product: product,
                                        onAddToBasket: _addToBasket,
                                      ),
                                    ),
                                  );
                                },
                                child: _CompactProductCard(
                                  product: product,
                                  promotion: promotion,
                                  onAddToBasket: () => _addToBasket(product),
                                  onOpenSeller: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SellerProfilePage(
                                          sellerId: product.businessId,
                                          sellerName: product.businessName,
                                          onAddToBasket: _addToBasket,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopDropDown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;

  const _TopDropDown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 48,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: const Color(0xFF9E1B4F).withOpacity(0.18),
            ),
          ),
        ),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _FilterActionButton extends StatelessWidget {
  final double width;
  final VoidCallback onPressed;
  final Widget icon;
  final Widget label;

  const _FilterActionButton({
    required this.width,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: label,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textDark,
          backgroundColor: Colors.white,
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

class _CompactProductCard extends StatefulWidget {
  final Product product;
  final PromotionRankingState promotion;
  final VoidCallback onAddToBasket;
  final VoidCallback onOpenSeller;

  const _CompactProductCard({
    required this.product,
    required this.promotion,
    required this.onAddToBasket,
    required this.onOpenSeller,
  });

  @override
  State<_CompactProductCard> createState() => _CompactProductCardState();
}

class _CompactProductCardState extends State<_CompactProductCard> {
  bool _showAdded = false;

  Product get product => widget.product;
  PromotionRankingState get promotion => widget.promotion;
  VoidCallback get onAddToBasket => widget.onAddToBasket;
  VoidCallback get onOpenSeller => widget.onOpenSeller;

  Future<void> _handleAdd() async {
    if (_showAdded) return;
    onAddToBasket();
    HapticFeedback.lightImpact();
    setState(() => _showAdded = true);
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (mounted) setState(() => _showAdded = false);
  }

  bool _isUsableUrl(String? url) {
    if (url == null) return false;
    final v = url.trim();
    return v.isNotEmpty &&
        (v.startsWith('http://') || v.startsWith('https://'));
  }

  String? _resolveVideoUrl(ProductMedia media) {
    if (_isUsableUrl(media.playbackUrl)) return media.playbackUrl!.trim();
    if (_isUsableUrl(media.originalUrl)) return media.originalUrl.trim();
    return null;
  }

  void _openGallery(BuildContext context) {
    final safeMedia = product.media.where((media) {
      if (media.type == "video") {
        return _resolveVideoUrl(media) != null;
      }
      return _isUsableUrl(media.originalUrl);
    }).toList();

    if (safeMedia.isEmpty) return;

    final items = safeMedia.map((media) {
      final videoUrl = _resolveVideoUrl(media);
      return MediaItem(
        url: media.type == "video" ? videoUrl! : media.originalUrl,
        type: media.type == "video" ? MediaType.video : MediaType.image,
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryViewerPage(items: items, initialIndex: 0),
      ),
    );
  }

  List<String> _shippingChips(BuildContext context, Product p) {
    final l10n = AppLocalizations.of(context)!;
    final List<String> out = [];

    if (p.shippingMode == "free_shipping" ||
        p.shippingMode == "seller_absorbs") {
      out.add(l10n.freeCargoLabel);
    } else if (p.shippingMode == "fixed_price" && p.shippingFee != null) {
      out.add(l10n.cargoPriceLabel("₺${p.shippingFee!.toStringAsFixed(0)}"));
    } else if (p.shippingMode == "carrier_calculated") {
      out.add(l10n.cargoCalculatedLabel);
    }

    if (p.freeShippingThreshold != null && p.freeShippingThreshold! > 0) {
      out.add(
        l10n.freeOverLabel("₺${p.freeShippingThreshold!.toStringAsFixed(0)}"),
      );
    }

    if (p.kdvRate != null) {
      out.add(l10n.vatRateLabel(p.kdvRate!.toStringAsFixed(0)));
    }

    if (p.taxIncluded == true) {
      out.add(l10n.vatIncludedLabel);
    }

    if (p.originCity != null && p.originCity!.trim().isNotEmpty) {
      out.add(p.originCity!);
    }

    return out;
  }

  String _smartTitle(String title) {
    final words = title.trim().split(' ');

    // اگر خیلی کوتاهه → همونو بده
    if (words.length <= 6) return title;

    // فقط 6 کلمه اول
    final short = words.take(6).join(' ');

    return "$short...";
  }

  @override
  Widget build(BuildContext context) {
    final favoriteService = ProductFavoriteService();
    final l10n = AppLocalizations.of(context)!;
    final hasDiscount =
        product.salePrice != null &&
        product.salePrice! > 0 &&
        product.salePrice! < product.price;

    final firstMedia = product.media.isNotEmpty
        ? product.media.first.originalUrl
        : null;

    final mobileCard = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================
          // IMAGE
          // =====================
          SizedBox(
            height: 100,

            child: Stack(
              clipBehavior: Clip.none,

              children: [
                /// IMAGE TAP ONLY
                GestureDetector(
                  onTap: () => _openGallery(context),

                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),

                    child: Container(
                      height: 100,
                      width: double.infinity,
                      color: Colors.white,

                      child: _isUsableUrl(firstMedia)
                          ? CachedNetworkImage(
                              imageUrl: firstMedia!,
                              fit: BoxFit.contain,
                            )
                          : const Center(
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                    ),
                  ),
                ),

                /// DISCOUNT BADGE
                Positioned(
                  top: 6,
                  left: 6,

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),

                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(6),
                    ),

                    child: Text(
                      "-${product.discountPercent}%",

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                /// OUT OF STOCK
                if (product.stock <= 0)
                  Positioned(
                    top: 6,
                    right: 6,

                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(6),
                      ),

                      child: Text(
                        l10n.outOfStockLabel,

                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                /// FAVORITE
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await favoriteService.toggleFavorite(
                        productId: product.id,
                        shopId: product.businessId,
                        name: product.name,
                        imageUrl: product.media.isNotEmpty
                            ? product.media.first.originalUrl
                            : null,
                        price: product.customerPrice,
                      );

                      (context as Element).markNeedsBuild();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: FutureBuilder<bool>(
                        future: favoriteService.isFavorite(product.id).first,
                        builder: (context, snapshot) {
                          final isFavorite = snapshot.data ?? false;
                          return Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: isFavorite ? Colors.red : Colors.black54,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =====================
          // CONTENT
          // =====================
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SELLER
                GestureDetector(
                  onTap: onOpenSeller,
                  child: Text(
                    product.businessName?.trim().isNotEmpty == true
                        ? product.businessName!
                        : l10n.sellerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.caption(
                      color: Colors.grey.shade700,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // NAME
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "${_brand(product.name)} ",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: _rest(product.name),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // RATING
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFFFF9800),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "4.5",
                      style: AppTheme.caption(
                        weight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "(128)",
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // PRICE
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasDiscount)
                            Text(
                              "₺${product.customerReferencePrice.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            "₺${product.customerPrice.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF9E1B4F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasDiscount)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "-${product.discountPercent}%",
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 6),

                // 🔥 FIXED BADGE AREA (تعادل همه کارت‌ها)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildBadges(l10n, product),
                ),

                const SizedBox(height: 8),

                // BUTTONS
                Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 24,
                      child: OutlinedButton(
                        onPressed: onOpenSeller,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: const Color(0xFF9E1B4F).withOpacity(0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Icon(Icons.storefront_outlined, size: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 24,
                        child: ElevatedButton(
                          onPressed: product.stock > 0 && !_showAdded
                              ? _handleAdd
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Row(
                              key: ValueKey(_showAdded),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _showAdded
                                      ? Icons.check_rounded
                                      : Icons.add_shopping_cart,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showAdded
                                      ? l10n.addedToCart
                                      : l10n.addButton,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final card = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) return mobileCard;
        return _buildDesktopCard(
          context,
          constraints.maxWidth,
          l10n,
          hasDiscount,
        );
      },
    );
    if (!promotion.isPromoted || promotion.campaignId == null) return card;
    return VisibilityDetector(
      key: Key('promotion-product-${product.id}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction < 0.5) return;
        PromotionAnalyticsService().recordImpression(
          campaignId: promotion.campaignId!,
          targetType: 'PRODUCT',
          targetId: product.id,
          placement: 'marketplace_product_list',
        );
      },
      child: card,
    );
  }

  Widget _buildDesktopCard(
    BuildContext context,
    double width,
    AppLocalizations l10n,
    bool hasDiscount,
  ) {
    final favoriteService = ProductFavoriteService();
    final firstMedia = product.media.isNotEmpty
        ? product.media.first.originalUrl
        : null;
    final imageWidth = width.clamp(160.0, 220.0);

    return Container(
      height: 320,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: imageWidth,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _openGallery(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: imageWidth,
                      height: double.infinity,
                      color: const Color(0xFFFAF7F9),
                      child: _isUsableUrl(firstMedia)
                          ? CachedNetworkImage(
                              imageUrl: firstMedia!,
                              fit: BoxFit.contain,
                            )
                          : const Center(
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                    ),
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _desktopBadge(
                      '-${product.discountPercent}%',
                      const Color(0xFFE53935),
                    ),
                  ),
                if (product.stock <= 0)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _desktopBadge(l10n.outOfStockLabel, Colors.black87),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await favoriteService.toggleFavorite(
                        productId: product.id,
                        shopId: product.businessId,
                        name: product.name,
                        imageUrl: firstMedia,
                        price: product.customerPrice,
                      );
                      if (mounted) setState(() {});
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: FutureBuilder<bool>(
                        future: favoriteService.isFavorite(product.id).first,
                        builder: (context, snapshot) => Icon(
                          snapshot.data ?? false
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 19,
                          color: snapshot.data ?? false
                              ? Colors.red
                              : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onOpenSeller,
                  child: Text(
                    product.businessName?.trim().isNotEmpty == true
                        ? product.businessName!
                        : l10n.sellerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.caption(
                      color: Colors.grey.shade700,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.h3(weight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 17,
                      color: Color(0xFFFF9800),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '4.5',
                      style: AppTheme.caption(weight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(128)',
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasDiscount)
                  Text(
                    '₺${product.customerReferencePrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      '₺${product.customerPrice.toStringAsFixed(2)}',
                      style: AppTheme.h2(
                        color: const Color(0xFF9E1B4F),
                        weight: FontWeight.w900,
                      ),
                    ),
                    if (hasDiscount) ...[
                      const SizedBox(width: 8),
                      _desktopBadge(
                        '-${product.discountPercent}%',
                        const Color(0xFF2E7D32),
                        foreground: Colors.white,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _buildBadges(l10n, product),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(LucideIcons.package, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      l10n.stockLabel(product.stock),
                      style: AppTheme.caption(),
                    ),
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 150,
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: product.stock > 0 && !_showAdded
                          ? _handleAdd
                          : null,
                      icon: Icon(
                        _showAdded
                            ? Icons.check_rounded
                            : Icons.add_shopping_cart,
                        size: 16,
                      ),
                      label: Text(
                        _showAdded ? l10n.addedToCart : l10n.addButton,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopBadge(
    String text,
    Color background, {
    Color foreground = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  List<Widget> _buildBadges(AppLocalizations l10n, Product product) {
    final badges = <Widget>[];

    // 🚚 shipping
    if (product.shippingFee == 0) {
      badges.add(
        _badge(l10n.freeCargoLabel, Colors.blue, const Color(0xFFE3F2FD)),
      );
    } else if (product.shippingFee != null) {
      badges.add(
        _badge(
          l10n.cargoPriceLabel(product.shippingFee!.toInt().toString()),
          Colors.blue,
          const Color(0xFFE3F2FD),
        ),
      );
    } else {
      badges.add(
        _badge(l10n.cargoCalculatedLabel, Colors.blue, const Color(0xFFE3F2FD)),
      );
    }

    // ⏱ delivery
    if (product.maxDeliveryDays != null) {
      badges.add(
        _badge(
          l10n.daysLabel(product.maxDeliveryDays.toString()),
          const Color(0xFF558B2F),
          const Color(0xFFF1F8E9),
        ),
      );
    }

    // 📦 stock
    if (product.stock > 0) {
      badges.add(
        _badge(
          l10n.inStockLabel,
          const Color(0xFF2E7D32),
          const Color(0xFFE8F5E9),
        ),
      );
    }

    // ⚠️ اگر کمتر از 3 تا بود → spacer
    while (badges.length < 3) {
      badges.add(const SizedBox(height: 10));
    }

    return badges
        .take(3)
        .map(
          (w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: w),
        )
        .toList();
  }

  Widget _badge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _brand(String title) {
    final words = title.trim().split(' ');
    return words.isNotEmpty ? words.first : "";
  }

  String _rest(String title) {
    final words = title.trim().split(' ');
    if (words.length <= 1) return "";

    return "${words.skip(1).take(5).join(' ')}...";
  }
}

class _MediaSlider extends StatefulWidget {
  final List<ProductMedia> media;
  final String? Function(ProductMedia media) resolveVideoUrl;

  const _MediaSlider({required this.media, required this.resolveVideoUrl});

  @override
  State<_MediaSlider> createState() => _MediaSliderState();
}

class _MediaSliderState extends State<_MediaSlider> {
  final PageController _controller = PageController(viewportFraction: 1);
  int _index = 0;

  bool _isUsableUrl(String? url) {
    if (url == null) return false;
    final v = url.trim();
    return v.isNotEmpty &&
        (v.startsWith('http://') || v.startsWith('https://'));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
      return Container(
        height: 150,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          color: Color(0xFFF3F3F3),
        ),
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Stack(
        children: [
          SizedBox(
            height: 110,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.media.length,

              onPageChanged: (i) {
                setState(() => _index = i);
              },
              itemBuilder: (_, i) {
                final m = widget.media[i];
                final isVideo = m.type == 'video';
                final videoUrl = isVideo ? widget.resolveVideoUrl(m) : null;

                if (isVideo) {
                  if (videoUrl != null) {
                    return SmartVideoPreview(
                      videoUrl: videoUrl,
                      thumbnail: _isUsableUrl(m.thumbnailUrl)
                          ? m.thumbnailUrl
                          : null,
                    );
                  }

                  if (_isUsableUrl(m.thumbnailUrl)) {
                    return Container(
                      color: Colors.white,
                      child: CachedNetworkImage(
                        imageUrl: m.thumbnailUrl!,
                        fit: BoxFit.contain,
                      ),
                    );
                  }

                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.videocam_off, color: Colors.white70),
                    ),
                  );
                }

                if (_isUsableUrl(m.originalUrl)) {
                  return Container(
                    color: Colors.white,
                    child: CachedNetworkImage(
                      imageUrl: m.originalUrl,
                      fit: BoxFit.contain,
                    ),
                  );
                }

                return Container(
                  color: const Color(0xFFF3F3F3),
                  child: const Center(child: Icon(Icons.broken_image_outlined)),
                );
              },
            ),
          ),
          if (widget.media.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.media.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: active ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF9E1B4F) : Colors.black26,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _BasketThumb extends StatelessWidget {
  final Product product;

  const _BasketThumb({required this.product});

  bool _isUsableUrl(String? url) {
    if (url == null) return false;
    final v = url.trim();
    return v.isNotEmpty &&
        (v.startsWith('http://') || v.startsWith('https://'));
  }

  @override
  Widget build(BuildContext context) {
    if (product.media.isEmpty) {
      return Container(
        color: const Color(0xFFF3F3F3),
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }

    final first = product.media.first;

    if (_isUsableUrl(first.thumbnailUrl)) {
      return CachedNetworkImage(
        imageUrl: first.thumbnailUrl!,
        fit: BoxFit.contain,
      );
    }

    if (_isUsableUrl(first.originalUrl)) {
      return CachedNetworkImage(
        imageUrl: first.originalUrl,
        fit: BoxFit.contain,
      );
    }

    return Container(
      color: const Color(0xFFF3F3F3),
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
