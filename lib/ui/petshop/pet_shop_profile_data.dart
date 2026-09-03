import 'package:cloud_firestore/cloud_firestore.dart';

class PetShopProfileData {
  const PetShopProfileData({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.district,
    required this.description,
    required this.categories,
    required this.gallery,
    required this.rawData,
    required this.productOwnerId,
    this.logoUrl,
    this.coverUrl,
    this.phone,
    this.whatsapp,
    this.email,
    this.website,
    this.instagram,
    this.latitude,
    this.longitude,
    this.rating,
    this.reviewCount = 0,
    this.workingHours,
    this.isVerified = false,
    this.distanceKm,
  });

  static const sectorAliases = {'pet_shop', 'petshop', 'seller', 'store'};

  final String id;
  final String name;
  final String address;
  final String city;
  final String district;
  final String description;
  final List<String> categories;
  final List<String> gallery;
  final Map<String, dynamic> rawData;
  final String productOwnerId;
  final String? logoUrl;
  final String? coverUrl;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;
  final String? instagram;
  final double? latitude;
  final double? longitude;
  final double? rating;
  final int reviewCount;
  final Map<String, dynamic>? workingHours;
  final bool isVerified;
  final double? distanceKm;

  PetShopProfileData copyWith({double? distanceKm}) => PetShopProfileData(
    id: id,
    name: name,
    address: address,
    city: city,
    district: district,
    description: description,
    categories: categories,
    gallery: gallery,
    rawData: rawData,
    productOwnerId: productOwnerId,
    logoUrl: logoUrl,
    coverUrl: coverUrl,
    phone: phone,
    whatsapp: whatsapp,
    email: email,
    website: website,
    instagram: instagram,
    latitude: latitude,
    longitude: longitude,
    rating: rating,
    reviewCount: reviewCount,
    workingHours: workingHours,
    isVerified: isVerified,
    distanceKm: distanceKm,
  );

  /// The sector-detail map, resolved across both stored representations.
  ///
  /// `businesses/{id}` stores sector details under `sectorData`, written by
  /// `registerBusiness`. The public projection `businesses_public/{id}`
  /// (functions/src/publicProjections.js) republishes exactly the same
  /// content under `publicSectorData` — it is listed in that file's own
  /// `PUBLIC_BUSINESS_KEYS`, while `sectorData` deliberately is not.
  ///
  /// Both public Petshop surfaces — the list page and the customer detail
  /// sheet it hands its `rawData` to — read `businesses_public`, so a reader
  /// that consulted `sectorData` alone saw an empty sector map there. Root
  /// business fields survived (`profile.displayName`, `contact.*`,
  /// `isVerified`) while every sector-scoped field silently rendered as its
  /// empty state. Reading both keys here, at the one shared model boundary,
  /// fixes every consumer at once and keeps direct `businesses` reads
  /// working unchanged. `sectorData` is preferred when both are present so a
  /// direct document read stays authoritative over any stale projection.
  static Map<String, dynamic> _sectorDataOf(Map<String, dynamic> data) {
    final canonical = _map(data['sectorData']);
    if (canonical.isNotEmpty) return canonical;
    return _map(data['publicSectorData']);
  }

  static bool isPetShopBusiness(Map<String, dynamic> data) {
    final sectors = _stringList(data['sectors']).map(_normalizeSector).toSet();
    final sectorData = _sectorDataOf(data);
    sectors.addAll(sectorData.keys.map(_normalizeSector));
    return sectors.any(sectorAliases.contains);
  }

