import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationTarget {
  final String targetKey;
  final String type;
  final String targetId;
  final String? targetOwnerId;

  final int reportCount;
  final int openReportCount;

  final int riskScore;
  final String effectiveStatus;

  final bool autoHidden;

  final Timestamp createdAt;
  final Timestamp updatedAt;

  ModerationTarget({
    required this.targetKey,
    required this.type,
    required this.targetId,
    required this.targetOwnerId,
    required this.reportCount,
    required this.openReportCount,
    required this.riskScore,
    required this.effectiveStatus,
    required this.autoHidden,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ModerationTarget.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    return ModerationTarget(
      targetKey: d["targetKey"],
      type: d["type"],
      targetId: d["targetId"],
      targetOwnerId: d["targetOwnerId"],
      reportCount: d["reportCount"] ?? 0,
      openReportCount: d["openReportCount"] ?? 0,
      riskScore: d["riskScore"] ?? 0,
      effectiveStatus: d["effectiveStatus"] ?? "clean",
      autoHidden: d["autoHidden"] ?? false,
      createdAt: d["createdAt"],
      updatedAt: d["updatedAt"],
    );
  }
}