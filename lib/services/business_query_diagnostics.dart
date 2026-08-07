import 'package:flutter/foundation.dart';

/// Temporary cross-page diagnostics for the public business directory.
/// Keep the messages stable so a single console search covers every sector.
abstract final class BusinessQueryDiagnostics {
  static void start(String source, String collection, String clauses) {
    debugPrint(
      'BUSINESS QUERY START source=$source collection=$collection clauses=$clauses',
    );
  }

  static void result(String source, int count) {
    debugPrint('BUSINESS QUERY RESULT COUNT source=$source count=$count');
  }

  static void error(String source, Object error, [StackTrace? stack]) {
    debugPrint('BUSINESS QUERY ERROR source=$source error=$error');
    if (stack != null) debugPrint('$stack');
  }

  static void filtered(String source, int count) {
    debugPrint('FILTERED RESULT COUNT source=$source count=$count');
  }
}
