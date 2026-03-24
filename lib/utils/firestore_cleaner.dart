import 'package:cloud_firestore/cloud_firestore.dart';

dynamic cleanDeep(dynamic v) {
  if (v == null) return null;

  if (v is Timestamp) return v.toDate().toIso8601String();
  if (v is DateTime) return v.toIso8601String();

  if (v is GeoPoint) {
    return {'lat': v.latitude, 'lng': v.longitude};
  }

  if (v is Map) {
    final out = <String, dynamic>{};
    v.forEach((key, value) {
      out[key.toString()] = cleanDeep(value);
    });
    return out;
  }

  if (v is List) {
    return v.map(cleanDeep).toList();
  }

  return v; // int, double, bool, String...
}