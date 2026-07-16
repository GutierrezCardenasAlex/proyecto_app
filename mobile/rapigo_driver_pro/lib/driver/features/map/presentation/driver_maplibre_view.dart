import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../../../../core/config/app_config.dart';
import '../../../../../core/map/map_style_cache.dart';
import '../../../../../core/map/offline_map.dart';
import '../../../../../core/map/rapigo_map_runtime.dart';
import '../../../../../core/map/route_service.dart';

class DriverMapLibreView extends ConsumerStatefulWidget {
  const DriverMapLibreView({
    super.key,
    required this.available,
    required this.tripAccepted,
    required this.driverLat,
    required this.driverLng,
    this.headingDegrees,
    required this.vehicleType,
    this.tripStatus,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.routeColor = const Color(0xFF2979FF),
    this.focusBounds,
    this.focusSignal = 0,
    this.onRouteUpdated,
    this.onOfflineRouteRetained,
    this.routePersistenceKey,
    this.routePersistenceReadKeys,
    this.routePersistenceWriteKeys,
    this.prefetchRoutePersistenceKey,
    this.idleZoomLevel,
    this.maxZoomPreference,
    this.idleTilt,
    this.idleBearingOverride,
    this.navigationTilt,
    this.driverMarkerScale,
    this.driverMarkerOffsetX,
    this.driverMarkerOffsetY,
    this.driverMarkerStyle,
    this.initialCenter,
    this.initialZoom,
    this.initialBearing,
    this.preserveInitialViewport = false,
    this.lockToFocusBounds = false,
    this.onMapReady,
    this.onDebugTelemetryChanged,
    this.onCameraViewportChanged,
    required this.onHardFailure,
  });

  final bool available;
  final bool tripAccepted;
  final double driverLat;
  final double driverLng;
  final double? headingDegrees;
  final String vehicleType;
  final String? tripStatus;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final Color routeColor;
  final LatLngBounds? focusBounds;
  final int focusSignal;
  final VoidCallback? onRouteUpdated;
  final VoidCallback? onOfflineRouteRetained;
  final String? routePersistenceKey;
  final List<String>? routePersistenceReadKeys;
  final List<String>? routePersistenceWriteKeys;
  final String? prefetchRoutePersistenceKey;
  final double? idleZoomLevel;
  final double? maxZoomPreference;
  final double? idleTilt;
  final double? idleBearingOverride;
  final double? navigationTilt;
  final double? driverMarkerScale;
  final double? driverMarkerOffsetX;
  final double? driverMarkerOffsetY;
  final String? driverMarkerStyle;
  final ll.LatLng? initialCenter;
  final double? initialZoom;
  final double? initialBearing;
  final bool preserveInitialViewport;
  final bool lockToFocusBounds;
  final VoidCallback? onMapReady;
  final void Function({
    required double centerLat,
    required double centerLng,
    required double zoom,
    required double tilt,
    required double cameraBearing,
    required double iconBearing,
    required double displayLat,
    required double displayLng,
  })?
  onDebugTelemetryChanged;
  final void Function(
    double centerLat,
    double centerLng,
    double zoom,
    double bearing,
  )?
  onCameraViewportChanged;
  final VoidCallback onHardFailure;

  @override
  ConsumerState<DriverMapLibreView> createState() => _DriverMapLibreViewState();
}

