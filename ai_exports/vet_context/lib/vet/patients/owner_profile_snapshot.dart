import 'package:cloud_firestore/cloud_firestore.dart';

const ownerProfileSnapshotKeys = [
  'ownerName',
  'ownerPhone',
  'emergencyContact',
  'emergencyPhone',
  'city',
  'district',
  'address',
  'email',
];

String? ownerSnapshotString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  if (text == '-') return null;
  return text;
}

bool hasMeaningfulOwnerProfile(Map<String, dynamic> profile) {
  return ownerProfileSnapshotKeys.any((key) {
    final value = ownerSnapshotString(profile[key]);
    return value != null;
  });
}

Map<String, dynamic> completeOwnerProfileSnapshot(
  Map<String, dynamic> profile,
) {
  return {
    for (final key in ownerProfileSnapshotKeys)
      key: ownerSnapshotString(profile[key]) ?? '',
  };
}

Map<String, dynamic> normalizeOwnerProfileSnapshot(
  Iterable<Map<String, dynamic>?> sources,
) {
  final profile = <String, dynamic>{};

  void mergeValue(String key, dynamic value) {
    final text = ownerSnapshotString(value);
    if (text == null) return;

    final existing = ownerSnapshotString(profile[key]);
    if (existing != null) return;

    profile[key] = text;
  }

  void mergeSource(Map<String, dynamic>? source) {
    if (source == null) return;

    final nestedOwnerProfile = source['ownerProfile'];
    if (nestedOwnerProfile is Map) {
      mergeSource(Map<String, dynamic>.from(nestedOwnerProfile));
    }

    for (final key in const ['owner', 'user', 'client']) {
      final nested = source[key];
      if (nested is Map) {
        mergeSource(Map<String, dynamic>.from(nested));
      }
    }

    mergeValue(
      'ownerName',
      source['ownerName'] ??
          source['ownerDisplayName'] ??
          source['displayName'] ??
          source['name'] ??
          source['fullName'] ??
          source['userName'] ??
          source['username'],
    );
    mergeValue(
      'ownerPhone',
      source['ownerPhone'] ??
          source['phone'] ??
          source['phoneNumber'] ??
          source['userPhone'],
    );
    mergeValue('emergencyContact', source['emergencyContact']);
    mergeValue(
      'emergencyPhone',
      source['emergencyPhone'] ?? source['emergencyContactNumber'],
    );
    mergeValue('city', source['city']);
    mergeValue('district', source['district']);
    mergeValue('address', source['address'] ?? source['registrationAddress']);
    mergeValue(
      'email',
      source['email'] ?? source['ownerEmail'] ?? source['userEmail'],
    );
  }

  for (final source in sources) {
    mergeSource(source);
  }

  return completeOwnerProfileSnapshot(profile);
}

Map<String, dynamic> mergeOwnerProfileSnapshots({
  required Map<String, dynamic> existing,
  required Map<String, dynamic> incoming,
}) {
  final merged = Map<String, dynamic>.from(existing);

  for (final entry in incoming.entries) {
    final value = ownerSnapshotString(entry.value);
    if (value == null) continue;

    final current = ownerSnapshotString(merged[entry.key]);
    if (current != null) continue;

    merged[entry.key] = value;
  }

  return completeOwnerProfileSnapshot(merged);
}

Future<Map<String, dynamic>> buildOwnerProfileSnapshot({
  required FirebaseFirestore firestore,
  required Map<String, dynamic> baseData,
  String? ownerId,
  String? petId,
}) async {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? dogData;

  final resolvedPetId =
      ownerSnapshotString(petId) ?? ownerSnapshotString(baseData['petId']);

  if (resolvedPetId != null) {
    final dogSnap = await firestore.collection('dogs').doc(resolvedPetId).get();
    dogData = dogSnap.data();
  }

  final blockedUids = <String>{
    for (final uid in [
      ownerSnapshotString(baseData['businessId']),
      ownerSnapshotString(baseData['vetId']),
      ownerSnapshotString(baseData['businessOwnerUid']),
      ownerSnapshotString(baseData['createdByBusinessId']),
      ownerSnapshotString(baseData['createdByVetId']),
    ])
      ?uid,
  };

  String? resolvedOwnerId;
  for (final uid in [
    ownerSnapshotString(baseData['petOwnerUid']),
    ownerSnapshotString(baseData['petOwnerId']),
    ownerSnapshotString(dogData?['ownerId']),
    ownerSnapshotString(dogData?['userId']),
    ownerSnapshotString(baseData['requesterUserId']),
    ownerSnapshotString(baseData['requesterUid']),
    ownerSnapshotString(ownerId),
    ownerSnapshotString(baseData['ownerId']),
    ownerSnapshotString(baseData['userId']),
    ownerSnapshotString(baseData['clientUserId']),
  ].whereType<String>()) {
    if (!blockedUids.contains(uid)) {
      resolvedOwnerId = uid;
      break;
    }
  }

  if (resolvedOwnerId != null) {
    final userSnap = await firestore
        .collection('users')
        .doc(resolvedOwnerId)
        .get();
    userData = userSnap.data();
  }

  return normalizeOwnerProfileSnapshot([baseData, dogData, userData]);
}
