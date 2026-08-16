import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/social_post.dart';
import 'social_post_share.dart';

import 'package:flutter/foundation.dart';

class SocialPostService {
  SocialPostService({
    FirebaseFirestore? firestore,
    String? Function()? currentUserId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFirestore _firestore;

  /// Resolves the acting user's UID. Defaults to the real
  /// `FirebaseAuth.instance.currentUser?.uid`; tests inject a fixed value
  /// since `FirebaseAuth.instance` cannot be faked without a real Firebase
  /// app/plugin.
  final String? Function() _currentUserId;

  CollectionReference<Map<String, dynamic>> get _postsCollection =>
      _firestore.collection('social_posts');

  CollectionReference<Map<String, dynamic>> get _likesCollection =>
      _firestore.collection('post_likes');

  String _likeDocId(String postId, String userId) {
    return '${postId}_$userId';
  }

  final Set<String> _pendingLikeToggles = {};

  /// STREAM PUBLIC POSTS
  Stream<List<SocialPost>> streamPublicPosts({int limit = 20}) {
    debugPrint('🔥 SOCIAL QUERY START');

    final query = _postsCollection
        .where('visibility', isEqualTo: 'public')
        .where('moderationStatus', isEqualTo: 'active')
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    debugPrint('🔥 QUERY READY → social_posts');

    return query.snapshots().map((snapshot) {
      debugPrint('🔥 POSTS RECEIVED: ${snapshot.docs.length}');
      for (final doc in snapshot.docs) {
        debugPrint('🔥 POST DOC: ${doc.id}');
      }

      return snapshot.docs.map((doc) => SocialPost.fromFirestore(doc)).toList();
    });
  }

  /// CREATE POST
  Future<void> createPost(SocialPost post) async {
    await _postsCollection.doc(post.id).set(post.toFirestore());
  }

  /// DELETE POST
  Future<void> deletePost(String postId) async {
    await _postsCollection.doc(postId).delete();
  }

  /// GET SINGLE POST
  Future<SocialPost?> getPost(String postId) async {
    final doc = await _postsCollection.doc(postId).get();

    if (!doc.exists) {
      return null;
    }

    return SocialPost.fromFirestore(doc);
  }

  Future<SocialPost?> getPublicPost(String postId) async {
    final doc = await _postsCollection.doc(postId).get();
    final data = doc.data();

    if (!doc.exists ||
        data == null ||
        !SocialPostShare.isPubliclyShareable(data)) {
      return null;
    }

    return SocialPost.fromFirestore(doc);
  }

  /// INCREMENT SHARE COUNT
  Future<void> incrementShareCount(String postId) async {
    await _postsCollection.doc(postId).update({
      'shareCount': FieldValue.increment(1),
    });
  }

  /// INCREMENT VIEW COUNT
  Future<void> incrementViewCount(String postId) async {
    await _postsCollection.doc(postId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  /// INCREMENT COMMENT COUNT
  Future<void> incrementCommentCount(String postId) async {
    await _postsCollection.doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  /// DECREMENT COMMENT COUNT
  Future<void> decrementCommentCount(String postId) async {
    await _postsCollection.doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  /// INCREMENT LIKE COUNT
  Future<void> incrementLikeCount(String postId) async {
    await _postsCollection.doc(postId).update({
      'likeCount': FieldValue.increment(1),
    });
  }

  /// DECREMENT LIKE COUNT
  Future<void> decrementLikeCount(String postId) async {
    await _postsCollection.doc(postId).update({
      'likeCount': FieldValue.increment(-1),
    });
  }

  Future<void> toggleLike(String postId) async {
    final uid = _currentUserId();

    if (uid == null) {
      debugPrint("🚫 Guest cannot like posts");
      return;
    }

    // Ignore a rapid duplicate tap on the same post while its previous
    // toggle is still in flight, instead of racing two read-then-write
    // batches that could double (or lose) the counter update.
    if (_pendingLikeToggles.contains(postId)) {
      return;
    }
    _pendingLikeToggles.add(postId);

    try {
      final likeRef = _likesCollection.doc(_likeDocId(postId, uid));
      final postRef = _postsCollection.doc(postId);
      final likeDoc = await likeRef.get();
      final batch = _firestore.batch();

      if (likeDoc.exists) {
        batch.delete(likeRef);
        batch.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        batch.set(likeRef, {
          'userId': uid,
          'postId': postId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(postRef, {'likeCount': FieldValue.increment(1)});
      }

      await batch.commit();
    } finally {
      _pendingLikeToggles.remove(postId);
    }
  }

  Stream<bool> likedStream(String postId) {
    final uid = _currentUserId();

    if (uid == null) {
      return Stream.value(false);
    }

    return _likesCollection
        .doc(_likeDocId(postId, uid))
        .snapshots()
        .map((doc) => doc.exists);
  }
}
