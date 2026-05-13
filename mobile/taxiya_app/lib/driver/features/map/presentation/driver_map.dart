import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/map/geocoding_service.dart';
import '../../../../../core/map/interactive_destination_marker.dart';
import '../../../../../core/map/map_navigation_banner.dart';
import '../../../../../core/map/offline_map.dart';
import '../../../../../core/map/route_service.dart';

class DriverMap extends ConsumerStatefulWidget {
  const DriverMap({
    super.key,
    required this.available,
    required this.tripAccepted,
    required this.driverLat,
    required this.driverLng,
    required this.vehicleType,
    this.tripStatus,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.routeColor = const Color(0xFFF97316),
    this.focusBounds,
    this.focusSignal = 0,
    this.onRouteUpdated,
  });

  final bool available;
  final bool tripAccepted;
  final double driverLat;
  final double driverLng;
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

  @override
  ConsumerState<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends ConsumerState<DriverMap> {
  static const double _rerouteDistanceMeters = 34;
  static const double _rerouteTargetShiftMeters = 50;
  static const double _detailRefreshDistanceMeters = 45;
  final MapController _mapController = MapController();
  RoutePathBundle? _routeBundle;
  RoutePathBundle? _upcomingRouteBundle;
  String? _routeKey;
  String? _upcomingRouteKey;
  LatLng? _lastRouteEnd;
  bool _shouldAnnounceRouteUpdate = false;
  final Distance _distance = const Distance();
  MapLocationDetails? _currentLocationDetails;
  MapLocationDetails? _targetLocationDetails;
  LatLng? _lastCurrentLookupPoint;
  LatLng? _lastTargetLookupPoint;
  Timer? _detailsDebounce;

  @override
  void initState() {
    super.initState();
    _refreshRoute();
    _scheduleLocationDetailsRefresh(force: true);
  }

  @override
  void didUpdateWidget(covariant DriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldRefreshRoute(oldWidget)) {
      _shouldAnnounceRouteUpdate = _shouldShowRouteUpdatedNotice();
      _refreshRoute();
    }
    if (oldWidget.focusSignal != widget.focusSignal) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyFocus());
    }
    if (_shouldRefreshLocationDetails(oldWidget)) {
      _scheduleLocationDetailsRefresh();
    }
  }

  @override
  void dispose() {
    _detailsDebounce?.cancel();
    super.dispose();
  }

  bool _shouldShowRouteUpdatedNotice() {
    final currentTarget = _currentRouteTarget();
    final routePoints = _routeBundle?.primary;
    if (currentTarget == null || routePoints == null || routePoints.length < 2) {
      return false;
    }
    final routeService = ref.read(routeServiceProvider);
    final offRouteDistance = routeService.distanceToRoute(
      point: LatLng(widget.driverLat, widget.driverLng),
      route: routePoints,
    );
    final targetShift = _lastRouteEnd == null
        ? double.infinity
        : routeService.pointDistance(_lastRouteEnd!, currentTarget);
    return offRouteDistance > _rerouteDistanceMeters || targetShift > _rerouteTargetShiftMeters;
  }

  void _applyFocus() {
    if (!mounted) {
      return;
    }
    final bounds = widget.focusBounds;
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(56, 120, 56, 220),
        ),
      );
      return;
    }
    _mapController.move(_currentRouteTarget() ?? LatLng(widget.driverLat, widget.driverLng), AppConfig.mapInitialZoom);
  }

  bool _shouldRefreshRoute(DriverMap oldWidget) {
    if (oldWidget.tripStatus != widget.tripStatus) {
      return true;
    }

    final currentTarget = _currentRouteTarget();
    final oldTarget = _targetFor(
      tripStatus: oldWidget.tripStatus,
      pickupLat: oldWidget.pickupLat,
      pickupLng: oldWidget.pickupLng,
      destinationLat: oldWidget.destinationLat,
      destinationLng: oldWidget.destinationLng,
    );

    final routePoints = _routeBundle?.primary;
    if (routePoints == null || routePoints.length < 2) {
      return oldWidget.driverLat != widget.driverLat ||
          oldWidget.driverLng != widget.driverLng ||
          oldTarget != currentTarget;
    }

    if (currentTarget == null) {
      return oldTarget != null;
    }

    final routeService = ref.read(routeServiceProvider);
    final offRouteDistance = routeService.distanceToRoute(
      point: LatLng(widget.driverLat, widget.driverLng),
      route: routePoints,
    );
    final targetShift = _lastRouteEnd == null
        ? double.infinity
        : routeService.pointDistance(_lastRouteEnd!, currentTarget);
    return offRouteDistance > _rerouteDistanceMeters || targetShift > _rerouteTargetShiftMeters;
  }

  Future<void> _refreshRoute() async {
    final driverPoint = LatLng(widget.driverLat, widget.driverLng);
    final pickupPoint = widget.pickupLat != null && widget.pickupLng != null
        ? LatLng(widget.pickupLat!, widget.pickupLng!)
        : null;
    final finalDestinationPoint = widget.destinationLat != null && widget.destinationLng != null
        ? LatLng(widget.destinationLat!, widget.destinationLng!)
        : null;
    final routeTargetPoint = _currentRouteTarget();
    if (routeTargetPoint == null) {
      if (mounted) {
        setState(() {
          _routeBundle = null;
          _upcomingRouteBundle = null;
          _routeKey = null;
          _upcomingRouteKey = null;
        });
      }
      return;
    }

    final nextKey = '${driverPoint.latitude.toStringAsFixed(5)},${driverPoint.longitude.toStringAsFixed(5)}>'
        '${routeTargetPoint.latitude.toStringAsFixed(5)},${routeTargetPoint.longitude.toStringAsFixed(5)}';
    if (_routeKey == nextKey && _routeBundle != null) {
      return;
    }

    final routeService = ref.read(routeServiceProvider);
    try {
      final bundle = await routeService.fetchRouteBundle(
        start: driverPoint,
        end: routeTargetPoint,
      );
      RoutePathBundle? upcomingBundle;
      String? upcomingKey;
      if (pickupPoint != null &&
          finalDestinationPoint != null &&
          const {'accepted', 'arriving', 'at_pickup'}.contains(widget.tripStatus)) {
        upcomingKey =
            '${pickupPoint.latitude.toStringAsFixed(5)},${pickupPoint.longitude.toStringAsFixed(5)}>'
            '${finalDestinationPoint.latitude.toStringAsFixed(5)},${finalDestinationPoint.longitude.toStringAsFixed(5)}';
        if (_upcomingRouteKey == upcomingKey && _upcomingRouteBundle != null) {
          upcomingBundle = _upcomingRouteBundle;
        } else {
          upcomingBundle = await routeService.fetchRouteBundle(
            start: pickupPoint,
            end: finalDestinationPoint,
          );
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _routeBundle = bundle;
        _upcomingRouteBundle = upcomingBundle;
        _routeKey = nextKey;
        _upcomingRouteKey = upcomingKey;
        _lastRouteEnd = routeTargetPoint;
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
          primary: <LatLng>[driverPoint, routeTargetPoint],
          start: driverPoint,
          end: routeTargetPoint,
        );
        _upcomingRouteBundle =
            pickupPoint != null &&
                    finalDestinationPoint != null &&
                    const {'accepted', 'arriving', 'at_pickup'}.contains(widget.tripStatus)
                ? RoutePathBundle(
                    primary: <LatLng>[pickupPoint, finalDestinationPoint],
                    start: pickupPoint,
                    end: finalDestinationPoint,
                  )
                : null;
        _routeKey = nextKey;
        _upcomingRouteKey = pickupPoint != null && finalDestinationPoint != null
            ? '${pickupPoint.latitude.toStringAsFixed(5)},${pickupPoint.longitude.toStringAsFixed(5)}>'
                '${finalDestinationPoint.latitude.toStringAsFixed(5)},${finalDestinationPoint.longitude.toStringAsFixed(5)}'
            : null;
        _lastRouteEnd = routeTargetPoint;
      });
      if (_shouldAnnounceRouteUpdate) {
        _shouldAnnounceRouteUpdate = false;
        widget.onRouteUpdated?.call();
      }
    }
  }

  bool _shouldRefreshLocationDetails(DriverMap oldWidget) {
    final currentPoint = LatLng(widget.driverLat, widget.driverLng);
    final movedEnough = _lastCurrentLookupPoint == null ||
        _distance(currentPoint, _lastCurrentLookupPoint!) > _detailRefreshDistanceMeters;
    final oldTarget = _targetFor(
      tripStatus: oldWidget.tripStatus,
      pickupLat: oldWidget.pickupLat,
      pickupLng: oldWidget.pickupLng,
      destinationLat: oldWidget.destinationLat,
      destinationLng: oldWidget.destinationLng,
    );
    final newTarget = _currentRouteTarget();
    final targetChanged = oldTarget != newTarget ||
        (_lastTargetLookupPoint != null &&
            newTarget != null &&
            _distance(newTarget, _lastTargetLookupPoint!) > _detailRefreshDistanceMeters);
    return movedEnough || targetChanged;
  }

  void _scheduleLocationDetailsRefresh({bool force = false}) {
    _detailsDebounce?.cancel();
    _detailsDebounce = Timer(force ? Duration.zero : const Duration(milliseconds: 500), () {
      unawaited(_refreshLocationDetails(force: force));
    });
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
    final driverPoint = LatLng(widget.driverLat, widget.driverLng);
    final targetPoint = _currentRouteTarget();
    try {
      if (force ||
          _lastCurrentLookupPoint == null ||
          _distance(driverPoint, _lastCurrentLookupPoint!) > _detailRefreshDistanceMeters) {
        final details = await geocoding.reverseLookup(driverPoint);
        if (mounted) {
          setState(() {
            _currentLocationDetails = details;
            _lastCurrentLookupPoint = driverPoint;
          });
        }
      }
      if (targetPoint != null &&
          (force ||
              _lastTargetLookupPoint == null ||
              _distance(targetPoint, _lastTargetLookupPoint!) > _detailRefreshDistanceMeters)) {
        final details = await geocoding.reverseLookup(targetPoint);
        if (mounted) {
          setState(() {
            _targetLocationDetails = details;
            _lastTargetLookupPoint = targetPoint;
          });
        }
      } else if (targetPoint == null && mounted && _targetLocationDetails != null) {
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
            primary: 'Punto del viaje',
            secondary: 'Potosi',
            fullAddress: 'Potosi',
          );
        }
      });
    }
  }

  LatLng? _currentRouteTarget() {
    return _targetFor(
      tripStatus: widget.tripStatus,
      pickupLat: widget.pickupLat,
      pickupLng: widget.pickupLng,
      destinationLat: widget.destinationLat,
      destinationLng: widget.destinationLng,
    );
  }

  LatLng? _targetFor({
    required String? tripStatus,
    required double? pickupLat,
    required double? pickupLng,
    required double? destinationLat,
    required double? destinationLng,
  }) {
    final pickupPoint = pickupLat != null && pickupLng != null
        ? LatLng(pickupLat, pickupLng)
        : null;
    final destinationPoint = destinationLat != null && destinationLng != null
        ? LatLng(destinationLat, destinationLng)
        : null;
    return tripStatus == 'in_progress' ? destinationPoint : pickupPoint;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(offlineMapProvider);
    final driverPoint = LatLng(widget.driverLat, widget.driverLng);
    final pickupPoint = widget.pickupLat != null && widget.pickupLng != null
        ? LatLng(widget.pickupLat!, widget.pickupLng!)
        : null;
    final destinationPoint = widget.destinationLat != null && widget.destinationLng != null
        ? LatLng(widget.destinationLat!, widget.destinationLng!)
        : null;
    final isOnPickupStage = const {'accepted', 'arriving', 'at_pickup'}.contains(widget.tripStatus);
    final isOnDestinationStage = widget.tripStatus == 'in_progress';
    final routePoint = isOnDestinationStage ? destinationPoint : pickupPoint;
    final initialCenter = widget.tripAccepted && routePoint != null ? routePoint : driverPoint;
    final offlineMap = ref.read(offlineMapProvider.notifier);
    final fallbackOnlineLayer = offlineMap.buildFallbackOnlineTileLayer(
      userAgentPackageName: 'bo.taxiya.driver',
    );
    final viewBounds = AppConfig.potosiViewBounds;
    final routeService = ref.read(routeServiceProvider);
    final visiblePrimaryRoute = _routeBundle == null
        ? null
        : routeService.trimRouteFromPoint(
            point: driverPoint,
            route: _routeBundle!.primary,
          );
    final visibleAlternativeRoutes = _routeBundle == null
        ? const <List<LatLng>>[]
        : _routeBundle!.alternatives
            .map(
              (route) => routeService.trimRouteFromPoint(
                point: driverPoint,
                route: route,
              ),
            )
            .where((route) => route.length >= 2)
            .toList(growable: false);
    final visibleUpcomingRoute = _upcomingRouteBundle == null
        ? null
        : routeService.trimRouteFromPoint(
            point: pickupPoint ?? driverPoint,
            route: _upcomingRouteBundle!.primary,
          );

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: AppConfig.mapInitialZoom,
            minZoom: AppConfig.mapMinZoom,
            maxZoom: AppConfig.mapMaxZoom,
            cameraConstraint: CameraConstraint.contain(bounds: viewBounds),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            ...?fallbackOnlineLayer == null ? null : [fallbackOnlineLayer],
            offlineMap.buildTileLayer(
              userAgentPackageName: 'bo.taxiya.driver',
            ),
            CircleLayer(
              circles: const [
                CircleMarker(
                  point: LatLng(-19.5836, -65.7531),
                  radius: 15000,
                  useRadiusInMeter: true,
                  color: Color(0x1AF97316),
                  borderColor: Color(0x55F97316),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            if (widget.tripAccepted &&
                routePoint != null &&
                (isOnPickupStage || isOnDestinationStage) &&
                visibleAlternativeRoutes.isNotEmpty)
              PolylineLayer(
                polylines: visibleAlternativeRoutes
                    .map(
                      (route) => Polyline(
                        points: route,
                        strokeWidth: 2.5,
                        color: widget.routeColor.withValues(alpha: 0.18),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (widget.tripAccepted &&
                isOnPickupStage &&
                pickupPoint != null &&
                destinationPoint != null &&
                (visibleUpcomingRoute?.length ?? 0) >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: visibleUpcomingRoute!,
                    strokeWidth: 3.5,
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.28),
                  ),
                ],
              ),
            if (widget.tripAccepted &&
                routePoint != null &&
                (isOnPickupStage || isOnDestinationStage) &&
                (visiblePrimaryRoute?.length ?? 0) >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: visiblePrimaryRoute!,
                    strokeWidth: 4,
                    color: widget.routeColor,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: driverPoint,
                  width: 50,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.available ? const Color(0xFF17181B) : const Color(0xFF3A3A41),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.available ? const Color(0x66F97316) : const Color(0xFF55555E),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.available ? const Color(0xFFF97316) : const Color(0xFF0F0F10))
                              .withValues(alpha: 0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _vehicleIcon(widget.vehicleType),
                      color: widget.available ? const Color(0xFFF97316) : const Color(0xFFFFF4EC),
                      size: 22,
                    ),
                  ),
                ),
                if (widget.tripAccepted && routePoint != null)
                  Marker(
                    point: routePoint,
                    width: 112,
                    height: 94,
                    child: InteractiveDestinationMarker(
                      icon: isOnDestinationStage ? Icons.flag_rounded : Icons.place_rounded,
                      color: const Color(0xFFF97316),
                      label: isOnDestinationStage ? 'Destino' : 'Recojo',
                    ),
                  ),
                if (widget.tripAccepted &&
                    isOnPickupStage &&
                    destinationPoint != null &&
                    destinationPoint != routePoint)
                  Marker(
                    point: destinationPoint,
                    width: 102,
                    height: 88,
                    child: const InteractiveDestinationMarker(
                      icon: Icons.flag_rounded,
                      color: Color(0xFF0EA5E9),
                      label: 'Luego destino',
                      size: 28,
                    ),
                  ),
              ],
            ),
          ],
        ),
        const Positioned(
          left: 16,
          bottom: 16,
          child: OfflineMapReadyBadge(),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: MapNavigationTriggerButton(
            currentLabel: _currentLocationDetails?.primary ?? 'Ubicacion actual',
            currentDetail: _currentLocationDetails?.secondary ?? 'Buscando calle...',
            targetLabel: routePoint != null
                ? (_targetLocationDetails?.primary ??
                    (isOnDestinationStage ? 'Destino del viaje' : 'Punto de recojo'))
                : null,
            targetDetail: routePoint != null
                ? (_targetLocationDetails?.secondary ?? 'Buscando referencia...')
                : null,
            remainingDistanceLabel: _formatDistance(_routeBundle?.distanceMeters),
            remainingDurationLabel: _formatDuration(_routeBundle?.durationSeconds),
            targetCaption: isOnDestinationStage ? 'Destino' : 'Recojo',
          ),
        ),
      ],
    );
  }

  IconData _vehicleIcon(String type) {
    return type.toLowerCase() == 'moto'
        ? Icons.two_wheeler_rounded
        : Icons.directions_car_filled_rounded;
  }
}
