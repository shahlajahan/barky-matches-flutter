import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_subscription_details_page.dart';

class AdminSubscriptionPage extends StatefulWidget {
  const AdminSubscriptionPage({super.key});

  @override
  State<AdminSubscriptionPage> createState() =>
      _AdminSubscriptionPageState();
}

class _AdminSubscriptionPageState
    extends State<AdminSubscriptionPage> {

  String search = "";

  @override
  Widget build(BuildContext context) {

    final stream = FirebaseFirestore.instance
        .collection("users")
        .limit(50)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Subscription Management"),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {

          if (snapshot.hasError) {
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
              child: Text("No users found"),
            );
          }

          /// 🔎 Filter
          final filtered = docs.where((doc) {

            final userId = doc.id.toLowerCase();

            return userId.contains(search);

          }).toList();

          return Column(
            children: [

              /// 🔎 Search
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search userId...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      search = value.toLowerCase();
                    });
                  },
                ),
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {

                    final doc = filtered[index];
                    final userId = doc.id;

                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection("subscriptions")
                          .where("userId", isEqualTo: userId)
                          .limit(1)
                          .get(),

                      builder: (context, subSnap) {

                        /// loading state
                        if (subSnap.connectionState ==
                            ConnectionState.waiting) {

                          return const ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text("Loading subscription..."),
                          );
                        }

                        String plan = "free";
                        String status = "active";
                        double price = 0;

                        /// subscription exists
                        if (subSnap.hasData &&
                            subSnap.data!.docs.isNotEmpty) {

                          final subData =
                              subSnap.data!.docs.first.data()
                                  as Map<String, dynamic>;

                          plan = subData["plan"] ?? "free";
                          status = subData["status"] ?? "active";

                          /// 🔥 SAFE PRICE PARSING
                          price = (subData["price"] as num?)
                                  ?.toDouble() ??
                              0.0;
                        }

                        /// icon logic
                        IconData icon;

                        switch (plan) {
                          case "gold":
                            icon = Icons.workspace_premium;
                            break;

                          case "premium":
                            icon = Icons.star;
                            break;

                          default:
                            icon = Icons.person_outline;
                        }

                        return ListTile(
                          leading: Icon(icon),

                          title: Text(userId),

                          subtitle: Text(
                            "$plan • $status • \$${price.toStringAsFixed(2)}",
                          ),

                          trailing:
                              const Icon(Icons.chevron_right),

                          onTap: () {

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminSubscriptionDetailsPage(
                                      subscriptionId: userId,
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
          );
        },
      ),
    );
  }
}