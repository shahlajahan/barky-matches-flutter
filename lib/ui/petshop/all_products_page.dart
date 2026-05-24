import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

import 'package:barky_matches_fixed/ui/product/product_detail_page.dart';
import 'package:barky_matches_fixed/ui/product/seller_profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final List<CartItem> _cart = [];

  @override
void initState() {
  super.initState();
  _sellerIdFilter = widget.initialSellerId;

  _loadCartFromFirestore(); // ✅ فقط اینجا

  _searchController.addListener(() {
    if (_query != _searchController.text.trim()) {
      setState(() {
        _query = _searchController.text.trim();
      });
    }
  });
}
  @override
  void dispose() {
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
            price: product.finalPrice,
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

  double get _cartSubtotal {
    return _cart.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  int get _cartCount {
    return _cart.fold<int>(0, (sum, item) => sum + item.quantity);
  }
Future<void> _loadCartFromFirestore() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('cart')
      .get();

  setState(() {
    _cart.clear();

    _cart.addAll(snapshot.docs.map((doc) {
      final data = doc.data();

      final price = (data['price'] as num).toDouble();

      // 🔥 ساخت Product فیک ولی valid
      final product = Product(
  id: data['productId'],
  name: data['name'],
  description: '',
  price: price,
  currency: 'TRY', // 🔥 اینو اضافه کن
  businessId: data['shopId'],
  media: [],
  stock: 0,              // 👈 اینم چون requiredه
  category: 'general',   // 👈 اینم requiredه
  isActive: true,        // 👈 اینم requiredه
);

      return CartItem(
        productId: data['productId'],
        product: product, // ✅ دیگه null نیست
        shopId: data['shopId'],
        name: data['name'],
        price: price,
        quantity: data['quantity'],
      );
    }));
  });
}
  void _openBasket() {
  final l10n = AppLocalizations.of(context)!;
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
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
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
                          style:
                              AppTheme.caption(color: AppTheme.muted),
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
                              style: AppTheme.body(
                                  color: AppTheme.muted),
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
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.black12),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 72,
                                        height: 72,
                                        child:
                                            _BasketThumb(product: p),
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
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: AppTheme.body(
                                              weight:
                                                  FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            p.businessName ??
                                                l10n.sellerLabel,
                                            style: AppTheme.caption(
                                              color:
                                                  AppTheme.muted,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "₺${(item.price * item.quantity).toStringAsFixed(0)}",
                                            style: AppTheme.h3(
                                              color: const Color(
                                                  0xFF9E1B4F),
                                              weight:
                                                  FontWeight.w800,
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
_syncCartToFirestore();
                                            });
                                          },
                                          icon: const Icon(Icons
                                              .remove_circle_outline),
                                        ),
                                        AnimatedSwitcher(
  duration: const Duration(milliseconds: 250),
  transitionBuilder: (child, animation) {
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
    key: ValueKey(item.quantity), // 🔥 مهم
    style: AppTheme.body(weight: FontWeight.w700),
  ),
),
                                        IconButton(
                                          onPressed: () {
                                            setModalState(() {
                                              _changeQuantity(item, 1);
_syncCartToFirestore();
                                            });
                                          },
                                          icon: const Icon(Icons
                                              .add_circle_outline),
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
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                              color:
                                  Colors.black.withOpacity(0.06)),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n.subtotalLabel,
                                style: AppTheme.body(
                                  color: AppTheme.textDark,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "₺${_cartSubtotal.toStringAsFixed(0)}",
                                style: AppTheme.h3(
                                  color:
                                      const Color(0xFF9E1B4F),
                                  weight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // CHECKOUT
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CheckoutPage(items: _cart),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFFFFC107),
                              foregroundColor: Colors.black,
                              minimumSize:
                                  const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
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

Future<void> _syncCartToFirestore() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

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
        result.sort((a, b) {
          int score(Product p) {
            int s = 0;
            if (p.salePrice != null && p.salePrice! < p.price) s += 20;
            if (p.allowFreeShipping) s += 10;
            if (p.media.isNotEmpty) s += 8;
            if ((p.businessName ?? '').isNotEmpty) s += 5;
            if (p.stock > 0) s += 5;
            return s;
          }

          return score(b).compareTo(score(a));
        });
    }

    return result;
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
          IconButton(
            onPressed: _cart.isEmpty ? null : _openBasket,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(LucideIcons.shoppingBag),
                if (_cartCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
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
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('products')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("🔥 REAL ERROR: ${snapshot.error}");
            return Center(
              child: Text(
                l10n.errorLoadingProducts(snapshot.error.toString()),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(child: Text(l10n.noActiveProductsFound));
          }

          final products = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Product.fromJson(doc.id, data);
          }).toList();

          final categories = products
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
contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
border: OutlineInputBorder(
  borderRadius: BorderRadius.circular(18),
  borderSide: BorderSide.none,
),
enabledBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(18),
  borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
),
focusedBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(18),
  borderSide: BorderSide(color: const Color(0xFF9E1B4F).withOpacity(0.18)),
),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      // =========================
      // CATEGORY
      // =========================
      _TopDropDown<String?>(
        width: 110,
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

      const SizedBox(width: 8),

      // =========================
      // SHIPPING
      // =========================
      _TopDropDown<String?>(
        width: 150,
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

      const SizedBox(width: 8),

      // =========================
      // SORT
      // =========================
      _TopDropDown<String>(
        width: 150,
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

      const SizedBox(width: 8),

      // =========================
      // CLEAR SELLER ONLY
      // =========================
      if (_sellerIdFilter != null)
        ActionChip(
          onPressed: () {
            setState(() {
              _sellerIdFilter = null;
            });
          },
          avatar: const Icon(Icons.store_mall_directory_outlined, size: 18),
          label: Text(l10n.sellerLabel),
        ),

      const SizedBox(width: 8),

      // =========================
      // 🔥 RESET ALL FILTERS
      // =========================
      ActionChip(
        onPressed: _resetFilters,
        avatar: const Icon(Icons.refresh_rounded, size: 18),
        label: Text(l10n.resetFiltersButton),
      ),
    ],
  ),
),
                    const SizedBox(height: 4),
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
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.52,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
  final product = filtered[index];

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(product: product),
        ),
      );
    },
    child: _CompactProductCard(
      product: product,
      onAddToBasket: () => _addToBasket(product),
      onOpenSeller: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SellerProfilePage(
  sellerId: product.businessId,
  sellerName: product.businessName,
),
          ),
        );
      },
    ),
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
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
    borderSide: BorderSide(color: const Color(0xFF9E1B4F).withOpacity(0.18)),
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

