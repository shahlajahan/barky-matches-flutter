import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:barky_matches_fixed/debug/firestore_query_trace.dart';

import 'package:barky_matches_fixed/ui/business/business_card_data.dart';

import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_driver_location_resolver.dart';

import 'package:barky_matches_fixed/ui/pet_taxi/services/pet_taxi_business_location_resolver.dart';

class PetTaxiBusinessRepository {
  Future<List<BusinessCardData>> loadBusinesses() async {
    final query = FirebaseFirestore.instance
        .collection('businesses_public')
        .where('status', isEqualTo: 'approved');
    FirestoreQueryTrace.log(
      file: 'lib/ui/pet_taxi/repositories/pet_taxi_business_repository.dart',
      method: 'loadBusinesses',
      line: 17,
      collection: 'businesses_public',
      clauses: const ["where(status, isEqualTo: approved)"],
      terminalCall: 'get()',
      query: query,
    );
    final snapshot = await query.get();

    final businesses =
        snapshot.docs
            .map((doc) => mapPetTaxiBusiness(doc.id, doc.data()))
            .whereType<BusinessCardData>()
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return businesses;
  }

  BusinessCardData? mapPetTaxiBusiness(String id, Map<String, dynamic> data) {
    final root = <String, dynamic>{...data, 'id': id};

    final sectorData = map(root['publicSectorData']);
    final taxi = map(
      sectorData['pet_taxi'] ?? sectorData['petTaxi'] ?? sectorData['taxi'],
    );

    final raw = [
      root['sector'],
      root['sectors'],
      root['businessType'],
      root['category'],
      sectorData.keys.join(' '),
      sectorData.toString(),
    ].join(' ').toLowerCase();

    if (!raw.contains('pet_taxi') &&
        !raw.contains('pet taxi') &&
        !raw.contains('taxi')) {
      return null;
    }

    final profile = map(root['profile']);
    final contact = map(root['contact']);
    final compliance = map(taxi['compliance']);
    final vehicle = map(taxi['vehicle']);
    final media = map(taxi['profileContent']);

    final name = firstText([
      profile['displayName'],
      taxi['displayName'],
      root['businessName'],
      root['name'],
    ]);

    final city = contact['city']?.toString().trim() ?? '';
    final district = contact['district']?.toString().trim() ?? '';
    final address = firstText([
      contact['addressLine'],
      [district, city].where((e) => e.isNotEmpty).join(', '),
    ]);

    return BusinessCardData(
      id: id,
      name: name.isNotEmpty ? name : 'Pet Taxi',
      city: city,
      district: district,
      address: address,
      specialties: const ['Pet Taxi', 'Safe Transport'],
      services: const ['One way', 'Round trip', 'Vet', 'Groomy', 'Hotel'],
      phone: contact['phone']?.toString(),
      whatsapp: contact['whatsapp']?.toString() ?? contact['phone']?.toString(),
      description: firstText([
        taxi['description'],
        profile['description'],
        vehicle['vehicleType'],
      ]),
      isVerified: map(root['verification'])['isVerified'] == true,
      status: root['status']?.toString() ?? 'approved',
      type: BusinessType.petTaxi,
      logoUrl: firstText([
        profile['logoUrl'],
        taxi['logo'],
        media['clinicLogoUrl'],
      ]),
      rawData: {...root, 'petTaxiCompliance': compliance},
      data: root,
    );
  }

  Future<BusinessCardData> findNearestBusiness({
    required dynamic pickup,
  }) async {
    final businesses = await loadBusinesses();

    if (businesses.isEmpty) {
      throw Exception('No pet taxi business found');
    }

    BusinessCardData? nearest;
    double nearestDistance = double.infinity;

    for (final business in businesses) {
      final data = business.data ?? {};

      PetTaxiBusinessLocationResolver.scheduleMigrationIfNeeded(
        businessId: business.id,
        businessData: data,
      );

      final sectorData = map(data['publicSectorData']);
      final taxi = map(
        sectorData['pet_taxi'] ?? sectorData['petTaxi'] ?? sectorData['taxi'],
      );

      final isAvailable =
          taxi['isAvailable'] == true ||
          taxi['available'] == true ||
          taxi['online'] == true;

      if (!isAvailable) {
        debugPrint('Skipped offline business -> ${business.name}');
        continue;
      }

      final resolvedLocation = PetTaxiBusinessLocationResolver.resolve(data);
      final location = resolvedLocation.location;

      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();

      debugPrint('Driver location source = ${resolvedLocation.sourceLabel}');
      debugPrint('Driver position = $lat, $lng');
      debugPrint('Business = ${business.name}');
      debugPrint('Pickup = ${pickup.lat}, ${pickup.lng}');

      if (lat == null || lng == null) {
        debugPrint('Location missing -> skipped');
        continue;
      }

      final distance = _distanceKm(pickup.lat, pickup.lng, lat, lng);

      debugPrint('Distance = ${distance.toStringAsFixed(2)} km');

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = business;
      }
    }

    if (nearest == null) {
      throw Exception('No available pet taxi business found');
    }

    return nearest;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degToRad(double degree) {
    return degree * pi / 180;
  }

  Map<String, dynamic> map(dynamic value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }

    return <String, dynamic>{};
  }

  String firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }
}
