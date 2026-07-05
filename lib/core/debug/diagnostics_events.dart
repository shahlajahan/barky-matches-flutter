import 'app_log.dart';
import 'diagnostics_reporter.dart';

class DiagnosticsEvents {
  DiagnosticsEvents._();

  static Future<void> mapInitializationFailed({
    String? message,
    Map<String, dynamic>? data,
  }) async {
    AppLog.error(
      message ?? 'Map initialization failed',
      data: data,
    );
    await DiagnosticsReporter().captureDiagnosticEvent(
      reason: 'MapInitializationFailed',
      severity: 'warning',
    );
  }

  static Future<void> mapSuspiciousWhiteScreen({
    String? message,
    Map<String, dynamic>? data,
  }) async {
    AppLog.error(
      message ?? 'Map suspicious white screen',
      data: data,
    );
    await DiagnosticsReporter().captureDiagnosticEvent(
      reason: 'MapSuspiciousWhiteScreen',
      severity: 'warning',
    );
  }

  static Future<void> imageUploadFailed({
    String? message,
    Map<String, dynamic>? data,
  }) async {
    AppLog.error(
      message ?? 'Image upload failed',
      data: data,
    );
    await DiagnosticsReporter().captureDiagnosticEvent(
      reason: 'ImageUploadFailed',
      severity: 'warning',
    );
  }

  static Future<void> firestorePermissionDenied({
    String? message,
    Map<String, dynamic>? data,
  }) async {
    AppLog.error(
      message ?? 'Firestore permission denied',
      data: data,
    );
    await DiagnosticsReporter().captureDiagnosticEvent(
      reason: 'FirestorePermissionDenied',
      severity: 'error',
    );
  }

  static Future<void> paymentTimeout({
    String? message,
    Map<String, dynamic>? data,
  }) async {
    AppLog.error(
      message ?? 'Payment timed out',
      data: data,
    );
    await DiagnosticsReporter().captureDiagnosticEvent(
      reason: 'PaymentTimeout',
      severity: 'warning',
    );
  }

  static Future<void> unknownFailure({
    String? message,
    Map<String, dynamic>? data,
  }) async {
    AppLog.error(
      message ?? 'Unknown failure',
      data: data,
    );
    await DiagnosticsReporter().captureDiagnosticEvent(
      reason: 'UnknownFailure',
      severity: 'error',
    );
  }
}
