// lib/data/location_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_models.dart';
import 'location_cache.dart';

class LocationRepository {
  final FirebaseFirestore _db;
  final LocationCache _cache;

  LocationRepository({
    FirebaseFirestore? db,
    required LocationCache cache,
  })  : _db = db ?? FirebaseFirestore.instance,
        _cache = cache;

  // ---------------------------
  // In-memory cache
  // ---------------------------
  List<Country>? _countriesCache;
  final Map<String, List<Admin1>> _admin1Cache = {};
  final Map<String, List<Admin2>> _admin2Cache = {};

  // ---------------------------
  // TTL (30 days for locations)
  // ---------------------------
  static const Duration _ttl = Duration(days: 30);

  bool get _isCacheFresh => _cache.isFresh(ttl: _ttl);

  // ============================================================
  // COUNTRIES
  // ============================================================
  Future<List<Country>> getCountries({
    bool onlyEnabled = true,
    bool forceRefresh = false,
  }) async {
    // 1️⃣ memory
    if (!forceRefresh && _countriesCache != null) {
      return _countriesCache!;
    }

    // 2️⃣ hive
    if (!forceRefresh && _isCacheFresh) {
      final raw = _cache.getTrCitiesRaw(); // reuse cities slot for countries
      if (raw != null && raw.isNotEmpty) {
        final list = raw
            .map((e) => Country.fromMap(e))
            .toList()
            .onlyEnabled()
            .sorted();

        _countriesCache = list;
        return list;
      }
    }

    // 3️⃣ firestore
    try {
      Query q = _db.collection('countries').orderBy('sort');
      if (onlyEnabled) q = q.where('enabled', isEqualTo: true);

      final snap = await q.get();

      final list = snap.docs
          .map((d) => Country.fromMap(d.data() as Map<String, dynamic>))
          .toList()
          .sorted();

      _countriesCache = list;

      // save to hive
      await _cache.putTrCitiesRaw(
        list.map((e) => e.toMap()).toList(),
      );

      return list;
    } catch (e) {
      // offline fallback
      if (_countriesCache != null) return _countriesCache!;
      return [];
    }
  }

  // ============================================================
  // ADMIN1
  // ============================================================
  Future<List<Admin1>> getAdmin1(
    String countryCode, {
    bool onlyEnabled = true,
    bool forceRefresh = false,
  }) async {
    // memory
    if (!forceRefresh && _admin1Cache[countryCode] != null) {
      return _admin1Cache[countryCode]!;
    }

    final hiveKey = 'admin1_$countryCode';

    // hive fallback
    if (!forceRefresh && _isCacheFresh) {
      final raw = _cache.readRawList(hiveKey);
      if (raw != null && raw.isNotEmpty) {
        final list = raw
            .map((e) => Admin1.fromMap(e['id'], e))
            .toList()
            .onlyEnabled()
            .sorted();

        _admin1Cache[countryCode] = list;
        return list;
      }
    }

    try {
      Query q = _db
          .collection('countries')
          .doc(countryCode)
          .collection('admin1')
          .orderBy('sort');

      if (onlyEnabled) q = q.where('enabled', isEqualTo: true);

      final snap = await q.get();

      final list = snap.docs
          .map((d) => Admin1.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList()
          .sorted();

      _admin1Cache[countryCode] = list;

      await _cache.writeRawList(
        hiveKey,
        list.map((e) => e.toMap()).toList(),
      );

      return list;
    } catch (e) {
      if (_admin1Cache[countryCode] != null) {
        return _admin1Cache[countryCode]!;
      }
      return [];
    }
  }

  // ============================================================
  // ADMIN2
  // ============================================================
  Future<List<Admin2>> getAdmin2(
    String countryCode,
    String admin1Id, {
    bool onlyEnabled = true,
    bool forceRefresh = false,
  }) async {
    final key = '$countryCode|$admin1Id';

    if (!forceRefresh && _admin2Cache[key] != null) {
      return _admin2Cache[key]!;
    }

    final hiveKey = 'admin2_$key';

    if (!forceRefresh && _isCacheFresh) {
      final raw = _cache.readRawList(hiveKey);
      if (raw != null && raw.isNotEmpty) {
        final list = raw
            .map((e) => Admin2.fromMap(e['id'], e))
            .toList()
            .onlyEnabled()
            .sorted();

        _admin2Cache[key] = list;
        return list;
      }
    }

    try {
      Query q = _db
          .collection('countries')
          .doc(countryCode)
          .collection('admin1')
          .doc(admin1Id)
          .collection('admin2')
          .orderBy('sort');

      if (onlyEnabled) q = q.where('enabled', isEqualTo: true);

      final snap = await q.get();

      final list = snap.docs
          .map((d) => Admin2.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList()
          .sorted();

      _admin2Cache[key] = list;

      await _cache.writeRawList(
        hiveKey,
        list.map((e) => e.toMap()).toList(),
      );

      return list;
    } catch (e) {
      if (_admin2Cache[key] != null) {
        return _admin2Cache[key]!;
      }
      return [];
    }
  }

  // ---------------------------
  // Clear memory only
  // ---------------------------
  void clearMemory() {
    _countriesCache = null;
    _admin1Cache.clear();
    _admin2Cache.clear();
  }

  // ---------------------------
  // Full reset (memory + hive)
  // ---------------------------
  Future<void> clearAll() async {
    clearMemory();
    await _cache.clearAll();
  }
}