import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostLikeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _likes =>
      _firestore.collection('post_likes');

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('social_posts');

  String _docId(String postId, String userId) {
    return '${postId}_$userId';
  }

  Future<bool> isLiked(String postId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    final doc = await _likes.doc(_docId(postId, user.uid)).get();

    return doc.exists;
  }

  Stream<bool> likeStream(String postId) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Stream.value(false);
    }

    return _likes
        .doc(_docId(postId, user.uid))
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleLike(String postId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final likeDocId = _docId(postId, user.uid);

    final likeRef = _likes.doc(likeDocId);

    final postRef = _posts.doc(postId);

    final likeDoc = await likeRef.get();

    final batch = _firestore.batch();

    if (likeDoc.exists) {
      batch.delete(likeRef);

      batch.update(postRef, {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(likeRef, {
        'userId': user.uid,
        'postId': postId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(postRef, {'likeCount': FieldValue.increment(1)});
    }

    await batch.commit();
  }
}
