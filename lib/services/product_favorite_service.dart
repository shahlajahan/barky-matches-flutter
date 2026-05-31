import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductFavoriteService {
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _ref() {
    final uid = _uid;
    if (uid == null) {
      throw Exception('User not logged in');
    }

    return _db.collection('users').doc(uid).collection('favoriteProducts');
  }

  Stream<bool> isFavorite(String productId) {
    final uid = _uid;
    if (uid == null) return Stream.value(false);

    return _db
        .collection('users')
        .doc(uid)
        .collection('favoriteProducts')
        .doc(productId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleFavorite({
    required String productId,
    required String shopId,
    required String name,
    required String? imageUrl,
    required double price,
  }) async {
    final docRef = _ref().doc(productId);
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'productId': productId,
        'shopId': shopId,
        'name': name,
        'imageUrl': imageUrl,
        'price': price,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}