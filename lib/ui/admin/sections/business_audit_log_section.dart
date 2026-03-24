import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_section.dart';

class BusinessAuditLogSection extends StatelessWidget {
  final String businessId;

  const BusinessAuditLogSection({
    super.key,
    required this.businessId,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSection(
      title: "Admin Activity",
      icon: Icons.history_outlined,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("admin_logs")
            .where("entityType", isEqualTo: "business")
            .where("entityId", isEqualTo: businessId)
            .orderBy("createdAt", descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Text(
              "No admin activity yet",
              style: TextStyle(color: Colors.black54),
            );
          }

          return Column(
            children: docs.map((doc) {
              final data =
                  doc.data() as Map<String, dynamic>;

              final action = data["action"] ?? "";
              final reason = data["reason"];
              final ts = data["createdAt"] as Timestamp?;

              final date = ts != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      ts.millisecondsSinceEpoch)
                  : null;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Icon(
                      Icons.circle,
                      size: 8,
                      color: Colors.grey,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatAction(action),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),

                          if (reason != null)
                            Text(
                              "Reason: $reason",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),

                          if (date != null)
                            Text(
                              "${date.toLocal()}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black38,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String _formatAction(String action) {
    switch (action) {
      case "approved":
        return "Business Approved";
      case "rejected":
        return "Business Rejected";
      case "notes_updated":
        return "Admin Notes Updated";
      default:
        return action;
    }
  }
}