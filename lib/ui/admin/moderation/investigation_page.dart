// lib/ui/admin/moderation/investigation_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'models/moderation_report.dart';
import 'widgets/target_risk_summary_card.dart';
import 'widgets/moderation_audit_timeline.dart';

class InvestigationPage extends StatelessWidget {

  final String reportId;
  final String targetId;
  final String type;

  const InvestigationPage({
    super.key,
    required this.reportId,
    required this.targetId,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {

    final reportDoc = FirebaseFirestore.instance
        .collection("reports")
        .doc(reportId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Investigation"),
        backgroundColor: Colors.pink,
      ),

      body: FutureBuilder<DocumentSnapshot>(
        future: reportDoc.get(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final report =
              ModerationReport.fromSnapshot(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// HEADER
                Text(
                  "Reported ${report.type}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                /// TARGET
                Text("Target ID: ${report.targetId}"),

                const SizedBox(height: 10),

                /// REASON
                Text("Reason: ${report.reasonCode}"),

                const SizedBox(height: 10),

                /// MESSAGE
                if (report.message.isNotEmpty)
                  Text("Message: ${report.message}"),

                const SizedBox(height: 10),

                /// REPORTER
                Text("Reported by: ${report.reportedBy}"),

                const SizedBox(height: 20),

                /// CREATED
                Text(
                  "Created: ${report.createdAt}",
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 30),

                /// RISK SUMMARY
                TargetRiskSummaryCard(
                  targetId: targetId,
                  type: type,
                ),

                const SizedBox(height: 30),

                /// ADMIN ACTIONS
                const Text(
                  "Admin Actions",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () async {

                    await _reviewReport("approved");

                    Navigator.pop(context);

                  },
                  child: const Text("Approve Report"),
                ),

                const SizedBox(height: 10),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  onPressed: () async {

                    await _reviewReport("rejected");

                    Navigator.pop(context);

                  },
                  child: const Text("Reject Report"),
                ),

                const SizedBox(height: 30),

                /// AUDIT
                const Text(
                  "Audit Timeline",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                ModerationAuditTimeline(
                  targetId: targetId,
                  type: type,
                ),

              ],
            ),
          );

        },
      ),
    );
  }

  Future<void> _reviewReport(String action) async {

    await FirebaseFunctions.instanceFor(
  region: "europe-west3",
).httpsCallable("reviewReport")
        .call({
      "reportId": reportId,
      "action": action,
    });

  }

}