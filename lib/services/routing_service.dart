import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteStep {
  final String instruction;
  final double distance;
  final double duration;
  final String modifier;
  final String type;
  final LatLng? location;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.modifier,
    required this.type,
    this.location,
  });
}

class RouteDetails {
  final List<LatLng> points;
  final double distanceInMeters;
  final double durationInSeconds;
  final List<RouteStep> steps;

  RouteDetails({
    required this.points,
    required this.distanceInMeters,
    required this.durationInSeconds,
    required this.steps,
  });

  String get formattedDistance {
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceInMeters.round()} m';
  }

  String get formattedDuration {
    final minutes = (durationInSeconds / 60).round();
    if (minutes < 1) return '1 min';
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      return '${hours}h ${remainingMins}m';
    }
    return '$minutes mins';
  }
}

class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  /// Fetches real road driving directions between start and end coordinates via OSRM
  Future<RouteDetails?> fetchRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          final List<LatLng> points = coordinates.map((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

          final double distance = (route['distance'] as num).toDouble();
          final double duration = (route['duration'] as num).toDouble();

          final List<RouteStep> steps = [];
          if (route['legs'] != null && (route['legs'] as List).isNotEmpty) {
            final leg = route['legs'][0];
            if (leg['steps'] != null) {
              for (var s in leg['steps']) {
                final maneuver = s['maneuver'] ?? {};
                final stepName = s['name'] ?? '';
                final type = maneuver['type'] ?? 'turn';
                final modifier = maneuver['modifier'] ?? '';

                LatLng? stepLocation;
                if (maneuver['location'] != null && (maneuver['location'] as List).length >= 2) {
                  stepLocation = LatLng(
                    (maneuver['location'][1] as num).toDouble(),
                    (maneuver['location'][0] as num).toDouble(),
                  );
                }

                final instruction = _formatInstruction(type, modifier, stepName);

                steps.add(RouteStep(
                  instruction: instruction,
                  distance: (s['distance'] as num?)?.toDouble() ?? 0.0,
                  duration: (s['duration'] as num?)?.toDouble() ?? 0.0,
                  modifier: modifier,
                  type: type,
                  location: stepLocation,
                ));
              }
            }
          }

          return RouteDetails(
            points: points,
            distanceInMeters: distance,
            durationInSeconds: duration,
            steps: steps,
          );
        }
      }
    } catch (_) {
      // Fallback below
    }

    return _buildFallbackRoute(start, end);
  }

  /// Calculates the shortest distance in meters from the user position to the route polyline
  double distanceToRoute(LatLng userPos, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return double.infinity;
    const distanceCalc = Distance();
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, userPos, routePoints[i]);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  /// Checks whether the user is off-route beyond a threshold (default 40 meters)
  bool isOffRoute(LatLng userPos, List<LatLng> routePoints, {double thresholdMeters = 40.0}) {
    return distanceToRoute(userPos, routePoints) > thresholdMeters;
  }

  /// Finds the index of the closest point along the route
  int getNearestRoutePointIndex(LatLng userPos, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return 0;
    const distanceCalc = Distance();
    double minDistance = double.infinity;
    int nearestIndex = 0;

    for (int i = 0; i < routePoints.length; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, userPos, routePoints[i]);
      if (d < minDistance) {
        minDistance = d;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  /// Calculates bearing in degrees between two coordinates
  double calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * pi / 180;
    final startLng = start.longitude * pi / 180;
    final endLat = end.latitude * pi / 180;
    final endLng = end.longitude * pi / 180;

    final dLng = endLng - startLng;
    final y = sin(dLng) * cos(endLat);
    final x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLng);
    final rad = atan2(y, x);
    final deg = rad * 180 / pi;
    return (deg + 360) % 360;
  }

  String _formatInstruction(String type, String modifier, String name) {
    final street = name.isNotEmpty ? ' onto $name' : '';
    if (type == 'depart') return 'Head towards destination$street';
    if (type == 'arrive') return 'Arrive at destination';
    if (modifier.isNotEmpty) {
      final modFormatted = modifier.replaceAll('_', ' ');
      final capitalized = modFormatted.isNotEmpty
          ? '${modFormatted[0].toUpperCase()}${modFormatted.substring(1)}'
          : modFormatted;
      return '$capitalized$street';
    }
    final typeCap = type.isNotEmpty ? '${type[0].toUpperCase()}${type.substring(1)}' : type;
    return '$typeCap$street';
  }

  RouteDetails _buildFallbackRoute(LatLng start, LatLng end) {
    final List<LatLng> points = [
      start,
      LatLng(
        start.latitude + (end.latitude - start.latitude) * 0.25,
        start.longitude + (end.longitude - start.longitude) * 0.2,
      ),
      LatLng(
        start.latitude + (end.latitude - start.latitude) * 0.5,
        start.longitude + (end.longitude - start.longitude) * 0.55,
      ),
      LatLng(
        start.latitude + (end.latitude - start.latitude) * 0.75,
        start.longitude + (end.longitude - start.longitude) * 0.8,
      ),
      end,
    ];

    final distanceMeters = const Distance().as(LengthUnit.Meter, start, end) * 1.25;
    final durationSeconds = (distanceMeters / 8.33);

    return RouteDetails(
      points: points,
      distanceInMeters: distanceMeters,
      durationInSeconds: durationSeconds,
      steps: [
        RouteStep(
          instruction: 'Proceed along route towards destination',
          distance: distanceMeters,
          duration: durationSeconds,
          modifier: 'straight',
          type: 'depart',
          location: start,
        ),
        RouteStep(
          instruction: 'Arrive at destination',
          distance: 0,
          duration: 0,
          modifier: '',
          type: 'arrive',
          location: end,
        ),
      ],
    );
  }
}
