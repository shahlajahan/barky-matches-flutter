import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreQueryTrace {
  static final Map<String, int> _startCounts = {};

  static void log({
    required String file,
    required String method,
    required int line,
    required String collection,
    required List<String> clauses,
    required String terminalCall,
    required Object query,
  }) {
    final signature = [
      collection,
      ...clauses,
      terminalCall,
    ].join(' | ');

    final occurrence = (_startCounts[signature] ?? 0) + 1;
    _startCounts[signature] = occurrence;

    debugPrint(
      '[FIRESTORE_QUERY]'
      ' file=$file'
      ' method=$method'
      ' line=$line'
      ' collection=$collection'
      ' clauses=${clauses.join(" -> ")}'
      ' terminal=$terminalCall'
      ' hash=${query.hashCode}'
      ' occurrence=$occurrence',
    );
  }
}
