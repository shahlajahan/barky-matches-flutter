import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum PetTaxiLocationSource { currentLocation, contactLocation }

class PetTaxiResolvedLocation {
  final double lat;
  final double lng;
  final PetTaxiLocationSource source;
  final Object? updatedAt;

  const PetTaxiResolvedLocation({
    required this.lat,
    required this.lng,
    required this.source,
    this.updatedAt,
  });

  LatLng get latLng => LatLng(lat, lng);
}

class PetTaxiDriverLocationResolver {
  static const liveLocationMaxAge = Duration(minutes: 30);

  static PetTaxiResolvedLocation? resolveDisplayLocation({
    required Map<String, dynamic> taxi,
    required Map<String, dynamic> contact,
    DateTime? now,
  }) {
    final currentLocation = _map(taxi['currentLocation']);
    final fallbackLocation = _map(contact['location']);
    final resolvedNow = now ?? DateTime.now();

    final currentLat = _readDouble(currentLocation, 'lat');
    final currentLng = _readDouble(currentLocation, 'lng');
    final currentUpdatedAt = currentLocation['updatedAt'];

    if (currentLat != null &&
        currentLng != null &&
        _isFreshLiveLocation(currentUpdatedAt, resolvedNow)) {
      return PetTaxiResolvedLocation(
        lat: currentLat,
        lng: currentLng,
        source: PetTaxiLocationSource.currentLocation,
        updatedAt: currentUpdatedAt,
      );
    }

    final fallbackLat = _readDouble(fallbackLocation, 'lat');
    final fallbackLng = _readDouble(fallbackLocation, 'lng');

    if (fallbackLat == null || fallbackLng == null) {
      return null;
    }

    return PetTaxiResolvedLocation(
      lat: fallbackLat,
      lng: fallbackLng,
      source: PetTaxiLocationSource.contactLocation,
      updatedAt: fallbackLocation['updatedAt'],
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }

    if (value is GeoPoint) {
      return {'lat': value.latitude, 'lng': value.longitude};
    }

    return <String, dynamic>{};
  }

  static double? _readDouble(Map<String, dynamic> location, String key) {
    final value = location[key] ?? location[_alternateCoordinateKey(key)];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static String _alternateCoordinateKey(String key) {
    switch (key) {
      case 'lat':
        return 'latitude';
      case 'lng':
        return 'longitude';
      default:
        return key;
    }
  }

  static bool _isFreshLiveLocation(Object? updatedAt, DateTime now) {
    final updatedAtDate = _readDateTime(updatedAt);
    if (updatedAtDate == null) {
      return false;
    }

    return now.difference(updatedAtDate).abs() <= liveLocationMaxAge;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }
}
