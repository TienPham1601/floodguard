import 'dart:convert';
import 'dart:developer' as dev;
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class RouteStep {
  final String instruction;
  final double distance;
  final LatLng point;

  RouteStep({required this.instruction, required this.distance, required this.point});
}

class Destination {
  final String name;
  final LatLng pos;
  final String address;
  Destination({required this.name, required this.pos, this.address = ''});
}

class FloodPoint {
  final LatLng pos;
  final int depthCm;
  FloodPoint({required this.pos, required this.depthCm});
}

final List<FloodPoint> floodPoints = [];

class RouteResult {
  final List<LatLng> points;
  final String distanceText;
  final String durationText;
  final int distanceMeters;
  final int durationSeconds;
  final String summary;
  final List<RouteStep> steps;

  const RouteResult({
    required this.points,
    required this.distanceText,
    required this.durationText,
    required this.distanceMeters,
    required this.durationSeconds,
    this.summary = '',
    this.steps = const [],
  });
}

class RoutingService {
  static Future<RouteResult?> fetchRoute(
    LatLng origin, 
    LatLng destination, {
    List<List<LatLng>>? avoidPolygons,
  }) async {
    final url = Uri.parse('${ApiConfig.orsBaseUrl}/v2/directions/driving-car/geojson');
    
    // ORS dùng [longitude, latitude]
    final Map<String, dynamic> body = {
      "coordinates": [
        [origin.longitude, origin.latitude],
        [destination.longitude, destination.latitude]
      ],
      "instructions": "true",
      "options": {
        "avoid_polygons": avoidPolygons != null && avoidPolygons.isNotEmpty ? {
          "type": "MultiPolygon",
          "coordinates": avoidPolygons.map((p) => [p.map((pt) => [pt.longitude, pt.latitude]).toList()]).toList()
        } : null
      }
    };

    dev.log('ORS_DEBUG: Fetching route from $origin to $destination');
    if (avoidPolygons != null && avoidPolygons.isNotEmpty) {
      dev.log('ORS_DEBUG: Avoiding ${avoidPolygons.length} polygons');
    }

    try {
      final res = await http.post(
        url,
        headers: {
          'Authorization': ApiConfig.orsApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 12));

      dev.log('ORS_DEBUG: Status ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final feature = data['features'][0];
        final geometry = feature['geometry']['coordinates'] as List;
        final props = feature['properties']['segments'][0];
        
        final List<RouteStep> routeSteps = [];
        final List stepsData = props['steps'];
        for (var s in stepsData) {
          final waypoints = s['way_points'] as List;
          final pointIdx = waypoints[0] as int;
          final coord = geometry[pointIdx];
          routeSteps.add(RouteStep(
            instruction: s['instruction'],
            distance: (s['distance'] as num).toDouble(),
            point: LatLng(coord[1], coord[0]),
          ));
        }

        final points = geometry.map((c) => LatLng(c[1], c[0])).toList();
        dev.log('ORS_DEBUG: Success, drawn ${points.length} points');

        return RouteResult(
          points: points,
          distanceText: _formatDistance(props['distance'].round()),
          durationText: _formatDuration(props['duration'].round()),
          distanceMeters: props['distance'].round(),
          durationSeconds: props['duration'].round(),
          steps: routeSteps,
          summary: '',
        );
      } else {
        dev.log('ORS_DEBUG: Error response: ${res.body}');
        // Nếu lỗi do avoid_polygons quá lớn, thử lại không có avoid
        if (avoidPolygons != null && avoidPolygons.isNotEmpty) {
          dev.log('ORS_DEBUG: Retrying without avoid_polygons...');
          return fetchRoute(origin, destination);
        }
      }
    } catch (e) {
      dev.log('ORS_DEBUG: Critical Error: $e');
    }

    dev.log('ORS_DEBUG: Falling back to OSRM...');
    return _fetchFallbackOSRM(origin, destination);
  }

  static Future<List<RouteResult>> fetchRoutes(LatLng origin, LatLng destination) async {
    final r = await fetchRoute(origin, destination);
    return r != null ? [r] : [];
  }

  static Future<RouteResult?> _fetchFallbackOSRM(LatLng origin, LatLng destination) async {
    final String urlCoords = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$urlCoords?overview=full&geometries=polyline&steps=true');

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['code'] == 'Ok') {
          final route = data['routes'][0];
          final List<LatLng> points = decodePolyline(route['geometry']);
          
          final List<RouteStep> routeSteps = [];
          for (var leg in route['legs']) {
            for (var step in leg['steps']) {
              final loc = step['maneuver']['location'] as List;
              routeSteps.add(RouteStep(
                instruction: step['maneuver']['instruction'] ?? 'Đi thẳng',
                distance: (step['distance'] as num).toDouble(),
                point: LatLng(loc[1], loc[0]),
              ));
            }
          }

          return RouteResult(
            points: points,
            distanceText: _formatDistance(route['distance'].round()),
            durationText: _formatDuration(route['duration'].round()),
            distanceMeters: route['distance'].round(),
            durationSeconds: route['duration'].round(),
            steps: routeSteps,
            summary: route['summary'] ?? '',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static String _formatDistance(int meters) =>
      meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1)} km';

  static String _formatDuration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes phút';
    final int rest = minutes % 60;
    return '${minutes ~/ 60} giờ $rest phút';
  }

  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int result = 0, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
