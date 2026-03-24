import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminSearchEntityType {
  user,
  dog,
  business,
  report,
  complaint,
}

AdminSearchEntityType adminSearchEntityTypeFromString(String value) {
  switch (value) {
    case 'user':
      return AdminSearchEntityType.user;
    case 'dog':
      return AdminSearchEntityType.dog;
    case 'business':
      return AdminSearchEntityType.business;
    case 'report':
      return AdminSearchEntityType.report;
    case 'complaint':
      return AdminSearchEntityType.complaint;
    default:
      return AdminSearchEntityType.user;
  }
}

String adminSearchEntityTypeToString(AdminSearchEntityType type) {
  switch (type) {
    case AdminSearchEntityType.user:
      return 'user';
    case AdminSearchEntityType.dog:
      return 'dog';
    case AdminSearchEntityType.business:
      return 'business';
    case AdminSearchEntityType.report:
      return 'report';
    case AdminSearchEntityType.complaint:
      return 'complaint';
  }
}

class AdminSearchItem {
  final String id;
  final AdminSearchEntityType entityType;
  final String entityId;

  final String title;
  final String subtitle;
  final String? status;
  final String? badge;
  final String? photoUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final Map<String, dynamic> extra;

  const AdminSearchItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.subtitle,
    required this.extra,
    this.status,
    this.badge,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminSearchItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AdminSearchItem(
      id: doc.id,
      entityType: adminSearchEntityTypeFromString(
        (data['entityType'] ?? 'user').toString(),
      ),
      entityId: (data['entityId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      status: data['status']?.toString(),
      badge: data['badge']?.toString(),
      photoUrl: data['photoUrl']?.toString(),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
      extra: Map<String, dynamic>.from(data['extra'] ?? {}),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}