import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../../../core/config/app_config.dart';
import '../../../../core/map/geocoding_service.dart';
import '../../../../core/map/interactive_destination_marker.dart';
import '../../../../core/map/map_style_cache.dart';
import '../../../../core/map/map_navigation_banner.dart';
import '../../../../core/map/offline_map.dart';
import '../../../../core/map/rapigo_map_runtime.dart';
import '../../../../core/map/route_service.dart';
import '../../maps/services/map_viewport_cache.dart';
import '../../maps/services/network_status_service.dart';

class PotosiMapDriverMarker {
  const PotosiMapDriverMarker({
    required this.point,
    this.driverId,
    this.vehicleType,
    this.isHighlighted = false,
  });

  final LatLng point;
  final String? driverId;
  final String? vehicleType;
  final bool isHighlighted;
}

class PotosiMapSurface extends ConsumerStatefulWidget {
  const PotosiMapSurface({
    super.key,
    required this.drivers,
    required this.userLocation,
    this.userAccuracyMeters,
    this.userHeadingDegrees,
    this.routeStart,
    this.routeTarget,
    this.secondaryMarker,
    this.showRoute = false,
    this.showTargetMarker = true,
    this.routeColor = const Color(0xFF2979FF),
    this.focusBounds,
    this.focusPadding = const EdgeInsets.fromLTRB(56, 120, 56, 220),
    this.focusSignal = 0,
    this.onRouteUpdated,
    this.onMapTap,
    this.showTargetEditBadge = false,
    this.onMapCenterChanged,
    this.cameraCenterTarget,
    this.cameraCenterSignal = 0,
    this.zoomActionSignal = 0,
    this.zoomActionDelta = 0,
    this.showUtilityControls = true,
    this.showLiveNavigationMode = false,
    this.userMarkerAccentColor = const Color(0xFF0F6CBD),
    this.userMarkerHaloColor = const Color(0xFF0F6CBD),
    this.userMarkerBorderColor = const Color(0xFFD7E6FB),
    this.viewportCacheKey,
  });

  final List<PotosiMapDriverMarker> drivers;
  final LatLng userLocation;
  final double? userAccuracyMeters;
  final double? userHeadingDegrees;
  final LatLng? routeStart;
  final LatLng? routeTarget;
  final LatLng? secondaryMarker;
  final bool showRoute;
  final bool showTargetMarker;
  final Color routeColor;
  final LatLngBounds? focusBounds;
  final EdgeInsets focusPadding;
  final int focusSignal;
  final VoidCallback? onRouteUpdated;
  final ValueChanged<LatLng>? onMapTap;
  final bool showTargetEditBadge;
  final void Function(LatLng center, bool hasGesture)? onMapCenterChanged;
  final LatLng? cameraCenterTarget;
  final int cameraCenterSignal;
  final int zoomActionSignal;
  final double zoomActionDelta;
  final bool showUtilityControls;
  final bool showLiveNavigationMode;
  final Color userMarkerAccentColor;
  final Color userMarkerHaloColor;
  final Color userMarkerBorderColor;
  final String? viewportCacheKey;

  @override
  ConsumerState<PotosiMapSurface> createState() => _PotosiMapSurfaceState();
}

