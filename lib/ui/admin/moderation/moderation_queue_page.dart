import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'investigation_page.dart';

class ModerationQueuePage extends StatelessWidget {
  const ModerationQueuePage({super.key});

  @override
  Widget build(BuildContext context) {

    final stream = FirebaseFirestore.instance
    .collection("moderation_targets")
.where("pendingReportCount", isGreaterThan: 0)
.orderBy("pendingReportCount", descending: true)
    .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Moderation Queue"),
        backgroundColor: Colors.pink,
      ),
      body: StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection("reports")
      .where("status", isEqualTo: "pending")
      .orderBy("createdAt", descending: true)
      .snapshots(),
  builder: (context, snapshot) {

    print("📊 moderation state → ${snapshot.connectionState}");
    print("📊 moderation error → ${snapshot.error}");

    if (snapshot.hasError) {
      return Center(
        child: Text("Firestore error: ${snapshot.error}"),
      );
    }

    if (!snapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final reports = snapshot.data!.docs;

    if (reports.isEmpty) {
      return const Center(
        child: Text("No pending moderation items"),
      );
    }

    return ListView.builder(
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        final data = report.data() as Map<String, dynamic>;

        final type = data["type"] ?? "";
        final reason = data["reasonCode"] ?? "";
        final targetId = data["targetId"] ?? "";

        return _buildReportItem(
          context,
          report.id,
          type,
          reason,
          targetId,
        );
      },
    );
  },
)
    );
  }

  Widget _buildReportItem(
      BuildContext context,
      String reportId,
      String type,
      String reason,
      String targetId,
      ) {

    IconData icon;

    switch (type) {
      case "dog":
        icon = Icons.pets;
        break;

      case "user":
        icon = Icons.person;
        break;

      case "business":
        icon = Icons.store;
        break;

      case "chat":
        icon = Icons.chat;
        break;

      default:
        icon = Icons.flag;
    }

    return ListTile(
      leading: Icon(icon, color: Colors.red),
      title: Text("Reported $type"),
      subtitle: Text("Reason: $reason"),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvestigationPage(
              reportId: reportId,
              targetId: targetId,
              type: type,
            ),
          ),
        );

      },
    );
  }
}