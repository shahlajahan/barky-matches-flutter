import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/ui/admin/moderation/moderation_case_detail_page.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

/// Refund-request review queue. Report moderation now lives entirely in
/// AdminReportsPage - this page used to also list reports (duplicating that
/// screen with raw IDs); that section has been removed.
class ModerationQueuePage extends StatelessWidget {
  const ModerationQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.refundRequests),
        backgroundColor: Colors.pink,
      ),
      body: ListView(children: [_refundRequestsSection()]),
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
            child: Text(
              AppLocalizations.of(
                context,
              )!.refundQueueError('${snapshot.error}'),
            ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                AppLocalizations.of(context)!.refundRequests,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(
                  AppLocalizations.of(context)!.noPendingRefundRequests,
                ),
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
            Text(
              AppLocalizations.of(context)!.userValue(
                _text(data["userName"], "Unknown"),
              ),
            ),
            Text(
              AppLocalizations.of(
                context,
              )!.appointmentValue(_formatDate(scheduledAt)),
            ),
            Text(
              AppLocalizations.of(
                context,
              )!.cancelledValue(_formatDate(cancelledAt)),
            ),
            Text(AppLocalizations.of(context)!.amountValue(_amount(data))),
            if (hours != null)
              Text(
                AppLocalizations.of(
                  context,
                )!.hoursBeforeAppointmentValue(hours.toStringAsFixed(1)),
              ),
            if (_text(data["refundReason"], "").isNotEmpty)
              Text(
                AppLocalizations.of(context)!.reasonValue(
                  _text(data["refundReason"], ""),
                ),
              ),
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
