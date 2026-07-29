import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';

const Map<ReportReasonCode, String> _kReasonLabels = {
  ReportReasonCode.spam: 'Spam',
  ReportReasonCode.abuse: 'Abuse / harassment',
  ReportReasonCode.scam: 'Scam',
  ReportReasonCode.fakeProfile: 'Fake profile',
  ReportReasonCode.inappropriateContent: 'Inappropriate content',
  ReportReasonCode.animalSafety: 'Animal safety',
  ReportReasonCode.other: 'Other',
};

/// Single entry point for reporting any target type (dog, user, post,
/// comment, business). Replaces the old dead ReportDialog and the buggy
/// ReportButton (which nested its own dialog inside a bottom sheet).
Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  String? targetOwnerId,
}) async {
  final appState = context.read<AppState>();
  if (appState.isGuest) {
    appState.openGuestFeatureGate();
    return;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
      targetOwnerId: targetOwnerId,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String? targetOwnerId;

  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.targetOwnerId,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReasonCode? _reasonCode;
  final _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reasonCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason')),
      );
      return;
    }

    setState(() => _submitting = true);

    final description = _descriptionController.text.trim();
    final outcome = await ReportService.submitReport(
      targetType: widget.targetType,
      targetId: widget.targetId,
      targetOwnerId: widget.targetOwnerId,
      reasonCode: _reasonCode!,
      description: description.isEmpty ? null : description,
    );

    if (!mounted) return;

    if (outcome.result == ReportSubmitResult.success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you for helping keep the community safe.')),
      );
      return;
    }

    setState(() => _submitting = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_messageFor(outcome))));
  }

  String _messageFor(ReportSubmitOutcome outcome) {
    switch (outcome.result) {
      case ReportSubmitResult.alreadyReported:
        return "You've already reported this - it's pending review.";
      case ReportSubmitResult.rateLimited:
        return 'Too many reports submitted recently. Please try again later.';
      case ReportSubmitResult.targetNotFound:
        return 'This item no longer exists.';
      case ReportSubmitResult.unauthenticated:
        return 'Please sign in to submit a report.';
      case ReportSubmitResult.unavailable:
        return "Couldn't reach the server. Check your connection and try again.";
      case ReportSubmitResult.success:
        return 'Report submitted.';
      case ReportSubmitResult.error:
        return outcome.message ?? 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_outlined),
                  const SizedBox(width: 8),
                  Text('Report', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ReportReasonCode>(
                initialValue: _reasonCode,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                items: _kReasonLabels.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _reasonCode = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
