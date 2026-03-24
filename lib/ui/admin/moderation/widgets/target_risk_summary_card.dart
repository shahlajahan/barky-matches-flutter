// lib/ui/admin/moderation/widgets/target_risk_summary_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TargetRiskSummaryCard extends StatelessWidget {

  final String targetId;
  final String type;

  const TargetRiskSummaryCard({
    super.key,
    required this.targetId,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {

    final key = "${type}_$targetId";

    final doc = FirebaseFirestore.instance
        .collection("moderation_targets")
        .doc(key);

    return FutureBuilder<DocumentSnapshot>(
      future: doc.get(),
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const SizedBox();
        }

        if (!snapshot.data!.exists) {
          return const SizedBox();
        }

        final data =
            snapshot.data!.data() as Map<String, dynamic>;

        final pending =
            data["pendingReportCount"] ?? 0;

        final weight =
            data["pendingWeight"] ?? 0;

        final autoStatus =
            data["autoStatus"] ?? "active";

        final adminStatus =
            data["adminStatus"] ?? "none";

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text(
                  "Risk Summary",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text("Pending Reports: $pending"),

                Text("Weight Score: $weight"),

                Text("Auto Status: $autoStatus"),

                Text("Admin Status: $adminStatus"),

              ],
            ),
          ),
        );
      },
    );
  }
}