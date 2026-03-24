import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminActivityFeed extends StatelessWidget {
  const AdminActivityFeed({super.key});

  @override
  Widget build(BuildContext context) {

    print("📜 AdminActivityFeed BUILD");

    final stream = FirebaseFirestore.instance
        .collection("admin_logs")
        .orderBy("createdAt", descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {

        print("📡 AdminActivity snapshot:");
        print("hasData: ${snapshot.hasData}");
        print("hasError: ${snapshot.hasError}");
        print("connectionState: ${snapshot.connectionState}");

        /// ERROR
        if (snapshot.hasError) {

          print("❌ AdminActivity ERROR → ${snapshot.error}");

          return Center(
            child: Text(
              "Activity error:\n${snapshot.error}",
              textAlign: TextAlign.center,
            ),
          );
        }

        /// LOADING
        if (!snapshot.hasData) {

          print("⏳ waiting for admin logs...");

          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;

        print("✅ Admin logs loaded: ${docs.length}");

        /// EMPTY
        if (docs.isEmpty) {

          return const Center(
            child: Text("No admin activity yet"),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {

            final data = docs[index].data() as Map<String,dynamic>;

            /// ---- FLEXIBLE FIELD SUPPORT ----
            final action =
                data["action"] ??
                data["type"] ??
                data["event"] ??
                "activity";

            final entity =
                data["entityType"] ??
                data["targetType"] ??
                "";

            final id =
                data["entityId"] ??
                data["targetId"] ??
                "";

            final Timestamp? ts = data["createdAt"];
            final DateTime? time = ts?.toDate();

            print("📌 activity → $action / $entity");

            /// ---- FORMAT ACTION TEXT ----
            final title = _formatAction(action, entity);

            /// ---- ICON ----
            final icon = _iconForAction(action);

            return ListTile(
              leading: Icon(icon, color: Colors.grey[700]),
              title: Text(title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  if (id.isNotEmpty)
                    Text(
                      id,
                      style: const TextStyle(fontSize: 12),
                    ),

                  if (time != null)
                    Text(
                      DateFormat("MMM d • HH:mm").format(time),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// ------------------------------------------------
  /// FORMAT ACTION TEXT
  /// ------------------------------------------------
  String _formatAction(String action, String entity) {

  switch (action) {

    case "approved":
      return "Business approved";

    case "rejected":
      return "Business rejected";

    case "business_suspend":
      return "Business suspended";

    case "business_restore":
      return "Business restored";

    case "suspended":
      return "Business suspended";

    case "report":
      return "Content reported";

    case "fraud_flag":
      return "Fraud alert";

    default:
      return "$action $entity".trim();
  }
}

  /// ------------------------------------------------
  /// ICON SELECTOR
  /// ------------------------------------------------
  IconData _iconForAction(String action) {

  switch (action) {

    case "approved":
      return Icons.check_circle;

    case "rejected":
      return Icons.cancel;

    case "business_suspend":
    case "suspended":
      return Icons.block;

    case "business_restore":
      return Icons.restore;

    case "report":
      return Icons.flag;

    case "fraud_flag":
      return Icons.warning;

    default:
      return Icons.history;
  }
}
}