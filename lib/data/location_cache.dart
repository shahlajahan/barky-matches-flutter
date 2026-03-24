// lib/data/location_cache.dart
import 'package:hive/hive.dart';

/// Hive schema strategy:
/// - Store raw List<Map> to avoid adapters and keep it flexible.
/// - Add meta keys for version + updatedAt to support invalidation/TTL.
class LocationCacheKeys {
  static const String boxName = 'location_cache_v1';

  // ---- meta ----
  static const String metaSchemaVersion = 'meta_schema_version';
  static const String metaUpdatedAtMillis = 'meta_updated_at_millis';

  // bump this if you change key formats or stored payload structure
  static const int schemaVersion = 1;

  // ---- payload keys ----
  static const String trCities = 'tr_cities'; // List<Map{id,name,...}>

  /// Districts are stored per-city:
  /// tr_districts_34 -> List<Map{id,name,...}>
  static String trDistrictsForCity(String cityId) => 'tr_districts_$cityId';
}

class LocationCache {
  LocationCache(this._box);

  final Box _box;

  // ---------------------------
  // Open
  // ---------------------------
  static Future<LocationCache> open() async {
    final box = await Hive.openBox(LocationCacheKeys.boxName);
    final cache = LocationCache(box);

    // Ensure meta exists
    await cache._ensureMeta();
    return cache;
  }

  Future<void> _ensureMeta() async {
    final v = _box.get(LocationCacheKeys.metaSchemaVersion);
    if (v != LocationCacheKeys.schemaVersion) {
      // schema changed → wipe cache to avoid mismatches
      await _box.clear();
      await _box.put(LocationCacheKeys.metaSchemaVersion, LocationCacheKeys.schemaVersion);
      await _box.put(LocationCacheKeys.metaUpdatedAtMillis, 0);
    } else {
      // ensure keys exist
      _box.put(LocationCacheKeys.metaSchemaVersion, LocationCacheKeys.schemaVersion);
      _box.put(LocationCacheKeys.metaUpdatedAtMillis, _box.get(LocationCacheKeys.metaUpdatedAtMillis) ?? 0);
    }
  }

  // ---------------------------
  // TTL / Freshness
  // ---------------------------
  int get updatedAtMillis {
    final v = _box.get(LocationCacheKeys.metaUpdatedAtMillis);
    return v is int ? v : 0;
  }

  bool isFresh({required Duration ttl}) {
    final updated = updatedAtMillis;
    if (updated <= 0) return false;
    final age = DateTime.now().millisecondsSinceEpoch - updated;
    return age <= ttl.inMilliseconds;
  }

  Future<void> touchNow() async {
    await _box.put(
      LocationCacheKeys.metaUpdatedAtMillis,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ---------------------------
  // Helpers (raw conversions)
  // ---------------------------
  List<Map<String, dynamic>>? _readListOfMaps(String key) {
    final v = _box.get(key);
    if (v is List) {
      return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return null;
  }

  Future<void> _writeListOfMaps(String key, List<Map<String, dynamic>> items) async {
    await _box.put(key, items);
    await touchNow();
  }

  // ---------------------------
  // Cities (TR)
  // ---------------------------
  List<Map<String, dynamic>>? getTrCitiesRaw() {
    return _readListOfMaps(LocationCacheKeys.trCities);
  }

  Future<void> putTrCitiesRaw(List<Map<String, dynamic>> items) async {
    await _writeListOfMaps(LocationCacheKeys.trCities, items);
  }

  // ---------------------------
  // Districts (TR per city)
  // ---------------------------
  List<Map<String, dynamic>>? getTrDistrictsRaw(String cityId) {
    return _readListOfMaps(LocationCacheKeys.trDistrictsForCity(cityId));
  }

  Future<void> putTrDistrictsRaw(String cityId, List<Map<String, dynamic>> items) async {
    await _writeListOfMaps(LocationCacheKeys.trDistrictsForCity(cityId), items);
  }

  // ---------------------------
  // Maintenance
  // ---------------------------
  Future<void> clearAll() async {
    await _box.clear();
    await _box.put(LocationCacheKeys.metaSchemaVersion, LocationCacheKeys.schemaVersion);
    await _box.put(LocationCacheKeys.metaUpdatedAtMillis, 0);
  }

  Future<void> clearDistrictsForCity(String cityId) async {
    await _box.delete(LocationCacheKeys.trDistrictsForCity(cityId));
    await touchNow();
  }

  // ---------------------------
// Generic read/write (public)
// ---------------------------

List<Map<String, dynamic>>? readRawList(String key) {
  final v = _box.get(key);
  if (v is List) {
    return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return null;
}

Future<void> writeRawList(String key, List<Map<String, dynamic>> items) async {
  await _box.put(key, items);
  await touchNow();
}
}