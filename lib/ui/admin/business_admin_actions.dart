import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class BusinessAdminActions extends StatefulWidget {
  final String businessId;
  final String requestId; // ممکن است برای برخی businessها null/خالی باشد
  final String status;    // pending | approved | rejected | suspended

  const BusinessAdminActions({
    super.key,
    required this.businessId,
    required this.requestId,
    required this.status,
  });

  @override
  State<BusinessAdminActions> createState() => _BusinessAdminActionsState();
}

class _BusinessAdminActionsState extends State<BusinessAdminActions> {
  bool _isLoading = false;

  HttpsCallable get _resolveCallable =>
      FirebaseFunctions.instanceFor(region: "europe-west3")
          .httpsCallable("resolveBusinessRequest");

  HttpsCallable get _suspendCallable =>
      FirebaseFunctions.instanceFor(region: "europe-west3")
          .httpsCallable("suspendBusiness");

  HttpsCallable get _restoreCallable =>
      FirebaseFunctions.instanceFor(region: "europe-west3")
          .httpsCallable("restoreBusiness");

  @override
  Widget build(BuildContext context) {
    final status = widget.status;

    // PENDING → Approve / Reject
    if (status == "pending") {
      return Row(
        children: [
          /// ❌ REJECT
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : _handleReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Reject"),
            ),
          ),

          const SizedBox(width: 12),

          /// ✅ APPROVE
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text("Approve"),
            ),
          ),
        ],
      );
    }

    // APPROVED → Suspend
    if (status == "approved") {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSuspend,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Suspend"),
            ),
          ),
        ],
      );
    }

    // SUSPENDED → Restore
    if (status == "suspended") {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRestore,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Restore"),
            ),
          ),
        ],
      );
    }

    // سایر حالت‌ها
    return const SizedBox.shrink();
  }

  // =========================
  // APPROVE
  // =========================

  Future<void> _handleApprove() async {
    setState(() => _isLoading = true);

    try {
      await _resolveCallable.call({
        "requestId": widget.requestId,
        "action": "approved",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Business approved")),
        );
      }
    } catch (e) {
      _showError(e);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // =========================
  // REJECT
  // =========================

  Future<void> _handleReject() async {
    final reason = await _showReasonDialog(
      title: "Reject Business",
      hint: "Enter rejection reason...",
      confirmText: "Reject",
      confirmColor: Colors.red,
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _resolveCallable.call({
        "requestId": widget.requestId,
        "action": "rejected",
        "reason": reason,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Business rejected")),
        );
      }
    } catch (e) {
      _showError(e);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // =========================
  // SUSPEND
  // =========================

  Future<void> _handleSuspend() async {
    final reason = await _showReasonDialog(
      title: "Suspend Business",
      hint: "Enter suspension reason...",
      confirmText: "Suspend",
      confirmColor: Colors.orange,
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _suspendCallable.call({
        "businessId": widget.businessId,
        "reason": reason,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Business suspended")),
        );
      }
    } catch (e) {
      _showError(e);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // =========================
  // RESTORE
  // =========================

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);

    try {
      await _restoreCallable.call({
        "businessId": widget.businessId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Business restored")),
        );
      }
    } catch (e) {
      _showError(e);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // =========================
  // DIALOG
  // =========================

  Future<String?> _showReasonDialog({
    required String title,
    required String hint,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Action failed: $e")),
    );
  }
}