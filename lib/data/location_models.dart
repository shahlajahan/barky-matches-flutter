// lib/data/location_models.dart

class Country {
  final String code;
  final String name;
  final String? nameLocal;
  final String? dialCode;
  final bool enabled;
  final int sort;

  const Country({
    required this.code,
    required this.name,
    this.nameLocal,
    this.dialCode,
    required this.enabled,
    required this.sort,
  });

  // ---------------------------
  // Factory
  // ---------------------------
  factory Country.fromMap(Map<String, dynamic> m) {
    return Country(
      code: (m['code'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      nameLocal: m['name_local']?.toString(),
      dialCode: m['dial_code']?.toString(),
      enabled: (m['enabled'] ?? true) == true,
      sort: (m['sort'] ?? 9999) is int
          ? (m['sort'] ?? 9999)
          : int.tryParse('${m['sort']}') ?? 9999,
    );
  }

  // ---------------------------
  // ToMap (for Hive cache)
  // ---------------------------
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'name_local': nameLocal,
      'dial_code': dialCode,
      'enabled': enabled,
      'sort': sort,
    };
  }

  // ---------------------------
  // CopyWith
  // ---------------------------
  Country copyWith({
    String? code,
    String? name,
    String? nameLocal,
    String? dialCode,
    bool? enabled,
    int? sort,
  }) {
    return Country(
      code: code ?? this.code,
      name: name ?? this.name,
      nameLocal: nameLocal ?? this.nameLocal,
      dialCode: dialCode ?? this.dialCode,
      enabled: enabled ?? this.enabled,
      sort: sort ?? this.sort,
    );
  }

  // ---------------------------
  // Display Name (for search)
  // ---------------------------
  String get displayName => nameLocal ?? name;

  // ---------------------------
  // Equality (important for cache)
  // ---------------------------
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}








class Admin1 {
  final String id;
  final String name;
  final String? nameLocal;
  final bool enabled;
  final int sort;

  const Admin1({
    required this.id,
    required this.name,
    this.nameLocal,
    required this.enabled,
    required this.sort,
  });

  factory Admin1.fromMap(String id, Map<String, dynamic> m) {
    return Admin1(
      id: id,
      name: (m['name'] ?? '').toString(),
      nameLocal: m['name_local']?.toString(),
      enabled: (m['enabled'] ?? true) == true,
      sort: (m['sort'] ?? 9999) is int
          ? (m['sort'] ?? 9999)
          : int.tryParse('${m['sort']}') ?? 9999,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_local': nameLocal,
      'enabled': enabled,
      'sort': sort,
    };
  }

  Admin1 copyWith({
    String? id,
    String? name,
    String? nameLocal,
    bool? enabled,
    int? sort,
  }) {
    return Admin1(
      id: id ?? this.id,
      name: name ?? this.name,
      nameLocal: nameLocal ?? this.nameLocal,
      enabled: enabled ?? this.enabled,
      sort: sort ?? this.sort,
    );
  }

  String get displayName => nameLocal ?? name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Admin1 &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}








class Admin2 {
  final String id;
  final String name;
  final String? nameLocal;
  final bool enabled;
  final int sort;

  const Admin2({
    required this.id,
    required this.name,
    this.nameLocal,
    required this.enabled,
    required this.sort,
  });

  factory Admin2.fromMap(String id, Map<String, dynamic> m) {
    return Admin2(
      id: id,
      name: (m['name'] ?? '').toString(),
      nameLocal: m['name_local']?.toString(),
      enabled: (m['enabled'] ?? true) == true,
      sort: (m['sort'] ?? 9999) is int
          ? (m['sort'] ?? 9999)
          : int.tryParse('${m['sort']}') ?? 9999,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_local': nameLocal,
      'enabled': enabled,
      'sort': sort,
    };
  }

  Admin2 copyWith({
    String? id,
    String? name,
    String? nameLocal,
    bool? enabled,
    int? sort,
  }) {
    return Admin2(
      id: id ?? this.id,
      name: name ?? this.name,
      nameLocal: nameLocal ?? this.nameLocal,
      enabled: enabled ?? this.enabled,
      sort: sort ?? this.sort,
    );
  }

  String get displayName => nameLocal ?? name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Admin2 &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  
}

// ==============================
// Sorting Extensions
// ==============================

extension CountryListX on List<Country> {
  List<Country> sorted() {
    final list = [...this];
    list.sort((a, b) {
      final bySort = a.sort.compareTo(b.sort);
      if (bySort != 0) return bySort;
      return a.displayName.compareTo(b.displayName);
    });
    return list;
  }

  List<Country> onlyEnabled() {
    return where((c) => c.enabled).toList();
  }
}

extension Admin1ListX on List<Admin1> {
  List<Admin1> sorted() {
    final list = [...this];
    list.sort((a, b) {
      final bySort = a.sort.compareTo(b.sort);
      if (bySort != 0) return bySort;
      return a.displayName.compareTo(b.displayName);
    });
    return list;
  }

  List<Admin1> onlyEnabled() {
    return where((c) => c.enabled).toList();
  }
}

extension Admin2ListX on List<Admin2> {
  List<Admin2> sorted() {
    final list = [...this];
    list.sort((a, b) {
      final bySort = a.sort.compareTo(b.sort);
      if (bySort != 0) return bySort;
      return a.displayName.compareTo(b.displayName);
    });
    return list;
  }

  List<Admin2> onlyEnabled() {
    return where((c) => c.enabled).toList();
  }
}






// ==============================
// Search Utility (Turkish Safe)
// ==============================

extension StringSearchX on String {
  String normalized() {
    return toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u');
  }
}

extension Admin2SearchX on List<Admin2> {
  List<Admin2> search(String query) {
    final q = query.normalized();
    return where((e) => e.displayName.normalized().contains(q)).toList();
  }
}

extension Admin1SearchX on List<Admin1> {
  List<Admin1> search(String query) {
    final q = query.normalized();
    return where((e) => e.displayName.normalized().contains(q)).toList();
  }
}