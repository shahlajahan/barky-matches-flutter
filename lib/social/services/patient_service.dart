import 'package:cloud_firestore/cloud_firestore.dart';

class PatientService {
  static final PatientService instance = PatientService._();

  PatientService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> ensurePatientExists({
    required String businessId,
    required String ownerId,
    required String petId,

    required String petName,
    required String breed,
    required String ownerName,

    String notes = '',
  }) async {
    final patientsRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('patients');

    final existing = await patientsRef
        .where('petId', isEqualTo: petId)
        .limit(1)
        .get();

    // PATIENT EXISTS
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({
        'lastVisitAt': FieldValue.serverTimestamp(),

        'updatedAt': FieldValue.serverTimestamp(),
      });

      return;
    }

    // CREATE NEW PATIENT
    await patientsRef.add({
      'businessId': businessId,

      'ownerId': ownerId,
      'petId': petId,

      'petName': petName,
      'breed': breed,
      'ownerName': ownerName,

      'notes': notes,

      'needsFollowUp': false,
      'isActive': true,

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),

      'lastVisitAt': FieldValue.serverTimestamp(),
    });
  }
}
