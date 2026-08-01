import 'package:cloud_firestore/cloud_firestore.dart';

class CreatorLedgerSummary {
  const CreatorLedgerSummary({
    required this.qualifiedUsers,
    required this.qualifiedPartners,
    required this.pendingRewards,
  });

  final int qualifiedUsers;
  final int qualifiedPartners;
  final double pendingRewards;
}

class CreatorLedgerService {
  const CreatorLedgerService._();

  static Future<CreatorLedgerSummary> loadForCreator(String? creatorUid) async {
    if (creatorUid == null || creatorUid.isEmpty) {
      return const CreatorLedgerSummary(
        qualifiedUsers: 0,
        qualifiedPartners: 0,
        pendingRewards: 0,
      );
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('creator_reward_ledger')
        .where('creatorUid', isEqualTo: creatorUid)
        .get();

    var users = 0;
    var partners = 0;
    var pending = 0.0;
    for (final document in snapshot.docs) {
      final data = document.data();
      switch (data['leadType']) {
        case 'user':
          users++;
        case 'partner':
          partners++;
      }
      if (data['status'] == 'pending') {
        pending += (data['rewardAmount'] as num?)?.toDouble() ?? 0;
      }
    }

    return CreatorLedgerSummary(
      qualifiedUsers: users,
      qualifiedPartners: partners,
      pendingRewards: pending,
    );
  }
}
