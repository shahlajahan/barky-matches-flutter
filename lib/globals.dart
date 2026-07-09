import 'package:flutter/foundation.dart'; // ✅ این خط
import 'dog.dart';
import 'package:barky_matches_fixed/dogs_box_manager.dart';

List<Dog> getMyDogs(String userId) {
  if (!DogsBoxManager.instance.isReady) {
    debugPrint('❌ dogsBox is not open');
    return [];
  }

  final result = DogsBoxManager.instance.getDogsForOwner(userId);

  debugPrint('🐶 getMyDogs: found ${result.length} dogs for userId="$userId"');

  for (final d in result) {
    debugPrint(
      '   → ${d.name} | owner="${d.ownerId}" | adoption=${d.isAvailableForAdoption}',
    );
  }

  return result;
}
