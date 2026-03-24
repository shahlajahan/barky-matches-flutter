import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/complaint_model.dart';
import '../admin_evidence_viewer.dart';

class AdminComplaintDetailPage extends StatelessWidget {

  final ComplaintModel complaint;

  const AdminComplaintDetailPage({
    super.key,
    required this.complaint,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Complaint Detail"),
        backgroundColor: Colors.pink,
      ),

      body: Column(
        children: [

          /// complaint info
          _ComplaintInfo(complaint: complaint),

          const Divider(),

          /// message thread
          Expanded(
            child: _ComplaintMessages(
              complaintId: complaint.id,
            ),
          ),

          /// admin actions
          _AdminActions(
            complaintId: complaint.id,
          )
        ],
      ),
    );
  }
}
class _ComplaintInfo extends StatelessWidget {

  final ComplaintModel complaint;

  const _ComplaintInfo({
    required this.complaint,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            complaint.displayTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text("Target: ${complaint.targetTypeLabel}"),

          Text("Category: ${complaint.categoryLabel}"),

          Text("Severity: ${complaint.severityLabel}"),

          Text("Status: ${complaint.statusLabel}"),

          const SizedBox(height: 10),

          Text(
            complaint.description,
            style: const TextStyle(fontSize: 15),
          ),
          if (complaint.screenshotUrl != null &&
    complaint.screenshotUrl!.isNotEmpty)

  Padding(
    padding: const EdgeInsets.only(top:20),

    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text(
          "Evidence",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),

        const SizedBox(height:10),

        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(

  onTap: () {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEvidenceViewer(
          imageUrl: complaint.screenshotUrl!,
        ),
      ),
    );

  },

  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      complaint.screenshotUrl!,
      height: 250,
      width: double.infinity,
      fit: BoxFit.cover,
    ),
  ),
)
        ),
      ],
    ),
  ),
        ],
      ),
    );
  }
}
class _ComplaintMessages extends StatelessWidget {

  final String complaintId;

  const _ComplaintMessages({
    required this.complaintId,
  });

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("complaints")
          .doc(complaintId)
          .collection("messages")
          .orderBy("createdAt")
          .snapshots(),
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {

            final data = docs[index].data() as Map<String, dynamic>;

            final text = data["text"] ?? "";
            final senderType = data["senderType"] ?? "user";

            return ListTile(
              title: Text(text),
              subtitle: Text(senderType),
            );
          },
        );
      },
    );
  }
}
class _AdminActions extends StatelessWidget {

  final String complaintId;

  const _AdminActions({
    required this.complaintId,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () {

              FirebaseFirestore.instance
                  .collection("complaints")
                  .doc(complaintId)
                  .update({
                "status": "resolved"
              });

            },
            child: const Text("Resolve"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {

              FirebaseFirestore.instance
                  .collection("complaints")
                  .doc(complaintId)
                  .update({
                "status": "dismissed"
              });

            },
            child: const Text("Dismiss"),
          ),

        ],
      ),
    );
  }
}