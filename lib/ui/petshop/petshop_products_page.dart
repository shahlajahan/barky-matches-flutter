import 'package:flutter/material.dart';

import '../../services/marketplace_discovery_controller.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
//import 'package:barky_matches_fixed/ui/petshop/widgets/checkout_button.dart';
import '../../models/product.dart';
import 'package:barky_matches_fixed/models/product_media.dart';
import 'package:barky_matches_fixed/ui/checkout/checkout_page.dart';

class PetShopProductsPage extends StatefulWidget {
  final String shopId;

  const PetShopProductsPage({super.key, required this.shopId});

  @override
  State<PetShopProductsPage> createState() => _PetShopProductsPageState();
}

class _PetShopProductsPageState extends State<PetShopProductsPage> {
  // Slice 7D — the shop storefront's only data source.
  late final MarketplaceDiscoveryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MarketplaceDiscoveryController()..addListener(_onCatalogChanged);
    _controller.load(businessId: widget.shopId);
  }

  void _onCatalogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onCatalogChanged);
    _controller.dispose();
    super.dispose();
  }

  final List<CartItem> _cart = [];

  String getMediaUrl(ProductMedia m) {
    if (m.type == 'video') {
      return m.thumbnailUrl ?? m.playbackUrl ?? m.originalUrl;
    }
    return m.originalUrl;
  }

  void _addToCart(Product product) {
    final index = _cart.indexWhere((e) => e.productId == product.id);

    setState(() {
      if (index != -1) {
        final old = _cart[index];

        _cart[index] = old.copyWith(quantity: old.quantity + 1);
      } else {
        _cart.add(
          CartItem(
            productId: product.id,
            shopId: product.businessId,
            name: product.name,
            price: product.customerPrice,
            quantity: 1,
            imageUrl: product.media.isNotEmpty
                ? getMediaUrl(product.media.first)
                : null,
            product: product,
          ),
        );
      }
    });

    debugPrint("🛒 CART COUNT: ${_cart.length}");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.addedToCart)),
    );
  }

  double get _totalPrice {
    return _cart.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    debugPrint("🔥 OPEN SHOP ID: ${widget.shopId}");

    return Scaffold(
      appBar: AppBar(title: Text(l10n.petShopTitle)),
      body: Column(
        children: [
          /// 🔥 REAL PRODUCTS FROM FIRESTORE
          Expanded(
            child: Builder(
              builder: (context) {
                // Marketplace Revision 43 §0.41 (Slice 7D) — the shop's
                // catalogue comes from the trusted callable, scoped to this
                // shop, never from a direct Firestore query. `isActive` and
                // `moderationStatus` were never the publication contract;
                // the server's live eligibility evaluation is.
                switch (_controller.status) {
                  case DiscoveryStatus.idle:
                  case DiscoveryStatus.loading:
                    return const Center(child: CircularProgressIndicator());
                  case DiscoveryStatus.failed:
                    return Center(child: Text(l10n.somethingWentWrong));
                  case DiscoveryStatus.empty:
                    return Center(child: Text(l10n.noProductsFound));
                  case DiscoveryStatus.loaded:
                    break;
                }

                final items = _controller.products;
                if (items.isEmpty) {
                  return Center(child: Text(l10n.noProductsFound));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final product = items[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            /// IMAGE
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                product.media.isNotEmpty
                                    ? getMediaUrl(product.media.first)
                                    : 'https://via.placeholder.com/70',

                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                            ),

                            const SizedBox(width: 12),

                            /// INFO
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "${product.customerPrice.toStringAsFixed(2)} ₺",
                                  ),
                                ],
                              ),
                            ),

                            /// ADD BUTTON
                            ElevatedButton(
                              onPressed: () => _addToCart(product),
                              child: Text(l10n.addToCartButton),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          /// 🧾 CART + CHECKOUT
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
              ),
              child: Column(
                children: [
                  /// TOTAL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.totalLabel,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${_totalPrice.toStringAsFixed(2)} ₺",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  /// CHECKOUT
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cart.isEmpty
                          ? null
                          : () {
                              final checkoutItems = List<CartItem>.from(_cart);
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (_) => CheckoutPage(
                                    items: checkoutItems,
                                    onPaymentVerified: () async {
                                      if (!mounted) return;
                                      setState(() {
                                        for (final purchased in checkoutItems) {
                                          final index = _cart.indexWhere(
                                            (item) =>
                                                item.productId ==
                                                purchased.productId,
                                          );
                                          if (index == -1) continue;
                                          final remaining =
                                              _cart[index].quantity -
                                              purchased.quantity;
                                          if (remaining > 0) {
                                            _cart[index] = _cart[index]
                                                .copyWith(quantity: remaining);
                                          } else {
                                            _cart.removeAt(index);
                                          }
                                        }
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(l10n.checkoutButton),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
