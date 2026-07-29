import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report_target_registry.dart';

/// A resolved, human-readable view of a report's target - resolved via the
/// target-type registry so this service never needs a switch statement per
/// type. New target types only need a registry entry, not a change here.
class ReportTargetInfo {
  final bool exists;
  final String name;
  final String? imageUrl;
  final String? ownerId;
  final String? ownerName;
  final bool isModerated;

  const ReportTargetInfo({
    required this.exists,
    required this.name,
    this.imageUrl,
    this.ownerId,
    this.ownerName,
    this.isModerated = false,
  });

  factory ReportTargetInfo.notFound() =>
      const ReportTargetInfo(exists: false, name: 'Target no longer exists');
}

class ReportUserInfo {
  final String name;
  final String? photoUrl;

  const ReportUserInfo({required this.name, this.photoUrl});

  factory ReportUserInfo.unknown() =>
      const ReportUserInfo(name: 'Unknown user');
}

class ReportTargetResolverService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<ReportTargetInfo> resolveTarget(
    String targetType,
    String targetId,
  ) async {
    final config = kReportTargetRegistry[targetType];
    if (config == null) return ReportTargetInfo.notFound();

    final doc = await _firestore
        .collection(config.collection)
        .doc(targetId)
        .get();
    if (!doc.exists) return ReportTargetInfo.notFound();

    final data = doc.data() ?? <String, dynamic>{};
    final display = config.resolveDisplay(data);
    final ownerId = config.resolveOwnerId(data);

    String? ownerName;
    if (ownerId != null && ownerId.isNotEmpty) {
      ownerName = (await resolveUser(ownerId)).name;
    }

    return ReportTargetInfo(
      exists: true,
      name: display.name,
      imageUrl: display.imageUrl,
      ownerId: ownerId,
      ownerName: ownerName,
      isModerated: config.isModerated(data),
    );
  }

  static Future<ReportUserInfo> resolveUser(String userId) async {
    if (userId.isEmpty) return ReportUserInfo.unknown();

    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return ReportUserInfo.unknown();

    final data = doc.data() ?? <String, dynamic>{};
    final name =
        (data['username'] ?? data['name'] ?? data['displayName']) as String? ??
        'User';
    final photoUrl =
        (data['photoUrl'] ?? data['profileImageUrl']) as String?;

    return ReportUserInfo(name: name, photoUrl: photoUrl);
  }
}