class _DriverMapLibreViewState extends ConsumerState<DriverMapLibreView>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  static const Duration _followLoopInterval = Duration(milliseconds: 110);
  static const Duration _idleRoadSnapCooldown = Duration(milliseconds: 850);
  ml.MapLibreMapController? _controller;
  RoutePathBundle? _routeBundle;
  String? _routeKey;
  bool _styleLoaded = false;
  bool _isSyncingScene = false;
  bool _didFail = false;
  Timer? _failSafeTimer;
  Timer? _resumeSettleTimer;
  Timer? _followLoopTimer;
  DateTime? _lastIdleRoadSnapAt;
  String? _resolvedStyleString;
  final Set<String> _loadedDriverMarkerImageIds = <String>{};
  bool _pickupMarkerImageLoaded = false;
  bool _destinationMarkerImageLoaded = false;
  bool _preserveViewportOnResume = false;
  bool _initialViewportLocked = false;
  ml.Circle? _driverHaloOuterCircle;
  ml.Circle? _driverHaloInnerCircle;
  ml.Symbol? _driverSymbol;
  ml.Circle? _targetHaloCircle;
  ml.Symbol? _targetSymbol;
  ml.Circle? _secondaryTargetHaloCircle;
  ml.Symbol? _secondaryTargetSymbol;
  ll.LatLng? _lastRouteRefreshDriverPoint;
  ll.LatLng? _lastAnimatedCameraTarget;
  double? _lastAnimatedCameraZoom;
  double? _lastAnimatedCameraBearing;
  double? _lastPersistedCenterLat;
  double? _lastPersistedCenterLng;
  double? _lastPersistedZoom;
  double? _lastPersistedBearing;
  double _currentCameraCenterLat = 0;
  double _currentCameraCenterLng = 0;
  double _currentCameraZoom = AppConfig.mapInitialZoom;
  double _currentCameraTilt = 48;
  double _currentCameraBearing = 0;
  DateTime? _lastCameraAnimationAt;
  bool _routeLayersReady = false;
  ll.LatLng? _displayDriverPoint;
  ll.LatLng? _idleRoadSnapPoint;
  ll.LatLng? _lastRoadSnapSourcePoint;
  ll.LatLng? _lastRawDriverPoint;
  ll.LatLng? _lastRouteSourceVisualPoint;
  DateTime? _lastRouteSourceUpdatedAt;
  DateTime? _lastRawDriverAt;
  double _estimatedSpeedMps = 0;
  double? _idleMarkerBearing;
  bool _isRefreshingIdleRoadSnap = false;

  static const String _driverMarkerImageId = 'rapigo_driver_navigation_marker';
  static const String _pickupMarkerImageId = 'rapigo_trip_pickup_marker_a';
  static const String _destinationMarkerImageId =
      'rapigo_trip_destination_marker_b';
  static const String _routeSourceId = 'rapigo_driver_route_source';
  static const String _routeCasingLayerId = 'rapigo_driver_route_casing';
  static const String _routeGlowLayerId = 'rapigo_driver_route_glow';
  static const String _routeMainLayerId = 'rapigo_driver_route_main';

  String get _activeDriverMarkerImageId =>
      '${_driverMarkerImageId}_${widget.driverMarkerStyle ?? 'rapigo'}_${_driverMarkerVisualStateKey()}';

  String _driverMarkerVisualStateKey() {
    final status = widget.tripStatus;
    if (status == 'completed') {
      return 'finalizando';
    }
    if (status == 'at_pickup' || status == 'in_progress') {
      return 'con_pasajero';
    }
    if (status == 'accepted' || status == 'arriving') {
      return 'en_camino';
    }
    if (widget.available) {
      return 'libre';
    }
    return 'desconectado';
  }

  static const double _defaultMaxZoom = 16.35;

  @override
  void initState() {
    super.initState();
    _initialViewportLocked = widget.preserveInitialViewport;
    _lastRawDriverPoint = _driverPoint;
    _lastRawDriverAt = DateTime.now();
    _currentCameraCenterLat =
        widget.initialCenter?.latitude ?? widget.driverLat;
    _currentCameraCenterLng =
        widget.initialCenter?.longitude ?? widget.driverLng;
    _currentCameraZoom = widget.initialZoom ?? AppConfig.mapInitialZoom;
    _currentCameraTilt = widget.tripAccepted
        ? (widget.navigationTilt ?? 56)
        : (widget.idleTilt ?? 48);
    _currentCameraBearing = widget.initialBearing ?? 0;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadStyleString());
    _startFailSafe();
    _refreshRoute();
    unawaited(_refreshIdleRoadSnap(force: true));
    _startFollowLoop();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant DriverMapLibreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged =
        oldWidget.driverLat != widget.driverLat ||
        oldWidget.driverLng != widget.driverLng ||
        oldWidget.headingDegrees != widget.headingDegrees;
    final markerVisualChanged =
        oldWidget.driverMarkerStyle != widget.driverMarkerStyle ||
        oldWidget.driverMarkerScale != widget.driverMarkerScale ||
        oldWidget.driverMarkerOffsetX != widget.driverMarkerOffsetX ||
        oldWidget.driverMarkerOffsetY != widget.driverMarkerOffsetY;
    final routeStructureChanged =
        oldWidget.tripStatus != widget.tripStatus ||
        oldWidget.pickupLat != widget.pickupLat ||
        oldWidget.pickupLng != widget.pickupLng ||
        oldWidget.destinationLat != widget.destinationLat ||
        oldWidget.destinationLng != widget.destinationLng;
    final cameraProfileChanged =
        oldWidget.tripAccepted != widget.tripAccepted ||
        oldWidget.idleZoomLevel != widget.idleZoomLevel ||
        oldWidget.maxZoomPreference != widget.maxZoomPreference ||
        oldWidget.idleTilt != widget.idleTilt ||
        oldWidget.idleBearingOverride != widget.idleBearingOverride ||
        oldWidget.navigationTilt != widget.navigationTilt;
    if (routeStructureChanged) {
      _initialViewportLocked = false;
      _refreshRoute();
    } else if (locationChanged) {
      final now = DateTime.now();
      final previousRawPoint = _lastRawDriverPoint;
      final previousRawAt = _lastRawDriverAt;
      if (previousRawPoint != null && previousRawAt != null) {
        final elapsedMs = now.difference(previousRawAt).inMilliseconds;
        if (elapsedMs > 0) {
          final distance = const ll.Distance().as(
            ll.LengthUnit.Meter,
            previousRawPoint,
            _driverPoint,
          );
          final instantSpeed = distance / (elapsedMs / 1000);
          _estimatedSpeedMps =
              (_estimatedSpeedMps * 0.58) + (instantSpeed * 0.42);
        }
      }
      _lastRawDriverPoint = _driverPoint;
      _lastRawDriverAt = now;
      _initialViewportLocked = false;
      unawaited(_refreshIdleRoadSnap());
      if (_shouldRefreshRouteForDriverMovement()) {
        _refreshRoute();
      } else {
        unawaited(_updateDriverVisuals());
        unawaited(_syncCamera());
      }
    } else if (markerVisualChanged) {
      unawaited(_updateDriverVisuals());
    } else if (cameraProfileChanged) {
      _initialViewportLocked = false;
      unawaited(_syncCamera(force: true));
    } else if (oldWidget.focusSignal != widget.focusSignal) {
      _initialViewportLocked = false;
      unawaited(_syncCamera(force: true));
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
    widget.onCameraViewportChanged?.call(
      camera.target.latitude,
      camera.target.longitude,
      camera.zoom,
      camera.bearing,
    );
  }

  void _emitDebugTelemetry() {
    final point = _visualDriverPoint();
    widget.onDebugTelemetryChanged?.call(
      centerLat: _currentCameraCenterLat,
      centerLng: _currentCameraCenterLng,
      zoom: _currentCameraZoom,
      tilt: _currentCameraTilt,
      cameraBearing: _currentCameraBearing,
      iconBearing: _driverMarkerRotation,
      displayLat: point.latitude,
      displayLng: point.longitude,
    );
  }

  ll.LatLng _smoothedTarget(ll.LatLng target) {
    final previous = _lastAnimatedCameraTarget;
    if (previous == null) {
      return target;
    }
    final distanceMeters = const ll.Distance().as(
      ll.LengthUnit.Meter,
      previous,
      target,
    );
    final factor = widget.tripAccepted
        ? distanceMeters > 30
              ? 0.58
              : distanceMeters > 14
              ? 0.46
              : distanceMeters > 6
              ? 0.34
              : 0.24
        : distanceMeters > 26
        ? 0.54
        : distanceMeters > 12
        ? 0.40
        : distanceMeters > 5
        ? 0.28
        : 0.18;
    final next = ll.LatLng(
      previous.latitude + ((target.latitude - previous.latitude) * factor),
      previous.longitude + ((target.longitude - previous.longitude) * factor),
    );
    return next;
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
      _routeGeoJson(const <ll.LatLng>[]),
    );
    await controller.addLineLayer(
      _routeSourceId,
      _routeCasingLayerId,
      const ml.LineLayerProperties(
        lineColor: '#082D57',
        lineOpacity: 0.88,
        lineWidth: 10.6,
        lineBlur: 0.12,
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    await controller.addLineLayer(
      _routeSourceId,
      _routeGlowLayerId,
      const ml.LineLayerProperties(
        lineColor: '#6EE7FF',
        lineOpacity: 0.18,
        lineWidth: 15.2,
        lineBlur: 1.02,
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    await controller.addLineLayer(
      _routeSourceId,
      _routeMainLayerId,
      const ml.LineLayerProperties(
        lineColor: '#3EDBFF',
        lineOpacity: 0.96,
        lineWidth: 6.6,
        lineBlur: 0.08,
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    _routeLayersReady = true;
  }

  Map<String, dynamic> _routeGeoJson(List<ll.LatLng> route) {
    final visibleRoute = _visibleRoute(route);
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'Feature',
          'properties': const <String, dynamic>{},
          'geometry': <String, dynamic>{
            'type': 'LineString',
            'coordinates': visibleRoute
                .map((point) => <double>[point.longitude, point.latitude])
                .toList(growable: false),
          },
        },
      ],
    };
  }

  List<ll.LatLng> _visibleRoute(List<ll.LatLng> route) {
    if (!widget.tripAccepted || widget.lockToFocusBounds || route.length < 2) {
      return route;
    }
    final visualPoint = _visualDriverPoint();
    final snapped = _nearestPointOnPolyline(visualPoint, route);
    final distanceMeters = const ll.Distance().as(
      ll.LengthUnit.Meter,
      visualPoint,
      snapped.point,
    );
    if (distanceMeters > 52) {
      return route;
    }
    final remaining = <ll.LatLng>[snapped.point];
    remaining.addAll(route.skip(snapped.segmentIndex + 1));
    if (remaining.length < 2) {
      remaining.add(route.last);
    }
    return remaining;
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

  ll.LatLng get _driverPoint => ll.LatLng(widget.driverLat, widget.driverLng);

  ll.LatLng? get _pickupPoint =>
      widget.pickupLat != null && widget.pickupLng != null
      ? ll.LatLng(widget.pickupLat!, widget.pickupLng!)
      : null;

  ll.LatLng? get _destinationPoint =>
      widget.destinationLat != null && widget.destinationLng != null
      ? ll.LatLng(widget.destinationLat!, widget.destinationLng!)
      : null;

  bool get _showsPreviewTripRoute =>
      widget.lockToFocusBounds &&
      _pickupPoint != null &&
      _destinationPoint != null;

  ll.LatLng get _routeStartPoint =>
      _showsPreviewTripRoute ? _pickupPoint! : _driverPoint;

  ll.LatLng? get _routeEndPoint =>
      _showsPreviewTripRoute ? _destinationPoint : _routePoint;

  bool get _isOnDestinationStage =>
      widget.tripStatus == 'in_progress' || widget.tripStatus == 'completed';

  ll.LatLng? get _routePoint =>
      _isOnDestinationStage ? _destinationPoint : _pickupPoint;

  List<String> _normalizedRouteReadKeys() {
    final keys = <String>[];
    final primary = widget.routePersistenceKey?.trim();
    if (primary != null && primary.isNotEmpty) {
      keys.add(primary);
    }
    for (final item in widget.routePersistenceReadKeys ?? const <String>[]) {
      final normalized = item.trim();
      if (normalized.isNotEmpty && !keys.contains(normalized)) {
        keys.add(normalized);
      }
    }
    return keys;
  }

  List<String> _normalizedRouteWriteKeys() {
    final keys = <String>[];
    final primary = widget.routePersistenceKey?.trim();
    if (primary != null && primary.isNotEmpty) {
      keys.add(primary);
    }
    for (final item in widget.routePersistenceWriteKeys ?? const <String>[]) {
      final normalized = item.trim();
      if (normalized.isNotEmpty && !keys.contains(normalized)) {
        keys.add(normalized);
      }
    }
    return keys;
  }

  Future<RoutePathBundle?> _readFirstPersistedBundle(
    RouteService routeService,
    List<String> keys,
  ) async {
    for (final key in keys) {
      final bundle = await routeService.readNamedBundle(key);
      if (bundle != null && bundle.primary.length >= 2) {
        return bundle;
      }
    }
    return null;
  }

  Future<void> _writePersistedBundle(
    RouteService routeService,
    List<String> keys,
    RoutePathBundle bundle,
  ) async {
    for (final key in keys) {
      await routeService.writeNamedBundle(key, bundle);
    }
  }

  Future<void> _prefetchStageDestinationRoute(RouteService routeService) async {
    final prefetchKey = widget.prefetchRoutePersistenceKey?.trim();
    if (prefetchKey == null || prefetchKey.isEmpty) {
      return;
    }
    final pickup = _pickupPoint;
    final destination = _destinationPoint;
    if (pickup == null || destination == null) {
      return;
    }
    final existing = await routeService.readNamedBundle(prefetchKey);
    if (existing != null && existing.primary.length >= 2) {
      return;
    }
    try {
      final bundle = await routeService.fetchRouteBundle(
        start: pickup,
        end: destination,
        allowDirectFallback: false,
      );
      if (bundle.primary.length >= 2) {
        await routeService.writeNamedBundle(prefetchKey, bundle);
      }
    } catch (_) {
      // Keep silent: prefetch is best-effort and must never break the current map.
    }
  }

  ll.LatLng _visualDriverPoint() {
    final animated = _displayDriverPoint;
    if (animated != null) {
      return animated;
    }
    return _targetDriverPoint();
  }

  ll.LatLng _targetDriverPoint() {
    final route = _routeBundle?.primary;
    if (widget.lockToFocusBounds) {
      return _driverPoint;
    }
    if (!widget.tripAccepted) {
      return _idleRoadSnapPoint ?? _driverPoint;
    }
    if (!widget.tripAccepted || route == null || route.length < 2) {
      return _driverPoint;
    }
    return _snapHardToRoute(_driverPoint, route);
  }

  ll.LatLng _projectPointMeters(
    ll.LatLng origin,
    double bearingDegrees,
    double distanceMeters,
  ) {
    final angularDistance = distanceMeters / 6378137.0;
    final bearing = bearingDegrees * 0.017453292519943295;
    final lat1 = origin.latitude * 0.017453292519943295;
    final lon1 = origin.longitude * 0.017453292519943295;
    final sinLat1 = math.sin(lat1);
    final cosLat1 = math.cos(lat1);
    final sinAd = math.sin(angularDistance);
    final cosAd = math.cos(angularDistance);

    final lat2 = math.asin(
      (sinLat1 * cosAd) + (cosLat1 * sinAd * math.cos(bearing)),
    );
    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearing) * sinAd * cosLat1,
          cosAd - (sinLat1 * math.sin(lat2)),
        );
    return ll.LatLng(lat2 * 57.29577951308232, lon2 * 57.29577951308232);
  }

  ll.LatLng _idleCameraTarget() {
    final point = _targetDriverPoint();
    final bearing = widget.idleBearingOverride ?? _currentCameraBearing;
    if (bearing.isNaN || bearing.isInfinite) {
      return point;
    }
    final metersAhead = _estimatedSpeedMps > 10
        ? 68.0
        : _estimatedSpeedMps > 5
        ? 52.0
        : 38.0;
    return _projectPointMeters(point, bearing, metersAhead);
  }

  double get _driverMarkerRotation {
    if (widget.tripAccepted) {
      final route = _routeBundle?.primary;
      final currentPoint = _visualDriverPoint();
      if (route != null && route.length >= 2) {
        final routeBearing = _navigationMarkerBearing(currentPoint, route);
        final viewportRelativeBearing = routeBearing - _currentCameraBearing;
        final normalized = viewportRelativeBearing % 360;
        return normalized < 0 ? normalized + 360 : normalized;
      }
      final heading = widget.headingDegrees ?? 0;
      final viewportRelativeBearing = heading - _currentCameraBearing;
      final normalized = viewportRelativeBearing % 360;
      return normalized < 0 ? normalized + 360 : normalized;
    }
    if (!widget.tripAccepted) {
      if (widget.idleBearingOverride != null) {
        return 0;
      }
      final idleBearing = _idleMarkerBearing ?? 0;
      if (idleBearing.isNaN || idleBearing.isInfinite) {
        return 0;
      }
      final viewportRelativeBearing = idleBearing - _currentCameraBearing;
      final normalized = viewportRelativeBearing % 360;
      return normalized < 0 ? normalized + 360 : normalized;
    }
    return 0;
  }

  void _startFollowLoop() {
    _followLoopTimer?.cancel();
    _followLoopTimer = Timer.periodic(_followLoopInterval, (_) {
      _tickFollowLoop();
    });
  }

  void _tickFollowLoop() {
    if (!mounted) {
      return;
    }
    final targetPoint = _targetDriverPoint();
    final currentPoint = _displayDriverPoint ?? targetPoint;
    final distanceMeters = const ll.Distance().as(
      ll.LengthUnit.Meter,
      currentPoint,
      targetPoint,
    );
    var pointFactor = widget.tripAccepted
        ? distanceMeters > 18
              ? 0.36
              : distanceMeters > 8
              ? 0.29
              : 0.22
        : distanceMeters > 18
        ? 0.62
        : distanceMeters > 8
        ? 0.50
        : 0.36;
    if (!widget.tripAccepted && _idleRoadSnapPoint != null) {
      pointFactor = distanceMeters > 12
          ? 0.82
          : distanceMeters > 4
          ? 0.68
          : 0.54;
    }
    if (widget.tripAccepted) {
      final speedBoost = _estimatedSpeedMps > 16
          ? 0.22
          : _estimatedSpeedMps > 10
          ? 0.16
          : _estimatedSpeedMps > 5
          ? 0.10
          : 0.04;
      pointFactor += speedBoost;
      final route = _routeBundle?.primary;
      if (route != null && route.length >= 2) {
        final routeBearing = _navigationCameraBearing(currentPoint, route);
        final referenceBearing = _lastAnimatedCameraBearing ?? routeBearing;
        var turnDelta = (routeBearing - referenceBearing) % 360;
        if (turnDelta > 180) {
          turnDelta -= 360;
        } else if (turnDelta < -180) {
          turnDelta += 360;
        }
        if (turnDelta.abs() > 18) {
          pointFactor += 0.14;
        } else if (turnDelta.abs() > 8) {
          pointFactor += 0.08;
        }
      }
      pointFactor = pointFactor.clamp(0.24, 0.72);
    }
    final snapThresholdMeters = widget.tripAccepted
        ? 0.18
        : (_idleRoadSnapPoint != null ? 1.15 : 0.32);
    final nextPoint = distanceMeters < snapThresholdMeters
        ? targetPoint
        : ll.LatLng(
            currentPoint.latitude +
                ((targetPoint.latitude - currentPoint.latitude) * pointFactor),
            currentPoint.longitude +
                ((targetPoint.longitude - currentPoint.longitude) *
                    pointFactor),
          );

    final movedEnough = distanceMeters > (widget.tripAccepted ? 0.16 : 0.08);

    if (!widget.tripAccepted) {
      final headingDistance = const ll.Distance().as(
        ll.LengthUnit.Meter,
        currentPoint,
        nextPoint,
      );
      if (_lastRoadSnapSourcePoint != null &&
          _idleRoadSnapPoint != null &&
          const ll.Distance().as(
                ll.LengthUnit.Meter,
                _lastRoadSnapSourcePoint!,
                _idleRoadSnapPoint!,
              ) >
              0.45) {
        _idleMarkerBearing = _smoothIdleBearing(
          _bearingBetween(_lastRoadSnapSourcePoint!, _idleRoadSnapPoint!),
        );
      } else if (headingDistance > 0.45) {
        _idleMarkerBearing = _smoothIdleBearing(
          _bearingBetween(currentPoint, nextPoint),
        );
      }
    }

    _displayDriverPoint = nextPoint;

    if (!movedEnough) {
      return;
    }

    if (_controller != null && _styleLoaded && !_isSyncingScene) {
      unawaited(_updateDriverVisuals());
      if (!widget.lockToFocusBounds &&
          (widget.tripAccepted || widget.available)) {
        unawaited(_syncCamera());
      }
    }
    _emitDebugTelemetry();
  }

  double _bearingBetween(ll.LatLng from, ll.LatLng to) {
    final lat1 = from.latitude * 0.017453292519943295;
    final lat2 = to.latitude * 0.017453292519943295;
    final dLon = (to.longitude - from.longitude) * 0.017453292519943295;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        (math.cos(lat1) * math.sin(lat2)) -
        (math.sin(lat1) * math.cos(lat2) * math.cos(dLon));
    final bearing = math.atan2(y, x) * 57.29577951308232;
    return (bearing + 360) % 360;
  }

  double _smoothIdleBearing(double targetBearing) {
    final previous = _idleMarkerBearing;
    if (previous == null || previous.isNaN || previous.isInfinite) {
      return targetBearing;
    }
    var delta = (targetBearing - previous) % 360;
    if (delta > 180) {
      delta -= 360;
    } else if (delta < -180) {
      delta += 360;
    }
    final factor = delta.abs() > 35
        ? 0.34
        : delta.abs() > 16
        ? 0.22
        : 0.12;
    final next = previous + (delta * factor);
    final normalized = next % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  ll.LatLng _snapHardToRoute(ll.LatLng current, List<ll.LatLng> route) {
    final snapped = _nearestPointOnPolyline(current, route);
    final distanceMeters = const ll.Distance().as(
      ll.LengthUnit.Meter,
      current,
      snapped.point,
    );
    if (distanceMeters > 55) {
      return current;
    }
    if (distanceMeters <= 6) {
      return snapped.point;
    }
    final factor = distanceMeters <= 16 ? 0.94 : 0.82;
    return ll.LatLng(
      current.latitude + ((snapped.point.latitude - current.latitude) * factor),
      current.longitude +
          ((snapped.point.longitude - current.longitude) * factor),
    );
  }

  _SnappedRoutePoint _nearestPointOnPolyline(
    ll.LatLng point,
    List<ll.LatLng> route,
  ) {
    var bestPoint = route.first;
    var bestDistance = double.infinity;
    var bestIndex = 0;
    for (var i = 0; i < route.length - 1; i++) {
      final candidate = _projectPointToSegment(point, route[i], route[i + 1]);
      final distance = const ll.Distance().as(
        ll.LengthUnit.Meter,
        point,
        candidate,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        bestPoint = candidate;
        bestIndex = i;
      }
    }
    return _SnappedRoutePoint(point: bestPoint, segmentIndex: bestIndex);
  }

  ll.LatLng _routeLookAheadTarget(
    ll.LatLng current,
    List<ll.LatLng> route, {
    required double metersAhead,
  }) {
    if (route.length < 2) {
      return current;
    }
    final snapped = _nearestPointOnPolyline(current, route);
    var remaining = metersAhead;
    var anchor = snapped.point;
    for (var i = snapped.segmentIndex + 1; i < route.length; i++) {
      final next = route[i];
      final legDistance = const ll.Distance().as(
        ll.LengthUnit.Meter,
        anchor,
        next,
      );
      if (legDistance >= remaining) {
        final ratio = legDistance <= 0.01
            ? 1.0
            : (remaining / legDistance).clamp(0.0, 1.0);
        return ll.LatLng(
          anchor.latitude + ((next.latitude - anchor.latitude) * ratio),
          anchor.longitude + ((next.longitude - anchor.longitude) * ratio),
        );
      }
      remaining -= legDistance;
      anchor = next;
    }
    return route.last;
  }

  double _navigationCameraBearing(ll.LatLng current, List<ll.LatLng> route) {
    final target = _routeLookAheadTarget(
      current,
      route,
      metersAhead: _isOnDestinationStage ? 84 : 66,
    );
    final routeBearing = _bearingBetween(current, target);
    if (routeBearing.isNaN || routeBearing.isInfinite) {
      return 0;
    }
    return routeBearing;
  }

  double _navigationMarkerBearing(ll.LatLng current, List<ll.LatLng> route) {
    final target = _routeLookAheadTarget(
      current,
      route,
      metersAhead: _isOnDestinationStage ? 28 : 22,
    );
    final routeBearing = _bearingBetween(current, target);
    if (routeBearing.isNaN || routeBearing.isInfinite) {
      return 0;
    }
    return routeBearing;
  }

  double _smoothedBearing(double targetBearing) {
    final previous = _lastAnimatedCameraBearing;
    if (previous == null) {
      return targetBearing;
    }
    var delta = (targetBearing - previous) % 360;
    if (delta > 180) {
      delta -= 360;
    } else if (delta < -180) {
      delta += 360;
    }
    final factor = delta.abs() > 45
        ? 0.28
        : delta.abs() > 18
        ? 0.22
        : 0.16;
    final next = previous + (delta * factor);
    final normalized = next % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  ll.LatLng _projectPointToSegment(ll.LatLng p, ll.LatLng a, ll.LatLng b) {
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
    return ll.LatLng(ay + (aby * clamped), ax + (abx * clamped));
  }

  Future<void> _refreshRoute() async {
    final routeStart = _routeStartPoint;
    final routeEnd = _routeEndPoint;
    if (!widget.tripAccepted || routeEnd == null) {
      if (mounted) {
        setState(() {
          _routeBundle = null;
          _routeKey = null;
          _lastRouteSourceVisualPoint = null;
          _lastRouteSourceUpdatedAt = null;
          _lastRouteRefreshDriverPoint = _driverPoint;
        });
      }
      unawaited(_syncScene());
      return;
    }

    final nextKey =
        '${routeStart.latitude.toStringAsFixed(5)},${routeStart.longitude.toStringAsFixed(5)}>'
        '${routeEnd.latitude.toStringAsFixed(5)},${routeEnd.longitude.toStringAsFixed(5)}>'
        '${widget.tripStatus}';
    if (_routeKey == nextKey) {
      unawaited(_syncScene());
      return;
    }

    final routeService = ref.read(routeServiceProvider);
    final readKeys = _normalizedRouteReadKeys();
    final writeKeys = _normalizedRouteWriteKeys();
    if (readKeys.isNotEmpty) {
      final cachedBundle = await _readFirstPersistedBundle(
        routeService,
        readKeys,
      );
      if (cachedBundle != null && mounted) {
        setState(() {
          _routeBundle = cachedBundle;
          _lastRouteSourceVisualPoint = null;
          _lastRouteSourceUpdatedAt = null;
          _lastRouteRefreshDriverPoint = _driverPoint;
        });
        await _syncScene();
        widget.onRouteUpdated?.call();
      }
    }

    final preserveCachedRoute = readKeys.isNotEmpty;

    try {
      final bundle = await routeService.fetchRouteBundle(
        start: routeStart,
        end: routeEnd,
        allowDirectFallback: !preserveCachedRoute,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _routeKey = nextKey;
        _routeBundle = bundle;
        _lastRouteSourceVisualPoint = null;
        _lastRouteSourceUpdatedAt = null;
        _lastRouteRefreshDriverPoint = _driverPoint;
      });
      if (writeKeys.isNotEmpty) {
        await _writePersistedBundle(routeService, writeKeys, bundle);
      }
      await _prefetchStageDestinationRoute(routeService);
      widget.onRouteUpdated?.call();
      await _syncScene();
    } catch (_) {
      if (!mounted) {
        return;
      }
      final cachedBundle = readKeys.isEmpty
          ? null
          : await _readFirstPersistedBundle(routeService, readKeys);
      setState(() {
        _routeKey = nextKey;
        _routeBundle =
            cachedBundle ??
            RoutePathBundle(
              primary: [routeStart, routeEnd],
              start: routeStart,
              end: routeEnd,
            );
        _lastRouteSourceVisualPoint = null;
        _lastRouteSourceUpdatedAt = null;
        _lastRouteRefreshDriverPoint = _driverPoint;
      });
      if (cachedBundle != null && cachedBundle.primary.length >= 2) {
        widget.onOfflineRouteRetained?.call();
        widget.onRouteUpdated?.call();
      } else {
        widget.onRouteUpdated?.call();
      }
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
          route != null && route.length >= 2 ? route : const <ll.LatLng>[],
        ),
      );

      await _upsertDriverMarker(controller);
      await _upsertTripMarkers(controller);
      await _syncCamera();
    } catch (_) {
      _triggerFallback();
    } finally {
      _isSyncingScene = false;
    }
  }

  Future<void> _refreshIdleRoadSnap({bool force = false}) async {
    if (widget.tripAccepted || widget.lockToFocusBounds) {
      _idleRoadSnapPoint = null;
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _lastIdleRoadSnapAt != null &&
        now.difference(_lastIdleRoadSnapAt!) < _idleRoadSnapCooldown) {
      return;
    }
    final previous = _lastRoadSnapSourcePoint;
    if (!force && previous != null) {
      final delta = const ll.Distance().as(
        ll.LengthUnit.Meter,
        previous,
        _driverPoint,
      );
      if (delta < 3.5) {
        return;
      }
    }
    if (_isRefreshingIdleRoadSnap) {
      return;
    }
    _isRefreshingIdleRoadSnap = true;
    final sourcePoint = _driverPoint;
    final previousSnapped = _idleRoadSnapPoint;
    _lastIdleRoadSnapAt = now;
    _lastRoadSnapSourcePoint = sourcePoint;
    try {
      final snapped = await ref
          .read(routeServiceProvider)
          .snapToRoadIfPossible(sourcePoint);
      if (!mounted || widget.tripAccepted || widget.lockToFocusBounds) {
        return;
      }
      _idleRoadSnapPoint = snapped;
      final snappedDelta = previousSnapped == null
          ? const ll.Distance().as(ll.LengthUnit.Meter, sourcePoint, snapped)
          : const ll.Distance().as(
              ll.LengthUnit.Meter,
              previousSnapped,
              snapped,
            );
      if (snappedDelta > 0.55) {
        final bearingAnchor = previousSnapped ?? sourcePoint;
        _idleMarkerBearing = _smoothIdleBearing(
          _bearingBetween(bearingAnchor, snapped),
        );
      }
      if (_controller != null && _styleLoaded && !_isSyncingScene) {
        await _updateDriverVisuals();
        await _syncCamera();
      }
    } catch (_) {
      _idleRoadSnapPoint = null;
    } finally {
      _isRefreshingIdleRoadSnap = false;
    }
  }

  Future<void> _upsertDriverMarker(ml.MapLibreMapController controller) async {
    final point = _toMlLatLng(_visualDriverPoint());
    final iconScale = widget.driverMarkerScale ?? 1.56;
    final iconOffset = Offset(
      widget.driverMarkerOffsetX ?? 0,
      widget.driverMarkerOffsetY ?? 0,
    );
    await _ensureDriverMarkerImage(controller);
    if (_driverHaloOuterCircle != null || _driverHaloInnerCircle != null) {
      if (_driverHaloOuterCircle != null) {
        await controller.removeCircle(_driverHaloOuterCircle!);
        _driverHaloOuterCircle = null;
      }
      if (_driverHaloInnerCircle != null) {
        await controller.removeCircle(_driverHaloInnerCircle!);
        _driverHaloInnerCircle = null;
      }
    }
    if (_driverSymbol == null) {
      _driverSymbol = await controller.addSymbol(
        ml.SymbolOptions(
          geometry: point,
          iconImage: _activeDriverMarkerImageId,
          iconSize: iconScale,
          iconRotate: _driverMarkerRotation,
          iconOffset: iconOffset,
          iconAnchor: 'center',
        ),
      );
    } else {
      await controller.updateSymbol(
        _driverSymbol!,
        ml.SymbolOptions(
          geometry: point,
          iconImage: _activeDriverMarkerImageId,
          iconSize: iconScale,
          iconRotate: _driverMarkerRotation,
          iconOffset: iconOffset,
        ),
      );
    }
  }

  bool _shouldRefreshRouteForDriverMovement() {
    if (!widget.tripAccepted ||
        _routeEndPoint == null ||
        widget.lockToFocusBounds) {
      return false;
    }
    final previous = _lastRouteRefreshDriverPoint;
    if (previous == null) {
      return true;
    }
    final distance = const ll.Distance().as(
      ll.LengthUnit.Meter,
      previous,
      _driverPoint,
    );
    return distance >= 8;
  }

  Future<void> _updateDriverVisuals() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || _isSyncingScene) {
      return;
    }

    try {
      final route = _routeBundle?.primary;
      if (widget.tripAccepted &&
          route != null &&
          route.length >= 2 &&
          _shouldUpdateRouteSource()) {
        await controller.setGeoJsonSource(_routeSourceId, _routeGeoJson(route));
      }
      await _upsertDriverMarker(controller);
    } catch (_) {
      await _syncScene();
    }
  }

  bool _shouldUpdateRouteSource() {
    final visualPoint = _visualDriverPoint();
    final previousPoint = _lastRouteSourceVisualPoint;
    final previousAt = _lastRouteSourceUpdatedAt;
    final now = DateTime.now();
    final movedMeters = previousPoint == null
        ? double.infinity
        : const ll.Distance().as(
            ll.LengthUnit.Meter,
            previousPoint,
            visualPoint,
          );
    final elapsed = previousAt == null ? null : now.difference(previousAt);
    if (movedMeters < 1.2 &&
        elapsed != null &&
        elapsed < const Duration(milliseconds: 700)) {
      return false;
    }
    _lastRouteSourceVisualPoint = visualPoint;
    _lastRouteSourceUpdatedAt = now;
    return true;
  }

  double _routeDistanceMeters(List<ll.LatLng> route) {
    if (route.length < 2) {
      return 0;
    }
    var total = 0.0;
    for (var index = 0; index < route.length - 1; index++) {
      total += const ll.Distance().as(
        ll.LengthUnit.Meter,
        route[index],
        route[index + 1],
      );
    }
    return total;
  }

  double? _remainingNavigationDistanceMeters() {
    final target = _routePoint;
    if (!widget.tripAccepted || target == null) {
      return null;
    }
    final route = _routeBundle?.primary;
    if (route != null && route.length >= 2) {
      return _routeDistanceMeters(_visibleRoute(route));
    }
    return const ll.Distance().as(
      ll.LengthUnit.Meter,
      _visualDriverPoint(),
      target,
    );
  }

  String _formatNavigationDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters >= 9500 ? 0 : 1)} km';
    }
    return '${meters.clamp(0, double.infinity).round()} m';
  }

  String get _navigationBannerTitle =>
      _isOnDestinationStage ? 'Sigue hacia destino' : 'Sigue hacia recojo';

  String get _navigationBannerSubtitle {
    final distance = _remainingNavigationDistanceMeters();
    final stage = _isOnDestinationStage ? 'Destino' : 'Recojo';
    if (distance == null) {
      return '$stage activo en el mapa';
    }
    return '${_formatNavigationDistance(distance)} restantes';
  }

  Future<void> _ensureDriverMarkerImage(
    ml.MapLibreMapController controller,
  ) async {
    final imageId = _activeDriverMarkerImageId;
    if (_loadedDriverMarkerImageIds.contains(imageId)) {
      return;
    }
    final bytes = await _buildDriverMarkerImageBytes();
    await controller.addImage(imageId, bytes);
    _loadedDriverMarkerImageIds.add(imageId);
  }

  Path _navigationSvgRepoMarkerPath() {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(21.81, 34.75)
      ..lineTo(21.5, 34.75)
      ..arcToPoint(const Offset(18, 31.58), radius: const Radius.circular(3.8))
      ..lineTo(16, 20.12)
      ..arcToPoint(
        const Offset(14.88, 19),
        radius: const Radius.circular(1.36),
        clockwise: false,
      )
      ..lineTo(3.42, 17)
      ..arcToPoint(
        const Offset(2.86, 9.58),
        radius: const Radius.circular(3.84),
      )
      ..lineTo(29.66, 0.46)
      ..arcToPoint(
        const Offset(34.54, 5.34),
        radius: const Radius.circular(3.84),
      )
      ..lineTo(25.43, 32.14)
      ..arcToPoint(
        const Offset(21.81, 34.75),
        radius: const Radius.circular(3.79),
      )
      ..close()
      ..moveTo(30.47, 2.83)
      ..lineTo(3.66, 11.94)
      ..arcToPoint(
        const Offset(3.86, 14.53),
        radius: const Radius.circular(1.34),
        clockwise: false,
      )
      ..lineTo(15.32, 16.53)
      ..arcToPoint(
        const Offset(18.43, 19.64),
        radius: const Radius.circular(3.85),
      )
      ..lineTo(20.43, 31.1)
      ..arcToPoint(
        const Offset(23.02, 31.3),
        radius: const Radius.circular(1.34),
        clockwise: false,
      )
      ..lineTo(32.17, 4.53)
      ..arcToPoint(
        const Offset(30.47, 2.83),
        radius: const Radius.circular(1.34),
        clockwise: false,
      )
      ..close();
  }

  void _drawNavigationSvgRepoMarker(
    Canvas canvas,
    Offset center,
    Paint paint, {
    Offset offset = Offset.zero,
  }) {
    canvas.save();
    canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
    canvas.rotate(-math.pi / 3.08);
    canvas.scale(2.55);
    canvas.translate(-17.5, -17.5);
    canvas.drawPath(_navigationSvgRepoMarkerPath(), paint);
    canvas.restore();
  }

  Future<Uint8List> _buildDriverMarkerImageBytes() async {
    const size = 158.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);
    final style = widget.driverMarkerStyle ?? 'rapigo';

    if (style == 'rapigo') {
      const haloColor = Color(0xFF1976FF);
      final haloOuter = Paint()
        ..color = haloColor.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
      final haloInner = Paint()
        ..color = haloColor.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawCircle(center, 36, haloOuter);
      canvas.drawCircle(center, 25, haloInner);

      final groundShadow = Paint()
        ..color = const Color(0x421976FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawOval(
        Rect.fromCenter(center: center.translate(0, 35), width: 34, height: 11),
        groundShadow,
      );

      _drawNavigationSvgRepoMarker(
        canvas,
        center,
        Paint()
          ..color = const Color(0x3A000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        offset: const Offset(0, 5),
      );
      _drawNavigationSvgRepoMarker(
        canvas,
        center,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.94)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 1.55,
      );
      _drawNavigationSvgRepoMarker(
        canvas,
        center,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(center.dx - 28, center.dy - 36),
            Offset(center.dx + 30, center.dy + 36),
            const [Color(0xFF60A5FA), Color(0xFF1976FF), Color(0xFF0B5DE2)],
            const [0, 0.58, 1],
          ),
      );
      canvas.drawCircle(
        center.translate(0, 4),
        4.4,
        Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.82),
      );
      canvas.drawCircle(
        center.translate(0, 4),
        7.4,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    } else {
      final softShadow = Paint()
        ..color = const Color(0x4064748B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
      canvas.drawCircle(center, 38, softShadow);

      canvas.drawCircle(center, 34, Paint()..color = const Color(0x3F94A3B8));

      canvas.drawCircle(center, 29, Paint()..color = const Color(0x19FFFFFF));

      final triangleShadow = Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11);
      Path markerPath;
      if (style == 'triangle') {
        markerPath = Path()
          ..moveTo(center.dx, center.dy - 28)
          ..lineTo(center.dx + 23, center.dy + 18)
          ..lineTo(center.dx - 23, center.dy + 18)
          ..close();
      } else if (style == 'dart') {
        markerPath = Path()
          ..moveTo(center.dx, center.dy - 30)
          ..lineTo(center.dx + 16, center.dy + 10)
          ..lineTo(center.dx + 2, center.dy + 6)
          ..lineTo(center.dx, center.dy + 26)
          ..lineTo(center.dx - 2, center.dy + 6)
          ..lineTo(center.dx - 16, center.dy + 10)
          ..close();
      } else {
        markerPath = Path()
          ..moveTo(center.dx, center.dy - 34)
          ..lineTo(center.dx + 21, center.dy + 14)
          ..lineTo(center.dx + 6, center.dy + 10)
          ..lineTo(center.dx, center.dy + 28)
          ..lineTo(center.dx - 6, center.dy + 10)
          ..lineTo(center.dx - 21, center.dy + 14)
          ..close();
      }
      canvas.drawPath(markerPath.shift(const Offset(0, 3)), triangleShadow);
      canvas.drawPath(markerPath, Paint()..color = const Color(0xFF14C6E8));
      canvas.drawPath(
        markerPath,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _clearTripMarkers(ml.MapLibreMapController controller) async {
    if (_targetHaloCircle != null) {
      await controller.removeCircle(_targetHaloCircle!);
      _targetHaloCircle = null;
    }
    if (_targetSymbol != null) {
      await controller.removeSymbol(_targetSymbol!);
      _targetSymbol = null;
    }
    if (_secondaryTargetHaloCircle != null) {
      await controller.removeCircle(_secondaryTargetHaloCircle!);
      _secondaryTargetHaloCircle = null;
    }
    if (_secondaryTargetSymbol != null) {
      await controller.removeSymbol(_secondaryTargetSymbol!);
      _secondaryTargetSymbol = null;
    }
  }

  Future<void> _upsertTripMarkers(ml.MapLibreMapController controller) async {
    final target = _routePoint;
    if (!widget.tripAccepted || target == null) {
      await _clearTripMarkers(controller);
      return;
    }

    await _ensurePickupMarkerImage(controller);
    await _ensureDestinationMarkerImage(controller);

    final targetPoint = _toMlLatLng(target);
    final targetImageId = _isOnDestinationStage
        ? _destinationMarkerImageId
        : _pickupMarkerImageId;

    if (_targetHaloCircle == null) {
      _targetHaloCircle = await controller.addCircle(
        ml.CircleOptions(
          geometry: targetPoint,
          circleRadius: 28,
          circleColor: _isOnDestinationStage ? '#60A5FA' : '#4ADE80',
          circleOpacity: 0.2,
          circleBlur: 0.92,
        ),
      );
    } else {
      await controller.updateCircle(
        _targetHaloCircle!,
        ml.CircleOptions(
          geometry: targetPoint,
          circleRadius: 28,
          circleColor: _isOnDestinationStage ? '#60A5FA' : '#4ADE80',
        ),
      );
    }
    if (_targetSymbol == null) {
      _targetSymbol = await controller.addSymbol(
        ml.SymbolOptions(
          geometry: targetPoint,
          iconImage: targetImageId,
          iconSize: 1.3,
          iconAnchor: 'bottom',
        ),
      );
    } else {
      await controller.updateSymbol(
        _targetSymbol!,
        ml.SymbolOptions(
          geometry: targetPoint,
          iconImage: targetImageId,
          iconSize: 1.3,
        ),
      );
    }

    if (!_isOnDestinationStage && _destinationPoint != null) {
      final destinationPoint = _toMlLatLng(_destinationPoint!);
      if (_secondaryTargetHaloCircle == null) {
        _secondaryTargetHaloCircle = await controller.addCircle(
          ml.CircleOptions(
            geometry: destinationPoint,
            circleRadius: 24,
            circleColor: '#F87171',
            circleOpacity: 0.18,
            circleBlur: 0.86,
          ),
        );
      } else {
        await controller.updateCircle(
          _secondaryTargetHaloCircle!,
          ml.CircleOptions(geometry: destinationPoint, circleRadius: 24),
        );
      }
      if (_secondaryTargetSymbol == null) {
        _secondaryTargetSymbol = await controller.addSymbol(
          ml.SymbolOptions(
            geometry: destinationPoint,
            iconImage: _destinationMarkerImageId,
            iconSize: 1.22,
            iconAnchor: 'bottom',
          ),
        );
      } else {
        await controller.updateSymbol(
          _secondaryTargetSymbol!,
          ml.SymbolOptions(geometry: destinationPoint, iconSize: 1.22),
        );
      }
    } else {
      if (_secondaryTargetHaloCircle != null) {
        await controller.removeCircle(_secondaryTargetHaloCircle!);
        _secondaryTargetHaloCircle = null;
      }
      if (_secondaryTargetSymbol != null) {
        await controller.removeSymbol(_secondaryTargetSymbol!);
        _secondaryTargetSymbol = null;
      }
    }
  }

  Future<void> _ensurePickupMarkerImage(
    ml.MapLibreMapController controller,
  ) async {
    if (_pickupMarkerImageLoaded) {
      return;
    }
    await controller.addImage(
      _pickupMarkerImageId,
      await _buildWaypointMarkerBytes(
        label: 'A',
        fillColor: const Color(0xFF1DB954),
        glowColor: const Color(0x661DB954),
      ),
    );
    _pickupMarkerImageLoaded = true;
  }

  Future<void> _ensureDestinationMarkerImage(
    ml.MapLibreMapController controller,
  ) async {
    if (_destinationMarkerImageLoaded) {
      return;
    }
    await controller.addImage(
      _destinationMarkerImageId,
      await _buildWaypointMarkerBytes(
        label: 'B',
        fillColor: const Color(0xFFEF4444),
        glowColor: const Color(0x66EF4444),
      ),
    );
    _destinationMarkerImageLoaded = true;
  }

  Future<Uint8List> _buildWaypointMarkerBytes({
    required String label,
    required Color fillColor,
    required Color glowColor,
  }) async {
    const width = 112.0;
    const height = 136.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(const Offset(width / 2, 42), 26, glowPaint);

    final pinPath = Path()
      ..moveTo(width / 2, height - 10)
      ..quadraticBezierTo(width / 2 - 10, height - 26, width / 2 - 22, 84)
      ..arcToPoint(
        const Offset(width / 2 + 22, 84),
        radius: const Radius.circular(30),
        clockwise: false,
      )
      ..quadraticBezierTo(width / 2 + 10, height - 26, width / 2, height - 10)
      ..close();

    canvas.drawPath(pinPath, Paint()..color = fillColor);
    canvas.drawCircle(
      const Offset(width / 2, 42),
      26,
      Paint()..color = fillColor,
    );
    canvas.drawCircle(
      const Offset(width / 2, 42),
      26,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 27,
      fontWeight: FontWeight.w900,
    );
    final textStyle = ui.TextStyle(color: Colors.white);
    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(label);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(paragraph, const Offset(0, 24));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _syncCamera({bool force = false}) async {
    final controller = _controller;
    if (controller == null ||
        !_styleLoaded ||
        _preserveViewportOnResume ||
        _initialViewportLocked) {
      return;
    }

    try {
      final now = DateTime.now();
      if (!force &&
          _lastCameraAnimationAt != null &&
          now.difference(_lastCameraAnimationAt!) <
              const Duration(milliseconds: 140)) {
        return;
      }
      if (widget.lockToFocusBounds && widget.focusBounds != null) {
        final bounds = widget.focusBounds!;
        await controller.animateCamera(
          ml.CameraUpdate.newLatLngBounds(
            ml.LatLngBounds(
              southwest: ml.LatLng(bounds.south, bounds.west),
              northeast: ml.LatLng(bounds.north, bounds.east),
            ),
            left: 54,
            top: 118,
            right: 54,
            bottom: 360,
          ),
        );
        _lastAnimatedCameraTarget = ll.LatLng(
          (bounds.north + bounds.south) / 2,
          (bounds.east + bounds.west) / 2,
        );
        _lastAnimatedCameraZoom = null;
        _lastAnimatedCameraBearing = 0;
        _lastCameraAnimationAt = now;
        return;
      }
      if (widget.tripAccepted && _routePoint != null) {
        final route = _routeBundle?.primary;
        final currentVisualPoint = _visualDriverPoint();
        final desiredTarget = _smoothedTarget(
          route != null && route.length >= 2
              ? _routeLookAheadTarget(
                  currentVisualPoint,
                  route,
                  metersAhead: _isOnDestinationStage ? 112 : 92,
                )
              : currentVisualPoint,
        );
        final nextZoom = math.min(
          _isOnDestinationStage ? 18.15 : 17.85,
          widget.maxZoomPreference ?? _defaultMaxZoom,
        );
        final nextTilt = widget.navigationTilt ?? 56;
        final rawBearing = route != null && route.length >= 2
            ? _navigationCameraBearing(currentVisualPoint, route)
            : 0.0;
        final nextBearing = _smoothedBearing(rawBearing);
        final targetDelta = _lastAnimatedCameraTarget == null
            ? double.infinity
            : const ll.Distance().as(
                ll.LengthUnit.Meter,
                _lastAnimatedCameraTarget!,
                desiredTarget,
              );
        final bearingDelta = _lastAnimatedCameraBearing == null
            ? double.infinity
            : (() {
                var delta = (nextBearing - _lastAnimatedCameraBearing!) % 360;
                if (delta > 180) {
                  delta -= 360;
                } else if (delta < -180) {
                  delta += 360;
                }
                return delta.abs();
              })();
        final tiltDelta = (_currentCameraTilt - nextTilt).abs();
        if (!force &&
            targetDelta < 2.2 &&
            bearingDelta < 2.2 &&
            tiltDelta < 0.8 &&
            _lastAnimatedCameraZoom != null &&
            (_lastAnimatedCameraZoom! - nextZoom).abs() < 0.08) {
          return;
        }
        await controller.animateCamera(
          ml.CameraUpdate.newCameraPosition(
            ml.CameraPosition(
              target: _toMlLatLng(desiredTarget),
              zoom: nextZoom,
              bearing: nextBearing,
              tilt: nextTilt,
            ),
          ),
        );
        _lastAnimatedCameraTarget = desiredTarget;
        _lastAnimatedCameraZoom = nextZoom;
        _lastAnimatedCameraBearing = nextBearing;
        _lastCameraAnimationAt = now;
      } else {
        final desiredTarget = _smoothedTarget(_idleCameraTarget());
        final nextZoom = math.min(
          widget.idleZoomLevel ?? 16.15,
          widget.maxZoomPreference ?? _defaultMaxZoom,
        );
        final nextTilt = widget.idleTilt ?? 48;
        final nextBearing = widget.idleBearingOverride ?? 0;
        final targetDelta = _lastAnimatedCameraTarget == null
            ? double.infinity
            : const ll.Distance().as(
                ll.LengthUnit.Meter,
                _lastAnimatedCameraTarget!,
                desiredTarget,
              );
        final bearingDelta = _lastAnimatedCameraBearing == null
            ? double.infinity
            : (() {
                var delta = (nextBearing - _lastAnimatedCameraBearing!) % 360;
                if (delta > 180) {
                  delta -= 360;
                } else if (delta < -180) {
                  delta += 360;
                }
                return delta.abs();
              })();
        final tiltDelta = (_currentCameraTilt - nextTilt).abs();
        if (!force &&
            targetDelta < 2.2 &&
            bearingDelta < 2.2 &&
            tiltDelta < 0.8 &&
            _lastAnimatedCameraZoom != null &&
            (_lastAnimatedCameraZoom! - nextZoom).abs() < 0.08) {
          return;
        }
        await controller.animateCamera(
          ml.CameraUpdate.newCameraPosition(
            ml.CameraPosition(
              target: _toMlLatLng(desiredTarget),
              zoom: nextZoom,
              bearing: nextBearing,
              tilt: nextTilt,
            ),
          ),
        );
        _lastAnimatedCameraTarget = desiredTarget;
        _lastAnimatedCameraZoom = nextZoom;
        _lastAnimatedCameraBearing = nextBearing;
        _lastCameraAnimationAt = now;
      }
    } catch (_) {
      _triggerFallback();
    }
  }

  ml.LatLng _toMlLatLng(ll.LatLng point) =>
      ml.LatLng(point.latitude, point.longitude);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final styleString = _resolvedStyleString;

    if (styleString == null || styleString.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFC8DCF2),
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
            target: _toMlLatLng(widget.initialCenter ?? _driverPoint),
            zoom: widget.initialZoom ?? AppConfig.mapInitialZoom,
            bearing: widget.initialBearing ?? 0,
          ),
          minMaxZoomPreference: ml.MinMaxZoomPreference(
            12.4,
            widget.maxZoomPreference ?? _defaultMaxZoom,
          ),
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: false,
          compassEnabled: false,
          logoEnabled: false,
          trackCameraPosition: false,
          attributionButtonPosition: ml.AttributionButtonPosition.bottomLeft,
          attributionButtonMargins: const math.Point(-240, -240),
          onMapCreated: (controller) {
            _controller = controller;
          },
          onStyleLoadedCallback: () {
            _styleLoaded = true;
            _loadedDriverMarkerImageIds.clear();
            _pickupMarkerImageLoaded = false;
            _destinationMarkerImageLoaded = false;
            _routeLayersReady = false;
            _driverHaloOuterCircle = null;
            _driverHaloInnerCircle = null;
            _driverSymbol = null;
            _targetHaloCircle = null;
            _targetSymbol = null;
            _secondaryTargetHaloCircle = null;
            _secondaryTargetSymbol = null;
            _failSafeTimer?.cancel();
            widget.onMapReady?.call();
            unawaited(_syncScene());
          },
          onCameraMove: (position) {
            final lat = position.target.latitude;
            final lng = position.target.longitude;
            final zoom = position.zoom;
            final tilt = position.tilt;
            final bearing = position.bearing;
            _currentCameraCenterLat = lat;
            _currentCameraCenterLng = lng;
            _currentCameraZoom = zoom;
            _currentCameraTilt = tilt;
            _currentCameraBearing = bearing;
            _emitDebugTelemetry();
            final shouldPersist =
                _lastPersistedCenterLat == null ||
                _lastPersistedCenterLng == null ||
                _lastPersistedZoom == null ||
                _lastPersistedBearing == null ||
                const ll.Distance().as(
                      ll.LengthUnit.Meter,
                      ll.LatLng(
                        _lastPersistedCenterLat!,
                        _lastPersistedCenterLng!,
                      ),
                      ll.LatLng(lat, lng),
                    ) >
                    8.0 ||
                (_lastPersistedZoom! - zoom).abs() > 0.10 ||
                (_lastPersistedBearing! - bearing).abs() > 2.0;
            if (!shouldPersist) {
              return;
            }
            _lastPersistedCenterLat = lat;
            _lastPersistedCenterLng = lng;
            _lastPersistedZoom = zoom;
            _lastPersistedBearing = bearing;
            widget.onCameraViewportChanged?.call(lat, lng, zoom, bearing);
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
                    const Color(0xFFA9C8EA).withValues(alpha: 0.10),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF87ADD8).withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.tripAccepted && _routePoint != null)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: _DriverMiniNavigationBanner(
                  title: _navigationBannerTitle,
                  subtitle: _navigationBannerSubtitle,
                  accentColor: _isOnDestinationStage
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFFACC15),
                ),
              ),
            ),
          ),
        const Positioned(left: 16, bottom: 16, child: OfflineMapReadyBadge()),
      ],
    );
  }
}

class _DriverMiniNavigationBanner extends StatelessWidget {
  const _DriverMiniNavigationBanner({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE8101829),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.34)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.navigation_rounded,
                color: accentColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC7D2FE),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SnappedRoutePoint {
  const _SnappedRoutePoint({required this.point, required this.segmentIndex});

  final ll.LatLng point;
  final int segmentIndex;
}
