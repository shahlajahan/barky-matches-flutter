import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostSaveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _savedPosts =>
      _firestore.collection('saved_posts');

  String _docId(String postId, String userId) {
    return '${postId}_$userId';
  }

  Stream<bool> savedStream(String postId) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Stream.value(false);
    }

    return _savedPosts
        .doc(_docId(postId, user.uid))
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleSave(String postId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final docId = _docId(postId, user.uid);

    final docRef = _savedPosts.doc(docId);

    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'userId': user.uid,
        'postId': postId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
