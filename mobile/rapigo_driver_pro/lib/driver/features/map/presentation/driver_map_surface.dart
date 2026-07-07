import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../../../core/config/app_config.dart';
import '../../../../../core/map/offline_map.dart';
import '../../../../../core/map/rapigo_map_runtime.dart';
import '../../../../../features/maps/services/map_cache_manager.dart';
import '../../../../../features/maps/services/map_viewport_cache.dart';
import '../../driver/home/driver_initial_bootstrap.dart';
import 'driver_maplibre_view.dart';

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
  })? onDebugTelemetryChanged;

  @override
  ConsumerState<DriverMapSurface> createState() => _DriverMapSurfaceState();
}

class _DriverMapSurfaceState extends ConsumerState<DriverMapSurface>
    with AutomaticKeepAliveClientMixin {
  final _cacheManager = MapCacheManager(bounds: AppConfig.potosiOfflineBounds);
  CachedMapViewport? _cachedViewport;
  bool _vectorReady = false;
  bool _showSkeleton = true;
  bool _offlineReady = false;
  bool _offlinePrepared = false;
  bool _mapLoadFailed = false;
  bool _viewportResolved = false;

  MapViewportCache get _viewportCache =>
      MapViewportCache(namespace: widget.viewportCacheKey);

  @override
  void initState() {
    super.initState();
    _restoreCachedViewport();
    _resolveOfflineStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prepareOfflineFirstMap();
    });
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _showSkeleton = false;
      });
    });
  }

  Future<void> _restoreCachedViewport() async {
    final viewport = await _viewportCache.read();
    if (!mounted) return;
    setState(() {
      _cachedViewport = viewport;
      _viewportResolved = true;
    });
  }

  Future<void> _resolveOfflineStatus() async {
    final ready = await _cacheManager.hasOfflineRegion();
    if (!mounted) return;
    setState(() {
      _offlineReady = ready;
    });
  }

  Future<void> _prepareOfflineFirstMap() async {
    if (_offlinePrepared) {
      return;
    }
    _offlinePrepared = true;
    await ref.read(offlineMapProvider.notifier).ensureOfflineAvailability();
    await _resolveOfflineStatus();
  }

  ll.LatLng get _fallbackCenter =>
      _cachedViewport != null
          ? ll.LatLng(_cachedViewport!.centerLat, _cachedViewport!.centerLng)
          : ll.LatLng(widget.driverLat, widget.driverLng);

  double get _fallbackZoom => _cachedViewport?.zoom ?? AppConfig.mapInitialZoom;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final runtime = ref.watch(rapigoMapRuntimeProvider);
    final offlineState = ref.watch(offlineMapProvider);
    final showVectorMap = _vectorReady && !_mapLoadFailed;
    final canBuildMap = _viewportResolved;
    return Stack(
      children: [
        if (_showSkeleton || !_vectorReady || _mapLoadFailed)
          Positioned.fill(
            child: RapigoSkeletonMapPlaceholder(
              showOfflineLabel: _offlineReady || offlineState.isReady,
              showErrorState: _mapLoadFailed,
            ),
          ),
        if (canBuildMap)
          Positioned.fill(
            child: AnimatedScale(
              scale: showVectorMap ? 1 : 1.02,
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: showVectorMap ? 1 : 0,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: DriverMapLibreView(
                  available: widget.available,
                  tripAccepted: widget.tripAccepted,
                  driverLat: widget.driverLat,
                  driverLng: widget.driverLng,
                  headingDegrees: widget.headingDegrees,
                  vehicleType: widget.vehicleType,
                  tripStatus: widget.tripStatus,
                  pickupLat: widget.pickupLat,
                  pickupLng: widget.pickupLng,
                  destinationLat: widget.destinationLat,
                  destinationLng: widget.destinationLng,
                  routeColor: runtime.style.route,
                  focusBounds: widget.focusBounds,
                  focusSignal: widget.focusSignal,
                  onRouteUpdated: widget.onRouteUpdated,
                  onOfflineRouteRetained: widget.onOfflineRouteRetained,
                  routePersistenceKey: widget.routePersistenceKey,
                  routePersistenceReadKeys: widget.routePersistenceReadKeys,
                  routePersistenceWriteKeys: widget.routePersistenceWriteKeys,
                  prefetchRoutePersistenceKey: widget.prefetchRoutePersistenceKey,
                  idleZoomLevel: widget.idleZoomLevel,
                  maxZoomPreference: widget.maxZoomPreference,
                  idleTilt: widget.idleTilt,
                  idleBearingOverride: widget.idleBearingOverride,
                  navigationTilt: widget.navigationTilt,
                  driverMarkerScale: widget.driverMarkerScale,
                  driverMarkerOffsetX: widget.driverMarkerOffsetX,
                  driverMarkerOffsetY: widget.driverMarkerOffsetY,
                  driverMarkerStyle: widget.driverMarkerStyle,
                  lockToFocusBounds: widget.lockToFocusBounds,
                  initialCenter: _fallbackCenter,
                  initialZoom: _fallbackZoom,
                  initialBearing: _cachedViewport?.bearing,
                  preserveInitialViewport: _cachedViewport != null,
                  onDebugTelemetryChanged: widget.onDebugTelemetryChanged,
                  onMapReady: () {
                    if (!mounted) return;
                    setState(() {
                      _vectorReady = true;
                    });
                    DriverStartupTrace.markMapReady();
                  },
                  onCameraViewportChanged: (lat, lng, zoom, bearing) {
                    _viewportCache.write(
                      centerLat: lat,
                      centerLng: lng,
                      zoom: zoom,
                      bearing: bearing,
                    );
                  },
                  onHardFailure: () {
                    if (!mounted) return;
                    setState(() {
                      _vectorReady = false;
                      _mapLoadFailed = true;
                    });
                  },
                ),
              ),
            ),
          ),
        if (widget.showStatusBadge)
          Positioned(
            left: 16,
            top: 16,
            child: _OfflineFirstBadge(
              isOnline: _vectorReady && !_mapLoadFailed,
              isOfflineReady: offlineState.isReady || _offlineReady,
              isDownloading: offlineState.isDownloading,
              progress: offlineState.progress,
            ),
          ),
      ],
    );
  }
}

