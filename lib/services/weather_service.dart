import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String _apiKey =
      "edc4f78344c135028697b9f4afa4df81"; // 🔥 اینو بذار
  static const String _baseUrl =
      "https://api.openweathermap.org/data/2.5/weather";

  static Future<double?> getTemperature({
    required double lat,
    required double lon,
  }) async {
    try {
      final url = "$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['main']['temp'] as num).toDouble();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