class _PotosiMapSurfaceState extends ConsumerState<PotosiMapSurface>
    with AutomaticKeepAliveClientMixin {
  CachedMapViewport? _cachedViewport;
  bool _mapLoadFailed = false;
  bool _offlinePrepared = false;
  bool _vectorReady = false;
  bool _viewportResolved = false;

  @override
  bool get wantKeepAlive => true;

  bool get _supportsVectorMode => true;
  MapViewportCache get _viewportCache =>
      MapViewportCache(namespace: widget.viewportCacheKey);

  @override
  void initState() {
    super.initState();
    _restoreCachedViewport();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _offlinePrepared) {
        return;
      }
      _offlinePrepared = true;
      Future<void>.microtask(() async {
        await ref.read(networkStatusProvider.notifier).startMonitoring();
        await ref.read(offlineMapProvider.notifier).ensureOfflineAvailability();
      });
    });
  }

  Future<void> _restoreCachedViewport() async {
    final viewport = await _viewportCache.read();
    if (!mounted) {
      return;
    }
    setState(() {
      _cachedViewport = viewport;
      _viewportResolved = true;
    });
  }

  LatLng get _fallbackCenter => _cachedViewport != null
      ? LatLng(_cachedViewport!.centerLat, _cachedViewport!.centerLng)
      : (widget.routeStart ?? widget.userLocation);

  double get _fallbackZoom =>
      (_cachedViewport?.zoom ?? AppConfig.mapInitialZoom)
          .clamp(AppConfig.mapMinZoom, AppConfig.mapMaxZoom)
          .toDouble();

  double get _fallbackBearing => 0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final runtime = ref.watch(rapigoMapRuntimeProvider);
    final offlineState = ref.watch(offlineMapProvider);
    final shouldUseMapLibre =
        runtime.shouldUseMapLibre && !_mapLoadFailed && _supportsVectorMode;
    final canBuildMap = _viewportResolved;

    if (shouldUseMapLibre) {
      return Stack(
        children: [
          if (!_vectorReady || _mapLoadFailed)
            Positioned.fill(
              child: _RapigoPassengerMapLoadingSurface(
                offlineReady: offlineState.isReady,
              ),
            ),
          if (canBuildMap)
            Positioned.fill(
              child: AnimatedScale(
                scale: _vectorReady ? 1 : 1.02,
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _vectorReady ? 1 : 0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: _PotosiMapLibreView(
                    drivers: widget.drivers,
                    userLocation: widget.userLocation,
                    userAccuracyMeters: widget.userAccuracyMeters,
                    userHeadingDegrees: widget.userHeadingDegrees,
                    routeStart: widget.routeStart,
                    routeTarget: widget.routeTarget,
                    secondaryMarker: widget.secondaryMarker,
                    showRoute: widget.showRoute,
                    showTargetMarker: widget.showTargetMarker,
                    routeColor: runtime.style.route,
                    focusBounds: widget.focusBounds,
                    focusPadding: widget.focusPadding,
                    focusSignal: widget.focusSignal,
                    onRouteUpdated: widget.onRouteUpdated,
                    onMapTap: widget.onMapTap,
                    onMapCenterChanged: widget.onMapCenterChanged,
                    showTargetEditBadge: widget.showTargetEditBadge,
                    cameraCenterTarget: widget.cameraCenterTarget,
                    cameraCenterSignal: widget.cameraCenterSignal,
                    zoomActionSignal: widget.zoomActionSignal,
                    zoomActionDelta: widget.zoomActionDelta,
                    showLiveNavigationMode: widget.showLiveNavigationMode,
                    userMarkerAccentColor: widget.userMarkerAccentColor,
                    userMarkerHaloColor: widget.userMarkerHaloColor,
                    userMarkerBorderColor: widget.userMarkerBorderColor,
                    initialCenter: _fallbackCenter,
                    initialZoom: _fallbackZoom,
                    initialBearing: _fallbackBearing,
                    preserveInitialViewport: _cachedViewport != null,
                    onCameraViewportChanged: (lat, lng, zoom, bearing) {
                      _viewportCache.write(
                        centerLat: lat,
                        centerLng: lng,
                        zoom: zoom,
                        bearing: 0,
                      );
                    },
                    onMapReady: () {
                      if (!mounted) {
                        return;
                      }
                      setState(() => _vectorReady = true);
                    },
                    onHardFailure: () {
                      if (!mounted || _mapLoadFailed) {
                        return;
                      }
                      setState(() => _mapLoadFailed = true);
                    },
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return _RapigoPassengerMapLoadingSurface(
      offlineReady: offlineState.isReady,
    );
  }
}

class _RapigoPassengerMapLoadingSurface extends StatelessWidget {
  const _RapigoPassengerMapLoadingSurface({required this.offlineReady});

  final bool offlineReady;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF8FBFF),
            const Color(0xFFF4F8FF),
            const Color(0xFFEFF5FF),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F8CFF), Color(0xFF2563EB)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x223B82F6),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Preparando mapa',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              offlineReady
                  ? 'Mapa listo en caché'
                  : 'Cargando experiencia RAPIGO',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PotosiMapLibreView extends ConsumerStatefulWidget {
  const _PotosiMapLibreView({
    required this.drivers,
    required this.userLocation,
    this.userAccuracyMeters,
    this.userHeadingDegrees,
    this.routeStart,
    this.routeTarget,
    this.secondaryMarker,
    required this.showRoute,
    required this.showTargetMarker,
    required this.routeColor,
    this.focusBounds,
    required this.focusPadding,
    required this.focusSignal,
    this.onRouteUpdated,
    this.onMapTap,
    this.onMapCenterChanged,
    required this.showTargetEditBadge,
    this.cameraCenterTarget,
    required this.cameraCenterSignal,
    required this.zoomActionSignal,
    required this.zoomActionDelta,
    required this.showLiveNavigationMode,
    required this.userMarkerAccentColor,
    required this.userMarkerHaloColor,
    required this.userMarkerBorderColor,
    required this.initialCenter,
    required this.initialZoom,
    required this.initialBearing,
    this.preserveInitialViewport = false,
    required this.onCameraViewportChanged,
    required this.onMapReady,
    required this.onHardFailure,
  });

  final List<PotosiMapDriverMarker> drivers;
  final LatLng userLocation;
  final double? userAccuracyMeters;
  final double? userHeadingDegrees;
  final LatLng? routeStart;
  final LatLng? routeTarget;
  final LatLng? secondaryMarker;
  final bool showRoute;
  final bool showTargetMarker;
  final Color routeColor;
  final LatLngBounds? focusBounds;
  final EdgeInsets focusPadding;
  final int focusSignal;
  final VoidCallback? onRouteUpdated;
  final ValueChanged<LatLng>? onMapTap;
  final void Function(LatLng center, bool hasGesture)? onMapCenterChanged;
  final bool showTargetEditBadge;
  final LatLng? cameraCenterTarget;
  final int cameraCenterSignal;
  final int zoomActionSignal;
  final double zoomActionDelta;
  final bool showLiveNavigationMode;
  final Color userMarkerAccentColor;
  final Color userMarkerHaloColor;
  final Color userMarkerBorderColor;
  final LatLng initialCenter;
  final double initialZoom;
  final double initialBearing;
  final bool preserveInitialViewport;
  final void Function(
    double centerLat,
    double centerLng,
    double zoom,
    double bearing,
  )
  onCameraViewportChanged;
  final VoidCallback onMapReady;
  final VoidCallback onHardFailure;

  @override
  ConsumerState<_PotosiMapLibreView> createState() =>
      _PotosiMapLibreViewState();
}

class _PotosiMapLibreViewState extends ConsumerState<_PotosiMapLibreView>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  ml.MapLibreMapController? _controller;
  RoutePathBundle? _routeBundle;
  String? _routeKey;
  bool _styleLoaded = false;
  bool _isSyncingScene = false;
  bool _didFail = false;
  bool _cameraGestureActive = false;
  Timer? _failSafeTimer;
  Timer? _resumeSettleTimer;
  Timer? _followLoopTimer;
  String? _resolvedStyleString;
  bool _preserveViewportOnResume = false;
  bool _initialViewportLocked = false;
  bool _passengerMarkerImageLoaded = false;
  bool _driverMarkerImageLoaded = false;
  LatLng? _lastCameraTarget;
  ml.Circle? _passengerHaloCircle;
  ml.Circle? _passengerPulseCircle;
  ml.Circle? _passengerCoreCircle;
  ml.Symbol? _passengerSymbol;
  final List<ml.Circle> _nearbyDriverCircles = <ml.Circle>[];
  final List<ml.Symbol> _nearbyDriverSymbols = <ml.Symbol>[];
  ml.Circle? _targetHaloCircle;
  ml.Circle? _targetCoreCircle;
  ml.Circle? _secondaryTargetHaloCircle;
  ml.Circle? _secondaryTargetCoreCircle;
  bool _routeLayersReady = false;
  LatLng? _lastAnimatedCameraTarget;
  double? _lastAnimatedCameraZoom;
  double? _lastAnimatedCameraBearing;
  DateTime? _lastCameraAnimationAt;
  double? _lastPersistedCenterLat;
  double? _lastPersistedCenterLng;
  double? _lastPersistedZoom;
  double? _lastPersistedBearing;

  static const String _passengerMarkerImageId =
      'rapigo_passenger_navigation_marker';
  static const String _driverMarkerImageId = 'rapigo_nearby_taxi_marker';
  static const String _routeSourceId = 'rapigo_passenger_route_source';
  static const String _routeGlowLayerId = 'rapigo_passenger_route_glow';
  static const String _routeMainLayerId = 'rapigo_passenger_route_main';
  LatLng? _displayPassengerPoint;
  double? _displayHeadingDegrees;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initialViewportLocked = widget.preserveInitialViewport;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadStyleString());
    _startFailSafe();
    _refreshRoute();
    _startFollowLoop();
  }

  @override
  void didUpdateWidget(covariant _PotosiMapLibreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final userVisualChanged =
        oldWidget.userLocation != widget.userLocation ||
        oldWidget.userAccuracyMeters != widget.userAccuracyMeters ||
        oldWidget.userHeadingDegrees != widget.userHeadingDegrees;
    final routeStructureChanged =
        oldWidget.routeStart != widget.routeStart ||
        oldWidget.routeTarget != widget.routeTarget ||
        oldWidget.secondaryMarker != widget.secondaryMarker ||
        oldWidget.showRoute != widget.showRoute ||
        oldWidget.showTargetMarker != widget.showTargetMarker ||
        oldWidget.focusBounds != widget.focusBounds;
    final driversChanged = !_sameDriverMarkers(
      oldWidget.drivers,
      widget.drivers,
    );
    final zoomActionChanged =
        oldWidget.zoomActionSignal != widget.zoomActionSignal &&
        widget.zoomActionDelta != 0;
    final focusSignalChanged = oldWidget.focusSignal != widget.focusSignal;
    final cameraCenterSignalChanged =
        oldWidget.cameraCenterSignal != widget.cameraCenterSignal;

    if (zoomActionChanged) {
      _initialViewportLocked = false;
      unawaited(_applyExternalZoomDelta());
    }
    if (focusSignalChanged || cameraCenterSignalChanged) {
      _initialViewportLocked = false;
      unawaited(_syncCamera(useCameraCenterTarget: cameraCenterSignalChanged));
    }
    if (routeStructureChanged || driversChanged) {
      _initialViewportLocked = false;
      _refreshRoute();
      return;
    }
    if (userVisualChanged) {
      unawaited(_updatePassengerVisuals());
      return;
    }
  }

  void _unlockInitialViewportIfNeeded() {
    if (_initialViewportLocked) {
      _initialViewportLocked = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _failSafeTimer?.cancel();
    _resumeSettleTimer?.cancel();
    _followLoopTimer?.cancel();
    super.dispose();
  }

  Future<void> _applyExternalZoomDelta() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) {
      return;
    }
    try {
      final camera = controller.cameraPosition;
      if (camera == null) {
        return;
      }
      final nextZoom = (camera.zoom + widget.zoomActionDelta)
          .clamp(AppConfig.mapMinZoom, AppConfig.mapMaxZoom)
          .toDouble();
      await controller.animateCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: camera.target,
            zoom: nextZoom,
            bearing: camera.bearing,
            tilt: camera.tilt,
          ),
        ),
      );
      _lastAnimatedCameraTarget = LatLng(
        camera.target.latitude,
        camera.target.longitude,
      );
      _lastAnimatedCameraZoom = nextZoom;
      _lastAnimatedCameraBearing = camera.bearing;
      _lastCameraAnimationAt = DateTime.now();
    } catch (_) {
      // Ignore zoom taps while the map is still settling.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persistCurrentViewport();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _preserveViewportOnResume = true;
      _resumeSettleTimer?.cancel();
      _resumeSettleTimer = Timer(const Duration(seconds: 2), () {
        _preserveViewportOnResume = false;
      });
    }
  }

  void _persistCurrentViewport() {
    final camera = _controller?.cameraPosition;
    if (camera == null) {
      return;
    }
    widget.onCameraViewportChanged(
      camera.target.latitude,
      camera.target.longitude,
      camera.zoom,
      camera.bearing,
    );
  }

  LatLng _smoothedTarget(LatLng target) {
    final previous = _lastCameraTarget;
    if (previous == null) {
      _lastCameraTarget = target;
      return target;
    }
    final next = LatLng(
      previous.latitude + ((target.latitude - previous.latitude) * 0.74),
      previous.longitude + ((target.longitude - previous.longitude) * 0.74),
    );
    _lastCameraTarget = next;
    return next;
  }

  LatLng _forwardLookingTarget(
    LatLng origin, {
    required double headingDegrees,
    required double metersAhead,
  }) {
    final radians = headingDegrees * (math.pi / 180);
    final deltaLat = (metersAhead * math.cos(radians)) / 111320;
    final cosLat = math
        .cos(origin.latitude * (math.pi / 180))
        .abs()
        .clamp(0.2, 1.0);
    final deltaLng = (metersAhead * math.sin(radians)) / (111320 * cosLat);
    return LatLng(origin.latitude + deltaLat, origin.longitude + deltaLng);
  }

  bool _sameDriverMarkers(
    List<PotosiMapDriverMarker> previous,
    List<PotosiMapDriverMarker> current,
  ) {
    if (identical(previous, current)) {
      return true;
    }
    if (previous.length != current.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      final a = previous[index];
      final b = current[index];
      if (a.driverId != b.driverId ||
          a.vehicleType != b.vehicleType ||
          a.isHighlighted != b.isHighlighted ||
          a.point != b.point) {
        return false;
      }
    }
    return true;
  }

  LatLng _visualPassengerPoint() {
    final animated = _displayPassengerPoint;
    if (animated != null) {
      return animated;
    }
    return _targetPassengerPoint();
  }

  LatLng _targetPassengerPoint() {
    final route = _routeBundle?.primary;
    if (!widget.showLiveNavigationMode || route == null || route.length < 2) {
      return widget.userLocation;
    }
    return _snapSoftlyToRoute(widget.userLocation, route);
  }

  double _visualHeading() =>
      _displayHeadingDegrees ?? (widget.userHeadingDegrees ?? 0).toDouble();

  void _startFollowLoop() {
    _followLoopTimer?.cancel();
    _followLoopTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      _tickFollowLoop();
    });
  }

  void _tickFollowLoop() {
    if (!mounted) {
      return;
    }
    final targetPoint = _targetPassengerPoint();
    final currentPoint = _displayPassengerPoint ?? targetPoint;
    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      currentPoint,
      targetPoint,
    );
    final pointFactor = distanceMeters > 18
        ? 0.34
        : distanceMeters > 8
        ? 0.26
        : 0.18;
    final nextPoint = distanceMeters < 0.45
        ? targetPoint
        : LatLng(
            currentPoint.latitude +
                ((targetPoint.latitude - currentPoint.latitude) * pointFactor),
            currentPoint.longitude +
                ((targetPoint.longitude - currentPoint.longitude) *
                    pointFactor),
          );

    final targetHeading = (widget.userHeadingDegrees ?? 0).toDouble();
    final currentHeading = _displayHeadingDegrees ?? targetHeading;
    final nextHeading = _interpolateHeading(currentHeading, targetHeading);

    final headingDelta = _headingDelta(nextHeading, currentHeading).abs();
    final movedEnough = distanceMeters > 0.18;
    final rotatedEnough = headingDelta > 0.55;

    _displayPassengerPoint = nextPoint;
    _displayHeadingDegrees = nextHeading;

    if (!movedEnough && !rotatedEnough) {
      return;
    }

    if (_controller != null && _styleLoaded && !_isSyncingScene) {
      unawaited(_updatePassengerVisuals());
    }
  }

  double _headingDelta(double target, double current) {
    var delta = ((target - current) + 540) % 360 - 180;
    if (delta == -180) {
      delta = 180;
    }
    return delta;
  }

  double _interpolateHeading(double current, double target) {
    final delta = _headingDelta(target, current);
    if (delta.abs() < 0.6) {
      return current;
    }
    final factor = delta.abs() > 20 ? 0.30 : 0.18;
    final next = current + (delta * factor);
    return (next % 360 + 360) % 360;
  }

  LatLng _snapSoftlyToRoute(LatLng current, List<LatLng> route) {
    final snapped = _nearestPointOnPolyline(current, route);
    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      current,
      snapped,
    );
    if (distanceMeters > 26) {
      return current;
    }
    final factor = distanceMeters <= 4
        ? 0.90
        : distanceMeters <= 10
        ? 0.72
        : 0.52;
    return LatLng(
      current.latitude + ((snapped.latitude - current.latitude) * factor),
      current.longitude + ((snapped.longitude - current.longitude) * factor),
    );
  }

  LatLng _nearestPointOnPolyline(LatLng point, List<LatLng> route) {
    var bestPoint = route.first;
    var bestDistance = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final candidate = _projectPointToSegment(point, route[i], route[i + 1]);
      final distance = const Distance().as(LengthUnit.Meter, point, candidate);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestPoint = candidate;
      }
    }
    return bestPoint;
  }

  LatLng _projectPointToSegment(LatLng p, LatLng a, LatLng b) {
    final ax = a.longitude;
    final ay = a.latitude;
    final bx = b.longitude;
    final by = b.latitude;
    final px = p.longitude;
    final py = p.latitude;
    final abx = bx - ax;
    final aby = by - ay;
    final ab2 = (abx * abx) + (aby * aby);
    if (ab2 == 0) {
      return a;
    }
    final apx = px - ax;
    final apy = py - ay;
    final t = ((apx * abx) + (apy * aby)) / ab2;
    final clamped = t.clamp(0.0, 1.0);
    return LatLng(ay + (aby * clamped), ax + (abx * clamped));
  }

  void _startFailSafe() {
    _failSafeTimer?.cancel();
    _failSafeTimer = Timer(const Duration(seconds: 6), () {
      if (!_styleLoaded && _resolvedStyleString != null) {
        _triggerFallback();
      }
    });
  }

  Future<void> _ensureRouteLayers(ml.MapLibreMapController controller) async {
    if (_routeLayersReady) {
      return;
    }
    await controller.addGeoJsonSource(
      _routeSourceId,
      _routeGeoJson(const <LatLng>[]),
    );
    await controller.addLineLayer(
      _routeSourceId,
      _routeGlowLayerId,
      const ml.LineLayerProperties(
        lineColor: '#9EC5FF',
        lineOpacity: 0.22,
        lineWidth: 11.5,
        lineBlur: 0.9,
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    await controller.addLineLayer(
      _routeSourceId,
      _routeMainLayerId,
      ml.LineLayerProperties(
        lineColor: _hex(widget.routeColor),
        lineOpacity: 0.97,
        lineWidth: 5.8,
        lineBlur: 0.25,
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    _routeLayersReady = true;
  }

  Map<String, dynamic> _routeGeoJson(List<LatLng> route) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'Feature',
          'properties': const <String, dynamic>{},
          'geometry': <String, dynamic>{
            'type': 'LineString',
            'coordinates': route
                .map((point) => <double>[point.longitude, point.latitude])
                .toList(growable: false),
          },
        },
      ],
    };
  }

  Future<void> _loadStyleString() async {
    final runtime = ref.read(rapigoMapRuntimeProvider);
    final vectorStyleUrl = runtime.style.vectorStyleUrl?.trim() ?? '';
    if (vectorStyleUrl.isNotEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedStyleString = vectorStyleUrl;
      });
      return;
    }

    try {
      final rawStyle =
          MapStyleCache.get(runtime.style.assetPath) ??
          await MapStyleCache.preload(runtime.style.assetPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedStyleString = rawStyle;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedStyleString = runtime.style.assetPath;
      });
    }
  }

  void _triggerFallback() {
    if (_didFail || !mounted) {
      return;
    }
    _didFail = true;
    widget.onHardFailure();
  }

  Future<void> _refreshRoute() async {
    final target = widget.routeTarget;
    if (!widget.showRoute || target == null) {
      if (mounted) {
        setState(() {
          _routeBundle = null;
          _routeKey = null;
        });
      }
      await _syncScene();
      return;
    }

    final start = widget.routeStart ?? widget.userLocation;
    final nextKey =
        '${start.latitude.toStringAsFixed(5)},${start.longitude.toStringAsFixed(5)}>'
        '${target.latitude.toStringAsFixed(5)},${target.longitude.toStringAsFixed(5)}';
    if (_routeKey == nextKey) {
      await _syncScene();
      return;
    }

    try {
      final bundle = await ref
          .read(routeServiceProvider)
          .fetchRouteBundle(start: start, end: target);
      if (!mounted) {
        return;
      }
      setState(() {
        _routeBundle = bundle;
        _routeKey = nextKey;
      });
      widget.onRouteUpdated?.call();
      await _syncScene();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routeBundle = RoutePathBundle(
          primary: <LatLng>[start, target],
          start: start,
          end: target,
        );
        _routeKey = nextKey;
      });
      widget.onRouteUpdated?.call();
      await _syncScene();
    }
  }

  Future<void> _syncScene() async {
    if (_controller == null || !_styleLoaded || _isSyncingScene || !mounted) {
      return;
    }
    _isSyncingScene = true;
    try {
      final controller = _controller!;
      await _ensureRouteLayers(controller);

      final route = _routeBundle?.primary;
      await controller.setGeoJsonSource(
        _routeSourceId,
        _routeGeoJson(
          route != null && route.length >= 2 ? route : const <LatLng>[],
        ),
      );
      await controller.setLayerProperties(
        _routeMainLayerId,
        ml.LineLayerProperties(lineColor: _hex(widget.routeColor)),
      );

      await _upsertNearbyDrivers(controller);
      await _upsertPassengerMarker(controller);
      await _upsertTargetMarkers(controller);
    } catch (_) {
      _triggerFallback();
    } finally {
      _isSyncingScene = false;
    }
  }

  Future<void> _clearNearbyDrivers(ml.MapLibreMapController controller) async {
    if (_nearbyDriverCircles.isEmpty && _nearbyDriverSymbols.isEmpty) {
      return;
    }
    for (final circle in _nearbyDriverCircles) {
      await controller.removeCircle(circle);
    }
    for (final symbol in _nearbyDriverSymbols) {
      await controller.removeSymbol(symbol);
    }
    _nearbyDriverCircles.clear();
    _nearbyDriverSymbols.clear();
  }

  Future<void> _upsertNearbyDrivers(ml.MapLibreMapController controller) async {
    await _clearNearbyDrivers(controller);
    await _ensureDriverMarkerImage(controller);
    final ordered = [...widget.drivers]
      ..sort((a, b) {
        if (a.isHighlighted == b.isHighlighted) {
          return 0;
        }
        return a.isHighlighted ? 1 : -1;
      });

    for (final driver in ordered) {
      final point = _toMlLatLng(driver.point);
      final haloColor = driver.isHighlighted ? '#22C55E' : '#86EFAC';
      final markerColor = driver.isHighlighted ? '#BBF7D0' : '#DCFCE7';
      final markerRadius = driver.isHighlighted ? 10.0 : 8.0;
      final haloRadius = driver.isHighlighted ? 22.0 : 17.0;

      final halo = await controller.addCircle(
        ml.CircleOptions(
          geometry: point,
          circleRadius: haloRadius,
          circleColor: haloColor,
          circleOpacity: driver.isHighlighted ? 0.26 : 0.18,
          circleBlur: 0.78,
        ),
      );
      final marker = await controller.addCircle(
        ml.CircleOptions(
          geometry: point,
          circleRadius: markerRadius,
          circleColor: markerColor,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: driver.isHighlighted ? 2.2 : 1.5,
          circleStrokeOpacity: driver.isHighlighted ? 0.95 : 0.75,
          circleOpacity: driver.isHighlighted ? 0.82 : 0.48,
        ),
      );
      final symbol = await controller.addSymbol(
        ml.SymbolOptions(
          geometry: point,
          iconImage: _driverMarkerImageId,
          iconSize: driver.isHighlighted ? 1.02 : 0.86,
          iconAnchor: 'center',
        ),
      );
      _nearbyDriverCircles
        ..add(halo)
        ..add(marker);
      _nearbyDriverSymbols.add(symbol);
    }
  }

  Future<void> _upsertPassengerMarker(
    ml.MapLibreMapController controller,
  ) async {
    final point = _toMlLatLng(_visualPassengerPoint());
    final accuracyMeters = (widget.userAccuracyMeters ?? 20).clamp(8, 120);
    final haloRadius = 22 + (accuracyMeters / 16);
    final pulseRadius = 14 + (accuracyMeters / 24);

    if (_passengerHaloCircle == null) {
      _passengerHaloCircle = await controller.addCircle(
        ml.CircleOptions(
          geometry: point,
          circleRadius: haloRadius,
          circleColor: _hex(widget.userMarkerHaloColor),
          circleOpacity: 0.14,
          circleBlur: 0.94,
        ),
      );
    } else {
      await controller.updateCircle(
        _passengerHaloCircle!,
        ml.CircleOptions(geometry: point, circleRadius: haloRadius),
      );
    }
    if (_passengerPulseCircle == null) {
      _passengerPulseCircle = await controller.addCircle(
        ml.CircleOptions(
          geometry: point,
          circleRadius: pulseRadius,
          circleColor: _hex(widget.userMarkerAccentColor),
          circleOpacity: 0.24,
          circleBlur: 0.88,
        ),
      );
    } else {
      await controller.updateCircle(
        _passengerPulseCircle!,
        ml.CircleOptions(geometry: point, circleRadius: pulseRadius),
      );
    }
    if (_passengerCoreCircle == null) {
      _passengerCoreCircle = await controller.addCircle(
        ml.CircleOptions(
          geometry: point,
          circleRadius: 8.6,
          circleColor: '#F8FBFF',
          circleStrokeColor: _hex(widget.userMarkerAccentColor),
          circleStrokeWidth: 4.2,
          circleStrokeOpacity: 0.98,
          circleOpacity: 1,
        ),
      );
    } else {
      await controller.updateCircle(
        _passengerCoreCircle!,
        ml.CircleOptions(geometry: point),
      );
    }
    await _ensurePassengerMarkerImage(controller);
    if (_passengerSymbol == null) {
      _passengerSymbol = await controller.addSymbol(
        ml.SymbolOptions(
          geometry: point,
          iconImage: _passengerMarkerImageId,
          iconSize: 1.18,
          iconRotate: _visualHeading(),
          iconAnchor: 'center',
        ),
      );
    } else {
      await controller.updateSymbol(
        _passengerSymbol!,
        ml.SymbolOptions(geometry: point, iconRotate: _visualHeading()),
      );
    }
  }

  Future<void> _updatePassengerVisuals() async {
    final controller = _controller;
    if (controller == null ||
        !_styleLoaded ||
        _isSyncingScene ||
        _passengerHaloCircle == null ||
        _passengerPulseCircle == null ||
        _passengerCoreCircle == null ||
        _passengerSymbol == null) {
      return;
    }

    final point = _toMlLatLng(_visualPassengerPoint());
    final accuracyMeters = (widget.userAccuracyMeters ?? 20).clamp(8, 120);
    final haloRadius = 22 + (accuracyMeters / 16);
    final pulseRadius = 14 + (accuracyMeters / 24);

    try {
      await controller.updateCircle(
        _passengerHaloCircle!,
        ml.CircleOptions(geometry: point, circleRadius: haloRadius),
      );
      await controller.updateCircle(
        _passengerPulseCircle!,
        ml.CircleOptions(geometry: point, circleRadius: pulseRadius),
      );
      await controller.updateCircle(
        _passengerCoreCircle!,
        ml.CircleOptions(geometry: point),
      );
      await controller.updateSymbol(
        _passengerSymbol!,
        ml.SymbolOptions(geometry: point, iconRotate: _visualHeading()),
      );
    } catch (_) {
      await _syncScene();
    }
  }

  Future<void> _ensurePassengerMarkerImage(
    ml.MapLibreMapController controller,
  ) async {
    if (_passengerMarkerImageLoaded) {
      return;
    }
    await controller.addImage(
      _passengerMarkerImageId,
      await _buildPassengerMarkerImageBytes(),
    );
    _passengerMarkerImageLoaded = true;
  }

  Future<void> _ensureDriverMarkerImage(
    ml.MapLibreMapController controller,
  ) async {
    if (_driverMarkerImageLoaded) {
      return;
    }
    await controller.addImage(
      _driverMarkerImageId,
      await _buildDriverMarkerImageBytes(),
    );
    _driverMarkerImageLoaded = true;
  }

  Future<Uint8List> _buildDriverMarkerImageBytes() async {
    const size = 160.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    canvas.drawCircle(
      center,
      48,
      Paint()
        ..color = const Color(0x6634D399)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawCircle(center, 36, Paint()..color = const Color(0x2234D399));
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(-0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(2, 5), width: 82, height: 52),
        const Radius.circular(18),
      ),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    final carRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 82, height: 50),
      const Radius.circular(18),
    );
    canvas.drawRRect(carRect, Paint()..color = const Color(0xFFFACC15));
    canvas.drawRRect(
      carRect,
      Paint()
        ..color = const Color(0xFF111827)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -11), width: 44, height: 18),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF172554),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-23, -6), width: 18, height: 12),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.74),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(23, -6), width: 18, height: 12),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.74),
    );
    canvas.drawCircle(
      const Offset(-30, 18),
      8,
      Paint()..color = const Color(0xFF111827),
    );
    canvas.drawCircle(
      const Offset(30, 18),
      8,
      Paint()..color = const Color(0xFF111827),
    );
    canvas.drawCircle(
      const Offset(-30, 18),
      3.2,
      Paint()..color = const Color(0xFFE5E7EB),
    );
    canvas.drawCircle(
      const Offset(30, 18),
      3.2,
      Paint()..color = const Color(0xFFE5E7EB),
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> _buildPassengerMarkerImageBytes() async {
    const size = 144.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    final haloOuter = Paint()
      ..color = widget.userMarkerHaloColor.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    final haloInner = Paint()
      ..color = widget.userMarkerHaloColor.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, 33, haloOuter);
    canvas.drawCircle(center, 25, haloInner);
    canvas.drawCircle(
      center,
      24,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    final arrowPath = ui.Path()
      ..moveTo(center.dx, center.dy - 48)
      ..lineTo(center.dx + 12, center.dy - 22)
      ..lineTo(center.dx + 3, center.dy - 26)
      ..lineTo(center.dx, center.dy - 8)
      ..lineTo(center.dx - 3, center.dy - 26)
      ..lineTo(center.dx - 12, center.dy - 22)
      ..close();
    canvas.drawPath(
      arrowPath.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      arrowPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx, center.dy - 48),
          Offset(center.dx, center.dy - 8),
          <Color>[
            widget.userMarkerBorderColor.withValues(alpha: 0.96),
            widget.userMarkerAccentColor,
          ],
        ),
    );
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final discPaint = Paint()..color = const Color(0xFF0B0D12);
    canvas.drawCircle(center, 20, discPaint);
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = widget.userMarkerBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _upsertTargetMarkers(ml.MapLibreMapController controller) async {
    if (widget.showTargetMarker && widget.routeTarget != null) {
      final targetPoint = _toMlLatLng(widget.routeTarget!);
      if (_targetHaloCircle == null) {
        _targetHaloCircle = await controller.addCircle(
          ml.CircleOptions(
            geometry: targetPoint,
            circleRadius: 16.5,
            circleColor: '#FF6B6B',
            circleOpacity: 0.16,
            circleBlur: 0.86,
          ),
        );
      } else {
        await controller.updateCircle(
          _targetHaloCircle!,
          ml.CircleOptions(geometry: targetPoint),
        );
      }
      if (_targetCoreCircle == null) {
        _targetCoreCircle = await controller.addCircle(
          ml.CircleOptions(
            geometry: targetPoint,
            circleRadius: 7.4,
            circleColor: '#FFFFFF',
            circleStrokeColor: '#EF4444',
            circleStrokeWidth: 3.8,
            circleStrokeOpacity: 0.96,
            circleOpacity: 1,
          ),
        );
      } else {
        await controller.updateCircle(
          _targetCoreCircle!,
          ml.CircleOptions(geometry: targetPoint),
        );
      }
    } else {
      if (_targetHaloCircle != null) {
        await controller.removeCircle(_targetHaloCircle!);
        _targetHaloCircle = null;
      }
      if (_targetCoreCircle != null) {
        await controller.removeCircle(_targetCoreCircle!);
        _targetCoreCircle = null;
      }
    }

    if (widget.secondaryMarker != null) {
      final secondaryPoint = _toMlLatLng(widget.secondaryMarker!);
      if (_secondaryTargetHaloCircle == null) {
        _secondaryTargetHaloCircle = await controller.addCircle(
          ml.CircleOptions(
            geometry: secondaryPoint,
            circleRadius: 14.2,
            circleColor: '#4ADE80',
            circleOpacity: 0.16,
            circleBlur: 0.8,
          ),
        );
      } else {
        await controller.updateCircle(
          _secondaryTargetHaloCircle!,
          ml.CircleOptions(geometry: secondaryPoint),
        );
      }
      if (_secondaryTargetCoreCircle == null) {
        _secondaryTargetCoreCircle = await controller.addCircle(
          ml.CircleOptions(
            geometry: secondaryPoint,
            circleRadius: 6.6,
            circleColor: '#FFFFFF',
            circleStrokeColor: '#22C55E',
            circleStrokeWidth: 3.0,
            circleStrokeOpacity: 0.95,
            circleOpacity: 1,
          ),
        );
      } else {
        await controller.updateCircle(
          _secondaryTargetCoreCircle!,
          ml.CircleOptions(geometry: secondaryPoint),
        );
      }
    } else {
      if (_secondaryTargetHaloCircle != null) {
        await controller.removeCircle(_secondaryTargetHaloCircle!);
        _secondaryTargetHaloCircle = null;
      }
      if (_secondaryTargetCoreCircle != null) {
        await controller.removeCircle(_secondaryTargetCoreCircle!);
        _secondaryTargetCoreCircle = null;
      }
    }
  }

  Future<void> _syncCamera({bool useCameraCenterTarget = false}) async {
    final controller = _controller;
    if (controller == null ||
        !_styleLoaded ||
        _preserveViewportOnResume ||
        _initialViewportLocked) {
      return;
    }

    try {
      final now = DateTime.now();
      if (_lastCameraAnimationAt != null &&
          now.difference(_lastCameraAnimationAt!) <
              const Duration(milliseconds: 140)) {
        return;
      }
      if (useCameraCenterTarget && widget.cameraCenterTarget != null) {
        _unlockInitialViewportIfNeeded();
        final target = widget.cameraCenterTarget!;
        final nextZoom = widget.showLiveNavigationMode ? 16.5 : 15.5;
        final targetDelta = _lastAnimatedCameraTarget == null
            ? double.infinity
            : const Distance().as(
                LengthUnit.Meter,
                _lastAnimatedCameraTarget!,
                target,
              );
        if (targetDelta < 2.2 &&
            _lastAnimatedCameraZoom != null &&
            (_lastAnimatedCameraZoom! - nextZoom).abs() < 0.08) {
          return;
        }
        await controller.animateCamera(
          ml.CameraUpdate.newLatLngZoom(_toMlLatLng(target), nextZoom),
        );
        _lastAnimatedCameraTarget = target;
        _lastAnimatedCameraZoom = nextZoom;
        _lastAnimatedCameraBearing = 0;
        _lastCameraAnimationAt = now;
        return;
      }

      if (widget.showLiveNavigationMode) {
        _unlockInitialViewportIfNeeded();
        final heading = _visualHeading().clamp(0, 360).toDouble();
        final target = _smoothedTarget(
          _forwardLookingTarget(
            _visualPassengerPoint(),
            headingDegrees: heading,
            metersAhead: 44,
          ),
        );
        const nextZoom = 16.5;
        final targetDelta = _lastAnimatedCameraTarget == null
            ? double.infinity
            : const Distance().as(
                LengthUnit.Meter,
                _lastAnimatedCameraTarget!,
                target,
              );
        final bearingDelta = _lastAnimatedCameraBearing == null
            ? double.infinity
            : _lastAnimatedCameraBearing!.abs();
        if (targetDelta < 2.2 &&
            bearingDelta < 2.2 &&
            _lastAnimatedCameraZoom != null &&
            (_lastAnimatedCameraZoom! - nextZoom).abs() < 0.08) {
          return;
        }
        await controller.animateCamera(
          ml.CameraUpdate.newCameraPosition(
            ml.CameraPosition(
              target: _toMlLatLng(target),
              zoom: nextZoom,
              bearing: 0,
              tilt: 0,
            ),
          ),
        );
        _lastAnimatedCameraTarget = target;
        _lastAnimatedCameraZoom = nextZoom;
        _lastAnimatedCameraBearing = 0;
        _lastCameraAnimationAt = now;
        return;
      }

      if (widget.routeTarget == null &&
          widget.secondaryMarker == null &&
          !_cameraGestureActive) {
        _unlockInitialViewportIfNeeded();
        final heading = _visualHeading().clamp(0, 360).toDouble();
        final target = _smoothedTarget(
          _forwardLookingTarget(
            _visualPassengerPoint(),
            headingDegrees: heading,
            metersAhead: 30,
          ),
        );
        const nextZoom = 15.9;
        final targetDelta = _lastAnimatedCameraTarget == null
            ? double.infinity
            : const Distance().as(
                LengthUnit.Meter,
                _lastAnimatedCameraTarget!,
                target,
              );
        final bearingDelta = _lastAnimatedCameraBearing == null
            ? double.infinity
            : _lastAnimatedCameraBearing!.abs();
        if (targetDelta < 2.2 &&
            bearingDelta < 2.2 &&
            _lastAnimatedCameraZoom != null &&
            (_lastAnimatedCameraZoom! - nextZoom).abs() < 0.08) {
          return;
        }
        await controller.animateCamera(
          ml.CameraUpdate.newCameraPosition(
            ml.CameraPosition(
              target: _toMlLatLng(target),
              zoom: nextZoom,
              bearing: 0,
              tilt: 0,
            ),
          ),
        );
        _lastAnimatedCameraTarget = target;
        _lastAnimatedCameraZoom = nextZoom;
        _lastAnimatedCameraBearing = 0;
        _lastCameraAnimationAt = now;
        return;
      }

      final bounds = widget.focusBounds;
      if (bounds != null) {
        _unlockInitialViewportIfNeeded();
        await controller.animateCamera(
          ml.CameraUpdate.newLatLngBounds(
            ml.LatLngBounds(
              southwest: _toMlLatLng(bounds.southWest),
              northeast: _toMlLatLng(bounds.northEast),
            ),
            left: widget.focusPadding.left,
            top: widget.focusPadding.top,
            right: widget.focusPadding.right,
            bottom: widget.focusPadding.bottom,
          ),
        );
        return;
      }

      final focusPoints = <LatLng>[
        widget.routeStart ?? widget.userLocation,
        if (widget.routeTarget != null) widget.routeTarget!,
        if (widget.secondaryMarker != null) widget.secondaryMarker!,
      ];
      final center = _resolveCameraCenter(focusPoints);
      final zoom = _resolveCameraZoom(focusPoints);
      _unlockInitialViewportIfNeeded();
      final targetDelta = _lastAnimatedCameraTarget == null
          ? double.infinity
          : const Distance().as(
              LengthUnit.Meter,
              _lastAnimatedCameraTarget!,
              center,
            );
      final bearingDelta = _lastAnimatedCameraBearing == null
          ? double.infinity
          : _lastAnimatedCameraBearing!.abs();
      if (targetDelta < 2.2 &&
          bearingDelta < 2.2 &&
          _lastAnimatedCameraZoom != null &&
          (_lastAnimatedCameraZoom! - zoom).abs() < 0.08) {
        return;
      }
      await controller.animateCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: _toMlLatLng(center),
            zoom: zoom,
            bearing: 0,
            tilt: 0,
          ),
        ),
      );
      _lastAnimatedCameraTarget = center;
      _lastAnimatedCameraZoom = zoom;
      _lastAnimatedCameraBearing = 0;
      _lastCameraAnimationAt = now;
    } catch (_) {
      _triggerFallback();
    }
  }

  LatLng _resolveCameraCenter(List<LatLng> points) {
    if (points.isEmpty) {
      return widget.userLocation;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  double _resolveCameraZoom(List<LatLng> points) {
    if (points.length < 2) {
      return AppConfig.mapInitialZoom;
    }
    final distance = const Distance().as(
      LengthUnit.Meter,
      points.first,
      points.last,
    );
    if (distance <= 180) {
      return 16.4;
    }
    if (distance <= 400) {
      return 16.0;
    }
    if (distance <= 900) {
      return 15.5;
    }
    if (distance <= 1800) {
      return 15.0;
    }
    if (distance <= 3500) {
      return 15.0;
    }
    if (distance <= 7000) {
      return 14.3;
    }
    if (distance <= 12000) {
      return 13.6;
    }
    return 12.9;
  }

  ml.LatLng _toMlLatLng(LatLng point) =>
      ml.LatLng(point.latitude, point.longitude);

  String _hex(Color color) {
    final r = (color.r * 255.0)
        .round()
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    final g = (color.g * 255.0)
        .round()
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    final b = (color.b * 255.0)
        .round()
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    return '#$r$g$b';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final styleString = _resolvedStyleString;
    if (styleString == null || styleString.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFE7E9EC),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF2979FF)),
        ),
      );
    }

    return Stack(
      children: [
        ml.MapLibreMap(
          styleString: styleString,
          initialCameraPosition: ml.CameraPosition(
            target: _toMlLatLng(widget.initialCenter),
            zoom: widget.initialZoom,
            bearing: 0,
          ),
          minMaxZoomPreference: const ml.MinMaxZoomPreference(
            AppConfig.mapMinZoom,
            AppConfig.mapMaxZoom,
          ),
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: false,
          compassEnabled: false,
          trackCameraPosition: true,
          attributionButtonPosition: ml.AttributionButtonPosition.bottomLeft,
          onMapClick: widget.onMapTap == null
              ? null
              : (_, coordinates) {
                  widget.onMapTap?.call(
                    LatLng(coordinates.latitude, coordinates.longitude),
                  );
                },
          onCameraMove: (position) {
            final lat = position.target.latitude;
            final lng = position.target.longitude;
            final zoom = position.zoom;
            final bearing = 0.0;
            final shouldPersist =
                _lastPersistedCenterLat == null ||
                _lastPersistedCenterLng == null ||
                const Distance().as(
                      LengthUnit.Meter,
                      LatLng(
                        _lastPersistedCenterLat!,
                        _lastPersistedCenterLng!,
                      ),
                      LatLng(lat, lng),
                    ) >
                    3.5 ||
                _lastPersistedZoom == null ||
                (_lastPersistedZoom! - zoom).abs() > 0.05 ||
                _lastPersistedBearing == null;
            if (shouldPersist) {
              _lastPersistedCenterLat = lat;
              _lastPersistedCenterLng = lng;
              _lastPersistedZoom = zoom;
              _lastPersistedBearing = bearing;
              widget.onCameraViewportChanged(lat, lng, zoom, bearing);
            }
            _cameraGestureActive = true;
            widget.onMapCenterChanged?.call(LatLng(lat, lng), true);
          },
          onCameraIdle: () {
            final center = _controller?.cameraPosition?.target;
            if (center != null) {
              widget.onMapCenterChanged?.call(
                LatLng(center.latitude, center.longitude),
                _cameraGestureActive,
              );
            }
            _cameraGestureActive = false;
          },
          onMapCreated: (controller) {
            _controller = controller;
          },
          onStyleLoadedCallback: () {
            _styleLoaded = true;
            _routeLayersReady = false;
            _passengerMarkerImageLoaded = false;
            _passengerHaloCircle = null;
            _passengerPulseCircle = null;
            _passengerCoreCircle = null;
            _passengerSymbol = null;
            _nearbyDriverCircles.clear();
            _nearbyDriverSymbols.clear();
            _driverMarkerImageLoaded = false;
            _targetHaloCircle = null;
            _targetCoreCircle = null;
            _secondaryTargetHaloCircle = null;
            _secondaryTargetCoreCircle = null;
            _failSafeTimer?.cancel();
            widget.onMapReady();
            unawaited(_syncScene());
          },
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF74A7E2).withValues(alpha: 0.10),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF3E7BC0).withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned(left: 16, bottom: 16, child: OfflineMapReadyBadge()),
      ],
    );
  }
}

