import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
//import 'package:barky_matches_fixed/ui/petshop/widgets/checkout_button.dart';
import '../../models/product.dart';
import 'package:barky_matches_fixed/models/product_media.dart';
import 'package:barky_matches_fixed/ui/checkout/checkout_page.dart';

class PetShopProductsPage extends StatefulWidget {
  final String shopId;

  const PetShopProductsPage({
    super.key,
    required this.shopId,
  });

  @override
  State<PetShopProductsPage> createState() =>
      _PetShopProductsPageState();
}

class _PetShopProductsPageState extends State<PetShopProductsPage> {
  final List<CartItem> _cart = [];

  String getMediaUrl(ProductMedia m) {
  if (m.type == 'video') {
    return m.thumbnailUrl ?? m.playbackUrl ?? m.originalUrl;
  }
  return m.originalUrl;
}

  void _addToCart(Product product) {
    final index =
        _cart.indexWhere((e) => e.productId == product.id);

    setState(() {
      if (index != -1) {
        final old = _cart[index];

        _cart[index] = old.copyWith(
          quantity: old.quantity + 1,
        );
      } else {
        _cart.add(
          CartItem(
            productId: product.id,
            shopId: product.businessId,
            name: product.name,
            price: product.price,
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
      SnackBar(content: Text("${product.name} added to cart")),
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
  debugPrint("🔥 OPEN SHOP ID: ${widget.shopId}");

  return Scaffold(
      appBar: AppBar(
        title: const Text("Pet Shop"),
      ),
      body: Column(
        children: [
          /// 🔥 REAL PRODUCTS FROM FIRESTORE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
    .collection('businesses')
    .doc(widget.shopId)
    .collection('products')
    .where('isActive', isEqualTo: true)
    .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text("Error loading products"));
                }

                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                      child: Text("No products found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, index) {
                    final doc = docs[index];
                    final data =
                        doc.data() as Map<String, dynamic>;

                    final product =
                        Product.fromJson(doc.id, data);

                    return Card(
                      margin:
                          const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding:
                            const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            /// IMAGE
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(10),
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                      "${product.price} ₺"),
                                ],
                              ),
                            ),

                            /// ADD BUTTON
                            ElevatedButton(
                              onPressed: () =>
                                  _addToCart(product),
                              child: const Text("Add"),
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
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: Colors.black12,
                  )
                ],
              ),
              child: Column(
                children: [
                  /// TOTAL
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${_totalPrice.toStringAsFixed(2)} ₺",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
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
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => CheckoutPage(items: _cart),
          ),
        );
      },
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    child: const Text("Continue to Checkout"),
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