import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneSignupProfileInput {
  const PhoneSignupProfileInput({
    required this.username,
    required this.email,
    required this.phone,
    required this.city,
    required this.district,
    required this.receiveNews,
  });

  final String username;
  final String email;
  final String phone;
  final String city;
  final String district;
  final bool receiveNews;

  Map<String, dynamic> buildMergeData({
    required String authenticatedUid,
    required Object serverTimestamp,
    required bool existingProfileHasCreatedAt,
  }) {
    final data = <String, dynamic>{
      'uid': authenticatedUid,
      'phoneVerified': true,
      'phoneVerifiedAt': serverTimestamp,
      'receiveNews': receiveNews,
      'updatedAt': serverTimestamp,
    };

    void addNonEmpty(String key, String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) data[key] = trimmed;
    }

    addNonEmpty('username', username);
    addNonEmpty('email', email.toLowerCase());
    addNonEmpty('phone', phone);
    addNonEmpty('city', city);
    addNonEmpty('district', district);

    if (!existingProfileHasCreatedAt) {
      data['createdAt'] = serverTimestamp;
    }

    return data;
  }
}

Future<void> finalizePhoneSignupProfile({
  required String authenticatedUid,
  required PhoneSignupProfileInput input,
  FirebaseFirestore? firestore,
}) async {
  final database = firestore ?? FirebaseFirestore.instance;
  final reference = database.collection('users').doc(authenticatedUid);

  await database.runTransaction((transaction) async {
    final snapshot = await transaction.get(reference);
    final existingData = snapshot.data();
    final hasCreatedAt = existingData?.containsKey('createdAt') == true;
    final serverTimestamp = FieldValue.serverTimestamp();

    transaction.set(
      reference,
      input.buildMergeData(
        authenticatedUid: authenticatedUid,
        serverTimestamp: serverTimestamp,
        existingProfileHasCreatedAt: hasCreatedAt,
      ),
      SetOptions(merge: true),
    );
  });
}

Future<void> finalizePhoneSignupBeforeInitialization({
  required String authenticatedUid,
  required PhoneSignupProfileInput input,
  required Future<void> Function(
    String authenticatedUid,
    PhoneSignupProfileInput input,
  )
  finalizeProfile,
  required Future<void> Function() initializeUserB,
}) async {
  await finalizeProfile(authenticatedUid, input);
  await initializeUserB();
}
