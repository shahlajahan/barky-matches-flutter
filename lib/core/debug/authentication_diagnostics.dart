import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'app_log.dart';
import 'diagnostics_reporter.dart';

class AuthenticationDiagnostics {
  AuthenticationDiagnostics._();

  static void captureFailure({
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    String? reason,
    Map<String, dynamic>? data,
  }) {
    final FirebaseAuthException? authException = error is FirebaseAuthException
        ? error
        : null;
    final String reportReason =
        reason ?? authException?.code ?? '${operation}_failure';

    AppLog.auth(
      'Authentication failure captured',
      data: <String, dynamic>{
        'feature': 'authentication',
        'operation': operation,
        'exceptionType': error.runtimeType.toString(),
        if (authException != null) 'code': authException.code,
        if (authException?.message != null) 'message': authException!.message,
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        if (data != null) ...data,
      },
    );

    unawaited(
      DiagnosticsReporter().captureDiagnosticEvent(
        reason: reportReason,
        severity: 'error',
      ),
    );
  }
}
