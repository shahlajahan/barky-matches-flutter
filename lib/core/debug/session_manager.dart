import 'dart:math';

/// Lazily creates and caches the diagnostics session identifier.
class SessionManager {
  SessionManager._();

  static String? _sessionId;

  /// Returns the current app session identifier, generating it on first use.
  static String get sessionId => _sessionId ??= _generateSessionId();

  static String _generateSessionId() {
    final Random random = Random.secure();

    String segment(int length) {
      const String chars = '0123456789ABCDEF';
      final StringBuffer buffer = StringBuffer();

      for (int index = 0; index < length; index++) {
        buffer.write(chars[random.nextInt(chars.length)]);
      }

      return buffer.toString();
    }

    return '${segment(4)}-${segment(4)}';
  }
}
