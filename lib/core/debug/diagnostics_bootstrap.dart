import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'app_log.dart';
import 'diagnostics_reporter.dart';

class DiagnosticsBootstrap {
  DiagnosticsBootstrap._();

  static bool _initialized = false;
  static bool _capturing = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    final FlutterExceptionHandler? existingFlutterErrorHandler =
        FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (!_capturing) {
        _capturing = true;
        try {
          AppLog.error(
            'Unhandled FlutterError captured',
            data: <String, dynamic>{
              'exception': details.exceptionAsString(),
              'stackTrace': _truncateStackTrace(details.stack?.toString()),
              'library': details.library,
              'context': details.context?.toDescription(),
            },
          );

          unawaited(
            DiagnosticsReporter().captureCriticalError(reason: 'FlutterError'),
          );
        } finally {
          _capturing = false;
        }
      }

      if (existingFlutterErrorHandler != null) {
        existingFlutterErrorHandler(details);
        return;
      }

      FlutterError.presentError(details);
    };

    final ErrorCallback? existingPlatformErrorHandler =
        PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object exception, StackTrace stack) {
      if (!_capturing) {
        _capturing = true;
        try {
          AppLog.error(
            'Unhandled PlatformDispatcher error captured',
            data: <String, dynamic>{
              'exception': exception.toString(),
              'stackTrace': _truncateStackTrace(stack.toString()),
            },
          );

          unawaited(
            DiagnosticsReporter().captureCriticalError(
              reason: 'PlatformDispatcher',
            ),
          );
        } finally {
          _capturing = false;
        }
      }

      if (existingPlatformErrorHandler != null) {
        existingPlatformErrorHandler(exception, stack);
      }

      return false;
    };
  }

  static String? _truncateStackTrace(String? stackTrace) {
    if (stackTrace == null || stackTrace.length <= 4000) {
      return stackTrace;
    }

    return stackTrace.substring(0, 4000);
  }
}
