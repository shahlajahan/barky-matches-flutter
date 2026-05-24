import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/ui/admin/moderation/moderation_case_detail_page.dart';
import 'investigation_page.dart';

class ModerationQueuePage extends StatelessWidget {
  const ModerationQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Moderation Queue"),
        backgroundColor: Colors.pink,
      ),
      body: ListView(
        children: [
          _refundRequestsSection(),
          const Divider(height: 1),
          _reportsSection(),
        ],
      ),
    );
  }

  Widget _refundRequestsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("vet_appointments")
          .where("refundStatus", isEqualTo: "pending_manual_review")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Refund queue error: ${snapshot.error}"),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final ad = _timestampMillis(
            (a.data() as Map<String, dynamic>)["cancelledAt"],
          );
          final bd = _timestampMillis(
            (b.data() as Map<String, dynamic>)["cancelledAt"],
          );
          return bd.compareTo(ad);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                "Refund Requests",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text("No pending refund requests"),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildRefundItem(context, doc.id, data);
              }),
          ],
        );
      },
    );
  }

  Widget _reportsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reports")
          .where("status", isEqualTo: "pending")
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint("📊 moderation state → ${snapshot.connectionState}");
        debugPrint("📊 moderation error → ${snapshot.error}");

        if (snapshot.hasError) {
          return Center(child: Text("Firestore error: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                "Reports",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (reports.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text("No pending moderation items"),
              )
            else
              ...reports.map((report) {
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
              }),
          ],
        );
      },
    );
  }

  Widget _buildRefundItem(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    final scheduledAt = _asDateTime(data["scheduledAt"]);
    final cancelledAt = _asDateTime(
      data["cancelledAt"] ?? data["statusUpdatedAt"],
    );
    final hours = scheduledAt == null || cancelledAt == null
        ? null
        : scheduledAt.difference(cancelledAt).inMinutes / 60;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.payments_outlined, color: Colors.orange),
        title: Text(
          "${_text(data["petName"], "Pet")} • ${_text(data["businessName"], "Clinic")}",
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("User: ${_text(data["userName"], "Unknown")}"),
            Text("Appointment: ${_formatDate(scheduledAt)}"),
            Text("Cancelled: ${_formatDate(cancelledAt)}"),
            Text("Amount: ${_amount(data)}"),
            if (hours != null)
              Text("Hours before appointment: ${hours.toStringAsFixed(1)}"),
            if (_text(data["refundReason"], "").isNotEmpty)
              Text("Reason: ${_text(data["refundReason"], "")}"),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          debugPrint("🩺 ADMIN REFUND REVIEW OPEN → $appointmentId");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ModerationCaseDetailPage.refund(appointmentId: appointmentId),
            ),
          );
        },
      ),
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

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _timestampMillis(dynamic value) {
    return _asDateTime(value)?.millisecondsSinceEpoch ?? 0;
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return "-";
    return "${value.year.toString().padLeft(4, '0')}-"
        "${value.month.toString().padLeft(2, '0')}-"
        "${value.day.toString().padLeft(2, '0')} "
        "${value.hour.toString().padLeft(2, '0')}:"
        "${value.minute.toString().padLeft(2, '0')}";
  }

  static String _text(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? "";
    return text.isEmpty ? fallback : text;
  }

  static String _amount(Map<String, dynamic> data) {
    final value =
        data["amount"] ??
        data["paidAmount"] ??
        data["price"] ??
        data["servicePrice"] ??
        data["total"];
    if (value == null) return "-";
    return "$value ${_text(data["currency"], "TRY")}";
  }
}
