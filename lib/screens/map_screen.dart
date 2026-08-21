import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/spot_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import 'spot_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final Spot? initialNavigateSpot;

  const MapScreen({super.key, this.initialNavigateSpot});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  static const LatLng _initialCenter = LatLng(16.5062, 80.6480); // Vijayawada / AP Heritage

  // Navigation State
  Spot? _activeNavSpot;
  RouteDetails? _activeRoute;
  bool _isCalculatingRoute = false;
  bool _isRerouting = false;
  bool _isFollowingUser = true;
  bool _voiceGuidanceEnabled = true;

  LatLng? _currentUserLatLng;
  double _currentHeading = 0.0; // in degrees
  double _currentSpeedKmH = 0.0;
  StreamSubscription<Position>? _positionStreamSub;
  int _currentStepIndex = 0;
  DateTime _lastRerouteTime = DateTime.now().subtract(const Duration(seconds: 10));

  // The RAW, most recent GPS fix — used for logic that needs ground
  // truth (off-route detection, arrival checks, distance-to-next-step).
  // Kept separate from what's actually drawn on screen (below), so
  // animating the visuals never introduces lag into navigation logic.
  DateTime? _lastGpsFixTime;

  // The DISPLAYED marker/camera position — dead-reckoned (interpolated)
  // between the last two GPS fixes over the real time gap between
  // them, so the dot glides continuously at roughly true speed
  // instead of teleporting once per fix and sitting still in between.
  LatLng? _displayedUserLatLng;
  double _displayedHeading = 0.0;

  // Reused across every GPS tick during live-follow tracking, instead
  // of creating a fresh AnimationController per update (which was
  // both wasteful and could overlap/stutter). Kept short (200ms,
  // linear) so back-to-back GPS updates read as one continuous glide
  // rather than a series of small eased hops.
  late final AnimationController _followController;

  @override
  void initState() {
    super.initState();
    _followController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _initLocation();

    if (widget.initialNavigateSpot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startInAppNavigation(widget.initialNavigateSpot!);
      });
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _followController.dispose();
    super.dispose();
  }

  /// Dead-reckoning glide: interpolates the DISPLAYED user position
  /// (marker + camera, if following) from wherever it currently sits
  /// to the new GPS fix, over the actual real-world time gap since
  /// the previous fix — not a fixed short animation. This is what
  /// makes the dot appear to move continuously "parallel" to the
  /// user's real walking/driving pace, arriving at the new fix right
  /// as the next one comes in, instead of teleporting + freezing.
  void _glideDisplayedPositionTo(LatLng target, double targetHeading, Duration duration) {
    final start = _displayedUserLatLng ?? target;
    final startHeading = _displayedHeading;

    // Shortest-path heading interpolation so a turn from 350° to 10°
    // sweeps 20° forward, not the long way around through 180°.
    double headingDelta = targetHeading - startHeading;
    headingDelta = ((headingDelta + 180) % 360) - 180;

    _followController.stop();
    _followController.duration = duration;
    _followController.reset();

    final latTween = Tween<double>(begin: start.latitude, end: target.latitude);
    final lngTween = Tween<double>(begin: start.longitude, end: target.longitude);

    void listener() {
      final t = _followController.value;
      final lat = latTween.transform(t);
      final lng = lngTween.transform(t);
      final heading = startHeading + headingDelta * t;
      final displayed = LatLng(lat, lng);

      setState(() {
        _displayedUserLatLng = displayed;
        _displayedHeading = heading;
      });

      // Camera rides along with the same interpolated position every
      // frame, so marker and camera never drift out of sync with
      // each other.
      if (_isFollowingUser && _activeNavSpot != null) {
        _mapController.move(
          displayed,
          _mapController.camera.zoom < 14.5 ? 15.5 : _mapController.camera.zoom,
        );
      }
    }

    _followController.addListener(listener);
    _followController.forward().whenCompleteOrCancel(() {
      _followController.removeListener(listener);
    });
  }

  /// Butter-smooth Google Maps-like 60fps animated camera transitions
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );

    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService().fetchUserLocation();
    if (!mounted) return;
    if (pos != null) {
      final userPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentUserLatLng = userPos;
        _displayedUserLatLng = userPos;
        if (pos.heading > 0) {
          _currentHeading = pos.heading;
          _displayedHeading = pos.heading;
        }
      });
      if (_activeNavSpot == null) {
        _animatedMapMove(userPos, 13.5);
      }
    }
  }

  void _startInAppNavigation(Spot spot) async {
    setState(() {
      _activeNavSpot = spot;
      _isCalculatingRoute = true;
      _isFollowingUser = true;
      _currentStepIndex = 0;
    });

    Position? pos = LocationService().currentPosition;
    pos ??= await LocationService().fetchUserLocation();

    final userLat = pos?.latitude ?? LocationService.defaultLat;
    final userLng = pos?.longitude ?? LocationService.defaultLng;
    final startLatLng = LatLng(userLat, userLng);
    final destLatLng = LatLng(spot.lat, spot.lng);

    setState(() {
      _currentUserLatLng = startLatLng;
      _displayedUserLatLng = startLatLng;
      if (pos != null && pos.heading > 0) {
        _currentHeading = pos.heading;
        _displayedHeading = pos.heading;
      }
    });

    final route = await RoutingService().fetchRoute(
      start: startLatLng,
      end: destLatLng,
    );

    if (!mounted) return;

    setState(() {
      _activeRoute = route;
      _isCalculatingRoute = false;
    });

    if (route != null && route.points.isNotEmpty) {
      _fitMapToRoute(route.points);
    }

    _startLiveNavigationTracking();
  }

  /// Live GPS streaming with off-route detection and dynamic step progression
  void _startLiveNavigationTracking() {
    _positionStreamSub?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // Update every 3 meters movement
    );

    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
      if (!mounted) return;

      final newLatLng = LatLng(pos.latitude, pos.longitude);
      final speedKmH = pos.speed > 0 ? (pos.speed * 3.6) : 0.0;

      // Calculate bearing
      double heading = _currentHeading;
      if (pos.heading > 0) {
        heading = pos.heading;
      } else if (_currentUserLatLng != null) {
        heading = RoutingService().calculateBearing(_currentUserLatLng!, newLatLng);
      }

      // Raw ground-truth state updates immediately — navigation logic
      // (off-route detection, arrival, distance-to-step) always reads
      // the true fix, never the animated/interpolated one.
      setState(() {
        _currentUserLatLng = newLatLng;
        _currentHeading = heading;
        _currentSpeedKmH = speedKmH;
      });

      // Glide the DISPLAYED marker/camera position across the real
      // time gap since the last fix, so motion reads as continuous
      // rather than "teleport, then freeze for ~2s, repeat."  Clamped
      // so a very first fix or a long GPS dropout doesn't produce an
      // absurdly slow or instant glide.
      final now = DateTime.now();
      final rawGap = _lastGpsFixTime == null ? const Duration(milliseconds: 800) : now.difference(_lastGpsFixTime!);
      final clampedGap = rawGap < const Duration(milliseconds: 300)
          ? const Duration(milliseconds: 300)
          : (rawGap > const Duration(seconds: 4) ? const Duration(seconds: 4) : rawGap);
      _lastGpsFixTime = now;
      _glideDisplayedPositionTo(newLatLng, heading, clampedGap);

      // If active navigation mode, handle dynamic routing & step progression
      if (_activeNavSpot != null && _activeRoute != null) {
        _handleDynamicLocationProgress(newLatLng);
      }
    });
  }

  /// Dynamic off-route recalculation & turn instruction advancement
  void _handleDynamicLocationProgress(LatLng userPos) async {
    if (_activeNavSpot == null || _activeRoute == null) return;

    final destLatLng = LatLng(_activeNavSpot!.lat, _activeNavSpot!.lng);
    const distanceCalc = Distance();

    // 1. Check if user has arrived at destination
    final distToDest = distanceCalc.as(LengthUnit.Meter, userPos, destLatLng);
    if (distToDest < 25) {
      if (_voiceGuidanceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D9488),
            content: Text('🎉 You have arrived at ${_activeNavSpot!.name}!'),
          ),
        );
      }
      return;
    }

    // 2. Off-Route Detection (> 45 meters off route path)
    final isOffTrack = RoutingService().isOffRoute(userPos, _activeRoute!.points, thresholdMeters: 45.0);
    final now = DateTime.now();

    if (isOffTrack && now.difference(_lastRerouteTime).inSeconds >= 4 && !_isRerouting) {
      _lastRerouteTime = now;
      setState(() => _isRerouting = true);

      final newRoute = await RoutingService().fetchRoute(start: userPos, end: destLatLng);
      if (!mounted) return;

      if (newRoute != null) {
        setState(() {
          _activeRoute = newRoute;
          _isRerouting = false;
          _currentStepIndex = 0;
        });

        if (_voiceGuidanceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF1E1B4B),
              content: Row(
                children: [
                  Icon(Icons.alt_route_rounded, color: Colors.tealAccent, size: 20),
                  SizedBox(width: 10),
                  Text('Route updated based on your location'),
                ],
              ),
            ),
          );
        }
      } else {
        setState(() => _isRerouting = false);
      }
      return;
    }

    // 3. Advance to Next Step when approaching maneuver point
    if (_activeRoute!.steps.isNotEmpty && _currentStepIndex < _activeRoute!.steps.length - 1) {
      final currentStep = _activeRoute!.steps[_currentStepIndex];
      if (currentStep.location != null) {
        final distToManeuver = distanceCalc.as(LengthUnit.Meter, userPos, currentStep.location!);
        if (distToManeuver < 30) {
          setState(() {
            _currentStepIndex++;
          });
        }
      }
    }
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (points.isEmpty) return;

    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            top: 140,
            bottom: 180,
            left: 45,
            right: 45,
          ),
        ),
      );
    } catch (_) {
      _animatedMapMove(points.first, 14.0);
    }
  }

  void _stopInAppNavigation() {
    _positionStreamSub?.cancel();
    setState(() {
      _activeNavSpot = null;
      _activeRoute = null;
      _isCalculatingRoute = false;
      _isRerouting = false;
      _isFollowingUser = false;
      _currentStepIndex = 0;
    });

    if (_currentUserLatLng != null) {
      _animatedMapMove(_currentUserLatLng!, 13.5);
    }
  }

  void _recenterOnUser() {
    if (_currentUserLatLng != null) {
      setState(() => _isFollowingUser = true);
      _animatedMapMove(_currentUserLatLng!, 16.0);
    }
  }

  String _getDistanceToNextStep(LatLng userPos) {
    if (_activeRoute == null || _activeRoute!.steps.isEmpty) return '';
    final step = _activeRoute!.steps[_currentStepIndex];
    if (step.location == null) return _activeRoute!.formattedDistance;

    const distanceCalc = Distance();
    final d = distanceCalc.as(LengthUnit.Meter, userPos, step.location!);
    if (d >= 1000) {
      return 'In ${(d / 1000).toStringAsFixed(1)} km';
    }
    return 'In ${d.round()} m';
  }

  List<Marker> _buildMarkers(List<Spot> spots) {
    final List<Marker> markers = [];

    // 1. Google Maps-style Directional Navigation Puck — renders the
    // interpolated DISPLAYED position (continuous glide), not the raw
    // GPS fix (which would still snap once per update).
    final userPos = _displayedUserLatLng ??
        _currentUserLatLng ??
        (LocationService().currentPosition != null
            ? LatLng(LocationService().currentPosition!.latitude, LocationService().currentPosition!.longitude)
            : null);

    if (userPos != null) {
      markers.add(
        Marker(
          point: userPos,
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Pulsing Accuracy Halo
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
              ),
              // Direction Chevron Puck
              Transform.rotate(
                angle: _displayedHeading * (pi / 180),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.navigation,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Destination & Heritage Landmark Markers
    for (var spot in spots) {
      final isNavigatingToThis = _activeNavSpot?.id == spot.id;

      markers.add(
        Marker(
          point: LatLng(spot.lat, spot.lng),
          width: isNavigatingToThis ? 62 : 46,
          height: isNavigatingToThis ? 62 : 46,
          child: GestureDetector(
            onTap: () {
              if (_activeNavSpot == null) {
                _showSpotBottomSheet(spot);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isNavigatingToThis ? const Color(0xFFE11D48) : const Color(0xFF0D9488),
                shape: BoxShape.circle,
                border: isNavigatingToThis ? Border.all(color: Colors.white, width: 3.5) : null,
                boxShadow: [
                  BoxShadow(
                    color: isNavigatingToThis
                        ? const Color(0xFFE11D48).withValues(alpha: 0.55)
                        : Colors.black38,
                    blurRadius: isNavigatingToThis ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                isNavigatingToThis ? Icons.flag_rounded : Icons.location_on_rounded,
                color: Colors.white,
                size: isNavigatingToThis ? 34 : 26,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  void _showSpotBottomSheet(Spot spot) {
    final distanceStr = LocationService().calculateFormattedDistance(spot.lat, spot.lng);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: spot.imageUrl,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => Container(color: Colors.grey.shade200),
                      errorWidget: (ctx, url, err) => Container(color: Colors.teal.shade100),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            spot.category.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF0D9488),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          spot.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1B4B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.navigation_rounded, size: 14, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            Text(
                              distanceStr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              spot.rating.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Text(
                spot.shortDescription,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF0D9488)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SpotDetailScreen(spot: spot)),
                        );
                      },
                      child: const Text(
                        'View Details',
                        style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Start Navigation', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startInAppNavigation(spot);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getStepIcon(String? modifier, String? type) {
    if (type == 'arrive') return Icons.flag_rounded;
    if (modifier == null) return Icons.straight_rounded;
    if (modifier.contains('left')) return Icons.turn_left_rounded;
    if (modifier.contains('right')) return Icons.turn_right_rounded;
    if (modifier.contains('u-turn') || modifier.contains('uturn')) return Icons.u_turn_left_rounded;
    return Icons.straight_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isNavigating = _activeNavSpot != null;

    return StreamBuilder<List<Spot>>(
      stream: FirebaseService().getSpotsStream('All Cities'),
      builder: (context, snapshot) {
        final spots = snapshot.data ?? FirebaseService.getMockSpots('All Cities');
        final markers = _buildMarkers(spots);

        return Stack(
          children: [
            // Map Canvas with pan detection
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 12.5,
                minZoom: 3.0,
                maxZoom: 18.5,
                // Full gesture set (pinch, drag, fling, rotate) — the
                // default flutter_map config only allows a subset,
                // which is what made panning/zooming feel stiffer
                // than Google Maps. This also enables inertial fling
                // scrolling, a big part of the "smooth" feel.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture && _isFollowingUser) {
                    setState(() => _isFollowingUser = false);
                  }
                },
              ),
              children: [
                TileLayer(
                  // CartoDB Voyager: CDN-backed, retina-ready basemap —
                  // noticeably faster and crisper than raw
                  // tile.openstreetmap.org, and closer to Google Maps'
                  // light, clean cartography style. Still free, no API
                  // key or billing required.
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.smart_travel_companion',
                  maxZoom: 19,
                  // Renders @2x tiles on high-DPI phones so the map
                  // doesn't look blurry next to Google Maps' native app.
                  retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
                  // Prefetches a ring of tiles just outside the
                  // viewport so panning never shows a blank/grey tile
                  // popping in — this is most of what makes Google
                  // Maps feel like it has "no loading."
                  keepBuffer: 5,
                  panBuffer: 2,
                  // Soft cross-fade instead of a hard pop when a new
                  // tile finishes loading.
                  tileDisplay: const TileDisplay.fadeIn(
                    duration: Duration(milliseconds: 250),
                  ),
                ),

                // Multi-Layer Google Maps-grade Polyline
                if (_activeRoute != null && _activeRoute!.points.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      // Outer Casing / Soft Glow Shadow
                      Polyline(
                        points: _activeRoute!.points,
                        strokeWidth: 9.0,
                        color: const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                      ),
                      // Vibrant Inner Road Line (Google Blue / Emerald Green)
                      Polyline(
                        points: _activeRoute!.points,
                        strokeWidth: 6.0,
                        color: const Color(0xFF2563EB),
                      ),
                    ],
                  ),

                // Markers Layer
                MarkerLayer(
                  markers: markers,
                ),

                // Required attribution for CartoDB/OpenStreetMap free
                // tiles. Small, unobtrusive, tucked into the corner —
                // Google Maps shows one too, just less visible.
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  popupInitialDisplayDuration: const Duration(seconds: 3),
                  attributions: [
                    TextSourceAttribution(
                      'CARTO',
                      onTap: () {},
                    ),
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),

            // ROUTE CALCULATION / REROUTING OVERLAY
            if (_isCalculatingRoute || _isRerouting)
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _isRerouting
                              ? 'Rerouting based on your live location...'
                              : 'Calculating fastest route to ${_activeNavSpot?.name ?? 'place'}...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ACTIVE IN-APP NAVIGATION TOP HUD BANNER (Google Maps style)
            if (isNavigating && _activeRoute != null && !_isCalculatingRoute)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _activeRoute!.steps.isNotEmpty
                                  ? _getStepIcon(
                                      _activeRoute!.steps[_currentStepIndex].modifier,
                                      _activeRoute!.steps[_currentStepIndex].type,
                                    )
                                  : Icons.navigation_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_currentUserLatLng != null)
                                  Text(
                                    _getDistanceToNextStep(_currentUserLatLng!),
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                Text(
                                  _activeRoute!.steps.isNotEmpty
                                      ? _activeRoute!.steps[_currentStepIndex].instruction
                                      : 'Navigate to ${_activeNavSpot!.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _activeRoute!.formattedDistance,
                                        style: const TextStyle(
                                          color: Colors.tealAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _activeRoute!.formattedDuration,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _voiceGuidanceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                  color: _voiceGuidanceEnabled ? Colors.tealAccent : Colors.white38,
                                ),
                                tooltip: 'Voice Guidance',
                                onPressed: () {
                                  setState(() => _voiceGuidanceEnabled = !_voiceGuidanceEnabled);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.zoom_out_map_rounded, color: Colors.white70, size: 20),
                                tooltip: 'Route Overview',
                                onPressed: () => _fitMapToRoute(_activeRoute!.points),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // LIVE SPEEDOMETER BADGE (When driving)
            if (isNavigating && _currentSpeedKmH > 3)
              Positioned(
                top: 155,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed_rounded, color: Color(0xFF2563EB), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentSpeedKmH.round()} km/h',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // RECENTER / FOLLOW ME BUTTON (Shows "Re-center" if user dragged map)
            Positioned(
              top: isNavigating ? 155 : 16,
              right: 16,
              child: isNavigating && !_isFollowingUser
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 5,
                      ),
                      icon: const Icon(Icons.navigation, size: 14),
                      label: const Text('Re-center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _recenterOnUser,
                    )
                  : FloatingActionButton.small(
                      heroTag: 'my_location_btn',
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E1B4B),
                      elevation: 4,
                      onPressed: _recenterOnUser,
                      child: const Icon(Icons.my_location),
                    ),
            ),

            // ACTIVE NAVIGATION BOTTOM CONTROL PANEL
            if (isNavigating && _activeNavSpot != null)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: _activeNavSpot!.imageUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _activeNavSpot!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1E1B4B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Live In-App Navigation',
                                  style: TextStyle(
                                    color: Color(0xFF059669),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Exit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: _stopInAppNavigation,
                      ),
                    ],
                  ),
                ),
              ),

            // NORMAL MODE: HORIZONTAL CARDS SWITCHER
            if (!isNavigating)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: spots.length,
                    itemBuilder: (ctx, index) {
                      final spot = spots[index];
                      final dist = LocationService().calculateFormattedDistance(spot.lat, spot.lng);
                      return Container(
                        width: 260,
                        margin: const EdgeInsets.only(right: 12),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 6,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              _animatedMapMove(
                                LatLng(spot.lat, spot.lng),
                                14.5,
                              );
                              _showSpotBottomSheet(spot);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: spot.imageUrl,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          spot.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF1E1B4B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dist,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF0D9488),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 14),
                                            const SizedBox(width: 2),
                                            Text(
                                              spot.rating.toString(),
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}