class PotosiMap extends ConsumerStatefulWidget {
  const PotosiMap({
    super.key,
    required this.drivers,
    required this.userLocation,
    this.userAccuracyMeters,
    this.userHeadingDegrees,
    this.routeStart,
    this.routeTarget,
    this.secondaryMarker,
    this.showRoute = false,
    this.showTargetMarker = true,
    this.routeColor = const Color(0xFF2979FF),
    this.focusBounds,
    this.focusPadding = const EdgeInsets.fromLTRB(56, 120, 56, 220),
    this.focusSignal = 0,
    this.onRouteUpdated,
    this.onMapTap,
    this.showTargetEditBadge = false,
    this.onMapCenterChanged,
    this.cameraCenterTarget,
    this.cameraCenterSignal = 0,
    this.showUtilityControls = true,
    this.showLiveNavigationMode = false,
    this.userMarkerAccentColor = const Color(0xFF0F6CBD),
    this.userMarkerHaloColor = const Color(0xFF0F6CBD),
    this.userMarkerBorderColor = const Color(0xFFD7E6FB),
  });

  final List<PotosiMapDriverMarker> drivers;
  final LatLng userLocation;
  final double? userAccuracyMeters;
  final double? userHeadingDegrees;
  final LatLng? routeStart;
  final LatLng? routeTarget;
  final LatLng? secondaryMarker;
  final bool showRoute;
  final bool showTargetMarker;
  final Color routeColor;
  final LatLngBounds? focusBounds;
  final EdgeInsets focusPadding;
  final int focusSignal;
  final VoidCallback? onRouteUpdated;
  final ValueChanged<LatLng>? onMapTap;
  final bool showTargetEditBadge;
  final void Function(LatLng center, bool hasGesture)? onMapCenterChanged;
  final LatLng? cameraCenterTarget;
  final int cameraCenterSignal;
  final bool showUtilityControls;
  final bool showLiveNavigationMode;
  final Color userMarkerAccentColor;
  final Color userMarkerHaloColor;
  final Color userMarkerBorderColor;

