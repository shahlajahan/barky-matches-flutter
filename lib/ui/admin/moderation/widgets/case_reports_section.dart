// lib/admin/moderation/widgets/case_reports_section.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaseReportsSection extends StatelessWidget {
  final String targetId;

  const CaseReportsSection({
    super.key,
    required this.targetId,
  });

  @override
  Widget build(BuildContext context) {

    final stream = FirebaseFirestore.instance
        .collection("reports")
        .where("targetId", isEqualTo: targetId)
        .orderBy("createdAt", descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: docs.map((d) {

            final data = d.data() as Map<String, dynamic>;

            final reason = data["reasonText"] ?? "";
            final status = data["status"] ?? "";
            final message = data["message"] ?? "";

            return ListTile(
              leading: const Icon(Icons.flag),
              title: Text(reason),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  Text("Status: $status"),
                ],
              ),
            );

          }).toList(),
        );

      },
    );
  }
}