class _CompactProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToBasket;
  final VoidCallback onOpenSeller;

  const _CompactProductCard({
    required this.product,
    required this.onAddToBasket,
    required this.onOpenSeller,
  });

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
        builder: (_) => GalleryViewerPage(
          items: items,
          initialIndex: 0,
        ),
      ),
    );
  }

  List<String> _shippingChips(BuildContext context, Product p) {
    final l10n = AppLocalizations.of(context)!;
    final List<String> out = [];

  if (p.shippingMode == "free_shipping" || p.shippingMode == "seller_absorbs") {
    out.add(l10n.freeCargoLabel);
  } else if (p.shippingMode == "fixed_price" && p.shippingFee != null) {
      out.add(l10n.cargoPriceLabel("₺${p.shippingFee!.toStringAsFixed(0)}"));
    } else if (p.shippingMode == "carrier_calculated") {
    out.add(l10n.cargoCalculatedLabel);
  }

  if (p.freeShippingThreshold != null && p.freeShippingThreshold! > 0) {
      out.add(l10n.freeOverLabel("₺${p.freeShippingThreshold!.toStringAsFixed(0)}"));
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
  final l10n = AppLocalizations.of(context)!;
  final hasDiscount = product.salePrice != null &&
      product.salePrice! > 0 &&
      product.salePrice! < product.price;

  final firstMedia =
      product.media.isNotEmpty ? product.media.first.originalUrl : null;

  return Container(
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
        GestureDetector(
          onTap: () => _openGallery(context),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
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
              if (hasDiscount)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
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
              if (product.stock <= 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.outOfStockLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
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
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                  const Icon(Icons.star_rounded,
                      size: 14, color: Color(0xFFFF9800)),
                  const SizedBox(width: 2),
                  Text("4.5",
                      style: AppTheme.caption(
                        weight: FontWeight.w700,
                        color: AppTheme.textDark,
                      )),
                  const SizedBox(width: 4),
                  Text("(128)",
                      style: AppTheme.caption(color: AppTheme.muted)),
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
                            "₺${product.price.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          "₺${product.finalPrice.toStringAsFixed(0)}",
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
                          horizontal: 5, vertical: 2),
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
                          color:
                              const Color(0xFF9E1B4F).withOpacity(0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:
                          const Icon(Icons.storefront_outlined, size: 14),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 24,
                      child: ElevatedButton.icon(
                        onPressed:
                            product.stock > 0 ? onAddToBasket : null,
                        icon: const Icon(Icons.add_shopping_cart, size: 13),
                        label: Text(
                          l10n.addButton,
                          style: const TextStyle(fontSize: 10),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
}

List<Widget> _buildBadges(AppLocalizations l10n, Product product) {
  final badges = <Widget>[];

  // 🚚 shipping
  if (product.shippingFee == 0) {
    badges.add(_badge(l10n.freeCargoLabel, Colors.blue, const Color(0xFFE3F2FD)));
  } else if (product.shippingFee != null) {
    badges.add(_badge(l10n.cargoPriceLabel(product.shippingFee!.toInt().toString()), Colors.blue, const Color(0xFFE3F2FD)));
  } else {
    badges.add(_badge(l10n.cargoCalculatedLabel, Colors.blue, const Color(0xFFE3F2FD)));
  }

  // ⏱ delivery
  if (product.maxDeliveryDays != null) {
    badges.add(_badge(l10n.daysLabel(product.maxDeliveryDays.toString()), const Color(0xFF558B2F), const Color(0xFFF1F8E9)));
  }

  // 📦 stock
  if (product.stock > 0) {
    badges.add(_badge(l10n.inStockLabel, const Color(0xFF2E7D32), const Color(0xFFE8F5E9)));
  }

  // ⚠️ اگر کمتر از 3 تا بود → spacer
  while (badges.length < 3) {
    badges.add(const SizedBox(height: 10));
  }

  return badges.take(3).map((w) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: w,
  )).toList();
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

  return words.skip(1).take(5).join(' ') + "...";
}

}

class _MediaSlider extends StatefulWidget {
  final List<ProductMedia> media;
  final String? Function(ProductMedia media) resolveVideoUrl;

  const _MediaSlider({
    required this.media,
    required this.resolveVideoUrl,
  });

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
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined),
        ),
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
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined),
                  ),
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
