// lib/ui/admin/moderation/models/moderation_report.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationReport {

  final String id;
  final String type;
  final String targetId;
  final String reportedBy;
  final String reasonCode;
  final String reasonText;
  final String message;
  final String status;
  final DateTime? createdAt;

  ModerationReport({
    required this.id,
    required this.type,
    required this.targetId,
    required this.reportedBy,
    required this.reasonCode,
    required this.reasonText,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory ModerationReport.fromSnapshot(
      DocumentSnapshot snap) {

    final data = snap.data() as Map<String, dynamic>;

    return ModerationReport(

      id: snap.id,

      type: data["type"] ?? "",

      targetId: data["targetId"] ?? "",

      reportedBy: data["reportedBy"] ?? "",

      reasonCode: data["reasonCode"] ?? "",

      reasonText: data["reasonText"] ?? "",

      message: data["message"] ?? "",

      status: data["status"] ?? "",

      createdAt:
          (data["createdAt"] as Timestamp?)?.toDate(),
    );
  }

}