import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
        backgroundColor: AppTheme.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("No reports"),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final reportId = docs[index].id;

              final type = data['type'] ?? '';
              final targetId = data['targetId'] ?? '';
              final reason = data['reason'] ?? '';
              final status = data['status'] ?? '';
              final reporter = data['reportedBy'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ListTile(
                  title: Text("Type: $type"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text("Reason: $reason"),
                      Text("Target: $targetId"),
                      Text("Reporter: $reporter"),
                      Text("Status: $status"),

                      const SizedBox(height: 8),

                      Row(
                        children: [

                          ElevatedButton(
  onPressed: () {
    _updateStatus(reportId, "approved");
  },
  child: const Text("Approve"),
),

ElevatedButton(
  onPressed: () {
    _updateStatus(reportId, "rejected");
  },
  child: const Text("Reject"),
),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(String reportId, String action) async {
  try {

    final functions = FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    );

    final callable = functions.httpsCallable('reviewReport');

    await callable.call({
      "reportId": reportId,
      "action": action,
    });

  } catch (e) {
    debugPrint("Admin review error: $e");
  }
}
}