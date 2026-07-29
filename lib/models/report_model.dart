import 'package:cloud_firestore/cloud_firestore.dart';

/// Report target types are intentionally NOT a closed Dart enum. New target
/// types (vet appointments, marketplace products, chat messages, ...) should
/// be addable by registering one entry in `report_target_registry.dart`, not
/// by touching an exhaustive switch statement here or anywhere else.
class ReportTargetType {
  static const String dog = 'dog';
  static const String user = 'user';
  static const String post = 'post';
  static const String comment = 'comment';
  static const String business = 'business';

  static const List<String> values = [dog, user, post, comment, business];
}

enum ReportReasonCode {
  spam,
  abuse,
  scam,
  fakeProfile,
  inappropriateContent,
  animalSafety,
  other;

  String get firestoreValue {
    switch (this) {
      case ReportReasonCode.spam:
        return 'spam';
      case ReportReasonCode.abuse:
        return 'abuse';
      case ReportReasonCode.scam:
        return 'scam';
      case ReportReasonCode.fakeProfile:
        return 'fake_profile';
      case ReportReasonCode.inappropriateContent:
        return 'inappropriate_content';
      case ReportReasonCode.animalSafety:
        return 'animal_safety';
      case ReportReasonCode.other:
        return 'other';
    }
  }

  static ReportReasonCode fromFirestore(String? value) {
    switch (value) {
      case 'spam':
        return ReportReasonCode.spam;
      case 'abuse':
        return ReportReasonCode.abuse;
      case 'scam':
        return ReportReasonCode.scam;
      case 'fake_profile':
      case 'fake':
        return ReportReasonCode.fakeProfile;
      case 'inappropriate_content':
        return ReportReasonCode.inappropriateContent;
      case 'animal_safety':
        return ReportReasonCode.animalSafety;
      default:
        return ReportReasonCode.other;
    }
  }
}

enum ReportStatus {
  pending,
  approved,
  rejected;

  String get firestoreValue => name;

  static ReportStatus fromFirestore(String? value) {
    switch (value) {
      case 'approved':
        return ReportStatus.approved;
      case 'rejected':
        return ReportStatus.rejected;
      default:
        return ReportStatus.pending;
    }
  }
}

/// A single moderation report against a piece of content or a user.
///
/// Backward compatibility: reports created before this schema was introduced
/// used `type` instead of `targetType`, `reportedBy` instead of `reporterId`,
/// and `message` instead of `description`. [fromFirestore] reads the current
/// field name first and falls back to the legacy one so old and new report
/// documents render identically in the admin UI. This fallback is kept until
/// a deliberate future decision retires it — not removed as part of this work.
class Report {
  final String id;
  final String targetType;
  final String targetId;
  final String? targetOwnerId;
  final String reporterId;
  final ReportReasonCode reasonCode;
  final String? description;
  final ReportStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? moderationAction;
  final String? moderationNotes;

  const Report({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetOwnerId,
    required this.reporterId,
    required this.reasonCode,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.moderationAction,
    required this.moderationNotes,
  });

  factory Report.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};

    return Report(
      id: doc.id,
      targetType: (data['targetType'] ?? data['type'] ?? '').toString(),
      targetId: (data['targetId'] ?? '').toString(),
      targetOwnerId: data['targetOwnerId'] as String?,
      reporterId: (data['reporterId'] ?? data['reportedBy'] ?? '').toString(),
      reasonCode: ReportReasonCode.fromFirestore(data['reasonCode'] as String?),
      description: (data['description'] ?? data['message']) as String?,
      status: ReportStatus.fromFirestore(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      moderationAction: data['moderationAction'] as String?,
      moderationNotes: data['moderationNotes'] as String?,
    );
  }
}
