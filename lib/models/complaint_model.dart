import 'package:cloud_firestore/cloud_firestore.dart';

/// ------------------------------------------------------------
/// Complaint Enums
/// ------------------------------------------------------------

enum ComplaintTargetType {
  dog,
  user,
  business,
  adoption,
  chat,
  payment,
  system,
  app,
  unknown,
}

enum ComplaintCategory {
  harassment,
  scam,
  abuse,
  fakeListing,
  paymentDispute,
  safetyRisk,
  spam,
  impersonation,
  inappropriateContent,
  fraud,
  technicalIssue,
  other,
}

enum ComplaintSeverity {
  low,
  medium,
  high,
  critical,
}

enum ComplaintPriority {
  normal,
  urgent,
  escalated,
}

enum ComplaintStatus {
  open,
  underReview,
  waitingUser,
  resolved,
  dismissed,
  escalated,
  unknown,
}

enum ComplaintResolutionType {
  warning,
  contentRemoved,
  accountSuspended,
  accountRestricted,
  dismissed,
  refunded,
  noViolation,
  other,
}

/// ------------------------------------------------------------
/// Snapshot Models
/// ------------------------------------------------------------

class ComplaintReporterSnapshot {
  final String uid;
  final String? username;
  final String? email;
  final String? phone;
  final String? avatarUrl;

