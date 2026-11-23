import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'driver_map_motion.dart';
import 'driver_city_camera_constraint.dart';
import '../../../../../core/config/app_config.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../core/map/offline_map.dart';
import '../../../../../core/map/route_service.dart';

/// Uses the same tile provider and store as the downloaded city pack.
class DriverCachedMap extends ConsumerStatefulWidget {
  const DriverCachedMap({
    super.key,
    required this.driver,
    required this.center,
    required this.zoom,
    required this.routeColor,
    this.markerColor = const Color(0xFF087F5B),
    this.pickup,
    this.destination,
    this.destinationStage = false,
    this.preview = false,
    this.focusSignal = 0,
    this.heading = 0,
    this.readKeys = const [],
    this.writeKeys = const [],
    this.onReady,
    this.onRouteReady,
    this.onOfflineRoute,
    this.onViewport,
  });
  final LatLng driver, center;
  final LatLng? pickup, destination;
  final double zoom, heading;
  final Color routeColor;
  final Color markerColor;
  final bool destinationStage, preview;
  final int focusSignal;
  final List<String> readKeys, writeKeys;
  final VoidCallback? onReady, onRouteReady, onOfflineRoute;
  final void Function(double, double, double, double)? onViewport;
  @override
  ConsumerState<DriverCachedMap> createState() => _DriverCachedMapState();
}