  @override
  ConsumerState<PotosiMap> createState() => _PotosiMapState();
}

class _PotosiMapState extends ConsumerState<PotosiMap>
    with TickerProviderStateMixin {
  static const double _rerouteDistanceMeters = 38;
  static const double _rerouteTargetShiftMeters = 55;
  static const double _detailRefreshDistanceMeters = 45;
  final MapController _mapController = MapController();
  RoutePathBundle? _routeBundle;
  String? _routeKey;
  LatLng? _lastRouteEnd;
  bool _shouldAnnounceRouteUpdate = false;
  final Distance _distance = const Distance();
  MapLocationDetails? _currentLocationDetails;
  MapLocationDetails? _targetLocationDetails;
  LatLng? _lastCurrentLookupPoint;
  LatLng? _lastTargetLookupPoint;
  Timer? _detailsDebounce;
  bool _didApplyInitialFollow = false;
  bool _isFollowingUser = false;
  double _mapRotation = 0;
  late final AnimationController _cameraFollowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Animation<double>? _cameraLatAnimation;
  Animation<double>? _cameraLngAnimation;
  Animation<double>? _cameraZoomAnimation;
  VoidCallback? _cameraFrameListener;

  @override
  void initState() {
    super.initState();
    _refreshRoute();
    _scheduleLocationDetailsRefresh(force: true);
  }

  @override
  void didUpdateWidget(covariant PotosiMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldRefreshRoute(oldWidget)) {
      _shouldAnnounceRouteUpdate = _shouldShowRouteUpdatedNotice();
      _refreshRoute();
    }
    if (oldWidget.focusSignal != widget.focusSignal) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyFocus());
    }
    if (oldWidget.cameraCenterSignal != widget.cameraCenterSignal &&
        widget.cameraCenterTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _centerCameraOn(widget.cameraCenterTarget!),
      );
    }
    if (_shouldRefreshLocationDetails(oldWidget)) {
      _scheduleLocationDetailsRefresh();
    }
  }

  @override
  void dispose() {
    _detailsDebounce?.cancel();
    if (_cameraFrameListener != null) {
      _cameraFollowController.removeListener(_cameraFrameListener!);
      _cameraFrameListener = null;
    }
    _cameraFollowController.dispose();
    super.dispose();
  }

  bool _shouldShowRouteUpdatedNotice() {
    final target = widget.routeTarget;
    final start = widget.routeStart ?? widget.userLocation;
    final routePoints = _routeBundle?.primary;
    if (!widget.showRoute ||
        target == null ||
        routePoints == null ||
        routePoints.length < 2) {
      return false;
    }
    final routeService = ref.read(routeServiceProvider);
    final offRouteDistance = routeService.distanceToRoute(
      point: start,
      route: routePoints,
    );
    final targetShift = _lastRouteEnd == null
        ? double.infinity
        : routeService.pointDistance(_lastRouteEnd!, target);
    return offRouteDistance > _rerouteDistanceMeters ||
        targetShift > _rerouteTargetShiftMeters;
  }

  void _applyFocus() {
    if (!mounted) {
      return;
    }
    final bounds = widget.focusBounds;
    if (widget.showLiveNavigationMode && widget.routeStart != null) {
      _animateCameraTo(
        target: widget.routeStart!,
        zoom: 16.2,
        duration: const Duration(milliseconds: 620),
      );
      return;
    }
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: widget.focusPadding),
      );
      return;
    }
    final target = widget.showLiveNavigationMode
        ? (widget.routeStart ?? widget.routeTarget ?? widget.userLocation)
        : (widget.routeTarget ?? widget.userLocation);
    final zoom = widget.showLiveNavigationMode
        ? 16.0
        : AppConfig.mapInitialZoom;
    _animateCameraTo(target: target, zoom: zoom);
  }

  void _centerCameraOn(LatLng target) {
    if (!mounted) {
      return;
    }
    _animateCameraTo(target: target, zoom: _mapController.camera.zoom);
  }

  void _maybeFollowUser({bool force = false}) {
    if (!mounted) {
      return;
    }
    if (!force && !_isFollowingUser) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _animateCameraTo(
        target: widget.showLiveNavigationMode
            ? (widget.routeStart ?? widget.userLocation)
            : widget.userLocation,
        zoom: widget.showLiveNavigationMode
            ? math.max(_mapController.camera.zoom, 16.0)
            : _mapController.camera.zoom,
        duration: widget.showLiveNavigationMode
            ? const Duration(milliseconds: 680)
            : const Duration(milliseconds: 420),
      );
    });
  }

  void _animateCameraTo({
    required LatLng target,
    required double zoom,
    Duration duration = const Duration(milliseconds: 420),
  }) {
    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom
        .clamp(AppConfig.mapMinZoom, AppConfig.mapMaxZoom)
        .toDouble();
    final targetZoom = zoom
        .clamp(AppConfig.mapMinZoom, AppConfig.mapMaxZoom)
        .toDouble();
    final samePoint = _distance(currentCenter, target) < 2;
    final sameZoom = (currentZoom - targetZoom).abs() < 0.02;
    if (samePoint && sameZoom) {
      return;
    }

    _cameraFollowController
      ..duration = duration
      ..stop()
      ..reset();
    if (_cameraFrameListener != null) {
      _cameraFollowController.removeListener(_cameraFrameListener!);
      _cameraFrameListener = null;
    }

    _cameraLatAnimation =
        Tween<double>(
          begin: currentCenter.latitude,
          end: target.latitude,
        ).animate(
          CurvedAnimation(
            parent: _cameraFollowController,
            curve: Curves.easeOutCubic,
          ),
        );
    _cameraLngAnimation =
        Tween<double>(
          begin: currentCenter.longitude,
          end: target.longitude,
        ).animate(
          CurvedAnimation(
            parent: _cameraFollowController,
            curve: Curves.easeOutCubic,
          ),
        );
    _cameraZoomAnimation = Tween<double>(begin: currentZoom, end: targetZoom)
        .animate(
          CurvedAnimation(
            parent: _cameraFollowController,
            curve: Curves.easeOutCubic,
          ),
        );

    void handleFrame() {
      final lat = _cameraLatAnimation?.value;
      final lng = _cameraLngAnimation?.value;
      final nextZoom = _cameraZoomAnimation?.value;
      if (lat == null || lng == null || nextZoom == null || !mounted) {
        return;
      }
      _mapController.move(LatLng(lat, lng), nextZoom);
    }

    _cameraFrameListener = handleFrame;
    _cameraFollowController.addListener(handleFrame);
    _cameraFollowController.forward().whenCompleteOrCancel(() {
      if (_cameraFrameListener != null) {
        _cameraFollowController.removeListener(_cameraFrameListener!);
        _cameraFrameListener = null;
      }
      if (!mounted) {
        return;
      }
      _mapController.move(target, targetZoom);
    });
  }

  bool _shouldRefreshRoute(PotosiMap oldWidget) {
    if (oldWidget.showRoute != widget.showRoute) {
      return true;
    }
    final target = widget.routeTarget;
    final start = widget.routeStart ?? widget.userLocation;
    final routePoints = _routeBundle?.primary;
    if (!widget.showRoute ||
        target == null ||
        routePoints == null ||
        routePoints.length < 2) {
      return oldWidget.userLocation != widget.userLocation ||
          oldWidget.routeStart != widget.routeStart ||
          oldWidget.routeTarget != widget.routeTarget;
    }

    final routeService = ref.read(routeServiceProvider);
    final offRouteDistance = routeService.distanceToRoute(
      point: start,
      route: routePoints,
    );
    final targetShift = _lastRouteEnd == null
        ? double.infinity
        : routeService.pointDistance(_lastRouteEnd!, target);
    return offRouteDistance > _rerouteDistanceMeters ||
        targetShift > _rerouteTargetShiftMeters;
  }

  Future<void> _refreshRoute() async {
    final target = widget.routeTarget;
    if (!widget.showRoute || target == null) {
      if (mounted) {
        setState(() {
          _routeBundle = null;
          _routeKey = null;
        });
      }
      return;
    }

    final start = widget.routeStart ?? widget.userLocation;
    final nextKey =
        '${start.latitude.toStringAsFixed(5)},'
        '${start.longitude.toStringAsFixed(5)}>'
        '${target.latitude.toStringAsFixed(5)},${target.longitude.toStringAsFixed(5)}';
    if (_routeKey == nextKey && _routeBundle != null) {
      return;
    }

    try {
      final bundle = await ref
          .read(routeServiceProvider)
          .fetchRouteBundle(start: start, end: target);
      if (!mounted) {
        return;
      }
      setState(() {
        _routeBundle = bundle;
        _routeKey = nextKey;
        _lastRouteEnd = target;
      });
      if (_shouldAnnounceRouteUpdate) {
        _shouldAnnounceRouteUpdate = false;
        widget.onRouteUpdated?.call();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routeBundle = RoutePathBundle(
          primary: <LatLng>[start, target],
          start: start,
          end: target,
        );
        _routeKey = nextKey;
        _lastRouteEnd = target;
      });
      if (_shouldAnnounceRouteUpdate) {
        _shouldAnnounceRouteUpdate = false;
        widget.onRouteUpdated?.call();
      }
    }
  }

  bool _shouldRefreshLocationDetails(PotosiMap oldWidget) {
    final movedEnough =
        _lastCurrentLookupPoint == null ||
        _distance(widget.userLocation, _lastCurrentLookupPoint!) >
            _detailRefreshDistanceMeters;
    final oldTarget = oldWidget.routeTarget;
    final newTarget = widget.routeTarget;
    final targetChanged =
        oldTarget != newTarget ||
        (_lastTargetLookupPoint != null &&
            newTarget != null &&
            _distance(newTarget, _lastTargetLookupPoint!) >
                _detailRefreshDistanceMeters);
    return movedEnough || targetChanged;
  }

  void _scheduleLocationDetailsRefresh({bool force = false}) {
    _detailsDebounce?.cancel();
    _detailsDebounce = Timer(
      force ? Duration.zero : const Duration(milliseconds: 500),
      () {
        unawaited(_refreshLocationDetails(force: force));
      },
    );
  }

  String? _formatDistance(double? meters) {
    if (meters == null || meters <= 0) {
      return null;
    }
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
    }
    return '${meters.round()} m';
  }

  String? _formatDuration(double? seconds) {
    if (seconds == null || seconds <= 0) {
      return null;
    }
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours h';
    }
    return '$hours h $remainingMinutes min';
  }

  Future<void> _refreshLocationDetails({bool force = false}) async {
    final geocoding = ref.read(geocodingServiceProvider);
    final userPoint = widget.showLiveNavigationMode && widget.routeStart != null
        ? widget.routeStart!
        : widget.userLocation;
    final targetPoint = widget.routeTarget;
    try {
      if (force ||
          _lastCurrentLookupPoint == null ||
          _distance(userPoint, _lastCurrentLookupPoint!) >
              _detailRefreshDistanceMeters) {
        final details = await geocoding.reverseLookup(userPoint);
        if (mounted) {
          setState(() {
            _currentLocationDetails = details;
            _lastCurrentLookupPoint = userPoint;
          });
        }
      }
      if (targetPoint != null &&
          (force ||
              _lastTargetLookupPoint == null ||
              _distance(targetPoint, _lastTargetLookupPoint!) >
                  _detailRefreshDistanceMeters)) {
        final details = await geocoding.reverseLookup(targetPoint);
        if (mounted) {
          setState(() {
            _targetLocationDetails = details;
            _lastTargetLookupPoint = targetPoint;
          });
        }
      } else if (targetPoint == null &&
          mounted &&
          _targetLocationDetails != null) {
        setState(() {
          _targetLocationDetails = null;
          _lastTargetLookupPoint = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLocationDetails ??= const MapLocationDetails(
          primary: 'Ubicacion actual',
          secondary: 'Potosi',
          fullAddress: 'Potosi',
        );
        if (targetPoint == null) {
          _targetLocationDetails = null;
          _lastTargetLookupPoint = null;
        } else {
          _targetLocationDetails ??= const MapLocationDetails(
            primary: 'Destino del viaje',
            secondary: 'Potosi',
            fullAddress: 'Potosi',
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final offlineState = ref.watch(offlineMapProvider);
    final initialCenter =
        widget.routeTarget ?? widget.routeStart ?? widget.userLocation;
    final offlineMap = ref.read(offlineMapProvider.notifier);
    final routeService = ref.read(routeServiceProvider);
    final visiblePrimaryRoute = _routeBundle == null
        ? null
        : routeService.trimRouteFromPoint(
            point: widget.routeStart ?? widget.userLocation,
            route: _routeBundle!.primary,
          );
    final visibleAlternativeRoutes = _routeBundle == null
        ? const <List<LatLng>>[]
        : _routeBundle!.alternatives
              .map(
                (route) => routeService.trimRouteFromPoint(
                  point: widget.routeStart ?? widget.userLocation,
                  route: route,
                ),
              )
              .where((route) => route.length >= 2)
              .toList(growable: false);
    final orderedDrivers = [...widget.drivers]
      ..sort((a, b) {
        if (a.isHighlighted == b.isHighlighted) {
          return 0;
        }
        return a.isHighlighted ? 1 : -1;
      });
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: AppConfig.mapInitialZoom,
            minZoom: AppConfig.mapMinZoom,
            maxZoom: AppConfig.mapMaxZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onMapReady: () {
              if (_didApplyInitialFollow) {
                return;
              }
              _didApplyInitialFollow = true;
            },
            onPositionChanged: (_, hasGesture) {
              widget.onMapCenterChanged?.call(
                _mapController.camera.center,
                hasGesture,
              );
              final rotation = _mapController.camera.rotation;
              if (hasGesture) {
                final shouldUpdateRotation =
                    (_mapRotation - rotation).abs() > 0.8;
                if (_isFollowingUser || shouldUpdateRotation) {
                  setState(() {
                    _isFollowingUser = false;
                    _mapRotation = rotation;
                  });
                }
              } else if ((_mapRotation - rotation).abs() > 0.8) {
                setState(() {
                  _mapRotation = rotation;
                });
              }
            },
            onTap: (_, point) => widget.onMapTap?.call(point),
          ),
          children: [
            offlineMap.buildTileLayer(
              userAgentPackageName: 'bo.rapigo.passenger',
            ),
            if ((widget.userAccuracyMeters ?? 0) > 0)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: widget.userLocation,
                    radius: widget.userAccuracyMeters!
                        .clamp(12, 120)
                        .toDouble(),
                    useRadiusInMeter: true,
                    color: const Color(0x220F6CBD),
                    borderColor: const Color(0x550F6CBD),
                    borderStrokeWidth: 1.2,
                  ),
                ],
              ),
            if (widget.showRoute &&
                widget.routeTarget != null &&
                visibleAlternativeRoutes.isNotEmpty)
              PolylineLayer(
                polylines: visibleAlternativeRoutes
                    .map(
                      (route) => Polyline(
                        points: route,
                        strokeWidth: 2.5,
                        color: const Color(0xFF8AB4FF).withValues(alpha: 0.16),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (widget.showRoute &&
                widget.routeTarget != null &&
                (visiblePrimaryRoute?.length ?? 0) >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: visiblePrimaryRoute!,
                    strokeWidth: 4.6,
                    color: widget.routeColor,
                    borderColor: const Color(
                      0xFFB9D5FF,
                    ).withValues(alpha: 0.24),
                    borderStrokeWidth: 7.8,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.userLocation,
                  width: 64,
                  height: 64,
                  child: _PassengerLocationMarker(
                    headingDegrees: widget.userHeadingDegrees,
                    accuracyMeters: widget.userAccuracyMeters,
                    accentColor: widget.userMarkerAccentColor,
                    haloColor: widget.userMarkerHaloColor,
                    borderColor: widget.userMarkerBorderColor,
                  ),
                ),
                if (widget.showTargetMarker && widget.routeTarget != null)
                  Marker(
                    point: widget.routeTarget!,
                    width: 112,
                    height: 94,
                    child: InteractiveDestinationMarker(
                      icon: Icons.place_rounded,
                      color: const Color(0xFF3B82F6),
                      label: 'Destino',
                      showEditBadge: widget.showTargetEditBadge,
                      showShell: false,
                    ),
                  ),
                if (widget.secondaryMarker != null &&
                    widget.secondaryMarker != widget.routeTarget)
                  Marker(
                    point: widget.secondaryMarker!,
                    width: 102,
                    height: 88,
                    child: InteractiveDestinationMarker(
                      icon: Icons.flag_rounded,
                      color: const Color(0xFFEF4444),
                      label: 'Ruta final',
                      size: 28,
                      showEditBadge: widget.showTargetEditBadge,
                    ),
                  ),
                ...orderedDrivers.map(
                  (driver) => Marker(
                    point: driver.point,
                    width: driver.isHighlighted ? 104 : 72,
                    height: driver.isHighlighted ? 88 : 72,
                    child: _NearbyDriverMapMarker(
                      icon: _vehicleIcon(driver.vehicleType),
                      isHighlighted: driver.isHighlighted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF04101F).withValues(alpha: 0.16),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF030814).withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.showUtilityControls)
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => showOfflineMapSheet(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.96),
                    foregroundColor: offlineState.isDownloading
                        ? const Color(0xFFFACC15)
                        : offlineState.isReady
                        ? const Color(0xFF0F6CBD)
                        : const Color(0xFFF59E0B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(14),
                  ),
                  tooltip: 'Offline listo',
                  icon: Icon(
                    offlineState.isDownloading
                        ? Icons.downloading_rounded
                        : offlineState.isReady
                        ? Icons.offline_bolt_rounded
                        : Icons.cloud_queue_rounded,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 10),
                if (!_isFollowingUser) ...[
                  FloatingActionButton.small(
                    heroTag: 'passenger-map-recenter',
                    backgroundColor: const Color(0xFF0F6CBD),
                    foregroundColor: Colors.white,
                    onPressed: () {
                      _maybeFollowUser(force: true);
                    },
                    child: const _NavigationArrowIcon(size: 20),
                  ),
                  const SizedBox(height: 10),
                ],
                if (!widget.showLiveNavigationMode)
                  MapNavigationTriggerButton(
                    iconOnly: true,
                    currentLabel:
                        _currentLocationDetails?.primary ?? 'Ubicacion actual',
                    currentDetail:
                        _currentLocationDetails?.secondary ??
                        'Buscando calle...',
                    targetLabel:
                        widget.showTargetMarker && widget.routeTarget != null
                        ? (_targetLocationDetails?.primary ??
                              'Destino del viaje')
                        : null,
                    targetDetail:
                        widget.showTargetMarker && widget.routeTarget != null
                        ? (_targetLocationDetails?.secondary ??
                              'Buscando referencia...')
                        : null,
                    remainingDistanceLabel: _formatDistance(
                      _routeBundle?.distanceMeters,
                    ),
                    remainingDurationLabel: _formatDuration(
                      _routeBundle?.durationSeconds,
                    ),
                    targetCaption: widget.secondaryMarker != null
                        ? 'Punto del viaje'
                        : 'Destino',
                    onOpenOfflineInfo: () => showOfflineMapSheet(context),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _vehicleIcon(String? vehicleType) {
    return switch ((vehicleType ?? '').toLowerCase()) {
      'moto' => Icons.two_wheeler_rounded,
      _ => Icons.local_taxi_rounded,
    };
  }
}

class _PassengerLocationMarker extends StatefulWidget {
  const _PassengerLocationMarker({
    this.headingDegrees,
    this.accuracyMeters,
    required this.accentColor,
    required this.haloColor,
    required this.borderColor,
  });

  final double? headingDegrees;
  final double? accuracyMeters;
  final Color accentColor;
  final Color haloColor;
  final Color borderColor;

  @override
  State<_PassengerLocationMarker> createState() =>
      _PassengerLocationMarkerState();
}

class _PassengerLocationMarkerState extends State<_PassengerLocationMarker>
    with SingleTickerProviderStateMixin {
  double _previousHeading = 0;
  double _displayHeading = 0;
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1850),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _previousHeading = widget.headingDegrees ?? 0;
    _displayHeading = widget.headingDegrees ?? 0;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PassengerLocationMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousHeading = _displayHeading;
    _displayHeading = _resolveNextHeading(
      current: _previousHeading,
      target: widget.headingDegrees ?? 0,
    );
  }

  double _resolveNextHeading({
    required double current,
    required double target,
  }) {
    final normalizedCurrent = current % 360;
    final normalizedTarget = target % 360;
    var delta = normalizedTarget - normalizedCurrent;
    if (delta > 180) {
      delta -= 360;
    } else if (delta < -180) {
      delta += 360;
    }
    return current + delta;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _previousHeading, end: _displayHeading),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, animatedHeading, child) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final accuracyMeters = (widget.accuracyMeters ?? 18).clamp(6, 60);
            final accuracyFactor = ((accuracyMeters - 6) / 54).clamp(0.0, 1.0);
            final pulseScale =
                (1 + (_pulseController.value * 0.08)) + (accuracyFactor * 0.18);
            final pulseAlpha =
                (0.1 + (_pulseController.value * 0.08)) +
                (accuracyFactor * 0.05);
            final coneScale = 0.88 + ((accuracyMeters - 6) / 54) * 0.38;
            final coneAlpha = 0.11 + ((accuracyMeters - 6) / 54) * 0.12;
            final haloSize = 56 + (accuracyFactor * 18);
            return Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      width: haloSize,
                      height: haloSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.haloColor.withValues(alpha: pulseAlpha),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle:
                        ((animatedHeading) * (math.pi / 180)) - (math.pi / 8),
                    child: Transform.scale(
                      scale: coneScale,
                      child: CustomPaint(
                        size: const Size(54, 54),
                        painter: _HeadingConePainter(
                          color: widget.accentColor.withValues(
                            alpha: coneAlpha,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.borderColor, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x220F172A),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                  _NavigationArrowIcon(
                    size: 26,
                    headingDegrees: animatedHeading,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  const _HeadingConePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = ui.Path()
      ..moveTo(center.dx, center.dy - 2)
      ..quadraticBezierTo(
        center.dx - 11,
        center.dy - 16,
        center.dx - 5,
        center.dy - 25,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy - 31,
        center.dx + 5,
        center.dy - 25,
      )
      ..quadraticBezierTo(
        center.dx + 11,
        center.dy - 16,
        center.dx,
        center.dy - 2,
      )
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeadingConePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _NearbyDriverMapMarker extends StatefulWidget {
  const _NearbyDriverMapMarker({
    required this.icon,
    required this.isHighlighted,
  });

  final IconData icon;
  final bool isHighlighted;

  @override
  State<_NearbyDriverMapMarker> createState() => _NearbyDriverMapMarkerState();
}

class _NearbyDriverMapMarkerState extends State<_NearbyDriverMapMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isHighlighted;
    final markerCore = Container(
      width: isHighlighted ? 52 : 44,
      height: isHighlighted ? 52 : 44,
      decoration: BoxDecoration(
        color: const Color(0xFFFACC15),
        shape: BoxShape.circle,
        border: Border.all(
          color: isHighlighted ? Colors.white : const Color(0xFFFFF7CC),
          width: isHighlighted ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x55FACC15),
            blurRadius: isHighlighted ? 18 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        widget.icon,
        color: const Color(0xFF111827),
        size: isHighlighted ? 28 : 24,
      ),
    );

    if (!isHighlighted) {
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x2234D399),
              ),
            ),
            markerCore,
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseScale = 1 + (_pulseController.value * 0.12);
        final pulseOpacity = 0.16 + ((_pulseController.value) * 0.12);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x331D4ED8),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'Recomendado',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 66,
              height: 66,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(
                          const Color(0x2234D399),
                          const Color(0x4034D399),
                          _pulseController.value,
                        ),
                        border: Border.all(
                          color: const Color(
                            0xFF22C55E,
                          ).withValues(alpha: pulseOpacity),
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x3334D399),
                      border: Border.all(
                        color: const Color(0x6622C55E),
                        width: 1.4,
                      ),
                    ),
                    child: Center(child: markerCore),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NavigationArrowIcon extends StatelessWidget {
  const _NavigationArrowIcon({required this.size, this.headingDegrees});

  final double size;
  final double? headingDegrees;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: ((headingDegrees ?? 0) * (math.pi / 180)) - (math.pi / 8),
      child: Image.asset(
        'assets/images/flecha.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
