import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../dog.dart';

class DogSyncService {
  const DogSyncService();

  Future<List<Dog>> fetchCanonicalDogs() async {
    late final QuerySnapshot<Map<String, dynamic>> dogsSnapshot;
    try {
      dogsSnapshot = await FirebaseFirestore.instance
          .collection('dogs')
          .get();
    } on FirebaseException catch (e) {
      rethrow;
    }
    final Map<String, Dog> uniqueDogs = {};

    for (var doc in dogsSnapshot.docs) {
      final data = doc.data();

      final dog = Dog(
        id: doc.id,
        name: data['name'] ?? '',
        breed: data['breed'] ?? '',
        age: data['age'] ?? 0,
        gender: data['gender'] ?? '',
        healthStatus: data['healthStatus'] ?? '',
        isNeutered: _toBool(data['isNeutered']),
        description: data['description'] ?? '',
        traits: List<String>.from(data['traits'] ?? []),
        ownerGender: data['ownerGender'] ?? '',
        imagePaths: List<String>.from(data['imagePaths'] ?? []),
        isAvailableForAdoption: _toBool(data['isAvailableForAdoption']),
        isOwner: _toBool(data['isOwner']),
        ownerId: (data['ownerId']?.toString() ?? ''),
        latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      );

      if (!uniqueDogs.containsKey(dog.id)) {
        uniqueDogs[dog.id] = dog;
      } else {
        debugPrint('DogSyncService - Skipped duplicate dog id: ${dog.id}');
      }
    }

    return uniqueDogs.values.toList();
  }

  bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }
}
