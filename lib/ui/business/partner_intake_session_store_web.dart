import 'dart:convert';
import 'dart:html' as html;

const String _partnerIntakeSessionKey = 'petsupo.partner_intake';

Map<Object?, Object?>? readPartnerIntakeContext() {
  final raw = html.window.sessionStorage[_partnerIntakeSessionKey];
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  return decoded is Map ? decoded : null;
}

void savePartnerIntakeContext(Map<String, Object?> value) {
  html.window.sessionStorage[_partnerIntakeSessionKey] = jsonEncode(value);
}

void clearPartnerIntakeContext() {
  html.window.sessionStorage.remove(_partnerIntakeSessionKey);
}
