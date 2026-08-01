import 'dart:convert';
import 'dart:js_interop';

@JS('barkyGooglePlacesAutocomplete')
external JSPromise<JSString> _autocomplete(
  JSString query,
  JSString countryCode,
  JSString sessionToken,
);

@JS('barkyGooglePlaceDetails')
external JSPromise<JSString> _placeDetails(
  JSString placeId,
  JSString sessionToken,
);

@JS('barkyGoogleReverseGeocode')
external JSPromise<JSString> _reverseGeocode(
  JSNumber latitude,
  JSNumber longitude,
);

class WebGooglePlacePrediction {
  const WebGooglePlacePrediction({
    required this.placeId,
    required this.description,
  });

  final String placeId;
  final String description;
}

class WebGoogleLocation {
  const WebGoogleLocation({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.city,
    this.district,
  });

  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? city;
  final String? district;
}

class WebGoogleLocationService {
  const WebGoogleLocationService();

  Future<List<WebGooglePlacePrediction>> autocomplete(
    String query, {
    String? countryCode,
    required String sessionToken,
  }) async {
    final response = await _autocomplete(
      query.toJS,
      (countryCode ?? '').toJS,
      sessionToken.toJS,
    ).toDart;
    final decoded = jsonDecode(response.toDart);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) {
          final placeId = item['placeId']?.toString().trim() ?? '';
          final description = item['description']?.toString().trim() ?? '';
          if (placeId.isEmpty || description.isEmpty) return null;
          return WebGooglePlacePrediction(
            placeId: placeId,
            description: description,
          );
        })
        .whereType<WebGooglePlacePrediction>()
        .toList();
  }

  Future<WebGoogleLocation?> placeDetails(
    String placeId, {
    required String sessionToken,
  }) async {
    final response = await _placeDetails(
      placeId.toJS,
      sessionToken.toJS,
    ).toDart;
    return _decodeLocation(response.toDart);
  }

  Future<WebGoogleLocation?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    final response = await _reverseGeocode(
      latitude.toJS,
      longitude.toJS,
    ).toDart;
    return _decodeLocation(response.toDart);
  }

  WebGoogleLocation? _decodeLocation(String response) {
    final decoded = jsonDecode(response);
    if (decoded is! Map) return null;

    final latitude = _double(decoded['latitude']);
    final longitude = _double(decoded['longitude']);
    if (latitude == null || longitude == null) return null;

    return WebGoogleLocation(
      latitude: latitude,
      longitude: longitude,
      formattedAddress: decoded['formattedAddress']?.toString().trim() ?? '',
      city: _text(decoded['city']),
      district: _text(decoded['district']),
    );
  }

  double? _double(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
