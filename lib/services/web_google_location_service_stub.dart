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
  }) {
    throw UnsupportedError('Google Maps JavaScript is available on Web only.');
  }

  Future<WebGoogleLocation?> placeDetails(
    String placeId, {
    required String sessionToken,
  }) {
    throw UnsupportedError('Google Maps JavaScript is available on Web only.');
  }

  Future<WebGoogleLocation?> reverseGeocode(double latitude, double longitude) {
    throw UnsupportedError('Google Maps JavaScript is available on Web only.');
  }
}
