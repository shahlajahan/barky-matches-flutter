import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/report_model.dart';
import '../../../../models/report_target_registry.dart';
import '../../../../services/report_service.dart';
import '../../../../services/report_target_resolver_service.dart';
import '../../../../utils/relative_time.dart';
import 'moderation_audit_timeline.dart';

/// The production moderation card for a single report: resolves the
/// reporter and target to real names/images (via the target-type registry,
/// never a switch statement), lets an admin approve (picking the target's
/// registry-defined action) or reject, and shows the full report history +
/// moderation audit timeline for the target so decisions are consistent.
class ReportModerationCard extends StatefulWidget {
  final Report report;

  const ReportModerationCard({super.key, required this.report});

  @override
  State<ReportModerationCard> createState() => _ReportModerationCardState();
}

class _ReportModerationCardState extends State<ReportModerationCard> {
  late Future<ReportTargetInfo> _targetFuture;
  late Future<ReportUserInfo> _reporterFuture;
  Future<ReportUserInfo>? _reviewerFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final report = widget.report;
    _targetFuture = ReportTargetResolverService.resolveTarget(
      report.targetType,
      report.targetId,
    );
    _reporterFuture = ReportTargetResolverService.resolveUser(
      report.reporterId,
    );
    _reviewerFuture = report.reviewedBy != null
        ? ReportTargetResolverService.resolveUser(report.reviewedBy!)
        : null;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(_load);
  }

  Color _statusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.approved:
        return Colors.green;
      case ReportStatus.rejected:
        return Colors.red;
    }
  }

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

  String _errorMessage(AppLocalizations l10n, String? code, String? message) {
    switch (code) {
      case 'permission-denied':
        return l10n.moderationPermissionDenied;
      case 'not-found':
        return l10n.moderationNotFound;
      case 'failed-precondition':
        return l10n.moderationAlreadyReviewed;
      case 'unavailable':
        return l10n.moderationNetworkError;
      default:
        return message ?? l10n.reportGenericError;
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askNotes(String title) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.moderationNotesLabel),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.moderationCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.moderationConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _approve() async {
    final l10n = AppLocalizations.of(context)!;
    final config = kReportTargetRegistry[widget.report.targetType];
    if (config == null) {
      _showSnack(l10n.moderationUnknownTargetType);
      return;
    }

    final result = await showModalBottomSheet<_ApproveResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ApproveSheet(actions: config.moderationActions),
    );
    if (result == null) return;

    setState(() => _busy = true);
    final outcome = await ReportService.reviewReport(
      reportId: widget.report.id,
      action: 'approved',
      moderationAction: result.action,
      notes: result.notes,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (outcome.success) {
      _showSnack(
        outcome.targetFound
            ? l10n.moderationReportApproved
            : l10n.moderationReportApprovedNoTarget,
      );
    } else {
      _showSnack(_errorMessage(l10n, outcome.errorCode, outcome.message));
    }
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context)!;
    final notes = await _askNotes(l10n.moderationRejectReportTitle);
    if (notes == null) return;

    setState(() => _busy = true);
    final outcome = await ReportService.reviewReport(
      reportId: widget.report.id,
      action: 'rejected',
      notes: notes,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (outcome.success) {
      _showSnack(l10n.moderationReportRejected);
    } else {
      _showSnack(_errorMessage(l10n, outcome.errorCode, outcome.message));
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    final notes = await _askNotes(l10n.moderationRestoreTargetTitle);
    if (notes == null) return;

    setState(() => _busy = true);
    final outcome = await ReportService.restoreModerationTarget(
      targetType: widget.report.targetType,
      targetId: widget.report.targetId,
      notes: notes,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (outcome.success) {
      _showSnack(l10n.moderationTargetRestored);
      await _refresh();
    } else {
      _showSnack(_errorMessage(l10n, outcome.errorCode, outcome.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final report = widget.report;
    final typeConfig = kReportTargetRegistry[report.targetType];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(report.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor(report.status)),
                  ),
                  child: Text(
                    report.status.name.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(report.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatRelativeTime(report.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<ReportTargetInfo>(
              future: _targetFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                final target = snapshot.data!;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: target.imageUrl != null
                          ? NetworkImage(target.imageUrl!)
                          : null,
                      child: target.imageUrl == null
                          ? Icon(typeConfig?.icon ?? Icons.flag)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${typeConfig?.label ?? report.targetType}: ${target.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!target.exists)
                            Text(
                              l10n.moderationTargetGone,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          if (target.ownerName != null)
                            Text(
                              l10n.moderationOwnerLabel(target.ownerName!),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<ReportUserInfo>(
              future: _reporterFuture,
              builder: (context, snapshot) {
                return Text(
                  l10n.moderationReporterLabel(snapshot.data?.name ?? '...'),
                  style: const TextStyle(fontSize: 13),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              l10n.moderationReasonLabel(_reasonLabel(l10n, report.reasonCode)),
              style: const TextStyle(fontSize: 13),
            ),
            if ((report.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                report.description!,
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            if (report.status == ReportStatus.pending)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy ? null : _approve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: _busy
                          ? const _MiniSpinner()
                          : Text(l10n.moderationApproveButton),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy ? null : _reject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: _busy
                          ? const _MiniSpinner()
                          : Text(l10n.moderationRejectButton),
                    ),
                  ),
                ],
              )
            else
              FutureBuilder<ReportUserInfo>(
                future: _reviewerFuture,
                builder: (context, snapshot) {
                  final parts = <String>[
                    l10n.moderationReviewedByLabel(
                      snapshot.data?.name ?? report.reviewedBy ?? 'admin',
                    ),
                    if (report.moderationAction != null)
                      l10n.moderationActionLabel(report.moderationAction!),
                    formatRelativeTime(report.reviewedAt),
                  ].where((p) => p.isNotEmpty).toList();
                  return Text(
                    parts.join(' • '),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  );
                },
              ),
            FutureBuilder<ReportTargetInfo>(
              future: _targetFuture,
              builder: (context, snapshot) {
                final target = snapshot.data;
                if (target == null || !target.exists || !target.isModerated) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: _busy ? null : _restore,
                    child: Text(l10n.moderationRestoreButton),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                l10n.moderationHistorySectionTitle,
                style: const TextStyle(fontSize: 13),
              ),
              children: [
                _ReportHistorySection(
                  targetType: report.targetType,
                  targetId: report.targetId,
                  excludeReportId: report.id,
                ),
                ModerationAuditTimeline(
                  targetId: report.targetId,
                  type: report.targetType,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSpinner extends StatelessWidget {
  const _MiniSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 18,
    width: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}

class _ApproveResult {
  final String action;
  final String notes;

  const _ApproveResult(this.action, this.notes);
}

class _ApproveSheet extends StatefulWidget {
  final Map<String, String> actions;

  const _ApproveSheet({required this.actions});

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  String? _selected;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
              Text(
                l10n.moderationChooseAction,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ...widget.actions.entries.map(
                (e) => RadioListTile<String>(
                  value: e.key,
                  groupValue: _selected,
                  title: Text(e.value),
                  onChanged: (v) => setState(() => _selected = v),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.moderationNotesLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.pop(
                          context,
                          _ApproveResult(
                            _selected!,
                            _notesController.text.trim(),
                          ),
                        ),
                  child: Text(l10n.moderationApproveApply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportHistorySection extends StatelessWidget {
  final String targetType;
  final String targetId;
  final String excludeReportId;

  const _ReportHistorySection({
    required this.targetType,
    required this.targetId,
    required this.excludeReportId,
  });

  Color _statusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.approved:
        return Colors.green;
      case ReportStatus.rejected:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stream = FirebaseFirestore.instance
        .collection('reports')
        .where('targetType', isEqualTo: targetType)
        .where('targetId', isEqualTo: targetId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final reports = snapshot.data!.docs
            .map(Report.fromFirestore)
            .where((r) => r.id != excludeReportId)
            .toList();

        if (reports.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.moderationNoOtherReports,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          );
        }

        return Column(
          children: reports.map((r) {
            return FutureBuilder<ReportUserInfo>(
              future: ReportTargetResolverService.resolveUser(r.reporterId),
              builder: (context, snap) {
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: _statusColor(r.status),
                  ),
                  title: Text(
                    '${snap.data?.name ?? '...'} • ${r.status.name}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    formatRelativeTime(r.createdAt),
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}
