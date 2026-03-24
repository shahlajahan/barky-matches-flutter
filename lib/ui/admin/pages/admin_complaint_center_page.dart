import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/complaint_model.dart';
import 'admin_complaint_detail_page.dart';

class AdminComplaintCenterPage extends StatelessWidget {
  const AdminComplaintCenterPage({super.key});

  @override
  Widget build(BuildContext context) {

    final stream = FirebaseFirestore.instance
        .collection("complaints")
        .where("status", whereIn: ["open", "under_review", "escalated"])
        .orderBy("createdAt", descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Complaint Center"),
        backgroundColor: const Color(0xFF9E1B4F),
        actions: [

          /// TEST BUTTON
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {

              await FirebaseFirestore.instance
                  .collection("complaints")
                  .add({

                "createdBy": "testUser",

                "createdAt": FieldValue.serverTimestamp(),

                "updatedAt": FieldValue.serverTimestamp(),

                "targetType": "dog",

                "targetId": "testDog",

                "category": "harassment",

                "severity": "medium",

                "priority": "normal",

                "title": "Test complaint",

                "description": "Test complaint description",

                "status": "open",

                "evidenceCount": 0,

                "messageCount": 1,

                "isArchived": false
              });

            },
          )
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {

          if (snapshot.hasError) {

            debugPrint("🔥 FIRESTORE ERROR: ${snapshot.error}");

            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {

            debugPrint("⏳ Waiting for Firestore...");

            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData) {

            debugPrint("⚠️ Snapshot has no data");

            return const Center(
              child: Text("No data"),
            );
          }

          final docs = snapshot.data!.docs;

          debugPrint("📦 Complaints loaded: ${docs.length}");

          if (docs.isEmpty) {
            return const Center(
              child: Text("No complaints found"),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final doc = docs[index];

              final complaint = ComplaintModel.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>,
              );

              return _ComplaintCard(
                complaint: complaint,
              );
            },
          );
        },
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {

  final ComplaintModel complaint;

  const _ComplaintCard({
    required this.complaint,
  });

  Color _severityColor() {

    switch (complaint.severity) {

      case ComplaintSeverity.low:
        return Colors.green;

      case ComplaintSeverity.medium:
        return Colors.orange;

      case ComplaintSeverity.high:
        return Colors.red;

      case ComplaintSeverity.critical:
        return Colors.purple;

      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Card(

      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),

      elevation: 2,

      child: ListTile(

        title: Text(
          complaint.displayTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text("Target: ${complaint.targetTypeLabel}"),

            Text("Category: ${complaint.categoryLabel}"),

            const SizedBox(height: 6),

            Row(
              children: [

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _severityColor(),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    complaint.severityLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Text(
                  complaint.statusLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            )
          ],
        ),

        trailing: const Icon(Icons.arrow_forward_ios),

        onTap: () {

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminComplaintDetailPage(
                complaint: complaint,
              ),
            ),
          );
        },
      ),
    );
  }
}