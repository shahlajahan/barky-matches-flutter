import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/complaint_model.dart';
import '../admin_evidence_viewer.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

const _kPrimaryPink = Color(0xFFD6336C);
const _kResolveGreen = Color(0xFF2E7D32);
const _kDismissRed = Color(0xFFC62828);
const _kSurface = Color(0xFFF6F5F8);
const _kCardRadius = 16.0;

double _pagePadding(BuildContext context) =>
    MediaQuery.of(context).size.width >= 600 ? 20.0 : 16.0;

class AdminComplaintDetailPage extends StatelessWidget {
  final ComplaintModel complaint;

  const AdminComplaintDetailPage({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final padding = _pagePadding(context);

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: Text(l10n.complaintDetail),
        backgroundColor: _kPrimaryPink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                padding,
                padding,
                padding,
                padding + 88,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ComplaintHeader(complaint: complaint),
                  SizedBox(height: padding),
                  _StatusRow(complaint: complaint),
                  SizedBox(height: padding),
                  _SectionCard(
                    title: 'Description',
                    icon: Icons.notes_rounded,
                    child: Text(
                      complaint.description.trim().isEmpty
                          ? 'No description provided.'
                          : complaint.description,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: complaint.description.trim().isEmpty
                            ? Colors.black45
                            : Colors.black87,
                        fontStyle: complaint.description.trim().isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                  if (complaint.screenshotUrl != null &&
                      complaint.screenshotUrl!.isNotEmpty) ...[
                    SizedBox(height: padding),
                    _EvidenceSection(complaint: complaint, l10n: l10n),
                  ],
                  SizedBox(height: padding),
                  _DetailsSection(complaint: complaint, l10n: l10n),
                  SizedBox(height: padding),
                  _MessagesSection(complaintId: complaint.id),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _AdminActionBar(complaintId: complaint.id),
    );
  }
}

/// Title + created date, at the top of the page.
class _ComplaintHeader extends StatelessWidget {
  final ComplaintModel complaint;

  const _ComplaintHeader({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          complaint.displayTitle,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          complaint.createdAt == null
              ? 'Created date unknown'
              : 'Filed on ${_formatDate(complaint.createdAt!)}',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }
}

/// Status / Severity / Category as colored chips.
class _StatusRow extends StatelessWidget {
  final ComplaintModel complaint;

  const _StatusRow({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoChip(
          icon: _statusIcon(complaint.status),
          label: complaint.statusLabel,
          color: _statusColor(complaint.status),
        ),
        _InfoChip(
          icon: Icons.warning_amber_rounded,
          label: _capitalize(complaint.severityLabel),
          color: _severityColor(complaint.severity),
        ),
        _InfoChip(
          icon: Icons.category_rounded,
          label: complaint.categoryLabel,
          color: const Color(0xFF6A1B9A),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared rounded card used for every grouped section on the page.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final EdgeInsetsGeometry? childPadding;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.childPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _kPrimaryPink),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: childPadding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  final ComplaintModel complaint;
  final AppLocalizations l10n;

  const _EvidenceSection({required this.complaint, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionCard(
      title: l10n.evidence,
      icon: Icons.image_rounded,
      childPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AdminEvidenceViewer(imageUrl: complaint.screenshotUrl!),
              ),
            );
          },
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: SmartMedia(
                  url: complaint.screenshotUrl!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Complaint metadata (target, id, reporter, assignment) grouped in one card.
class _DetailsSection extends StatelessWidget {
  final ComplaintModel complaint;
  final AppLocalizations l10n;

  const _DetailsSection({required this.complaint, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final reporter = complaint.reporterSnapshot;
    final reporterLabel = reporter == null
        ? null
        : (reporter.username?.trim().isNotEmpty == true
              ? reporter.username!.trim()
              : (reporter.email?.trim().isNotEmpty == true
                    ? reporter.email!.trim()
                    : reporter.uid));

    return _SectionCard(
      title: 'Details',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.gps_fixed_rounded,
            label: 'Target',
            value: complaint.targetTypeLabel,
          ),
          _DetailRow(
            icon: Icons.tag_rounded,
            label: 'Complaint ID',
            value: complaint.id.isEmpty ? '—' : complaint.id,
            monospace: true,
          ),
          if (reporterLabel != null)
            _DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Reported by',
              value: reporterLabel,
            ),
          _DetailRow(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Assigned admin',
            value: complaint.isAssigned
                ? complaint.assignedAdminId!
                : 'Unassigned',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF0EEF2), width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.black45),
          const SizedBox(width: 10),
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message thread. Sized to its content instead of forcing a full-height
/// Expanded region, which previously left a large blank gap under the
/// Evidence card whenever a complaint had no messages yet.
class _MessagesSection extends StatelessWidget {
  final String complaintId;

  const _MessagesSection({required this.complaintId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionCard(
      title: 'Activity',
      icon: Icons.forum_outlined,
      childPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("complaints")
            .doc(complaintId)
            .collection("messages")
            .orderBy("createdAt")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: Colors.black38,
                  ),
                  SizedBox(width: 8),
                  Text(
                    l10n.complaintNoMessages,
                    style: TextStyle(fontSize: 13, color: Colors.black45),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final text = (data["text"] ?? "").toString();
              final senderType = (data["senderType"] ?? "user").toString();
              final isAdmin = senderType.toLowerCase() == 'admin';

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? _kPrimaryPink.withOpacity(0.06)
                      : const Color(0xFFF6F5F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderType,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isAdmin ? _kPrimaryPink : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Sticky bottom action bar: Resolve (primary) / Dismiss (destructive).
class _AdminActionBar extends StatefulWidget {
  final String complaintId;

  const _AdminActionBar({required this.complaintId});

  @override
  State<_AdminActionBar> createState() => _AdminActionBarState();
}

class _AdminActionBarState extends State<_AdminActionBar> {
  bool _updating = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _updating = true);
    try {
      await FirebaseFirestore.instance
          .collection("complaints")
          .doc(widget.complaintId)
          .update({"status": status});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'resolved'
                ? 'Complaint marked as resolved.'
                : 'Complaint dismissed.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _confirmAndUpdate({
    required String status,
    required String title,
    required String message,
    required Color color,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(title),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final padding = _pagePadding(context);

    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, 12, padding, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _updating
                      ? null
                      : () => _confirmAndUpdate(
                          status: 'dismissed',
                          title: l10n.dismiss,
                          message:
                              'This complaint will be marked as dismissed. Continue?',
                          color: _kDismissRed,
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kDismissRed,
                    side: const BorderSide(color: _kDismissRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    l10n.dismiss,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _updating
                      ? null
                      : () => _confirmAndUpdate(
                          status: 'resolved',
                          title: l10n.resolve,
                          message:
                              'This complaint will be marked as resolved. Continue?',
                          color: _kResolveGreen,
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kResolveGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _updating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    l10n.resolve,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return DateFormat('MMM d, yyyy · h:mm a').format(date);
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

Color _statusColor(ComplaintStatus status) {
  switch (status) {
    case ComplaintStatus.open:
      return const Color(0xFF1976D2);
    case ComplaintStatus.underReview:
      return const Color(0xFF7B1FA2);
    case ComplaintStatus.waitingUser:
      return const Color(0xFFF9A825);
    case ComplaintStatus.resolved:
      return _kResolveGreen;
    case ComplaintStatus.dismissed:
      return const Color(0xFF616161);
    case ComplaintStatus.escalated:
      return _kDismissRed;
    case ComplaintStatus.unknown:
      return const Color(0xFF9E9E9E);
  }
}

IconData _statusIcon(ComplaintStatus status) {
  switch (status) {
    case ComplaintStatus.open:
      return Icons.schedule_rounded;
    case ComplaintStatus.underReview:
      return Icons.visibility_outlined;
    case ComplaintStatus.waitingUser:
      return Icons.hourglass_bottom_rounded;
    case ComplaintStatus.resolved:
      return Icons.check_circle_rounded;
    case ComplaintStatus.dismissed:
      return Icons.cancel_rounded;
    case ComplaintStatus.escalated:
      return Icons.priority_high_rounded;
    case ComplaintStatus.unknown:
      return Icons.help_outline_rounded;
  }
}

Color _severityColor(ComplaintSeverity severity) {
  switch (severity) {
    case ComplaintSeverity.critical:
      return const Color(0xFFD32F2F);
    case ComplaintSeverity.high:
      return const Color(0xFFEF6C00);
    case ComplaintSeverity.medium:
      return const Color(0xFFF9A825);
    case ComplaintSeverity.low:
      return _kResolveGreen;
  }
}
