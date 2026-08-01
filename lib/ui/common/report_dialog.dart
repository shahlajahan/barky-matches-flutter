import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/app_localizations.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';

String _reasonLabel(AppLocalizations l10n, ReportReasonCode code) {
  switch (code) {
    case ReportReasonCode.spam:
      return l10n.reportReasonSpam;
    case ReportReasonCode.abuse:
      return l10n.reportReasonAbuse;
    case ReportReasonCode.scam:
      return l10n.reportReasonScam;
    case ReportReasonCode.fakeProfile:
      return l10n.reportReasonFakeProfile;
    case ReportReasonCode.inappropriateContent:
      return l10n.reportReasonInappropriateContent;
    case ReportReasonCode.animalSafety:
      return l10n.reportReasonAnimalSafety;
    case ReportReasonCode.other:
      return l10n.reportReasonOther;
  }
}

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
  // Shown inline in the sheet rather than via SnackBar: a SnackBar raised
  // from this context targets the Scaffold *behind* this modal bottom
  // sheet, so it renders hidden underneath it while the sheet stays open.
  String? _errorMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    if (_reasonCode == null) {
      setState(() => _errorMessage = l10n.reportSelectReasonError);
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.reportSubmittedSuccess)));
      return;
    }

    setState(() {
      _submitting = false;
      _errorMessage = _messageFor(l10n, outcome);
    });
  }

  String _messageFor(AppLocalizations l10n, ReportSubmitOutcome outcome) {
    switch (outcome.result) {
      case ReportSubmitResult.alreadyReported:
        return l10n.reportAlreadyReported;
      case ReportSubmitResult.rateLimited:
        return l10n.reportRateLimited;
      case ReportSubmitResult.targetNotFound:
        return l10n.reportTargetGone;
      case ReportSubmitResult.unauthenticated:
        return l10n.reportUnauthenticated;
      case ReportSubmitResult.unavailable:
        return l10n.reportNetworkError;
      case ReportSubmitResult.success:
        return l10n.reportGenericSuccess;
      case ReportSubmitResult.error:
        return outcome.message ?? l10n.reportGenericError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                  Text(
                    l10n.reportDialogTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ReportReasonCode>(
                initialValue: _reasonCode,
                decoration: InputDecoration(
                  labelText: l10n.reportReasonFieldLabel,
                  border: const OutlineInputBorder(),
                ),
                items: ReportReasonCode.values
                    .map(
                      (code) => DropdownMenuItem(
                        value: code,
                        child: Text(_reasonLabel(l10n, code)),
                      ),
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
                decoration: InputDecoration(
                  labelText: l10n.reportAdditionalDetailsHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
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
                      : Text(l10n.reportSubmitButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
