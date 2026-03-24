import 'dart:async';
import 'package:flutter/foundation.dart'; // ✅ این خط
import 'package:hive_flutter/hive_flutter.dart';
import 'dog.dart';


List<Dog> getMyDogs(String userId) {
  if (!Hive.isBoxOpen('dogsBox')) {
    debugPrint('❌ dogsBox is not open');
    return [];
  }

  final box = Hive.box<Dog>('dogsBox');

  final result = box.values.where((dog) {
    final owner = (dog.ownerId ?? '').trim();
    return owner == userId.trim();
  }).toList();

  debugPrint(
    '🐶 getMyDogs: found ${result.length} dogs for userId="$userId"',
  );

  for (final d in result) {
    debugPrint(
      '   → ${d.name} | owner="${d.ownerId}" | adoption=${d.isAvailableForAdoption}',
    );
  }

  return result;
}
