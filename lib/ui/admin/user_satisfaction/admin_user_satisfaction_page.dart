import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/feedback_item.dart';
import 'admin_feedback_detail_page.dart';

class AdminUserSatisfactionPage extends StatelessWidget {
  const AdminUserSatisfactionPage({super.key});

  @override
  Widget build(BuildContext context) {

    final stream = FirebaseFirestore.instance
        .collection("user_feedback")
        .orderBy("createdAt", descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("User Feedback"),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: stream,

        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          double avgRating = 0;
          int bugReports = 0;
          int featureRequests = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;

            avgRating += (data["rating"] ?? 0);

            if (data["category"] == "bug") {
              bugReports++;
            }

            if (data["category"] == "feature_request") {
              featureRequests++;
            }
          }

          if (docs.isNotEmpty) {
            avgRating = avgRating / docs.length;
          }

          return Column(
            children: [

              // KPI CARDS
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [

                    _KpiCard(
                      title: "Avg Rating",
                      value: avgRating.toStringAsFixed(1),
                    ),

                    _KpiCard(
                      title: "Total",
                      value: docs.length.toString(),
                    ),

                    _KpiCard(
                      title: "Bugs",
                      value: bugReports.toString(),
                    ),

                    _KpiCard(
                      title: "Features",
                      value: featureRequests.toString(),
                    ),

                  ],
                ),
              ),

              const Divider(),

              // LIST
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,

                  itemBuilder: (context, index) {

                    final doc = docs[index];

                    return FeedbackItem(
                      doc: doc,
                      onTap: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminFeedbackDetailPage(doc: doc),
                          ),
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

class _KpiCard extends StatelessWidget {

  final String title;
  final String value;

  const _KpiCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          children: [

            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(title),

          ],
        ),
      ),
    );
  }
}