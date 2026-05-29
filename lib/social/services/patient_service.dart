import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/patients/owner_profile_snapshot.dart';

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
    String ownerPhone = '',
    String emergencyContact = '',
    String emergencyPhone = '',
    String city = '',
    String district = '',
    String address = '',
    String email = '',
  }) async {
    final patientsRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('patients');

    final existing = await patientsRef
        .where('petId', isEqualTo: petId)
        .limit(1)
        .get();

    final ownerSnapshot = await buildOwnerProfileSnapshot(
      firestore: _firestore,
      ownerId: ownerId,
      petId: petId,
      baseData: {
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'emergencyContact': emergencyContact,
        'emergencyPhone': emergencyPhone,
        'city': city,
        'district': district,
        'address': address,
        'email': email,
      },
    );
    // ignore: avoid_print
    print('PATIENT OWNER UID $ownerId');
    // ignore: avoid_print
    print('DOG OWNER UID $petId');

    // PATIENT EXISTS
    if (existing.docs.isNotEmpty) {
      final existingData = existing.docs.first.data();
      final existingOwnerProfile = existingData['ownerProfile'] is Map
          ? Map<String, dynamic>.from(existingData['ownerProfile'] as Map)
          : <String, dynamic>{};
      final mergedOwnerProfile = mergeOwnerProfileSnapshots(
        existing: existingOwnerProfile,
        incoming: ownerSnapshot,
      );

      await existing.docs.first.reference.set({
        'lastVisitAt': FieldValue.serverTimestamp(),

        'updatedAt': FieldValue.serverTimestamp(),
        'ownerId': ownerId,
        'petOwnerUid': ownerId,
        if (hasMeaningfulOwnerProfile(mergedOwnerProfile))
          'ownerProfile': mergedOwnerProfile,
      }, SetOptions(merge: true));

      if (hasMeaningfulOwnerProfile(mergedOwnerProfile)) {
        // ignore: avoid_print
        print('PATIENT OWNER SNAPSHOT MERGED');
      }

      return;
    }

    // CREATE NEW PATIENT
    await patientsRef.add({
      'businessId': businessId,

      'ownerId': ownerId,
      'petOwnerUid': ownerId,
      'petId': petId,

      'petName': petName,
      'breed': breed,
      'ownerName': ownerName,
      if (hasMeaningfulOwnerProfile(ownerSnapshot))
        'ownerProfile': ownerSnapshot,

      'notes': notes,

      'needsFollowUp': false,
      'isActive': true,

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),

      'lastVisitAt': FieldValue.serverTimestamp(),
    });

    if (hasMeaningfulOwnerProfile(ownerSnapshot)) {
      // ignore: avoid_print
      print('PATIENT OWNER SNAPSHOT SAVED');
    }
  }
}
