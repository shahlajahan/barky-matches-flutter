// lib/ui/admin/moderation/widgets/moderation_audit_timeline.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../utils/relative_time.dart';
import '../../../../l10n/app_localizations.dart';

/// Shows the admin_logs audit trail for a single target (all report
/// approve/reject/restore actions taken against it). Reads `reason` at the
/// top level (the schema written by reviewReport/restoreModerationTarget/
/// reactivateUser) and falls back to the legacy nested `metadata.reason`
/// shape written by the now-removed reviewModerationCase, so any older
/// entries still render instead of showing a blank subtitle.
class ModerationAuditTimeline extends StatelessWidget {
  final String targetId;
  final String type;

  const ModerationAuditTimeline({
    super.key,
    required this.targetId,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection("admin_logs")
        .where("entityId", isEqualTo: targetId)
        .orderBy("createdAt", descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final docs = snapshot.data!.docs;
        final l10n = AppLocalizations.of(context)!;

        if (docs.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.moderationNoHistory,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;

            final action = (data["action"] ?? "").toString();
            final moderationAction = data["moderationAction"];
            final reason = (data["reason"] ?? data["metadata"]?["reason"] ?? "")
                .toString();
            final createdAt = (data["createdAt"] as Timestamp?)?.toDate();

            final subtitleParts = [
              if (moderationAction != null && moderationAction != 'null')
                'Action: $moderationAction',
              if (reason.isNotEmpty) reason,
              if (createdAt != null) formatRelativeTime(createdAt),
            ];

            return ListTile(
              dense: true,
              leading: const Icon(Icons.history, size: 20),
              title: Text(action),
              subtitle: Text(subtitleParts.join(' • ')),
            );
          }).toList(),
        );
      },
    );
  }
}
