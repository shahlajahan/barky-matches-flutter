import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBlockService {
  static Future<void> blockUser({
    required String targetUserId,
    required String name,
    required String username,
    required String photoUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("blockedUsers")
        .doc(targetUserId)
        .set({
      "blockedUserId": targetUserId,
      "name": name,
      "username": username,
      "photoUrl": photoUrl,
      "blockedAt": FieldValue.serverTimestamp(),
      "isActive": true,
    }, SetOptions(merge: true));
  }

  static Future<void> unblockUser({
    required String targetUserId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("blockedUsers")
        .doc(targetUserId)
        .delete();
  }

  static Future<bool> isUserBlocked(String targetUserId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("blockedUsers")
        .doc(targetUserId)
        .get();

    return doc.exists;
  }
}