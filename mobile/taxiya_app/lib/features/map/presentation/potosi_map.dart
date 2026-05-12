import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/map/interactive_destination_marker.dart';
import '../../../../core/map/offline_map.dart';
import '../../../../core/map/route_service.dart';

class PotosiMapDriverMarker {
  const PotosiMapDriverMarker({
    required this.point,
    this.vehicleType,
  });

  final LatLng point;
  final String? vehicleType;
}

class PotosiMap extends ConsumerStatefulWidget {
  const PotosiMap({
    super.key,
    required this.drivers,
    required this.userLocation,
    this.routeStart,
    this.routeTarget,
    this.secondaryMarker,
    this.showRoute = false,
    this.showTargetMarker = true,
    this.routeColor = const Color(0xFFF97316),
    this.focusBounds,
    this.focusSignal = 0,
    this.onRouteUpdated,
    this.onMapTap,
    this.showTargetEditBadge = false,
  });

  final List<PotosiMapDriverMarker> drivers;
  final LatLng userLocation;
  final LatLng? routeStart;
  final LatLng? routeTarget;
  final LatLng? secondaryMarker;
  final bool showRoute;
  final bool showTargetMarker;
  final Color routeColor;
  final LatLngBounds? focusBounds;
  final int focusSignal;
  final VoidCallback? onRouteUpdated;
  final ValueChanged<LatLng>? onMapTap;
  final bool showTargetEditBadge;

  @override
  ConsumerState<PotosiMap> createState() => _PotosiMapState();
}

class _PotosiMapState extends ConsumerState<PotosiMap> {
  static const double _rerouteDistanceMeters = 38;
  static const double _rerouteTargetShiftMeters = 55;
  final MapController _mapController = MapController();
  RoutePathBundle? _routeBundle;
  String? _routeKey;
  LatLng? _lastRouteEnd;
  bool _shouldAnnounceRouteUpdate = false;

  @override
  void initState() {
    super.initState();
    _refreshRoute();
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
  }

  bool _shouldShowRouteUpdatedNotice() {
    final target = widget.routeTarget;
    final start = widget.routeStart ?? widget.userLocation;
    final routePoints = _routeBundle?.primary;
    if (!widget.showRoute || target == null || routePoints == null || routePoints.length < 2) {
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
    _mapController.move(widget.routeTarget ?? widget.userLocation, AppConfig.mapInitialZoom);
  }

  bool _shouldRefreshRoute(PotosiMap oldWidget) {
    if (oldWidget.showRoute != widget.showRoute) {
      return true;
    }
    final target = widget.routeTarget;
    final start = widget.routeStart ?? widget.userLocation;
    final routePoints = _routeBundle?.primary;
    if (!widget.showRoute || target == null || routePoints == null || routePoints.length < 2) {
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
    return offRouteDistance > _rerouteDistanceMeters || targetShift > _rerouteTargetShiftMeters;
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
    final nextKey = '${start.latitude.toStringAsFixed(5)},'
        '${start.longitude.toStringAsFixed(5)}>'
        '${target.latitude.toStringAsFixed(5)},${target.longitude.toStringAsFixed(5)}';
    if (_routeKey == nextKey && _routeBundle != null) {
      return;
    }

    try {
      final bundle = await ref.read(routeServiceProvider).fetchRouteBundle(
            start: start,
            end: target,
          );
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

  @override
  Widget build(BuildContext context) {
    ref.watch(offlineMapProvider);
    final initialCenter = widget.routeTarget ?? widget.routeStart ?? widget.userLocation;
    final offlineMap = ref.read(offlineMapProvider.notifier);
    final fallbackOnlineLayer = offlineMap.buildFallbackOnlineTileLayer(
      userAgentPackageName: 'bo.taxiya.passenger',
    );
    final viewBounds = AppConfig.potosiViewBounds;
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
            onTap: (_, point) => widget.onMapTap?.call(point),
          ),
          children: [
            ...?fallbackOnlineLayer == null ? null : [fallbackOnlineLayer],
            offlineMap.buildTileLayer(
              userAgentPackageName: 'bo.taxiya.passenger',
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
            if (widget.showRoute && widget.routeTarget != null && visibleAlternativeRoutes.isNotEmpty)
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
            if (widget.showRoute && widget.routeTarget != null && (visiblePrimaryRoute?.length ?? 0) >= 2)
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
                  point: widget.userLocation,
                  width: 50,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF97316).withValues(alpha: 0.35),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_pin_circle, color: Color(0xFFF97316), size: 34),
                  ),
                ),
                if (widget.showTargetMarker && widget.routeTarget != null)
                  Marker(
                    point: widget.routeTarget!,
                    width: 112,
                    height: 94,
                    child: InteractiveDestinationMarker(
                      icon: Icons.place_rounded,
                      color: const Color(0xFFF97316),
                      label: 'Destino',
                      showEditBadge: widget.showTargetEditBadge,
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
                      color: const Color(0xFF0EA5E9),
                      label: 'Ruta final',
                      size: 28,
                      showEditBadge: widget.showTargetEditBadge,
                    ),
                  ),
                ...widget.drivers.map(
                  (driver) => Marker(
                    point: driver.point,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16171A),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x66F97316)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        _vehicleIcon(driver.vehicleType),
                        color: const Color(0xFFF97316),
                        size: 18,
                      ),
                    ),
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
      ],
    );
  }

  IconData _vehicleIcon(String? vehicleType) {
    return switch ((vehicleType ?? '').toLowerCase()) {
      'moto' => Icons.two_wheeler_rounded,
      _ => Icons.directions_car_filled_rounded,
    };
  }
}
