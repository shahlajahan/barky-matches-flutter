// lib/admin/moderation/moderation_case_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:barky_matches_fixed/ui/appointments/appointment_status_utils.dart';

import 'models/moderation_case.dart';
import 'widgets/case_reports_section.dart';
import 'widgets/moderation_action_bar.dart';
import 'widgets/moderation_audit_timeline.dart';

class ModerationCaseDetailPage extends StatefulWidget {
  final ModerationCase? c;
  final String? refundAppointmentId;

  const ModerationCaseDetailPage({super.key, required ModerationCase this.c})
    : refundAppointmentId = null;

  const ModerationCaseDetailPage.refund({
    super.key,
    required String appointmentId,
  }) : c = null,
       refundAppointmentId = appointmentId;

  @override
  State<ModerationCaseDetailPage> createState() =>
      _ModerationCaseDetailPageState();
}

class _ModerationCaseDetailPageState extends State<ModerationCaseDetailPage> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final refundAppointmentId = widget.refundAppointmentId;
    if (refundAppointmentId != null) {
      return _refundReviewScaffold(refundAppointmentId);
    }

    final c = widget.c!;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Moderation Case"),
        backgroundColor: Colors.pink,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _caseHeader(),

            CaseReportsSection(targetId: c.targetId),

            ModerationActionBar(
              caseId: c.id,
              targetId: c.targetId,
              type: c.type,
            ),

            ModerationAuditTimeline(targetId: c.targetId, type: c.type),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _caseHeader() {
    final c = widget.c!;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Target: ${c.type}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text("Target ID: ${c.targetId}"),

            const SizedBox(height: 10),

            Text("Reports: ${c.reportCount}"),

            const SizedBox(height: 10),

            Text("Risk Score: ${c.riskScore}"),

            const SizedBox(height: 10),

            Text("Priority: ${c.priority}"),
          ],
        ),
      ),
    );
  }

  Widget _refundReviewScaffold(String appointmentId) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Moderation Case"),
        backgroundColor: Colors.pink,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("vet_appointments")
            .doc(appointmentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Firestore error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text("Appointment not found"));
          }

          final data = snapshot.data!.data() ?? {};
          return SingleChildScrollView(
            child: Column(
              children: [
                _refundHeader(appointmentId, data),
                _refundActionBar(appointmentId, data),
                ModerationAuditTimeline(
                  targetId: appointmentId,
                  type: "vet_appointment",
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _refundHeader(String appointmentId, Map<String, dynamic> data) {
    final scheduledAt = _asDateTime(data["scheduledAt"]);
    final cancelledAt = _asDateTime(
      data["cancelledAt"] ?? data["statusUpdatedAt"],
    );
    final hours = AppointmentStatusUtils.hoursBeforeAppointment(
      scheduledAt: scheduledAt,
      cancelledAt: cancelledAt,
    );

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Refund Review",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("Appointment ID: $appointmentId"),
            const SizedBox(height: 10),
            Text("Payment Status: ${_text(data["paymentStatus"], "-")}"),
            const SizedBox(height: 10),
            Text("Refund Status: ${_text(data["refundStatus"], "-")}"),
            const SizedBox(height: 10),
            Text("Appointment Time: ${_formatDate(scheduledAt)}"),
            const SizedBox(height: 10),
            Text("Cancellation Time: ${_formatDate(cancelledAt)}"),
            const SizedBox(height: 10),
            Text(
              "Hours Before Appointment: ${hours == null ? "-" : hours.toStringAsFixed(1)}",
            ),
            const SizedBox(height: 10),
            Text("Business: ${_text(data["businessName"], "Unknown")}"),
            const SizedBox(height: 10),
            Text("User: ${_text(data["userName"], "Unknown")}"),
            const SizedBox(height: 10),
            Text("Pet: ${_text(data["petName"], "Unknown")}"),
            const SizedBox(height: 10),
            Text("Amount Paid: ${_amount(data)}"),
            const SizedBox(height: 10),
            Text("Refund Reason: ${_text(data["refundReason"], "-")}"),
            if (_text(data["refundError"], "").isNotEmpty) ...[
              const SizedBox(height: 10),
              Text("Refund Error: ${_text(data["refundError"], "-")}"),
            ],
          ],
        ),
      ),
    );
  }

  Widget _refundActionBar(String appointmentId, Map<String, dynamic> data) {
    final canReview = AppointmentStatusUtils.requiresManualRefundReview(data);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Admin Actions",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: !_processing && canReview
                  ? () => _reviewRefund(appointmentId, "approve")
                  : null,
              child: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Approve Refund"),
            ),
            ElevatedButton(
              onPressed: !_processing && canReview
                  ? () => _reviewRefund(appointmentId, "reject")
                  : null,
              child: const Text("Reject Refund"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewRefund(String appointmentId, String action) async {
    final note = await _askForNote(action);
    if (note == null) return;

    setState(() => _processing = true);

    try {
      const callableRegion = 'europe-west3';
      final currentUser = FirebaseAuth.instance.currentUser;

      debugPrint("🩺 ADMIN REFUND CALLABLE REGION → $callableRegion");
      debugPrint(
        "🌐 FUNCTIONS INSTANCE CREATED → reviewVetAppointmentRefund region=$callableRegion",
      );
      debugPrint("🩺 ADMIN REFUND AUTH UID → ${currentUser?.uid}");
      debugPrint(
        "🩺 ADMIN REFUND AUTH CURRENT USER NULL → ${currentUser == null}",
      );

      if (currentUser == null) {
        throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Admin user is not signed in.',
          details: null,
        );
      }
      /*
      final token = await currentUser.getIdToken(true);
      debugPrint(
        "🩺 ADMIN REFUND GET ID TOKEN SUCCESS → ${token?.isNotEmpty == true}",
      );
*/
      debugPrint(
        action == "approve"
            ? "🩺 ADMIN REFUND APPROVED → $appointmentId"
            : "🩺 ADMIN REFUND REJECTED → $appointmentId",
      );

      final callable = FirebaseFunctions.instanceFor(
        region: callableRegion,
      ).httpsCallable("reviewVetAppointmentRefund");

      await callable.call({
        "appointmentId": appointmentId,
        "action": action,
        "note": note,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == "approve" ? "Refund approved" : "Refund rejected",
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint("🩺 ADMIN REFUND FUNCTION ERROR RAW → $e");
      debugPrint("🩺 ADMIN REFUND FUNCTION ERROR STACK → $stack");
      debugPrint(
        "🩺 ADMIN REFUND FUNCTION ERROR → "
        "code=${e.code} message=${e.message} details=${e.details}",
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Refund review failed")),
      );
    } catch (e, stack) {
      debugPrint("🩺 ADMIN REFUND RAW ERROR → $e");
      debugPrint("🩺 ADMIN REFUND STACK → $stack");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Refund review failed: $e")));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<String?> _askForNote(String action) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(action == "approve" ? "Approve Refund" : "Reject Refund"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: "Note"),
            minLines: 2,
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return "-";
    return "${value.year.toString().padLeft(4, '0')}-"
        "${value.month.toString().padLeft(2, '0')}-"
        "${value.day.toString().padLeft(2, '0')} "
        "${value.hour.toString().padLeft(2, '0')}:"
        "${value.minute.toString().padLeft(2, '0')}";
  }

  String _text(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? "";
    return text.isEmpty ? fallback : text;
  }

  String _amount(Map<String, dynamic> data) {
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
