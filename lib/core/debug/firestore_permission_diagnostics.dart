import 'package:cloud_firestore/cloud_firestore.dart';

import 'diagnostics_events.dart';

class FirestorePermissionDiagnostics {
  FirestorePermissionDiagnostics._();

  static final Set<String> _reportedFailurePaths = <String>{};

  static bool isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  static Future<void> reportIfNeeded(
    Object error, {
    required String failurePath,
    String? message,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) async {
    if (!isPermissionDenied(error)) {
      return;
    }

    if (!_reportedFailurePaths.add(failurePath)) {
      return;
    }

    final exception = error as FirebaseException;
    await DiagnosticsEvents.firestorePermissionDenied(
      message: message ?? 'Firestore permission denied',
      data: <String, dynamic>{
        'failurePath': failurePath,
        'code': exception.code,
        'plugin': exception.plugin,
        'message': exception.message ?? exception.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        ...?data,
      },
    );
  }
}