class _DriverCachedMapState extends ConsumerState<DriverCachedMap>
    with TickerProviderStateMixin {
  final _map = MapController();
  late final TileLayer _tiles;
  List<LatLng> _route = const [];
  bool _ready = false;
  bool _follow = true;
  int _generation = 0;
  Timer? _viewportTimer;
  final _rerouteGate = DriverRerouteGate();
  bool _routeLoading = false;
  late final AnimationController _motion;
  late final AnimationController _cameraMotion;
  late LatLng _displayDriver, _driverFrom, _driverTo;
  double _displayHeading = 0, _headingFrom = 0, _headingDelta = 0;
  LatLng? _cameraFrom, _cameraTo;
  double _zoomFrom = 15, _zoomTo = 15;
  Widget? _routeLayer;
  Widget? _stopsLayer;
  final _sampleClock = Stopwatch();
  final _cadence = DriverMotionCadence();
  LatLng? _followFrom;
  bool _followingMotion = false;
  bool _snappingRoad = false;
  LatLng? _roadPoint, _roadSample;

  LatLng _onRoute(LatLng point) {
    if (widget.preview) return point;
    final projected = projectDriverToRoute(point, _route);
    // A real deviation must still trigger rerouting using the original GPS.
    return projected != null && const Distance()(point, projected) <= 60
        ? projected
        : point;
  }

  LatLng get _vehicleTarget {
    final onRoute = _onRoute(widget.driver);
    if (!widget.preview && distanceToDriverRoute(widget.driver, _route) <= 60) {
      return onRoute;
    }
    if (_roadSample == widget.driver && _roadPoint != null) return _roadPoint!;
    return widget.driver;
  }

  Future<void> _snapToStreet() async {
    if (_snappingRoad ||
        (!widget.preview &&
            distanceToDriverRoute(widget.driver, _route) <= 60)) {
      return;
    }
    final sample = widget.driver;
    _snappingRoad = true;
    try {
      final point = await ref
          .read(routeServiceProvider)
          .snapToRoadIfPossible(sample);
      if (!mounted || widget.driver != sample) return;
      _roadSample = sample;
      _roadPoint = point;
      setState(() => _updateVehicle(positionChanged: false));
    } finally {
      _snappingRoad = false;
      if (mounted && widget.driver != sample) unawaited(_snapToStreet());
    }
  }

  LatLng _lerp(LatLng from, LatLng to, double t) => LatLng(
    from.latitude + (to.latitude - from.latitude) * t,
    from.longitude + (to.longitude - from.longitude) * t,
  );

  void _animateCamera(LatLng center, double zoom) {
    if (!_ready) return;
    _followingMotion = false;
    _cameraFrom = _map.camera.center;
    _cameraTo = center;
    _zoomFrom = _map.camera.zoom;
    _zoomTo = zoom.clamp(12, 18);
    if (MediaQuery.disableAnimationsOf(context)) {
      _cameraMotion.stop();
      _map.move(center, _zoomTo);
    } else {
      _cameraMotion.forward(from: 0);
    }
  }

  void _updateVehicle({required bool positionChanged}) {
    final target = _vehicleTarget;
    final moved = const Distance()(_displayDriver, target);
    final heading = widget.heading.isFinite ? widget.heading : _displayHeading;
    if (moved < 2 && shortestHeadingDelta(_displayHeading, heading).abs() < 4) {
      return;
    }
    _motion.duration = positionChanged
        ? _cadence.next(_sampleClock.elapsed)
        : const Duration(milliseconds: 220);
    _followingMotion =
        _ready &&
        _follow &&
        !widget.preview &&
        !_cameraMotion.isAnimating &&
        moved >= 2;
    _followFrom = _followingMotion ? _map.camera.center : null;
    _driverFrom = _displayDriver;
    _driverTo = target;
    _headingFrom = _displayHeading;
    _headingDelta = shortestHeadingDelta(_displayHeading, heading);
    if (moved > 500 || MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _displayDriver = _driverTo;
      _displayHeading = heading;
      if (_followingMotion) _map.move(_driverTo, _map.camera.zoom);
      _followingMotion = false;
      _scheduleViewportSave();
    } else {
      _motion.forward(from: 0);
    }
  }

  void _scheduleViewportSave() {
    _viewportTimer?.cancel();
    _viewportTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || !_ready) return;
      final camera = _map.camera;
      widget.onViewport?.call(
        camera.center.latitude,
        camera.center.longitude,
        camera.zoom,
        camera.rotation,
      );
    });
  }

  void _setRoute(List<LatLng> points) {
    setState(() {
      _route = points;
      _updateVehicle(positionChanged: false);
      _routeLayer = points.length < 2
          ? null
          : RepaintBoundary(
              child: PolylineLayer(
                simplificationTolerance: 0.6,
                polylines: [
                  Polyline(
                    points: points,
                    color: widget.routeColor,
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            );
    });
  }

  LatLng? get _end => widget.preview || widget.destinationStage
      ? widget.destination
      : widget.pickup;

  @override
  void initState() {
    super.initState();
    _sampleClock.start();
    _cacheStops();
    _displayDriver = _driverFrom = _driverTo = widget.driver;
    _displayHeading = widget.heading.isFinite ? widget.heading : 0;
    _motion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 450),
        )..addListener(() {
          final t = _motion.value;
          _displayDriver = _onRoute(_lerp(_driverFrom, _driverTo, t));
          _displayHeading = _headingFrom + _headingDelta * t;
          if (_followingMotion && _follow && _ready && _followFrom != null) {
            _map.move(_lerp(_followFrom!, _driverTo, t), _map.camera.zoom);
          }
        });
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _followingMotion = false;
        _scheduleViewportSave();
      }
    });
    _cameraMotion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 450),
        )..addListener(() {
          if (!_ready || _cameraFrom == null || _cameraTo == null) return;
          final t = Curves.easeOutCubic.transform(_cameraMotion.value);
          _map.move(
            _lerp(_cameraFrom!, _cameraTo!, t),
            _zoomFrom + (_zoomTo - _zoomFrom) * t,
          );
        });
    _cameraMotion.addStatusListener((status) {
      if (status == AnimationStatus.completed) _scheduleViewportSave();
    });
    _tiles = ref
        .read(offlineMapProvider.notifier)
        .buildTileLayer(
          userAgentPackageName: 'com.rapigo.driver',
          keepBuffer: 2,
          tileUpdateTransformer: TileUpdateTransformers.throttle(
            const Duration(milliseconds: 80),
          ),
        );
    unawaited(_loadRoute());
    unawaited(_snapToStreet());
  }

  @override
  void didUpdateWidget(covariant DriverCachedMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.destination != widget.destination) {
      _cacheStops();
    }
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.destination != widget.destination ||
        oldWidget.destinationStage != widget.destinationStage ||
        oldWidget.preview != widget.preview ||
        !listEquals(oldWidget.readKeys, widget.readKeys)) {
      unawaited(_loadRoute(clear: true));
    }
    if (oldWidget.routeColor != widget.routeColor) _setRoute(_route);
    if (oldWidget.driver != widget.driver ||
        oldWidget.heading != widget.heading) {
      _updateVehicle(positionChanged: oldWidget.driver != widget.driver);
      if (oldWidget.driver != widget.driver) unawaited(_snapToStreet());
    }
    if (!widget.preview &&
        oldWidget.driver != widget.driver &&
        _end != null &&
        !_routeLoading &&
        _rerouteGate.shouldRefresh(
          now: DateTime.now(),
          distanceMeters: distanceToDriverRoute(widget.driver, _route),
          missingRoute: _route.isEmpty,
        )) {
      unawaited(_loadRoute(useCache: false));
    }
    if (_ready &&
        (oldWidget.focusSignal != widget.focusSignal ||
            oldWidget.preview != widget.preview)) {
      _follow = true;
      _focus();
    }
  }

  Future<void> _loadRoute({bool clear = false, bool useCache = true}) async {
    final generation = ++_generation;
    final end = _end;
    if (clear || end == null) _setRoute(const []);
    if (end == null) {
      _routeLoading = false;
      return;
    }
    _routeLoading = true;
    _rerouteGate.markAttempt(DateTime.now());
    final writeKeys = widget.writeKeys.toSet();
    final service = ref.read(routeServiceProvider);
    try {
      for (final key in useCache ? widget.readKeys.toSet() : <String>{}) {
        final cached = await service.readNamedBundle(key);
        if (!mounted || generation != _generation) return;
        if (cached != null &&
            cached.primary.length > 1 &&
            const Distance().as(LengthUnit.Meter, cached.end, end) < 80 &&
            (widget.preview
                ? const Distance()(
                        cached.start,
                        widget.pickup ?? widget.driver,
                      ) <
                      80
                : distanceToDriverRoute(widget.driver, cached.primary) < 80)) {
          _setRoute(cached.primary);
          widget.onRouteReady?.call();
          if (_ready && widget.preview && _follow) _focus();
          return;
        }
      }
      final route = await service
          .fetchRouteBundle(
            start: widget.preview
                ? widget.pickup ?? widget.driver
                : widget.driver,
            end: end,
            allowDirectFallback: false,
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted || generation != _generation) return;
      _setRoute(route.primary);
      widget.onRouteReady?.call();
      if (_ready && widget.preview && _follow) _focus();
      for (final key in writeKeys) {
        if (!mounted || generation != _generation) return;
        try {
          await service.writeNamedBundle(key, route);
        } catch (_) {
          // A disk write failure does not invalidate the displayed route.
        }
      }
    } catch (_) {
      if (!mounted || generation != _generation) return;
      // Never invent a road route when no saved route is available.
      widget.onOfflineRoute?.call();
    } finally {
      if (generation == _generation) _routeLoading = false;
    }
  }

  void _focus() {
    if (!widget.preview) {
      _animateCamera(_displayDriver, _map.camera.zoom);
      return;
    }
    final points = widget.preview
        ? <LatLng>[?widget.pickup, ?widget.destination, ..._route]
        : <LatLng>[widget.driver, ?_end, ..._route];
    if (points.length > 1 && points.first != points.last) {
      final fitted = CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: EdgeInsets.fromLTRB(
          32,
          80,
          32,
          math.min(180, _map.camera.nonRotatedSize.height * 0.3),
        ),
        maxZoom: 17,
      ).fit(_map.camera);
      _animateCamera(fitted.center, fitted.zoom);
    } else {
      _animateCamera(widget.driver, widget.zoom.clamp(12, 18));
    }
  }

  Widget _cacheStops() {
    return _stopsLayer = RepaintBoundary(
      child: MarkerLayer(
        markers: [
          if (widget.pickup != null)
            _marker(widget.pickup!, Icons.person_pin_circle, Colors.green),
          if (widget.destination != null)
            _marker(widget.destination!, Icons.flag_rounded, Colors.red),
        ],
      ),
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color) => Marker(
    point: point,
    width: 44,
    height: 44,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(icon, color: color, size: 26),
    ),
  );

  void _containCurrentViewport() {
    if (!mounted || !_ready) return;
    final camera = DriverCityCameraConstraint(
      bounds: AppConfig.potosiOfflineBounds,
    ).constrain(_map.camera);
    _map.move(camera.center, camera.zoom);
  }

  @override
  void reassemble() {
    super.reassemble();
    _containCurrentViewport();
  }

  @override
  void dispose() {
    _generation++;
    _sampleClock.stop();
    _viewportTimer?.cancel();
    _motion.dispose();
    _cameraMotion.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cityConstraint = DriverCityCameraConstraint(
        bounds: AppConfig.potosiOfflineBounds,
      );
      final initialCamera = cityConstraint.constrain(
        MapCamera(
          crs: const Epsg3857(),
          center: widget.center,
          zoom: widget.zoom.clamp(AppConfig.mapMinZoom, AppConfig.mapMaxZoom),
          rotation: 0,
          nonRotatedSize: constraints.biggest,
        ),
      );
      return RepaintBoundary(
        child: FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: initialCamera.center,
            initialZoom: initialCamera.zoom,
            minZoom: AppConfig.mapMinZoom,
            maxZoom: AppConfig.mapMaxZoom,
            cameraConstraint: cityConstraint,
            backgroundColor: const Color(0xFFE9E6DD),
            onMapEvent: (event) {
              if (event is MapEventNonRotatedSizeChange) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _containCurrentViewport(),
                );
              }
            },
            onMapReady: () {
              _ready = true;
              if (_end != null) _focus();
              widget.onReady?.call();
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture) {
                _follow = false;
                _followingMotion = false;
                _cameraMotion.stop();
              }
              if (_cameraMotion.isAnimating || _followingMotion) return;
              _scheduleViewportSave();
            },
          ),
          children: [
            _tiles,
            ?_routeLayer,
            _stopsLayer ?? _cacheStops(),
            AnimatedBuilder(
              animation: _motion,
              builder: (context, child) => MarkerLayer(
                markers: [
                  Marker(
                    point: _displayDriver,
                    width: 48,
                    height: 48,
                    child: Transform.rotate(
                      angle: _displayHeading * math.pi / 180,
                      child: child!,
                    ),
                  ),
                ],
              ),
              child: RepaintBoundary(
                child: Icon(
                  Icons.navigation_rounded,
                  color: widget.markerColor,
                  size: 42,
                  shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
                ),
              ),
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      );
    },
  );
}
