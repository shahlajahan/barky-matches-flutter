import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:barky_matches_fixed/ui/petshop/petshop_products_page.dart';

class PetShopListPage extends StatelessWidget {
  const PetShopListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pet Shops")),

      body: StreamBuilder<QuerySnapshot>(
        // 🔥 IMPORTANT: بدون where (چون دیتات structure متفاوت داره)
        stream: FirebaseFirestore.instance
            .collection('businesses')
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("Error loading pet shops"),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // 🔥 FILTER REAL DATA
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final sectors = List<String>.from(
              data['sectors'] ?? [],
            );

            return sectors.contains('pet_shop');
          }).toList();

          debugPrint("🏪 PETSHOPS FOUND: ${docs.length}");

          if (docs.isEmpty) {
            return const Center(
              child: Text("No pet shops found"),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, index) {
              final doc = docs[index];
              final data =
                  doc.data() as Map<String, dynamic>;

              // 🔥 درست از دیتای تو
              final name = data['profile']?['displayName'] ??
                  data['shopName'] ??
                  'Pet Shop';

              final logo =
                  data['profile']?['logoUrl'];

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: logo != null &&
                          logo.toString().isNotEmpty
                      ? NetworkImage(logo)
                      : null,
                  child: (logo == null ||
                          logo.toString().isEmpty)
                      ? const Icon(Icons.store)
                      : null,
                ),
                title: Text(name),

                onTap: () {
                  debugPrint(
                      "➡️ OPEN SHOP: ${doc.id}");

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PetShopProductsPage(
                        shopId: doc.id, // ✅ REAL ID
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}