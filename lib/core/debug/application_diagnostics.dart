import 'dart:async';

import 'app_log.dart';
import 'diagnostics_reporter.dart';

class ApplicationDiagnostics {
  ApplicationDiagnostics._();

  static const Set<String> _sensitiveMetadataKeys = <String>{
    'authorization',
    'authorizationheader',
    'authorizationheaders',
    'body',
    'email',
    'idtoken',
    'password',
    'refreshtoken',
    'requestbody',
    'token',
  };

  static void captureException({
    required String operation,
    required String feature,
    required Object exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? reason,
  }) {
    final String exceptionType = exception.runtimeType.toString();
    final String message = exception.toString();
    final Map<String, dynamic> sanitizedMetadata = _sanitizeMetadata(
      metadata ?? const <String, dynamic>{},
    );

    AppLog.error(
      'Unexpected application exception captured',
      data: <String, dynamic>{
        'feature': feature,
        'operation': operation,
        'exceptionType': exceptionType,
        'message': message,
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        if (sanitizedMetadata.isNotEmpty) 'metadata': sanitizedMetadata,
      },
    );

    unawaited(
      DiagnosticsReporter().captureDiagnosticEvent(
        reason: reason ?? exceptionType,
        severity: 'error',
      ),
    );
  }

  static Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> metadata) {
    final Map<String, dynamic> sanitized = <String, dynamic>{};

    metadata.forEach((String key, dynamic value) {
      if (_isSensitiveKey(key)) {
        return;
      }

      sanitized[key] = _sanitizeValue(value);
    });

    return sanitized;
  }

  static Object? _sanitizeValue(Object? value) {
    if (value is Map) {
      final Map<String, dynamic> sanitized = <String, dynamic>{};

      value.forEach((dynamic key, dynamic value) {
        final String stringKey = key.toString();
        if (_isSensitiveKey(stringKey)) {
          return;
        }

        sanitized[stringKey] = _sanitizeValue(value);
      });

      return sanitized;
    }

    if (value is List) {
      return value.map(_sanitizeValue).toList(growable: false);
    }

    return value;
  }

  static bool _isSensitiveKey(String key) {
    final String normalizedKey = key.toLowerCase().replaceAll(
      RegExp('[^a-z0-9]'),
      '',
    );

    return _sensitiveMetadataKeys.any(normalizedKey.contains);
  }
}
