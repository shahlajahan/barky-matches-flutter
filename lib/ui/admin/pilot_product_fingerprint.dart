import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Revision 28 pilot product approval contract — the frozen "corrected"
/// bound-field set, kept byte-identical to `firestore.rules`'
/// `pilotApprovalBoundFields()` and
/// `functions/src/marketplace/compliance/pilotProductApproval.js`'
/// `pilotApprovalBoundFields()`. `sku`/`businessId`/`createdAt` are
/// deliberately excluded — each is already immutable via its own
/// separate Rules predicate.
const List<String> kPilotApprovalBoundFields = [
  'name',
  'description',
  'price',
  'currency',
  'media',
  'category',
  'brand',
  'barcode',
  'salePrice',
  'kdvRate',
  'sellerRelationship',
];

/// Mirrors `pilotProductApproval.js`'s `canonicalStringify`: every
/// object's own keys sorted at every nesting level, array element order
/// preserved (array order is itself meaningful for `media`).
///
/// Numbers need special handling: Firestore stores prices/rates as
/// doubles, and Dart's `double.toString()` always keeps a trailing
/// `.0` for whole numbers (e.g. `100.0`) while JavaScript's
/// `JSON.stringify` never does (`100`). Left unhandled, this alone
/// would make the client fingerprint diverge from the server's for any
/// whole-number price, so whole-valued numbers are rendered without a
/// decimal point to match the server's `JSON.stringify` output exactly.
String _canonicalStringify(dynamic value) {
  if (value is List) {
    return '[${value.map(_canonicalStringify).join(",")}]';
  }
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    final parts = keys.map(
      (k) => '${jsonEncode(k)}:${_canonicalStringify(value[k])}',
    );
    return '{${parts.join(",")}}';
  }
  if (value == null) {
    return 'null';
  }
  if (value is num) {
    return _canonicalNumberToString(value);
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  if (value is String) {
    return jsonEncode(value);
  }
  return jsonEncode(value.toString());
}

String _canonicalNumberToString(num value) {
  if (value is int) return value.toString();
  final d = value as double;
  if (d.isFinite && d == d.truncateToDouble()) {
    return d.truncate().toString();
  }
  return d.toString();
}

/// Mirrors `pilotProductApproval.js`'s `computeContentFingerprint`: picks
/// only the keys in [kPilotApprovalBoundFields] that are actually present
/// on [productData] (presence-checked, not defaulted), canonicalizes, and
/// hashes with SHA-256. Must be computed from the *raw* Firestore
/// document map — not a hydrated model with backfilled defaults — so
/// that "present" here means the same thing it means server-side.
String computePilotProductContentFingerprint(
  Map<String, dynamic> productData,
) {
  final picked = <String, dynamic>{};
  for (final key in kPilotApprovalBoundFields) {
    if (productData.containsKey(key)) {
      picked[key] = productData[key];
    }
  }
  final canonical = _canonicalStringify(picked);
  return sha256.convert(utf8.encode(canonical)).toString();
}
