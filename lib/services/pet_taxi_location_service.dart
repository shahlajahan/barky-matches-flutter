import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'web_google_location_service.dart';

class PetTaxiRouteUnavailableException implements Exception {
  const PetTaxiRouteUnavailableException();
}

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

typedef PetTaxiLocationSearch =
    Future<List<PetTaxiLocationPoint>> Function(String query);

class PetTaxiLocationSearchController {
  PetTaxiLocationSearchController({
    required this.search,
    this.debounceDuration = const Duration(milliseconds: 350),
  });

  final PetTaxiLocationSearch search;
  final Duration debounceDuration;
  Timer? _timer;
  int _generation = 0;

  void schedule(
    String rawQuery, {
    required void Function() onSearching,
    required void Function(List<PetTaxiLocationPoint> results) onResults,
    required void Function(Object error) onError,
    required void Function() onCleared,
  }) {
    _timer?.cancel();
    final query = rawQuery.trim();
    final generation = ++_generation;
    if (query.length < 4) {
      onCleared();
      return;
    }

    onSearching();
    _timer = Timer(debounceDuration, () {
      _run(query, generation, onResults: onResults, onError: onError);
    });
  }

  Future<void> searchNow(
    String rawQuery, {
    required void Function() onSearching,
    required void Function(List<PetTaxiLocationPoint> results) onResults,
    required void Function(Object error) onError,
    required void Function() onCleared,
  }) async {
    _timer?.cancel();
    final query = rawQuery.trim();
    final generation = ++_generation;
    if (query.length < 4) {
      onCleared();
      return;
    }

    onSearching();
    await _run(query, generation, onResults: onResults, onError: onError);
  }

  Future<void> _run(
    String query,
    int generation, {
    required void Function(List<PetTaxiLocationPoint> results) onResults,
    required void Function(Object error) onError,
  }) async {
    try {
      final results = await search(query);
      if (generation == _generation) onResults(results);
    } catch (error) {
      if (generation == _generation) onError(error);
    }
  }

  void dispose() {
    cancelPending();
  }

  void cancelPending() {
    _timer?.cancel();
    _generation++;
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
    String? country,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 4) return const [];

    if (kIsWeb) {
      return _searchWebLocations(trimmed);
    }

    final locations = await geocoding.locationFromAddress(
      country == null || country.trim().isEmpty
          ? trimmed
          : '$trimmed, ${country.trim()}',
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

  Future<List<PetTaxiLocationPoint>> _searchWebLocations(String query) async {
    const service = WebGoogleLocationService();
    final sessionToken = 'pet_taxi_${DateTime.now().microsecondsSinceEpoch}';
    final predictions = await service.autocomplete(
      query,
      countryCode: 'TR',
      sessionToken: sessionToken,
    );
    final results = <PetTaxiLocationPoint>[];
    for (final prediction in predictions.take(5)) {
      try {
        final location = await service.placeDetails(
          prediction.placeId,
          sessionToken: sessionToken,
        );
        if (location == null ||
            !location.latitude.isFinite ||
            !location.longitude.isFinite) {
          continue;
        }
        final address = location.formattedAddress.trim().isNotEmpty
            ? location.formattedAddress.trim()
            : prediction.description;
        if (address.trim().isEmpty) continue;
        results.add(
          PetTaxiLocationPoint(
            formattedAddress: address,
            lat: location.latitude,
            lng: location.longitude,
          ),
        );
      } catch (_) {
        // A single malformed Places result must not discard the search.
      }
    }
    return results;
  }

  Future<String> reverseGeocode(double lat, double lng) async {
    if (kIsWeb) {
      try {
        final result = await const WebGoogleLocationService().reverseGeocode(
          lat,
          lng,
        );
        final address = result?.formattedAddress.trim() ?? '';
        if (address.isNotEmpty) return address;
      } catch (_) {
        // Fall back to coordinates when the web geocoder has no result.
      }
      return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }
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
  const PetTaxiRouteService({FirebaseFunctions? functions})
    : _functions = functions;

  final FirebaseFunctions? _functions;

  Future<PetTaxiRouteEstimate> estimateDrivingRoute({
    required PetTaxiLocationPoint pickup,
    required PetTaxiLocationPoint dropoff,
  }) async {
    // TODO: Extend request options for realtime traffic, toll/bridge detection,
    // airport detection, saved addresses, and route preview polylines.
    debugPrint('PetTaxiRouteService route request started');
    debugPrint(
      'PetTaxiRouteService pickup=${pickup.lat},${pickup.lng} dropoff=${dropoff.lat},${dropoff.lng}',
    );

    final functions =
        _functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');
    try {
      final result = await functions
          .httpsCallable(
            'estimatePetTaxiRoute',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
          )
          .call(<String, dynamic>{
            'origin': {'lat': pickup.lat, 'lng': pickup.lng},
            'destination': {'lat': dropoff.lat, 'lng': dropoff.lng},
          });
      final data = Map<String, dynamic>.from(result.data as Map);
      final distanceKm = (data['distanceKm'] as num?)?.toDouble();
      final durationMinutes = (data['durationMinutes'] as num?)?.round();
      if (distanceKm == null ||
          durationMinutes == null ||
          !distanceKm.isFinite ||
          distanceKm <= 0 ||
          durationMinutes <= 0) {
        throw StateError(
          'Pet Taxi route function returned an invalid estimate.',
        );
      }
      final estimate = PetTaxiRouteEstimate(
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        source: data['source']?.toString() ?? 'google_directions_driving',
        encodedPolyline: data['encodedPolyline']?.toString(),
      );
      debugPrint(
        'PetTaxiRouteService decoded distanceKm=${estimate.distanceKm} durationMinutes=${estimate.durationMinutes} polyline=${estimate.encodedPolyline == null ? 'none' : 'present'}',
      );
      return estimate;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found') {
        throw const PetTaxiRouteUnavailableException();
      }
      throw StateError(
        'Pet Taxi route estimation failed: ${error.message ?? error.code}',
      );
    } catch (e) {
      debugPrint('PetTaxi route estimate error: ${e.toString()}');
      rethrow;
    }
  }
}