class RapigoSkeletonMapPlaceholder extends StatelessWidget {
  const RapigoSkeletonMapPlaceholder({
    super.key,
    this.showOfflineLabel = false,
    this.showErrorState = false,
  });

  final bool showOfflineLabel;
  final bool showErrorState;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF06204A).withValues(alpha: 0.80),
              const Color(0xFF0A2C61).withValues(alpha: 0.52),
              const Color(0xFF04101F).withValues(alpha: 0.66),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0x55FFFFFF), Color(0x18FFFFFF)],
                  ),
                  border: Border.all(color: const Color(0x447DB7FF)),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                showErrorState
                    ? 'Reiniciando mapa premium'
                    : 'Preparando mapa offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                showOfflineLabel
                    ? 'Mapa azul listo en unos instantes'
                    : 'Sincronizando experiencia RAPIGO PRO',
                style: const TextStyle(
                  color: Color(0xFFAFC8EA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineFirstBadge extends StatelessWidget {
  const _OfflineFirstBadge({
    required this.isOnline,
    required this.isOfflineReady,
    required this.isDownloading,
    required this.progress,
  });

  final bool isOnline;
  final bool isOfflineReady;
  final bool isDownloading;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final accent = isDownloading
        ? const Color(0xFFFACC15)
        : isOnline
            ? const Color(0xFF7DB7FF)
            : const Color(0xFF47D16A);
    final title = isDownloading
        ? 'Preparando mapa offline'
        : isOnline
            ? 'Mapa listo en cache'
            : 'Mapa listo en cache';
    final subtitle = isDownloading
        ? '${(progress * 100).toStringAsFixed(0)}%'
        : isOnline
            ? (isOfflineReady ? 'Offline activado para Potosi' : 'Vista premium activa')
            : 'Sin internet, usando cache local';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xD9091A33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDownloading
                ? Icons.download_for_offline_rounded
                : isOnline
                    ? Icons.cloud_done_rounded
                    : Icons.offline_bolt_rounded,
            color: accent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFA6B6CC),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: const Color(0x332979FF),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
