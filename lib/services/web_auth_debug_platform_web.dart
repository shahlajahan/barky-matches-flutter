import 'dart:async';
import 'dart:html' as html;
import 'dart:convert';

const _debugStorageKey = 'petsupo.web_auth_debug.entries';

bool get webAuthDebugEnabled =>
    (html.window.location.search ?? '').contains('debugAuth=1');

void webAuthConsoleLog(String message) {
  html.window.console.log(message);
}

List<String> loadWebAuthDebugEntries() {
  if (!webAuthDebugEnabled) return const [];
  final raw = html.window.sessionStorage[_debugStorageKey];
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((entry) => entry.toString()).toList();
    }
  } catch (_) {}
  return const [];
}

void persistWebAuthDebugEntries(List<String> entries) {
  if (!webAuthDebugEnabled) return;
  html.window.sessionStorage[_debugStorageKey] = jsonEncode(entries);
}

Future<void> copyWebAuthDebugEntries(String text) async {
  if (!webAuthDebugEnabled) return;
  final textarea = html.TextAreaElement()..value = text;
  html.document.body?.append(textarea);
  textarea.select();
  html.document.execCommand('copy');
  textarea.remove();
}
