import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // Default fallback center (Vijayawada) if location permission denied/disabled
  static const double defaultLat = 16.5062;
  static const double defaultLng = 80.6480;

  Future<Position?> fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _currentPosition;
    } catch (_) {
      return null;
    }
  }

  /// Returns formatted string distance e.g. "1.2 km" or "850 m"
  String calculateFormattedDistance(double targetLat, double targetLng) {
    double userLat = _currentPosition?.latitude ?? defaultLat;
    double userLng = _currentPosition?.longitude ?? defaultLng;

    double distanceInMeters = Geolocator.distanceBetween(
      userLat,
      userLng,
      targetLat,
      targetLng,
    );

    if (distanceInMeters >= 1000) {
      double km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)} km away';
    } else {
      return '${distanceInMeters.round()} m away';
    }
  }
}
