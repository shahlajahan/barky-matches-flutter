import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    final hasDiscount =
        product.salePrice != null &&
        product.salePrice! > 0 &&
        product.salePrice! < product.price;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _bottomBar(product),
      body: CustomScrollView(
        slivers: [
          // =========================
          // 🔥 APP BAR + IMAGE SLIDER
          // =========================
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  _imageSlider(product),

                  // 🔥 INDICATOR
                  if (product.media.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(product.media.length, (i) {
                          final active = i == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF9E1B4F)
                                  : Colors.black26,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // =========================
          // 🔥 CONTENT
          // =========================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================
                  // 🏪 SELLER
                  // =========================
                  GestureDetector(
                    onTap: () {
                      // TODO: Seller page
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          product.businessName ?? "Seller",
                          style: AppTheme.body(weight: FontWeight.w700),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // =========================
                  // 📛 NAME
                  // =========================
                  Text(
                    product.name,
                    style: AppTheme.h2(weight: FontWeight.w900),
                  ),

                  const SizedBox(height: 10),

                  // =========================
                  // ⭐ RATING
                  // =========================
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Color(0xFFFF9800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "4.5",
                        style: AppTheme.body(weight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "(128 reviews)",
                        style: AppTheme.caption(color: AppTheme.muted),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // =========================
                  // 💰 PRICE
                  // =========================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasDiscount)
                        Text(
                          "₺${product.price.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        "₺${product.finalPrice.toStringAsFixed(0)}",
                        style: AppTheme.h1(
                          color: const Color(0xFF9E1B4F),
                          weight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (hasDiscount)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "-${product.discountPercent}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // =========================
                  // 🚚 SHIPPING
                  // =========================
                  _shippingBox(product),

                  const SizedBox(height: 22),

                  // =========================
                  // 📝 DESCRIPTION
                  // =========================
                  if (product.description.trim().isNotEmpty) ...[
                    Text(
                      "Product Details",
                      style: AppTheme.h3(weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(product.description, style: AppTheme.body()),
                    const SizedBox(height: 24),
                  ],

                  // =========================
                  // 🔧 SPECS
                  // =========================
                  _specRow("Stock", product.stock.toString()),
                  _specRow("Category", product.category),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🖼 IMAGE SLIDER
  // =========================
  Widget _imageSlider(Product product) {
    if (product.media.isEmpty) {
      return Container(color: Colors.grey.shade200);
    }

    return PageView.builder(
      itemCount: product.media.length,
      onPageChanged: (i) => setState(() => _currentIndex = i),
      itemBuilder: (_, i) {
        final m = product.media[i];

        return Container(
          color: Colors.white,
          child: CachedNetworkImage(
            imageUrl: m.originalUrl,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }

  // =========================
  // 🚚 SHIPPING BOX
  // =========================
  Widget _shippingBox(Product product) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              product.shippingMode == "free_shipping"
                  ? "Free Shipping"
                  : "Shipping calculated at checkout",
              style: AppTheme.body(weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔧 SPEC ROW
  // =========================
  Widget _specRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title, style: AppTheme.caption(color: AppTheme.muted)),
          const Spacer(),
          Text(value, style: AppTheme.body(weight: FontWeight.w700)),
        ],
      ),
    );
  }

  // =========================
  // 🛒 BOTTOM BAR
  // =========================
  Widget _bottomBar(Product product) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: product.stock > 0 ? () {} : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Add to Basket",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