  factory PetShopProfileData.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return PetShopProfileData.fromMap(document.id, document.data() ?? {});
  }

  factory PetShopProfileData.fromMap(String id, Map<String, dynamic> data) {
    final profile = _map(data['profile']);
    final contact = _map(data['contact']);
    final sectorData = _sectorDataOf(data);
    final petShop = _firstNonEmptyMap([
      sectorData['petshop'],
      sectorData['pet_shop'],
      sectorData['seller'],
      sectorData['store'],
    ]);
    final shopProfile = _map(petShop['profile']);
    final profileContent = _map(petShop['profileContent']);
    final social = _firstNonEmptyMap([
      profileContent['socialMedia'],
      shopProfile['socialMedia'],
      profile['socialMedia'],
    ]);

    final city = _text(contact['city'] ?? profile['city']);
    final district = _text(contact['district'] ?? profile['district']);
    final explicitAddress = _text(
      contact['address'] ?? profile['address'] ?? data['address'],
    );
    final address = explicitAddress.isNotEmpty
        ? explicitAddress
        : [district, city].where((value) => value.isNotEmpty).join(', ');

    final gallery = <String>{
      ..._stringList(data['images']),
      ..._stringList(data['gallery']),
      ..._stringList(profileContent['gallery']),
      ..._stringList(profileContent['shopPhotoUrls']),
      ..._stringList(shopProfile['gallery']),
    }.where((value) => value.trim().isNotEmpty).toList();

    final coverUrl = _firstText([
      data['coverImageUrl'],
      data['coverUrl'],
      profile['coverImageUrl'],
      profile['coverUrl'],
      profile['bannerUrl'],
      profileContent['coverImageUrl'],
      profileContent['coverUrl'],
      if (gallery.isNotEmpty) gallery.first,
    ]);
    final logoUrl = _firstText([
      profile['logoUrl'],
      profile['imageUrl'],
      data['logoUrl'],
      profileContent['logoUrl'],
      shopProfile['logoUrl'],
    ]);

    return PetShopProfileData(
      id: id,
      name: _firstText([
        profile['displayName'],
        profile['businessName'],
        profile['name'],
        petShop['shopName'],
        data['shopName'],
      ]),
      address: address,
      city: city,
      district: district,
      // Deterministic Bio precedence, canonical first.
      //
      // The Pet Shop form writes the seller's description to
      // `sectorData.petshop.profile.bio`, which the public projection
      // republishes at `publicSectorData.petshop.profile.bio`. That is the
      // canonical current path and must win: the top-level `profile.*` aliases
      // are legacy/shared fields that registration leaves empty for a Pet Shop
      // (`business_register_page.dart` submits `description: ""`), so a stale
      // value there must never mask what the seller actually submitted. The
      // legacy aliases remain as fallbacks so older documents, and businesses
      // created through other paths, still render.
      description: _firstText([
        shopProfile['bio'],
        profileContent['bio'],
        profile['bio'],
        profile['description'],
      ]),
      categories: _stringList(petShop['categories'] ?? petShop['shopTypes']),
      gallery: gallery,
      rawData: data,
      productOwnerId: _firstText([
        data['ownerUid'],
        data['sellerId'],
        data['uid'],
        id,
      ]),
      logoUrl: logoUrl.isEmpty ? null : logoUrl,
      coverUrl: coverUrl.isEmpty ? null : coverUrl,
      phone: _nullableText(contact['phone']),
      whatsapp: _nullableText(contact['whatsapp'] ?? contact['phone']),
      email: _nullableText(contact['email']),
      website: _nullableText(contact['website'] ?? social['website']),
      instagram: _nullableText(social['instagram']),
      latitude: _coordinate(data, petShop, contact, latitude: true),
      longitude: _coordinate(data, petShop, contact, latitude: false),
      rating: _number(data['rating'] ?? petShop['rating']),
      reviewCount:
          _integer(data['reviewsCount'] ?? petShop['reviewsCount']) ?? 0,
      workingHours: _workingHours(
        petShop['workingHoursMap'] ?? petShop['workingHours'],
      ),
      isVerified:
          data['isVerified'] == true ||
          _map(data['verification'])['isVerified'] == true,
    );
  }

  static String _normalizeSector(String value) =>
      value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  static Map<String, dynamic> _firstNonEmptyMap(List<dynamic> values) {
    for (final value in values) {
      final mapped = _map(value);
      if (mapped.isNotEmpty) return mapped;
    }
    return {};
  }

  static List<String> _stringList(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String? _nullableText(dynamic value) {
    final text = _text(value);
    return text.isEmpty ? null : text;
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_text(value));
  }

  static int? _integer(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(_text(value));
  }

  static double? _coordinate(
    Map<String, dynamic> root,
    Map<String, dynamic> sector,
    Map<String, dynamic> contact, {
    required bool latitude,
  }) {
    final primary = latitude ? 'lat' : 'lng';
    final secondary = latitude ? 'latitude' : 'longitude';
    final rootLocation = _map(root['location']);
    final sectorLocation = _map(sector['location']);
    for (final value in [
      root[primary],
      root[secondary],
      rootLocation[primary],
      rootLocation[secondary],
      sector[primary],
      sector[secondary],
      sectorLocation[primary],
      sectorLocation[secondary],
      contact[primary],
      contact[secondary],
    ]) {
      final parsed = _number(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static Map<String, dynamic>? _workingHours(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    final text = _text(value);
    return text.isEmpty ? null : {'hours': text};
  }
}
