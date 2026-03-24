// lib/ui/admin/moderation/widgets/moderation_audit_timeline.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationAuditTimeline extends StatelessWidget {
  final String targetId;
  final String type;

  const ModerationAuditTimeline({
    super.key,
    required this.targetId,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {

    final stream = FirebaseFirestore.instance
        .collection("admin_logs")
        .where("entityId", isEqualTo: targetId)
        .orderBy("createdAt", descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: docs.map((d) {

            final data = d.data() as Map<String, dynamic>;

            final action = data["action"] ?? "";
            final reason =
                (data["metadata"]?["reason"] ?? "").toString();

            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(action),
              subtitle: Text(reason),
            );

          }).toList(),
        );

      },
    );
  }
}