import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogsPage extends StatelessWidget {
  const AuditLogsPage({super.key});

  IconData _iconForAction(String action) {
    switch (action) {
      case "approved":
        return Icons.check_circle;
      case "rejected":
        return Icons.cancel;
      case "suspended":
        return Icons.block;
      case "restored":
        return Icons.restore;
      default:
        return Icons.admin_panel_settings;
    }
  }

  Color _colorForAction(String action) {
    switch (action) {
      case "approved":
        return Colors.green;
      case "rejected":
        return Colors.red;
      case "suspended":
        return Colors.orange;
      case "restored":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _shortId(String id) {
    if (id.length < 10) return id;
    return "${id.substring(0,6)}...${id.substring(id.length-4)}";
  }

  @override
  Widget build(BuildContext context) {

    final stream = FirebaseFirestore.instance
        .collection("admin_logs")
        .orderBy("createdAt", descending: true)
        .limit(100)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Audit Logs"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final data =
                  docs[index].data() as Map<String, dynamic>;

              final action = data["action"] ?? "";
              final entityType = data["entityType"] ?? "";
              final entityId = data["entityId"] ?? "";

              if (action.isEmpty && entityType.isEmpty) {
                return const SizedBox();
              }

              final reason =
                  data["metadata"]?["reason"] ?? "";

              final ts = data["createdAt"] as Timestamp?;
              final time = ts?.toDate();

              final icon = _iconForAction(action);
              final color = _colorForAction(action);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, color: color),
                ),

                title: Text(
                  "$action $entityType",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                subtitle: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Text(
                      _shortId(entityId),
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),

                    if (reason.isNotEmpty)
                      Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),

                trailing: Text(
                  time == null
                      ? ""
                      : "${time.day}/${time.month} "
                        "${time.hour}:${time.minute}",
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
}