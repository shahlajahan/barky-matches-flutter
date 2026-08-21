import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class SellerOffersPage extends StatelessWidget {
  final Product product;

  const SellerOffersPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasBarcode =
        product.barcode != null && product.barcode!.trim().isNotEmpty;

    // P0 gap review item 4: mirror the products read rule
    // (moderationStatus=='approved' && isActive==true for a non-owner
    // reader), or Firestore rejects the query.
    Query query = FirebaseFirestore.instance
        .collectionGroup('products')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved');

    if (hasBarcode) {
      query = query.where('barcode', isEqualTo: product.barcode);
    } else {
      query = query.where('name', isEqualTo: product.name);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sellers)),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("🔥 SELLER QUERY ERROR: ${snapshot.error}");
            return Center(
              child: Text(l10n.sellerQueryError(snapshot.error ?? '')),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(child: Text(l10n.noSellersFound));
          }

          final items = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Product.fromJson(doc.id, data);
          }).toList();

          items.sort((a, b) => a.customerPrice.compareTo(b.customerPrice));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final p = items[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(p.businessName ?? "Seller"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(p.name), Text(l10n.stockLabel(p.stock))],
                  ),
                  trailing: Text(
                    "${p.customerPrice.toStringAsFixed(2)} ${p.currency}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
