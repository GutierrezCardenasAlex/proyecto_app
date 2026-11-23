import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../../../core/config/app_config.dart';
import '../../../../../features/maps/services/map_viewport_cache.dart';
import '../../driver/home/driver_initial_bootstrap.dart';
import 'driver_cached_map.dart';

class DriverMapSurface extends ConsumerStatefulWidget {
  const DriverMapSurface({
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
    this.viewportCacheKey,
    this.idleZoomLevel,
    this.maxZoomPreference,
    this.idleTilt,
    this.idleBearingOverride,
    this.navigationTilt,
    this.driverMarkerScale,
    this.driverMarkerOffsetX,
    this.driverMarkerOffsetY,
    this.driverMarkerStyle,
    this.lockToFocusBounds = false,
    this.showStatusBadge = true,
    this.onDebugTelemetryChanged,
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
  final String? viewportCacheKey;
  final double? idleZoomLevel;
  final double? maxZoomPreference;
  final double? idleTilt;
  final double? idleBearingOverride;
  final double? navigationTilt;
  final double? driverMarkerScale;
  final double? driverMarkerOffsetX;
  final double? driverMarkerOffsetY;
  final String? driverMarkerStyle;
  final bool lockToFocusBounds;
  final bool showStatusBadge;
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

  @override
  ConsumerState<DriverMapSurface> createState() => _DriverMapSurfaceState();
}

class _DriverMapSurfaceState extends ConsumerState<DriverMapSurface>
    with AutomaticKeepAliveClientMixin {
  CachedMapViewport? _cachedViewport;
  bool _viewportResolved = false;

  MapViewportCache get _viewportCache =>
      MapViewportCache(namespace: widget.viewportCacheKey);

  @override
  void initState() {
    super.initState();
    _restoreCachedViewport();
  }

  Future<void> _restoreCachedViewport() async {
    CachedMapViewport? viewport;
    try {
      viewport = await _viewportCache.read().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      // A missing viewport must never prevent the map from opening.
    }
    if (!mounted) return;
    setState(() {
      _cachedViewport = viewport;
      _viewportResolved = true;
    });
  }

  ll.LatLng get _fallbackCenter => _cachedViewport != null
      ? ll.LatLng(_cachedViewport!.centerLat, _cachedViewport!.centerLng)
      : ll.LatLng(widget.driverLat, widget.driverLng);

  double get _fallbackZoom => _cachedViewport?.zoom ?? AppConfig.mapInitialZoom;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_viewportResolved) {
      return const ColoredBox(color: Color(0xFFAFC9E8));
    }
    return Stack(
      children: [
        Positioned.fill(
          child: DriverCachedMap(
            driver: ll.LatLng(widget.driverLat, widget.driverLng),
            center: _fallbackCenter,
            zoom: _fallbackZoom,
            heading: widget.headingDegrees ?? 0,
            routeColor: widget.routeColor,
            markerColor: switch (widget.tripStatus) {
              'accepted' || 'arriving' => const Color(0xFFF97316),
              'at_pickup' => const Color(0xFFA855F7),
              'in_progress' => const Color(0xFF0EA5E9),
              _ =>
                widget.available
                    ? const Color(0xFF087F5B)
                    : const Color(0xFF64748B),
            },
            pickup: widget.pickupLat != null && widget.pickupLng != null
                ? ll.LatLng(widget.pickupLat!, widget.pickupLng!)
                : null,
            destination:
                widget.destinationLat != null && widget.destinationLng != null
                ? ll.LatLng(widget.destinationLat!, widget.destinationLng!)
                : null,
            preview: widget.lockToFocusBounds,
            destinationStage: const {
              'in_progress',
              'completed',
            }.contains(widget.tripStatus),
            focusSignal: widget.focusSignal,
            readKeys: [
              if (widget.routePersistenceKey != null)
                widget.routePersistenceKey!,
              ...?widget.routePersistenceReadKeys,
            ],
            writeKeys: [
              if (widget.routePersistenceKey != null)
                widget.routePersistenceKey!,
              ...?widget.routePersistenceWriteKeys,
            ],
            onReady: () {
              DriverStartupTrace.markMapReady();
            },
            onRouteReady: widget.onRouteUpdated,
            onOfflineRoute: widget.onOfflineRouteRetained,
            onViewport: (lat, lng, zoom, bearing) => _viewportCache.write(
              centerLat: lat,
              centerLng: lng,
              zoom: zoom,
              bearing: bearing,
            ),
          ),
        ),
        if (widget.showStatusBadge)
          const Positioned(left: 16, top: 16, child: _MapCacheBadge()),
      ],
    );
  }
}

class _MapCacheBadge extends StatelessWidget {
  const _MapCacheBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xD9091A33),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, color: Color(0xFF7DB7FF), size: 18),
          SizedBox(width: 8),
          Text(
            'Caché de zonas recorridas',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
