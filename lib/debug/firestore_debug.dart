import 'package:barky_matches_fixed/core/debug/firestore_permission_diagnostics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Stream<QuerySnapshot<Map<String, dynamic>>> debugSnapshots(
  Query<Map<String, dynamic>> query,
  String label,
) {
  if (kDebugMode) {
    debugPrint('FIRESTORE STREAM START -> $label');
  }

  return query.snapshots().handleError((error, stackTrace) {
    FirestorePermissionDiagnostics.reportIfNeeded(
      error,
      failurePath: 'debugSnapshots:$label',
      message: 'Firestore stream permission denied',
      stackTrace: stackTrace,
      data: <String, dynamic>{'label': label},
    );
    if (kDebugMode) {
      debugPrint('FIRESTORE ERROR -> $label : $error');
      debugPrintStack(label: 'ERROR STACK ($label)');
    }
  });
}
