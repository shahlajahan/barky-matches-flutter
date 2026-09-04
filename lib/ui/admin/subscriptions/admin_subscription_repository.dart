import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSubscriptionRecord {
  AdminSubscriptionRecord({
    required this.userId,
    required this.userData,
    required this.subscriptionData,
  });

  final String userId;
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? subscriptionData;

  bool get hasSubscription => subscriptionData != null;

  String get displayName {
    final username = userData['username']?.toString().trim();
    if (username != null && username.isNotEmpty) return username;
    final email = userData['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    return userId;
  }

  String get plan =>
      subscriptionData?['plan']?.toString().toLowerCase() ?? 'normal';

  String get status =>
      subscriptionData?['status']?.toString().toLowerCase() ?? 'none';

  double get price => (subscriptionData?['price'] as num?)?.toDouble() ?? 0.0;

  String? get currency => subscriptionData?['currency']?.toString();
}

class AdminSubscriptionRepository {
  AdminSubscriptionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminSubscriptionRecord>> watchRecentUsers({int limit = 50}) {
    return _firestore.collection('users').limit(limit).snapshots().asyncMap((
      snapshot,
    ) {
      return Future.wait(snapshot.docs.map(_recordForUserSnapshot));
    });
  }

  Future<List<AdminSubscriptionRecord>> searchUsers(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return const [];

    final byUid = await _firestore.collection('users').doc(query).get();
    final records = <String, AdminSubscriptionRecord>{};
    if (byUid.exists) {
      records[byUid.id] = await _recordForUserSnapshot(byUid);
    }

    final usernameMatches = await _firestore
        .collection('users')
        .where('username', isEqualTo: query)
        .limit(20)
        .get();
    for (final doc in usernameMatches.docs) {
      records[doc.id] = await _recordForUserSnapshot(doc);
    }

    if (query.contains('@')) {
      final emails = {query, query.toLowerCase()};
      for (final email in emails) {
        final emailMatches = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(20)
            .get();
        for (final doc in emailMatches.docs) {
          records[doc.id] = await _recordForUserSnapshot(doc);
        }
      }
    }

    return records.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  Future<AdminSubscriptionRecord?> loadUser(String uid) async {
    final user = await _firestore.collection('users').doc(uid.trim()).get();
    if (!user.exists) return null;
    return _recordForUserSnapshot(user);
  }

  Future<AdminSubscriptionRecord> _recordForUserSnapshot(
    DocumentSnapshot<Map<String, dynamic>> user,
  ) async {
    return AdminSubscriptionRecord(
      userId: user.id,
      userData: user.data() ?? const {},
      subscriptionData: await _loadSubscriptionData(user.id),
    );
  }

  Future<Map<String, dynamic>?> _loadSubscriptionData(String userId) async {
    final direct = await _firestore
        .collection('subscriptions')
        .doc(userId)
        .get();
    if (direct.exists) return direct.data();

    final legacy = await _firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (legacy.docs.isEmpty) return null;
    return legacy.docs.first.data();
  }
}
