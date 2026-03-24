import 'package:cloud_firestore/cloud_firestore.dart';

String? findTimestampPath(dynamic v, [String path = 'root']) {
  if (v is Timestamp) return path;

  if (v is Map) {
    for (final e in v.entries) {
      final k = e.key?.toString() ?? 'null';
      final hit = findTimestampPath(e.value, '$path.$k');
      if (hit != null) return hit;
    }
  }

  if (v is List) {
    for (int i = 0; i < v.length; i++) {
      final hit = findTimestampPath(v[i], '$path[$i]');
      if (hit != null) return hit;
    }
  }

  return null;
}