import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
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
    this.routeTarget,
    this.showRoute = false,
    this.showTargetMarker = true,
  });

  final List<PotosiMapDriverMarker> drivers;
  final LatLng userLocation;
  final LatLng? routeTarget;
  final bool showRoute;
  final bool showTargetMarker;

  @override
  ConsumerState<PotosiMap> createState() => _PotosiMapState();
}

class _PotosiMapState extends ConsumerState<PotosiMap> {
  static const double _rerouteDistanceMeters = 60;
  static const double _rerouteTargetShiftMeters = 90;
  List<LatLng>? _routePoints;
  String? _routeKey;
  LatLng? _lastRouteEnd;

  @override
  void initState() {
    super.initState();
    _refreshRoute();
  }

  @override
  void didUpdateWidget(covariant PotosiMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldRefreshRoute(oldWidget)) {
      _refreshRoute();
    }
  }

  bool _shouldRefreshRoute(PotosiMap oldWidget) {
    if (oldWidget.showRoute != widget.showRoute) {
      return true;
    }
    final target = widget.routeTarget;
    if (!widget.showRoute || target == null || _routePoints == null || _routePoints!.length < 2) {
      return oldWidget.userLocation != widget.userLocation || oldWidget.routeTarget != widget.routeTarget;
    }

    final routeService = ref.read(routeServiceProvider);
    final offRouteDistance = routeService.distanceToRoute(
      point: widget.userLocation,
      route: _routePoints!,
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
          _routePoints = null;
          _routeKey = null;
        });
      }
      return;
    }

    final nextKey = '${widget.userLocation.latitude.toStringAsFixed(5)},'
        '${widget.userLocation.longitude.toStringAsFixed(5)}>'
        '${target.latitude.toStringAsFixed(5)},${target.longitude.toStringAsFixed(5)}';
    if (_routeKey == nextKey && _routePoints != null) {
      return;
    }

    try {
      final points = await ref.read(routeServiceProvider).fetchRoute(
            start: widget.userLocation,
            end: target,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _routePoints = points;
        _routeKey = nextKey;
        _lastRouteEnd = target;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routePoints = [widget.userLocation, target];
        _routeKey = nextKey;
        _lastRouteEnd = target;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(offlineMapProvider);
    final initialCenter = widget.routeTarget ?? widget.userLocation;
    final offlineMap = ref.read(offlineMapProvider.notifier);
    final viewBounds = AppConfig.potosiViewBounds;
    return Stack(
      children: [
        FlutterMap(
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
            if (widget.showRoute && widget.routeTarget != null && (_routePoints?.length ?? 0) >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints!,
                    strokeWidth: 5,
                    color: const Color(0xFFF97316),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.userLocation,
                  width: 56,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF97316).withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_pin_circle, color: Color(0xFFF97316), size: 40),
                  ),
                ),
                if (widget.showTargetMarker && widget.routeTarget != null)
                  Marker(
                    point: widget.routeTarget!,
                    width: 54,
                    height: 54,
                    child: const Icon(Icons.place, color: Color(0xFFF97316), size: 34),
                  ),
                ...widget.drivers.map(
                  (driver) => Marker(
                    point: driver.point,
                    width: 46,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16171A),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x66F97316)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        _vehicleIcon(driver.vehicleType),
                        color: const Color(0xFFF97316),
                        size: 22,
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
