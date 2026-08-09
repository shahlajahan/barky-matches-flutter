/// Normalizes the legacy embedded service map and the canonical projected
/// service list into the list shape used by public UI flows.
class PublicServiceNormalizer {
  const PublicServiceNormalizer._();

  static String? serviceId(Map<String, dynamic> service) {
    final value = (service['id'] ?? service['serviceId'])?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Keeps legacy public services visible when their projection predates
  /// canonical service IDs. Unidentified records are never ranked or turned
  /// into Promotion targets; they are appended unchanged instead.
  static List<Map<String, dynamic>> mergeRankedWithLegacyServices({
    required List<Map<String, dynamic>> ranked,
    required List<Map<String, dynamic>> source,
  }) {
    final rankedIds = ranked.map(serviceId).whereType<String>().toSet();
    final legacy = source.where((service) {
      final id = serviceId(service);
      return id == null || !rankedIds.contains(id);
    });
    return [...ranked, ...legacy];
  }

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
