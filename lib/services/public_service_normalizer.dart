/// Normalizes the legacy embedded service map and the canonical projected
/// service list into the list shape used by public UI flows.
class PublicServiceNormalizer {
  const PublicServiceNormalizer._();

  static List<Map<String, dynamic>> toMaps(dynamic raw) {
    if (raw is Map) {
      final nested = raw['offeredServices'] ?? raw['services'];
      if (nested != null && !identical(nested, raw)) {
        return toMaps(nested);
      }

      final result = <Map<String, dynamic>>[];
      for (final entry in raw.entries) {
        if (entry.value is Map) {
          final service = Map<String, dynamic>.from(entry.value as Map);
          service.putIfAbsent('id', () => entry.key.toString());
          result.add(service);
        }
      }
      if (result.isNotEmpty) return result;
      return [Map<String, dynamic>.from(raw)];
    }

    if (raw is Iterable) {
      return raw.expand<Map<String, dynamic>>((item) {
        if (item is Map) return [Map<String, dynamic>.from(item)];
        final title = item?.toString().trim() ?? '';
        return title.isEmpty
            ? const []
            : [
                <String, dynamic>{'title': title},
              ];
      }).toList();
    }

    final title = raw?.toString().trim() ?? '';
    return title.isEmpty
        ? <Map<String, dynamic>>[]
        : [
            {'title': title},
          ];
  }

  static List<String> toTitles(dynamic raw) {
    return toMaps(raw)
        .map(
          (service) =>
              (service['title'] ??
                      service['name'] ??
                      service['displayName'] ??
                      service['serviceName'] ??
                      '')
                  .toString()
                  .trim(),
        )
        .where((title) => title.isNotEmpty)
        .toList();
  }
}
