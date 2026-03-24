import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Stream<QuerySnapshot<Map<String, dynamic>>> debugSnapshots(
  Query<Map<String, dynamic>> query,
  String label,
) {
  if (kDebugMode) {
    debugPrint("🔥 FIRESTORE STREAM START → $label");
    // ❌ stack رو حذف کردیم (یا کنترلش می‌کنیم)
  }

  return query.snapshots().handleError((e, stack) {
    if (kDebugMode) {
      debugPrint("❌ FIRESTORE ERROR → $label : $e");
      debugPrintStack(label: "📍 ERROR STACK ($label)");
    }
  });
}