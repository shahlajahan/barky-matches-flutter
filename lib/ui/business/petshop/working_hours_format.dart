/// Canonical parsing/normalization for the Pet Shop single-string
/// working-hours field.
///
/// The registration form previously accepted any text, so a value such as
/// `10:00_21:00` was stored verbatim and rendered unchanged on the public
/// profile. This keeps the existing single-string model — no weekly
/// scheduler — but constrains it to one canonical representation.
///
/// Accepted input (after trimming, and tolerating whitespace around the
/// separator):
///   * `10:00-21:00`   ASCII hyphen-minus
///   * `10:00–21:00`   en dash
///   * `10:00—21:00`   em dash
///   * `10:00 to 21:00` / `10:00 ile 21:00` are **not** accepted — only the
///     three dash forms above, deliberately kept narrow.
///
/// Rejected: underscores and every other separator, non-24-hour values,
/// out-of-range hours/minutes, missing minutes, and ranges whose closing
/// time is not strictly after the opening time. Overnight ranges are
/// intentionally unsupported in this revision.
///
/// A rejected value is never silently rewritten into a valid one — callers
/// receive `null` and must surface a validation error instead.
class WorkingHoursFormat {
  const WorkingHoursFormat._();

  /// The dash used by the canonical form and by the localized example.
  static const String canonicalSeparator = '–';

  /// Separators accepted on input, normalized to [canonicalSeparator].
  static const List<String> acceptedSeparators = ['-', '–', '—'];

  /// A human-facing example, used by the localized hint.
  static const String example = '10:00–21:00';

  static final RegExp _pattern = RegExp(
    r'^(\d{1,2}):(\d{2})\s*[-–—]\s*(\d{1,2}):(\d{2})$',
  );

  /// Returns the canonical `HH:mm–HH:mm` form, or `null` when [raw] is not a
  /// value this contract accepts.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final match = _pattern.firstMatch(trimmed);
    if (match == null) return null;

    final openHour = int.tryParse(match.group(1)!);
    final openMinute = int.tryParse(match.group(2)!);
    final closeHour = int.tryParse(match.group(3)!);
    final closeMinute = int.tryParse(match.group(4)!);
    if (openHour == null ||
        openMinute == null ||
        closeHour == null ||
        closeMinute == null) {
      return null;
    }

    if (!_isValidTime(openHour, openMinute)) return null;
    if (!_isValidTime(closeHour, closeMinute)) return null;

    final openTotal = openHour * 60 + openMinute;
    final closeTotal = closeHour * 60 + closeMinute;
    // Overnight ranges are out of scope; an equal or reversed range is a
    // user error rather than a 24-hour shop.
    if (closeTotal <= openTotal) return null;

    return '${_two(openHour)}:${_two(openMinute)}'
        '$canonicalSeparator'
        '${_two(closeHour)}:${_two(closeMinute)}';
  }

  /// Whether [raw] is accepted by [normalize].
  static bool isValid(String? raw) => normalize(raw) != null;

  /// Display helper for values already persisted.
  ///
  /// Canonicalizes when possible, so a historical `10:00-21:00` record renders
  /// identically to a newly-submitted one. A malformed legacy value (for
  /// example the reported `10:00_21:00`) returns `null` rather than being shown
  /// verbatim: callers then fall back to their existing localized
  /// "hours unavailable" presentation. No time is ever invented, and the stored
  /// document is not modified — this affects display only.
  static String? forDisplay(String? stored) {
    if (stored == null) return null;
    final trimmed = stored.trim();
    if (trimmed.isEmpty) return null;
    return normalize(trimmed);
  }

  static bool _isValidTime(int hour, int minute) =>
      hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;

  static String _two(int value) => value.toString().padLeft(2, '0');
}
