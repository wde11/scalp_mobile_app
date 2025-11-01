import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DirectionsService {
  // Get API key from environment variable (secure)
  static String get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  final PolylinePoints _polylinePoints = PolylinePoints();

  Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (_apiKey.isEmpty) {
      print('ERROR: Google Maps API key not found in .env file');
      return null;
    }

    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final polylineString = route['overview_polyline']['points'];
          final duration = route['legs'][0]['duration']['text'];
          final distance = route['legs'][0]['distance']['text'];

          // Decode polyline points
          List<PointLatLng> result = _polylinePoints.decodePolyline(polylineString);
          List<LatLng> polylineCoordinates = result
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          return {
            'polylineCoordinates': polylineCoordinates,
            'duration': duration,
            'distance': distance,
            'startAddress': route['legs'][0]['start_address'],
            'endAddress': route['legs'][0]['end_address'],
          };
        } else {
          print('Directions API error: ${data['status']}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting directions: $e');
    }

    return null;
  }

  // Alternative method using flutter_polyline_points plugin directly
  Future<List<LatLng>?> getPolylinePoints({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (_apiKey.isEmpty) {
      print('ERROR: Google Maps API key not found in .env file');
      return null;
    }

    try {
      PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: _apiKey,
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        return result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      }
    } catch (e) {
      print('Error getting polyline: $e');
    }

    return null;
  }
}
