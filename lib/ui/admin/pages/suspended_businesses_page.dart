import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_admin_detail_page.dart';

class SuspendedBusinessesPage extends StatelessWidget {
  const SuspendedBusinessesPage({super.key});

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Suspended Businesses"),
      backgroundColor: Colors.pink,
    ),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("businesses")
          .where("status", isEqualTo: "suspended")
          .orderBy("statusUpdatedAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        /// 🔴 FIRESTORE QUERY ERROR DEBUG
        if (snapshot.hasError) {
          debugPrint("❌ SUSPENDED QUERY ERROR → ${snapshot.error}");

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "Firestore error:\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        /// ⏳ WAITING DATA
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint("⏳ Suspended businesses loading...");
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData) {
          debugPrint("⚠️ Suspended query returned no snapshot");
          return const Center(
            child: Text("No data received"),
          );
        }

        final docs = snapshot.data!.docs;

        debugPrint("📦 Suspended businesses count → ${docs.length}");

        if (docs.isEmpty) {
          return const Center(
            child: Text("No suspended businesses"),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {

            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final name = data["displayName"] ?? "Business";

            return ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text(name),
              subtitle: const Text("Suspended"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {

                debugPrint("➡️ Opening suspended business → ${doc.id}");

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