import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdoptionRequestService {

  /* =====================================================
   * CREATE REQUEST
   * ===================================================== */

  static Future<String> createRequest({
    required String targetType,
    required String targetId,
    required String targetOwnerId,
    required Map<String, dynamic> form,
    required List<String> documents,
    String? dogName,
  }) async {

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("UNAUTHENTICATED");
    }

    final uid = user.uid;

    if (uid == targetOwnerId) {
      throw Exception("CANNOT_REQUEST_OWN_DOG");
    }

    // 🔎 Anti duplicate
    final existing = await FirebaseFirestore.instance
        .collection('adoption_requests')
        .where('targetType', isEqualTo: targetType)
        .where('targetId', isEqualTo: targetId)
        .where('requesterId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final ref = await FirebaseFirestore.instance
        .collection('adoption_requests')
        .add({
      "targetType": targetType,
      "targetId": targetId,
      "targetOwnerId": targetOwnerId,

      "requesterId": uid,
      "requesterName": user.displayName ?? "User",

      "dogName": dogName,
      "form": form,
      "documents": documents,

      "status": "pending",
      "createdAt": FieldValue.serverTimestamp(),

      "decidedAt": null,
      "decidedBy": null,
      "adoptedAt": null,
      "closedAt": null,
      "closedReason": null,
    });

    return ref.id;
  }

  /* =====================================================
   * OWNER APPROVE / REJECT
   * ===================================================== */

  static Future<void> decideRequest({
    required String requestId,
    required String status, // approved | rejected
  }) async {

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("UNAUTHENTICATED");

    if (status != "approved" && status != "rejected") {
      throw Exception("INVALID_STATUS");
    }

    final ref =
        FirebaseFirestore.instance.collection('adoption_requests').doc(requestId);

    await FirebaseFirestore.instance.runTransaction((tx) async {

      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception("REQUEST_NOT_FOUND");

      final data = snap.data()!;
      final ownerId = (data['targetOwnerId'] ?? '').toString();
      final currentStatus = (data['status'] ?? '').toString();

      if (uid != ownerId) throw Exception("NOT_OWNER");
      if (currentStatus != 'pending') throw Exception("NOT_PENDING");

      tx.update(ref, {
        "status": status,
        "decidedAt": FieldValue.serverTimestamp(),
        "decidedBy": uid,
      });
    });
  }

  /* =====================================================
   * MARK DOG AS ADOPTED
   * ===================================================== */

  static Future<void> markDogAsAdopted({
    required String dogId,
    required String adoptedByRequestId,
  }) async {

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("UNAUTHENTICATED");

    final db = FirebaseFirestore.instance;

    final dogRef = db.collection('dogs').doc(dogId);
    final reqRef = db.collection('adoption_requests').doc(adoptedByRequestId);

    await db.runTransaction((tx) async {

      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw Exception("REQUEST_NOT_FOUND");

      final req = reqSnap.data()!;
      final reqOwnerId = (req['targetOwnerId'] ?? '').toString();
      final reqStatus = (req['status'] ?? '').toString();
      final reqTargetId = (req['targetId'] ?? '').toString();

      if (reqOwnerId != uid) throw Exception("NOT_OWNER");
      if (reqStatus != 'approved') throw Exception("REQUEST_NOT_APPROVED");
      if (reqTargetId != dogId) throw Exception("REQUEST_DOG_MISMATCH");

      final dogSnap = await tx.get(dogRef);
      if (!dogSnap.exists) throw Exception("DOG_NOT_FOUND");

      final dog = dogSnap.data()!;
      final dogOwnerId = (dog['ownerId'] ?? '').toString();
      final available = (dog['isAvailableForAdoption'] ?? false) == true;

      if (dogOwnerId != uid) throw Exception("NOT_OWNER");
      if (!available) throw Exception("ALREADY_NOT_AVAILABLE");

      tx.update(dogRef, {
        "isAvailableForAdoption": false,
        "adoptedAt": FieldValue.serverTimestamp(),
        "adoptedByRequestId": adoptedByRequestId,
      });

      tx.update(reqRef, {
        "status": "adopted",
        "adoptedAt": FieldValue.serverTimestamp(),
      });
    });

    // Close other requests
    final others = await db
        .collection('adoption_requests')
        .where('targetType', isEqualTo: 'dog')
        .where('targetId', isEqualTo: dogId)
        .where('status', whereIn: ['pending', 'approved'])
        .get();

    final batch = db.batch();

    for (final d in others.docs) {
      if (d.id == adoptedByRequestId) continue;

      batch.update(d.reference, {
        "status": "closed",
        "closedAt": FieldValue.serverTimestamp(),
        "closedReason": "dog_adopted",
      });
    }

    await batch.commit();
  }
}