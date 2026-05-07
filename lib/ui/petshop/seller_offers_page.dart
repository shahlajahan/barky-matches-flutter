import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/models/product.dart';

class SellerOffersPage extends StatelessWidget {
  final Product product;

  const SellerOffersPage({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final hasBarcode =
        product.barcode != null && product.barcode!.trim().isNotEmpty;

    Query query = FirebaseFirestore.instance
        .collectionGroup('products')
        .where('isActive', isEqualTo: true);

    if (hasBarcode) {
      query = query.where('barcode', isEqualTo: product.barcode);
    } else {
      query = query.where('name', isEqualTo: product.name);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sellers"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
  debugPrint("🔥 SELLER QUERY ERROR: ${snapshot.error}");
  return Center(
    child: Text("Error: ${snapshot.error}"),
  );
}

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("No sellers found"),
            );
          }

          final items = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Product.fromJson(doc.id, data);
          }).toList();

          items.sort((a, b) => a.finalPrice.compareTo(b.finalPrice));

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
                    children: [
                      Text(p.name),
                      Text("Stock: ${p.stock}"),
                    ],
                  ),
                  trailing: Text(
                    "${p.finalPrice} ${p.currency}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
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
}