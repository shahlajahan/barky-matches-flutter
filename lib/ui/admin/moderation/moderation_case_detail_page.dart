// lib/admin/moderation/moderation_case_detail_page.dart

import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:barky_matches_fixed/ui/appointments/appointment_status_utils.dart';

import 'widgets/moderation_audit_timeline.dart';

/// Vet-appointment refund review. Previously also supported a second,
/// unreachable "content moderation case" view (constructed with `c:`) built
/// on the now-removed moderation_cases/moderation_targets pipeline - report
/// moderation lives entirely in AdminReportsPage now, so only the refund
/// path remains.
class ModerationCaseDetailPage extends StatefulWidget {
  final String appointmentId;

  const ModerationCaseDetailPage.refund({super.key, required this.appointmentId});

  @override
  State<ModerationCaseDetailPage> createState() =>
      _ModerationCaseDetailPageState();
}

class _ModerationCaseDetailPageState extends State<ModerationCaseDetailPage> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    return _refundReviewScaffold(widget.appointmentId);
  }

  Widget _refundReviewScaffold(String appointmentId) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.moderationCase),
        backgroundColor: Colors.pink,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("vet_appointments")
            .doc(appointmentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                AppLocalizations.of(
                  context,
                )!.firestoreError('${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return Center(
              child: Text(AppLocalizations.of(context)!.appointmentNotFound),
            );
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
            Text(
              AppLocalizations.of(context)!.refundReview,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.appointmentIdValue(appointmentId),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.paymentStatusValue(
                _text(data["paymentStatus"], "-"),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.refundStatusValue(
                _text(data["refundStatus"], "-"),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(
                context,
              )!.appointmentTimeValue(_formatDate(scheduledAt)),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(
                context,
              )!.cancellationTimeValue(_formatDate(cancelledAt)),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.hoursBeforeAppointmentValue(
                hours == null ? "-" : hours.toStringAsFixed(1),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.businessValue(
                _text(data["businessName"], "Unknown"),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.userValue(
                _text(data["userName"], "Unknown"),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.petValue(
                _text(data["petName"], "Unknown"),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.amountPaidValue(_amount(data)),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.refundReasonValue(
                _text(data["refundReason"], "-"),
              ),
            ),
            if (_text(data["refundError"], "").isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)!.refundErrorValue(
                  _text(data["refundError"], "-"),
                ),
              ),
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
            Text(
              AppLocalizations.of(context)!.adminActions,
              style: const TextStyle(fontWeight: FontWeight.bold),
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
                  : Text(AppLocalizations.of(context)!.approveRefund),
            ),
            ElevatedButton(
              onPressed: !_processing && canReview
                  ? () => _reviewRefund(appointmentId, "reject")
                  : null,
              child: Text(AppLocalizations.of(context)!.rejectRefund),
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
      ).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.refundReviewFailed('$e'),
          ),
        ),
      );
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
          title: Text(
            action == "approve"
                ? AppLocalizations.of(context)!.approveRefund
                : AppLocalizations.of(context)!.rejectRefund,
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.note,
            ),
            minLines: 2,
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(AppLocalizations.of(context)!.submit),
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
