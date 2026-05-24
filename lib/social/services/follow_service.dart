import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> followUser({required String targetUserId}) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || targetUserId.trim().isEmpty) {
      throw StateError('Login required to follow user');
    }
    if (currentUserId == targetUserId) return;

    final batch = _firestore.batch();
    final followerRef = _firestore
        .collection('followers')
        .doc(targetUserId)
        .collection('userFollowers')
        .doc(currentUserId);
    final followingRef = _firestore
        .collection('following')
        .doc(currentUserId)
        .collection('userFollowing')
        .doc(targetUserId);
    final now = FieldValue.serverTimestamp();

    batch.set(followerRef, {'userId': currentUserId, 'createdAt': now});
    batch.set(followingRef, {'userId': targetUserId, 'createdAt': now});

    await batch.commit();
  }

  Future<void> unfollowUser({required String targetUserId}) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || targetUserId.trim().isEmpty) {
      throw StateError('Login required to unfollow user');
    }

    final batch = _firestore.batch();

    batch.delete(
      _firestore
          .collection('followers')
          .doc(targetUserId)
          .collection('userFollowers')
          .doc(currentUserId),
    );
    batch.delete(
      _firestore
          .collection('following')
          .doc(currentUserId)
          .collection('userFollowing')
          .doc(targetUserId),
    );

    await batch.commit();
  }

  Stream<bool> isFollowing(String targetUserId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || targetUserId.trim().isEmpty) {
      return Stream.value(false);
    }

    return _firestore
        .collection('following')
        .doc(currentUserId)
        .collection('userFollowing')
        .doc(targetUserId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<int> followersCountStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value(0);

    return _firestore
        .collection('followers')
        .doc(userId)
        .collection('userFollowers')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> followingCountStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value(0);

    return _firestore
        .collection('following')
        .doc(userId)
        .collection('userFollowing')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }
}
