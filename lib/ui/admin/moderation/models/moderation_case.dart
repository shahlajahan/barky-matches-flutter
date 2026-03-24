import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationCase {
  final String id;
  final String targetKey;
  final String type;
  final String targetId;
  final String? targetOwnerId;

  final String status;
  final String queueStatus;

  final String priority;
  final int priorityRank;

  final int reportCount;
  final int uniqueReporterCount;

  final int riskScore;

  final String? summary;

  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Timestamp lastActivityAt;

  ModerationCase({
    required this.id,
    required this.targetKey,
    required this.type,
    required this.targetId,
    required this.targetOwnerId,
    required this.status,
    required this.queueStatus,
    required this.priority,
    required this.priorityRank,
    required this.reportCount,
    required this.uniqueReporterCount,
    required this.riskScore,
    required this.summary,
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivityAt,
  });

  factory ModerationCase.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    return ModerationCase(
      id: doc.id,
      targetKey: d["targetKey"] ?? "",
      type: d["type"] ?? "",
      targetId: d["targetId"] ?? "",
      targetOwnerId: d["targetOwnerId"],
      status: d["status"] ?? "open",
      queueStatus: d["queueStatus"] ?? "pending_review",
      priority: d["priority"] ?? "low",
      priorityRank: d["priorityRank"] ?? 1,
      reportCount: d["reportCount"] ?? 0,
      uniqueReporterCount: d["uniqueReporterCount"] ?? 0,
      riskScore: d["riskScore"] ?? 0,
      summary: d["summary"],
      createdAt: d["createdAt"],
      updatedAt: d["updatedAt"],
      lastActivityAt: d["lastActivityAt"],
    );
  }
}