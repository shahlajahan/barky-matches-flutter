import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;

class PetTaxiLocationPoint {
  final String formattedAddress;
  final double lat;
  final double lng;

  const PetTaxiLocationPoint({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toMap() {
    return {'formattedAddress': formattedAddress, 'lat': lat, 'lng': lng};
  }
}

class PetTaxiRouteEstimate {
  final double distanceKm;
  final int durationMinutes;
  final String source;
  final String? encodedPolyline;

  const PetTaxiRouteEstimate({
    required this.distanceKm,
    required this.durationMinutes,
    required this.source,
    this.encodedPolyline,
  });

  Map<String, dynamic> toMap() {
    return {
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'source': source,
      'encodedPolyline': encodedPolyline,
    };
  }
}

class PetTaxiLocationSearchService {
  const PetTaxiLocationSearchService();

  Future<List<PetTaxiLocationPoint>> searchLocations(
    String query, {
    String city = 'Istanbul',
    String country = 'Turkey',
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 4) return const [];

    // TODO: Replace geocoding search with Google Places Autocomplete filtered
    // by configured country/admin region.
    final locations = await geocoding.locationFromAddress(
      '$trimmed, $city, $country',
    );

    final results = <PetTaxiLocationPoint>[];
    for (final location in locations.take(5)) {
      final address = await reverseGeocode(
        location.latitude,
        location.longitude,
      );
      results.add(
        PetTaxiLocationPoint(
          formattedAddress: address,
          lat: location.latitude,
          lng: location.longitude,
        ),
      );
    }
    return results;
  }

  Future<String> reverseGeocode(double lat, double lng) async {
    final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) {
      return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }

    final place = placemarks.first;
    final parts =
        [
              place.street,
              place.subLocality,
              place.locality,
              place.administrativeArea,
              place.country,
            ]
            .where((part) => part != null && part.trim().isNotEmpty)
            .map((part) => part!.trim())
            .toList();

    if (parts.isEmpty) {
      return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }
    return parts.join(', ');
  }
}

class PetTaxiRouteService {
  // Temporary: reuse the existing Maps key already configured in
  // lib/config/api_keys.dart and ios/Runner/AppDelegate.swift.
  static const String _googleDirectionsApiKey =
      'AIzaSyCN_Y8FNV_XI7Ru4S4UKKckrBi7HkI-GcY';

  const PetTaxiRouteService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<PetTaxiRouteEstimate> estimateDrivingRoute({
    required PetTaxiLocationPoint pickup,
    required PetTaxiLocationPoint dropoff,
  }) async {
    const apiKey = _googleDirectionsApiKey;
    if (apiKey.isEmpty) {
      throw StateError(
        'Google Directions API key is missing in PetTaxiRouteService.',
      );
    }

    // TODO: Move Google Directions calls behind a callable Cloud Function when
    // API keys are server-managed.
    // TODO: Extend request options for realtime traffic, toll/bridge detection,
    // airport detection, saved addresses, and route preview polylines.
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${pickup.lat},${pickup.lng}',
      'destination': '${dropoff.lat},${dropoff.lng}',
      'mode': 'driving',
      'region': 'tr',
      'language': 'tr',
      'units': 'metric',
      'alternatives': 'false',
      'key': apiKey,
    });
    final safeUri = uri.replace(
      queryParameters: {...uri.queryParameters, 'key': _maskedApiKey(apiKey)},
    );

    debugPrint('PetTaxiRouteService route request started');
    debugPrint(
      'PetTaxiRouteService pickup=${pickup.lat},${pickup.lng} dropoff=${dropoff.lat},${dropoff.lng}',
    );
    debugPrint('PetTaxiRouteService requestUrl=$safeUri');

    final client = _client ?? http.Client();
    try {
      final response = await client.get(uri);
      debugPrint('PetTaxiRouteService httpStatus=${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('PetTaxiRouteService responseBody=${response.body}');
        throw StateError(
          'Google Directions route request failed with HTTP ${response.statusCode}. Body: ${response.body}',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status']?.toString() ?? 'UNKNOWN';
      debugPrint('PetTaxiRouteService apiStatus=$status');
      if (status != 'OK') {
        final message = body['error_message']?.toString();
        debugPrint('PetTaxiRouteService apiError=${message ?? status}');
        debugPrint('PetTaxiRouteService responseBody=${response.body}');
        throw StateError(
          'Google Directions API failed with status $status${message == null ? '' : ': $message'}. Body: ${response.body}',
        );
      }

      final routes = body['routes'];
      if (routes is! List || routes.isEmpty) {
        debugPrint('PetTaxiRouteService responseBody=${response.body}');
        throw StateError('Google Directions returned no driving route.');
      }

      final route = Map<String, dynamic>.from(routes.first as Map);
      final legs = route['legs'];
      if (legs is! List || legs.isEmpty) {
        debugPrint('PetTaxiRouteService responseBody=${response.body}');
        throw StateError('Google Directions route has no distance legs.');
      }

      var distanceMeters = 0;
      var durationSeconds = 0;
      for (final leg in legs) {
        final data = Map<String, dynamic>.from(leg as Map);
        distanceMeters += _intValue(data['distance']);
        durationSeconds += _intValue(data['duration']);
      }

      if (distanceMeters <= 0 || durationSeconds <= 0) {
        debugPrint('PetTaxiRouteService responseBody=${response.body}');
        throw StateError(
          'Google Directions route distance or duration is missing. distanceMeters=$distanceMeters durationSeconds=$durationSeconds',
        );
      }

      final polyline = route['overview_polyline'];
      final estimate = PetTaxiRouteEstimate(
        distanceKm: double.parse((distanceMeters / 1000).toStringAsFixed(2)),
        durationMinutes: (durationSeconds / 60).ceil(),
        source: 'google_directions_driving',
        encodedPolyline: polyline is Map
            ? polyline['points']?.toString()
            : null,
      );
      debugPrint(
        'PetTaxiRouteService decoded distanceKm=${estimate.distanceKm} durationMinutes=${estimate.durationMinutes} polyline=${estimate.encodedPolyline == null ? 'none' : 'present'}',
      );
      return estimate;
    } catch (e) {
      debugPrint('PetTaxi route estimate error: ${e.toString()}');
      rethrow;
    } finally {
      if (_client == null) client.close();
    }
  }

  int _intValue(dynamic value) {
    if (value is Map && value['value'] is num) {
      return (value['value'] as num).round();
    }
    return 0;
  }

  String _maskedApiKey(String key) {
    if (key.length <= 8) return '***';
    return '${key.substring(0, 6)}...${key.substring(key.length - 4)}';
  }
}
