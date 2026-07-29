/// Formats a past DateTime as a short relative string ("2 hours ago").
/// Plain English for now - localization is a dedicated later pass rather
/// than churned per-widget.
String formatRelativeTime(DateTime? dateTime) {
  if (dateTime == null) return '';

  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m minute${m == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h hour${h == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 30) {
    final w = (diff.inDays / 7).floor();
    return '$w week${w == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 365) {
    final mo = (diff.inDays / 30).floor();
    return '$mo month${mo == 1 ? '' : 's'} ago';
  }
  final y = (diff.inDays / 365).floor();
  return '$y year${y == 1 ? '' : 's'} ago';
}
