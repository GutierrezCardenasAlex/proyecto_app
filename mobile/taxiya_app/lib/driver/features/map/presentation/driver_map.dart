import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/config/app_config.dart';
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

  @override
  ConsumerState<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends ConsumerState<DriverMap> {
  static const double _rerouteDistanceMeters = 55;
  static const double _rerouteTargetShiftMeters = 80;
  final MapController _mapController = MapController();
  List<LatLng>? _routePoints;
  String? _routeKey;
  LatLng? _lastRouteEnd;

  @override
  void initState() {
    super.initState();
    _refreshRoute();
  }

  @override
  void didUpdateWidget(covariant DriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldRefreshRoute(oldWidget)) {
      _refreshRoute();
    }
    if (oldWidget.focusSignal != widget.focusSignal) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyFocus());
    }
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

    if (_routePoints == null || _routePoints!.length < 2) {
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
      route: _routePoints!,
    );
    final targetShift = _lastRouteEnd == null
        ? double.infinity
        : routeService.pointDistance(_lastRouteEnd!, currentTarget);
    return offRouteDistance > _rerouteDistanceMeters || targetShift > _rerouteTargetShiftMeters;
  }

  Future<void> _refreshRoute() async {
    final driverPoint = LatLng(widget.driverLat, widget.driverLng);
    final destinationPoint = _currentRouteTarget();
    if (destinationPoint == null) {
      if (mounted) {
        setState(() {
          _routePoints = null;
          _routeKey = null;
        });
      }
      return;
    }

    final nextKey = '${driverPoint.latitude.toStringAsFixed(5)},${driverPoint.longitude.toStringAsFixed(5)}>'
        '${destinationPoint.latitude.toStringAsFixed(5)},${destinationPoint.longitude.toStringAsFixed(5)}';
    if (_routeKey == nextKey && _routePoints != null) {
      return;
    }

    try {
      final points = await ref.read(routeServiceProvider).fetchRoute(
            start: driverPoint,
            end: destinationPoint,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _routePoints = points;
        _routeKey = nextKey;
        _lastRouteEnd = destinationPoint;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routePoints = [driverPoint, destinationPoint];
        _routeKey = nextKey;
        _lastRouteEnd = destinationPoint;
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
    final viewBounds = AppConfig.potosiViewBounds;

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
                (_routePoints?.length ?? 0) >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints!,
                    strokeWidth: 5,
                    color: widget.routeColor,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: driverPoint,
                  width: 56,
                  height: 56,
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
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _vehicleIcon(widget.vehicleType),
                      color: widget.available ? const Color(0xFFF97316) : const Color(0xFFFFF4EC),
                    ),
                  ),
                ),
                if (widget.tripAccepted && routePoint != null)
                  Marker(
                    point: routePoint,
                    width: 54,
                    height: 54,
                    child: Icon(
                      isOnDestinationStage ? Icons.flag_rounded : Icons.place,
                      color: const Color(0xFFF97316),
                      size: 34,
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

  IconData _vehicleIcon(String type) {
    return type.toLowerCase() == 'moto'
        ? Icons.two_wheeler_rounded
        : Icons.directions_car_filled_rounded;
  }
}
