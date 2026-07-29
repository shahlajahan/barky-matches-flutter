import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post_comment.dart';

class PostCommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _comments =>
      _firestore.collection('post_comments');

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('social_posts');

  Stream<List<PostComment>> streamComments(String postId) {
    // Filtered client-side rather than with a `.where('isHidden', ...)`
    // clause: Firestore equality filters don't match documents missing the
    // field at all, which would hide every comment created before this
    // field existed. PostComment.fromFirestore already defaults isHidden
    // to false for those legacy docs, so filtering here handles both
    // correctly.
    return _comments
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PostComment.fromFirestore(doc))
              .where((comment) => !comment.isHidden)
              .toList(),
        );
  }

  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    final userData = userDoc.data() ?? {};

    final username =
        userData['username'] ??
        userData['name'] ??
        userData['displayName'] ??
        'User';

    final userPhoto =
        userData['photoUrl'] ?? userData['profileImageUrl'] ?? user.photoURL;
    final commentRef = _comments.doc();

    final batch = _firestore.batch();

    batch.set(commentRef, {
      'postId': postId,
      'userId': user.uid,
      'username': username,

      'userPhotoUrl': userPhoto,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'moderationStatus': 'active',
      'isHidden': false,
    });

    batch.update(_posts.doc(postId), {'commentCount': FieldValue.increment(1)});

    await batch.commit();
  }
}
