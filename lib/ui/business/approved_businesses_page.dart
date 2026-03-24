import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin/pages/business_admin_detail_page.dart';

class ApprovedBusinessesPage extends StatefulWidget {
  const ApprovedBusinessesPage({super.key});

  @override
  State<ApprovedBusinessesPage> createState() => _ApprovedBusinessesPageState();
}

class _ApprovedBusinessesPageState extends State<ApprovedBusinessesPage> {

  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Approved Businesses"),
        backgroundColor: Colors.pink,
      ),
      body: Column(
        children: [

          // 🔎 SEARCH FIELD
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search businesses...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // 📦 LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("businesses")
                  .where("status", isEqualTo: "approved")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {

                // 🔥 DEBUG INDEX ERROR
                if (snapshot.hasError) {
                  debugPrint("🔥 Firestore error:");
                  debugPrint(snapshot.error.toString());

                  return Center(
                    child: Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text("No approved businesses"),
                  );
                }

                // 🔎 SEARCH FILTER
                final filtered = docs.where((doc) {

                  final data = doc.data() as Map<String, dynamic>;

                  final name =
                      (data["displayName"] ?? "").toString().toLowerCase();

                  return name.contains(searchQuery);

                }).toList();

                debugPrint("Approved businesses: ${filtered.length}");

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text("No results"),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {

                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final profile =
    (data["profile"] as Map?)?.cast<String, dynamic>() ?? {};

final name = profile["displayName"] ?? "Unnamed";

                    final contact =
    (data["contact"] as Map?)?.cast<String, dynamic>() ?? {};

final city = contact["city"] ?? "";
final district = contact["district"] ?? "";

                    return ListTile(
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      subtitle: Text(
                        [district, city]
                            .where((e) => e.toString().isNotEmpty)
                            .join(", "),
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
          ),
        ],
      ),
    );
  }
}