  const ComplaintReporterSnapshot({
    required this.uid,
    this.username,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  factory ComplaintReporterSnapshot.fromMap(Map<String, dynamic>? map) {
    final data = map ?? <String, dynamic>{};

    return ComplaintReporterSnapshot(
      uid: (data['uid'] ?? '').toString(),
      username: data['username']?.toString(),
      email: data['email']?.toString(),
      phone: data['phone']?.toString(),
      avatarUrl: data['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
    };
  }

  ComplaintReporterSnapshot copyWith({
    String? uid,
    String? username,
    String? email,
    String? phone,
    String? avatarUrl,
  }) {
    return ComplaintReporterSnapshot(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class ComplaintTargetSnapshot {
  final String id;
  final String? title;
  final String? subtitle;
  final String? imageUrl;
  final String? ownerId;
  final Map<String, dynamic>? extra;

  const ComplaintTargetSnapshot({
    required this.id,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.ownerId,
    this.extra,
  });

  factory ComplaintTargetSnapshot.fromMap(Map<String, dynamic>? map) {
    final data = map ?? <String, dynamic>{};

    return ComplaintTargetSnapshot(
      id: (data['id'] ?? '').toString(),
      title: data['title']?.toString(),
      subtitle: data['subtitle']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      ownerId: data['ownerId']?.toString(),
      extra: data['extra'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['extra'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'ownerId': ownerId,
      'extra': extra,
    };
  }

  ComplaintTargetSnapshot copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? ownerId,
    Map<String, dynamic>? extra,
  }) {
    return ComplaintTargetSnapshot(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerId: ownerId ?? this.ownerId,
      extra: extra ?? this.extra,
    );
  }
}

/// ------------------------------------------------------------
/// Main Complaint Model
/// ------------------------------------------------------------

class ComplaintModel {
  final String id;

  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final ComplaintTargetType targetType;
  final String targetId;

  final ComplaintCategory category;
  final ComplaintSeverity severity;
  final ComplaintPriority priority;

  final String title;
  final String description;

final String? screenshotUrl;
  final ComplaintStatus status;

  final String? assignedAdminId;
  final DateTime? assignedAt;

  final ComplaintReporterSnapshot? reporterSnapshot;
  final ComplaintTargetSnapshot? targetSnapshot;

  final int evidenceCount;
  final int messageCount;

  final DateTime? lastMessageAt;
  final DateTime? lastAdminActionAt;

  final ComplaintResolutionType? resolutionType;
  final String? resolutionSummary;

  final List<String> linkedReportIds;
  final List<String> linkedEntityIds;
  final List<String> fraudFlags;

  final bool isArchived;

  const ComplaintModel({
    required this.id,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.targetType,
    required this.targetId,
    required this.category,
    required this.severity,
    required this.priority,
    required this.title,
    required this.description,
required this.status,

this.screenshotUrl,
    required this.assignedAdminId,
    required this.assignedAt,
    required this.reporterSnapshot,
    required this.targetSnapshot,
    required this.evidenceCount,
    required this.messageCount,
    required this.lastMessageAt,
    required this.lastAdminActionAt,
    required this.resolutionType,
    required this.resolutionSummary,
    required this.linkedReportIds,
    required this.linkedEntityIds,
    required this.fraudFlags,
    required this.isArchived,
  });

  /// ------------------------------------------------------------
  /// Defaults / Empty
  /// ------------------------------------------------------------

  factory ComplaintModel.empty() {
    return const ComplaintModel(
      id: '',
      createdBy: '',
      createdAt: null,
      updatedAt: null,
      targetType: ComplaintTargetType.unknown,
      targetId: '',
      category: ComplaintCategory.other,
      severity: ComplaintSeverity.medium,
      priority: ComplaintPriority.normal,
      title: '',
      description: '',

screenshotUrl: null,

status: ComplaintStatus.open,
      assignedAdminId: null,
      assignedAt: null,
      reporterSnapshot: null,
      targetSnapshot: null,
      evidenceCount: 0,
      messageCount: 0,
      lastMessageAt: null,
      lastAdminActionAt: null,
      resolutionType: null,
      resolutionSummary: null,
      linkedReportIds: [],
      linkedEntityIds: [],
      fraudFlags: [],
      isArchived: false,
    );
  }

  /// ------------------------------------------------------------
  /// Firestore
  /// ------------------------------------------------------------

  factory ComplaintModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return ComplaintModel.fromMap(data, docId: doc.id);
  }

  factory ComplaintModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    return ComplaintModel(
      id: docId ?? (map['complaintId'] ?? map['id'] ?? '').toString(),
      createdBy: (map['createdBy'] ?? '').toString(),
      createdAt: _readDateTime(map['createdAt']),
      updatedAt: _readDateTime(map['updatedAt']),
      targetType: _parseTargetType(map['targetType']),
      targetId: (map['targetId'] ?? '').toString(),
      category: _parseCategory(map['category']),
      severity: _parseSeverity(map['severity']),
      priority: _parsePriority(map['priority']),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),

screenshotUrl: map['screenshotUrl']?.toString(),

status: _parseStatus(map['status']),
      assignedAdminId: map['assignedAdminId']?.toString(),
      assignedAt: _readDateTime(map['assignedAt']),
      reporterSnapshot: map['reporterSnapshot'] is Map<String, dynamic>
          ? ComplaintReporterSnapshot.fromMap(
              Map<String, dynamic>.from(map['reporterSnapshot'] as Map),
            )
          : null,
      targetSnapshot: map['targetSnapshot'] is Map<String, dynamic>
          ? ComplaintTargetSnapshot.fromMap(
              Map<String, dynamic>.from(map['targetSnapshot'] as Map),
            )
          : null,
      evidenceCount: _readInt(map['evidenceCount']),
      messageCount: _readInt(map['messageCount']),
      lastMessageAt: _readDateTime(map['lastMessageAt']),
      lastAdminActionAt: _readDateTime(map['lastAdminActionAt']),
      resolutionType: map['resolutionType'] == null
          ? null
          : _parseResolutionType(map['resolutionType']),
      resolutionSummary: map['resolutionSummary']?.toString(),
      linkedReportIds: _readStringList(map['linkedReportIds']),
      linkedEntityIds: _readStringList(map['linkedEntityIds']),
      fraudFlags: _readStringList(map['fraudFlags']),
      isArchived: _readBool(map['isArchived']),
    );
  }

  Map<String, dynamic> toMap({
    bool includeId = false,
  }) {
    final data = <String, dynamic>{
      'createdBy': createdBy,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'targetType': targetType.name,
      'targetId': targetId,
      'category': _categoryToFirestore(category),
      'severity': severity.name,
      'priority': priority.name,
      'title': title,
      'description': description,

'screenshotUrl': screenshotUrl,

'status': _statusToFirestore(status),
      'assignedAdminId': assignedAdminId,
      'assignedAt': assignedAt == null ? null : Timestamp.fromDate(assignedAt!),
      'reporterSnapshot': reporterSnapshot?.toMap(),
      'targetSnapshot': targetSnapshot?.toMap(),
      'evidenceCount': evidenceCount,
      'messageCount': messageCount,
      'lastMessageAt': lastMessageAt == null
          ? null
          : Timestamp.fromDate(lastMessageAt!),
      'lastAdminActionAt': lastAdminActionAt == null
          ? null
          : Timestamp.fromDate(lastAdminActionAt!),
      'resolutionType': resolutionType == null
          ? null
          : _resolutionTypeToFirestore(resolutionType!),
      'resolutionSummary': resolutionSummary,
      'linkedReportIds': linkedReportIds,
      'linkedEntityIds': linkedEntityIds,
      'fraudFlags': fraudFlags,
      'isArchived': isArchived,
    };

    if (includeId) {
      data['complaintId'] = id;
    }

    return data;
  }

  /// ------------------------------------------------------------
  /// Convenience Getters
  /// ------------------------------------------------------------

  bool get isOpenLike =>
      status == ComplaintStatus.open ||
      status == ComplaintStatus.underReview ||
      status == ComplaintStatus.waitingUser ||
      status == ComplaintStatus.escalated;

  bool get isResolved => status == ComplaintStatus.resolved;

  bool get isDismissed => status == ComplaintStatus.dismissed;

  bool get isAssigned => assignedAdminId != null && assignedAdminId!.trim().isNotEmpty;

  bool get isHighRisk =>
      severity == ComplaintSeverity.high ||
      severity == ComplaintSeverity.critical ||
      priority == ComplaintPriority.urgent ||
      priority == ComplaintPriority.escalated;

  bool get hasEvidence => evidenceCount > 0;

  bool get hasMessages => messageCount > 0;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    return _defaultTitleFromCategory(category);
  }

  String get statusLabel => _statusLabel(status);

  String get severityLabel => severity.name;

  String get priorityLabel => priority.name;

  String get categoryLabel => _categoryLabel(category);

  String get targetTypeLabel => _targetTypeLabel(targetType);

  /// ------------------------------------------------------------
  /// CopyWith
  /// ------------------------------------------------------------

  ComplaintModel copyWith({
    String? id,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    ComplaintTargetType? targetType,
    String? targetId,
    ComplaintCategory? category,
    ComplaintSeverity? severity,
    ComplaintPriority? priority,
    String? title,
    String? description,
    ComplaintStatus? status,
    String? assignedAdminId,
    DateTime? assignedAt,
    ComplaintReporterSnapshot? reporterSnapshot,
    ComplaintTargetSnapshot? targetSnapshot,
    int? evidenceCount,
    int? messageCount,
    DateTime? lastMessageAt,
    DateTime? lastAdminActionAt,
    ComplaintResolutionType? resolutionType,
    String? resolutionSummary,
    List<String>? linkedReportIds,
    List<String>? linkedEntityIds,
    List<String>? fraudFlags,
    bool? isArchived,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      assignedAdminId: assignedAdminId ?? this.assignedAdminId,
      assignedAt: assignedAt ?? this.assignedAt,
      reporterSnapshot: reporterSnapshot ?? this.reporterSnapshot,
      targetSnapshot: targetSnapshot ?? this.targetSnapshot,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      messageCount: messageCount ?? this.messageCount,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastAdminActionAt: lastAdminActionAt ?? this.lastAdminActionAt,
      resolutionType: resolutionType ?? this.resolutionType,
      resolutionSummary: resolutionSummary ?? this.resolutionSummary,
      linkedReportIds: linkedReportIds ?? this.linkedReportIds,
      linkedEntityIds: linkedEntityIds ?? this.linkedEntityIds,
      fraudFlags: fraudFlags ?? this.fraudFlags,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  /// ------------------------------------------------------------
  /// Equality / Debug
  /// ------------------------------------------------------------

  @override
  String toString() {
    return 'ComplaintModel('
        'id: $id, '
        'targetType: ${targetType.name}, '
        'targetId: $targetId, '
        'category: ${category.name}, '
        'severity: ${severity.name}, '
        'priority: ${priority.name}, '
        'status: ${status.name}, '
        'isArchived: $isArchived'
        ')';
  }
}

/// ------------------------------------------------------------
/// Helpers
/// ------------------------------------------------------------

DateTime? _readDateTime(dynamic value) {
  if (value == null) return null;

  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}

int _readInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

bool _readBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) {
    final v = value.trim().toLowerCase();
    return v == 'true' || v == '1';
  }
  if (value is num) {
    return value != 0;
  }
  return false;
}

List<String> _readStringList(dynamic value) {
  if (value is Iterable) {
    return value.map((e) => e.toString()).toList();
  }
  return <String>[];
}

ComplaintTargetType _parseTargetType(dynamic value) {

  final raw = (value ?? '').toString().trim().toLowerCase();

  switch (raw) {

    case 'dog':
      return ComplaintTargetType.dog;

    case 'user':
      return ComplaintTargetType.user;

    case 'business':
      return ComplaintTargetType.business;

    case 'adoption':
      return ComplaintTargetType.adoption;

    case 'chat':
      return ComplaintTargetType.chat;

    case 'payment':
      return ComplaintTargetType.payment;

    case 'system':
      return ComplaintTargetType.system;

    case 'app':
      return ComplaintTargetType.system; // یا enum جدید بساز

    default:
      return ComplaintTargetType.unknown;
  }
}

ComplaintCategory _parseCategory(dynamic value) {
  final raw = (value ?? '').toString().trim().toLowerCase();

  switch (raw) {
    case 'harassment':
      return ComplaintCategory.harassment;
    case 'scam':
      return ComplaintCategory.scam;
    case 'abuse':
      return ComplaintCategory.abuse;
    case 'fakelisting':
    case 'fake_listing':
      return ComplaintCategory.fakeListing;
    case 'paymentdispute':
    case 'payment_dispute':
      return ComplaintCategory.paymentDispute;
    case 'safetyrisk':
    case 'safety_risk':
      return ComplaintCategory.safetyRisk;
    case 'spam':
      return ComplaintCategory.spam;
    case 'impersonation':
      return ComplaintCategory.impersonation;
    case 'inappropriatecontent':
    case 'inappropriate_content':
      return ComplaintCategory.inappropriateContent;
    case 'fraud':
      return ComplaintCategory.fraud;
    case 'technicalissue':
    case 'technical_issue':
      return ComplaintCategory.technicalIssue;
    default:
      return ComplaintCategory.other;
  }
}

ComplaintSeverity _parseSeverity(dynamic value) {
  final raw = (value ?? '').toString().trim().toLowerCase();

  switch (raw) {
    case 'low':
      return ComplaintSeverity.low;
    case 'medium':
      return ComplaintSeverity.medium;
    case 'high':
      return ComplaintSeverity.high;
    case 'critical':
      return ComplaintSeverity.critical;
    default:
      return ComplaintSeverity.medium;
  }
}

ComplaintPriority _parsePriority(dynamic value) {
  final raw = (value ?? '').toString().trim().toLowerCase();

  switch (raw) {
    case 'normal':
      return ComplaintPriority.normal;
    case 'urgent':
      return ComplaintPriority.urgent;
    case 'escalated':
      return ComplaintPriority.escalated;
    default:
      return ComplaintPriority.normal;
  }
}

ComplaintStatus _parseStatus(dynamic value) {
  final raw = (value ?? '').toString().trim().toLowerCase();

  switch (raw) {
    case 'open':
      return ComplaintStatus.open;
    case 'underreview':
    case 'under_review':
      return ComplaintStatus.underReview;
    case 'waitinguser':
    case 'waiting_user':
      return ComplaintStatus.waitingUser;
    case 'resolved':
      return ComplaintStatus.resolved;
    case 'dismissed':
      return ComplaintStatus.dismissed;
    case 'escalated':
      return ComplaintStatus.escalated;
    default:
      return ComplaintStatus.unknown;
  }
}

ComplaintResolutionType _parseResolutionType(dynamic value) {
  final raw = (value ?? '').toString().trim().toLowerCase();

  switch (raw) {
    case 'warning':
      return ComplaintResolutionType.warning;
    case 'contentremoved':
    case 'content_removed':
      return ComplaintResolutionType.contentRemoved;
    case 'accountsuspended':
    case 'account_suspended':
      return ComplaintResolutionType.accountSuspended;
    case 'accountrestricted':
    case 'account_restricted':
      return ComplaintResolutionType.accountRestricted;
    case 'dismissed':
      return ComplaintResolutionType.dismissed;
    case 'refunded':
      return ComplaintResolutionType.refunded;
    case 'noviolation':
    case 'no_violation':
      return ComplaintResolutionType.noViolation;
    default:
      return ComplaintResolutionType.other;
  }
}

String _categoryToFirestore(ComplaintCategory value) {
  switch (value) {
    case ComplaintCategory.fakeListing:
      return 'fake_listing';
    case ComplaintCategory.paymentDispute:
      return 'payment_dispute';
    case ComplaintCategory.safetyRisk:
      return 'safety_risk';
    case ComplaintCategory.inappropriateContent:
      return 'inappropriate_content';
    case ComplaintCategory.technicalIssue:
      return 'technical_issue';
    default:
      return value.name;
  }
}

String _statusToFirestore(ComplaintStatus value) {
  switch (value) {
    case ComplaintStatus.underReview:
      return 'under_review';
    case ComplaintStatus.waitingUser:
      return 'waiting_user';
    default:
      return value.name;
  }
}

String _resolutionTypeToFirestore(ComplaintResolutionType value) {
  switch (value) {
    case ComplaintResolutionType.contentRemoved:
      return 'content_removed';
    case ComplaintResolutionType.accountSuspended:
      return 'account_suspended';
    case ComplaintResolutionType.accountRestricted:
      return 'account_restricted';
    case ComplaintResolutionType.noViolation:
      return 'no_violation';
    default:
      return value.name;
  }
}

String _defaultTitleFromCategory(ComplaintCategory category) {
  switch (category) {
    case ComplaintCategory.harassment:
      return 'Harassment complaint';
    case ComplaintCategory.scam:
      return 'Scam complaint';
    case ComplaintCategory.abuse:
      return 'Abuse complaint';
    case ComplaintCategory.fakeListing:
      return 'Fake listing complaint';
    case ComplaintCategory.paymentDispute:
      return 'Payment dispute';
    case ComplaintCategory.safetyRisk:
      return 'Safety risk complaint';
    case ComplaintCategory.spam:
      return 'Spam complaint';
    case ComplaintCategory.impersonation:
      return 'Impersonation complaint';
    case ComplaintCategory.inappropriateContent:
      return 'Inappropriate content complaint';
    case ComplaintCategory.fraud:
      return 'Fraud complaint';
    case ComplaintCategory.technicalIssue:
      return 'Technical issue complaint';
    case ComplaintCategory.other:
      return 'Complaint';
  }
}

String _statusLabel(ComplaintStatus status) {
  switch (status) {
    case ComplaintStatus.open:
      return 'Open';
    case ComplaintStatus.underReview:
      return 'Under Review';
    case ComplaintStatus.waitingUser:
      return 'Waiting User';
    case ComplaintStatus.resolved:
      return 'Resolved';
    case ComplaintStatus.dismissed:
      return 'Dismissed';
    case ComplaintStatus.escalated:
      return 'Escalated';
    case ComplaintStatus.unknown:
      return 'Unknown';
  }
}

String _categoryLabel(ComplaintCategory category) {
  switch (category) {
    case ComplaintCategory.harassment:
      return 'Harassment';
    case ComplaintCategory.scam:
      return 'Scam';
    case ComplaintCategory.abuse:
      return 'Abuse';
    case ComplaintCategory.fakeListing:
      return 'Fake Listing';
    case ComplaintCategory.paymentDispute:
      return 'Payment Dispute';
    case ComplaintCategory.safetyRisk:
      return 'Safety Risk';
    case ComplaintCategory.spam:
      return 'Spam';
    case ComplaintCategory.impersonation:
      return 'Impersonation';
    case ComplaintCategory.inappropriateContent:
      return 'Inappropriate Content';
    case ComplaintCategory.fraud:
      return 'Fraud';
    case ComplaintCategory.technicalIssue:
      return 'Technical Issue';
    case ComplaintCategory.other:
      return 'Other';
  }
}

String _targetTypeLabel(ComplaintTargetType targetType) {
  switch (targetType) {
    case ComplaintTargetType.dog:
      return 'Dog';
    case ComplaintTargetType.user:
      return 'User';
    case ComplaintTargetType.business:
      return 'Business';
    case ComplaintTargetType.adoption:
      return 'Adoption';
    case ComplaintTargetType.chat:
      return 'Chat';
    case ComplaintTargetType.payment:
      return 'Payment';
    case ComplaintTargetType.system:
      return 'System';
    case ComplaintTargetType.unknown:
      return 'Unknown';
      case ComplaintTargetType.app:
  return 'App';
  }
}