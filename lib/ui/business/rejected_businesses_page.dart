import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin/pages/business_admin_detail_page.dart';

class RejectedBusinessesPage extends StatelessWidget {
  const RejectedBusinessesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rejected Businesses"),
        backgroundColor: Colors.pink,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("businesses")
            .where("status", isEqualTo: "rejected")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.hasError) {
            debugPrint(snapshot.error.toString());
            return Center(child: Text(snapshot.error.toString()));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("No rejected businesses"),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final profile =
                  (data["profile"] as Map?)?.cast<String, dynamic>() ?? {};

              final contact =
                  (data["contact"] as Map?)?.cast<String, dynamic>() ?? {};

              final name = profile["displayName"] ?? "Unnamed";
              final type = data["type"] ?? "business";

              final city = contact["city"] ?? "";
              final district = contact["district"] ?? "";

              return ListTile(
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: Text(
                  "$type • ${[district, city].where((e) => e.isNotEmpty).join(", ")}",
                ),

                trailing: const Icon(Icons.chevron_right),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessAdminDetailPage(
                        businessId: doc.id,
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