import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'business_admin_detail_page.dart';

class AdminBusinessSearchPage extends StatefulWidget {
  const AdminBusinessSearchPage({super.key});

  @override
  State<AdminBusinessSearchPage> createState() => _AdminBusinessSearchPageState();
}

class _AdminBusinessSearchPageState extends State<AdminBusinessSearchPage> {

  String searchQuery = "";
  String statusFilter = "all";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Business Search"),
        backgroundColor: Colors.pink,
      ),
      body: Column(
        children: [

          // SEARCH
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search business name...",
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

          // STATUS FILTER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              value: statusFilter,
              items: const [
                DropdownMenuItem(value: "all", child: Text("All")),
                DropdownMenuItem(value: "approved", child: Text("Approved")),
                DropdownMenuItem(value: "rejected", child: Text("Rejected")),
                DropdownMenuItem(value: "suspended", child: Text("Suspended")),
              ],
              onChanged: (value) {
                setState(() {
                  statusFilter = value ?? "all";
                });
              },
              decoration: const InputDecoration(
                labelText: "Filter by status",
              ),
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("businesses")
                  .orderBy("createdAt", descending: true)
                  .limit(200)
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

                final filtered = docs.where((doc) {

                  final data = doc.data() as Map<String, dynamic>;

                  final profile =
                      (data["profile"] as Map?)?.cast<String, dynamic>() ?? {};

                  final name =
                      (profile["displayName"] ?? "").toString().toLowerCase();

                  final status =
                      (data["status"] ?? "").toString();

                  final matchesSearch = name.contains(searchQuery);

                  final matchesStatus =
                      statusFilter == "all" ? true : status == statusFilter;

                  return matchesSearch && matchesStatus;

                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No results"));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {

                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final profile =
                        (data["profile"] as Map?)?.cast<String, dynamic>() ?? {};

                    final contact =
                        (data["contact"] as Map?)?.cast<String, dynamic>() ?? {};

                    final name = profile["displayName"] ?? "Unnamed";

                    final city = contact["city"] ?? "";
                    final district = contact["district"] ?? "";

                    final status = data["status"] ?? "unknown";

                    return ListTile(
                      title: Row(
                        children: [
                          Expanded(child: Text(name)),
                          _statusBadge(status),
                        ],
                      ),
                      subtitle: Text(
                        [district, city].where((e) => e.isNotEmpty).join(", "),
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

  Widget _statusBadge(String status) {

    Color color;

    switch (status) {
      case "approved":
        color = Colors.green;
        break;
      case "rejected":
        color = Colors.red;
        break;
      case "suspended":
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}