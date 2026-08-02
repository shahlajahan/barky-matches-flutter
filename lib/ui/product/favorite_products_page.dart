import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/ui/product/product_detail_page.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class FavoriteProductsPage extends StatelessWidget {
  final ValueChanged<Product> onAddToBasket;

  const FavoriteProductsPage({super.key, required this.onAddToBasket});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous == true;

    if (uid == null || isAnonymous) {
      return Container(
        color: AppTheme.bg,

        child: SafeArea(
          top: false,

          child: _buildEmptyState(
            "Login required",
            "Please login to see your favorite products",
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,

      appBar: AppBar(
        title: Text(l10n.favoriteProductsTitle),

        elevation: 0,

        backgroundColor: AppTheme.primary,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("favoriteProducts")
            .orderBy("createdAt", descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return _buildEmptyState(
              "No favorite products yet 🛍",

              "Tap the heart icon on products\nto save them here.",
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

            itemCount: docs.length,

            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),

                child: GestureDetector(
                  onTap: () async {
                    final productId = data["productId"];

                    final snapshot = await FirebaseFirestore.instance
                        .collectionGroup("products")
                        .get();

                    DocumentSnapshot? found;

                    for (final doc in snapshot.docs) {
                      if (doc.id == productId) {
                        found = doc;

                        break;
                      }
                    }

                    if (found == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.productNotFound)),
                      );

                      return;
                    }

                    final product = Product.fromJson(
                      found.id,

                      found.data() as Map<String, dynamic>,
                    );

                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(
                          product: product,
                          onAddToBasket: onAddToBasket,
                        ),
                      ),
                    );
                  },

                  child: Container(
                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(22),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),

                          blurRadius: 12,

                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),

                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),

                          child: data["imageUrl"] != null
                              ? Image.network(
                                  data["imageUrl"],

                                  width: 80,

                                  height: 80,

                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 80,

                                  height: 80,

                                  color: Colors.grey.shade200,

                                  child: const Icon(Icons.pets),
                                ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Text(
                                data["name"] ?? "",

                                maxLines: 2,

                                overflow: TextOverflow.ellipsis,

                                style: AppTheme.body(weight: FontWeight.w700),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                "₺${_customerPrice(data).toStringAsFixed(2)}",

                                style: AppTheme.h3(
                                  color: AppTheme.primary,

                                  weight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Container(
              padding: const EdgeInsets.all(22),

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                color: AppTheme.primary.withOpacity(0.08),
              ),

              child: Icon(
                Icons.favorite_border,

                size: 48,

                color: AppTheme.primary.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 24),

            Text(title, textAlign: TextAlign.center, style: AppTheme.h2()),

            const SizedBox(height: 10),

            Text(
              subtitle,

              textAlign: TextAlign.center,

              style: AppTheme.body(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}

double _customerPrice(Map<String, dynamic> data) {
  final base = ((data['salePrice'] ?? data['price']) as num?)?.toDouble() ?? 0;
  final rate = (data['kdvRate'] as num?)?.toDouble() ?? 0;
  return double.parse((base * (1 + rate / 100)).toStringAsFixed(2));
}
