import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/app_brand.dart';

const _potosiStoreName = 'potosi_online_map_v3';
const _offlineMinZoom = 12;
const _offlineMaxZoom = 18;

final offlineMapProvider =
    NotifierProvider<OfflineMapController, OfflineMapState>(OfflineMapController.new);

class OfflineMapBootstrap {
  static Future<void> ensureInitialized() async {
    await FMTCObjectBoxBackend().initialise();
    final store = const FMTCStore(_potosiStoreName);
    if (!await store.manage.ready) {
      await store.manage.create();
    }
  }
}

class OfflineMapState {
  const OfflineMapState({
    this.isDownloading = false,
    this.isReady = false,
    this.progress = 0,
    this.downloadedTiles = 0,
    this.totalTiles = 0,
    this.statusMessage,
    this.errorMessage,
  });

  final bool isDownloading;
  final bool isReady;
  final double progress;
  final int downloadedTiles;
  final int totalTiles;
  final String? statusMessage;
  final String? errorMessage;

  OfflineMapState copyWith({
    bool? isDownloading,
    bool? isReady,
    double? progress,
    int? downloadedTiles,
    int? totalTiles,
    String? statusMessage,
    String? errorMessage,
    bool clearStatus = false,
    bool clearError = false,
  }) {
    return OfflineMapState(
      isDownloading: isDownloading ?? this.isDownloading,
      isReady: isReady ?? this.isReady,
      progress: progress ?? this.progress,
      downloadedTiles: downloadedTiles ?? this.downloadedTiles,
      totalTiles: totalTiles ?? this.totalTiles,
      statusMessage: clearStatus ? null : statusMessage ?? this.statusMessage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class OfflineMapController extends Notifier<OfflineMapState> {
  static const _offlinePackInstalledKey = 'rapigo_passenger_offline_pack_installed_v1';

  final FMTCStore _store = const FMTCStore(_potosiStoreName);
  bool _isRefreshing = false;
  Future<void>? _downloadTask;

  @override
  OfflineMapState build() {
    Future<void>.microtask(refreshStatus);
    return const OfflineMapState();
  }

  TileProvider buildTileProvider() {
    // ignore: deprecated_member_use
    return _store.getTileProvider(
      loadingStrategy: BrowseLoadingStrategy.cacheFirst,
      storeStrategy: BrowseStoreStrategy.readUpdateCreate,
      cachedValidDuration: const Duration(days: 30),
      errorHandler: (error) {
        debugPrint('FMTC tile error: $error');
        return null;
      },
    );
  }

  TileLayer buildTileLayer({
    required String userAgentPackageName,
  }) {
    return TileLayer(
      urlTemplate: AppConfig.effectiveMapTilesUrlTemplate,
      userAgentPackageName: userAgentPackageName,
      tileProvider: buildTileProvider(),
      tileDimension: AppConfig.mapTileDimension,
      zoomOffset: AppConfig.mapTileZoomOffset,
      minZoom: _offlineMinZoom.toDouble(),
      maxZoom: _offlineMaxZoom.toDouble(),
      maxNativeZoom: _offlineMaxZoom,
      tileBounds: AppConfig.potosiViewBounds,
      keepBuffer: 4,
      panBuffer: 1,
      tileDisplay: const TileDisplay.instantaneous(),
    );
  }

  TileLayer? buildFallbackOnlineTileLayer({
    required String userAgentPackageName,
  }) {
    if (!AppConfig.shouldUseOpenStreetMapFallbackLayer) {
      return null;
    }
    return TileLayer(
      urlTemplate: AppConfig.mapTilesUrlTemplate,
      userAgentPackageName: userAgentPackageName,
      tileDimension: AppConfig.mapTileDimension,
      zoomOffset: AppConfig.mapTileZoomOffset,
      minZoom: _offlineMinZoom.toDouble(),
      maxZoom: _offlineMaxZoom.toDouble(),
      maxNativeZoom: _offlineMaxZoom,
      tileBounds: AppConfig.potosiViewBounds,
      keepBuffer: 2,
      panBuffer: 1,
      tileDisplay: const TileDisplay.instantaneous(),
    );
  }

  Future<void> refreshStatus() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    try {
      final isReady = await _store.manage.ready;
      final stats = isReady ? await _store.stats.all : (size: 0.0, length: 0, hits: 0, misses: 0);
      state = state.copyWith(
        isReady: stats.length > 0,
        downloadedTiles: stats.length,
        statusMessage: stats.length > 0
            ? AppConfig.hasDedicatedOfflineTileSource
                ? 'Mapa offline de ${AppConfig.offlineRegionName} listo'
                : 'Cache inteligente activo. El mapa guardara las zonas vistas para seguir mostrandolas cuando la señal baje.'
            : (AppConfig.hasDedicatedOfflineTileSource
                  ? 'Modo online listo. Puedes descargar ${AppConfig.offlineRegionName} cuando quieras.'
                  : 'Modo online listo. Mientras avances, el mapa ira guardando en cache las zonas que ya viste.'),
        clearError: true,
      );
      if (stats.length > 0) {
        await _markOfflinePackInstalled();
      } else {
        await _clearOfflinePackInstalled();
      }
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'No pudimos leer el cache offline: $error',
      );
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> downloadPotosiMap() async {
    if (_downloadTask != null) {
      await _downloadTask;
      return;
    }
    if (!AppConfig.hasDedicatedOfflineTileSource) {
      state = state.copyWith(
        statusMessage:
            'El mapa seguira funcionando online y guardando en cache las zonas recorridas para reutilizarlas si la señal baja.',
        clearError: true,
      );
      return;
    }

    _downloadTask = _performDownload();
    try {
      await _downloadTask;
    } finally {
      _downloadTask = null;
    }
  }

  Future<void> ensureOfflineAvailability({
    bool forceRefresh = false,
    bool forceDownload = false,
  }) async {
    if (forceRefresh || !state.isReady) {
      await refreshStatus();
    }

    if (!AppConfig.hasDedicatedOfflineTileSource) {
      return;
    }

    if (state.isDownloading) {
      return;
    }

    final alreadyInstalled = await _isOfflinePackInstalled();
    if (alreadyInstalled && !forceDownload) {
      return;
    }

    if (forceDownload || !state.isReady) {
      await downloadPotosiMap();
    }
  }

  Future<void> _performDownload() async {
    if (state.isDownloading) {
      return;
    }

    state = state.copyWith(
      isDownloading: true,
      progress: 0,
      downloadedTiles: 0,
      totalTiles: 0,
      statusMessage: 'Preparando descarga offline de ${AppConfig.offlineRegionName}...',
      clearError: true,
    );

    try {
      if (!await _store.manage.ready) {
        await _store.manage.create();
      }

      final region = RectangleRegion(AppConfig.potosiOfflineBounds).toDownloadable(
        minZoom: _offlineMinZoom,
        maxZoom: _offlineMaxZoom,
        options: TileLayer(
          urlTemplate: AppConfig.effectiveOfflineTilesUrlTemplate,
          userAgentPackageName: 'bo.rapigo.passenger.offline',
          tileDimension: AppConfig.mapTileDimension,
          zoomOffset: AppConfig.mapTileZoomOffset,
          minZoom: _offlineMinZoom.toDouble(),
          maxZoom: _offlineMaxZoom.toDouble(),
        ),
      );

      final download = _store.download.startForeground(
        region: region,
        parallelThreads: 8,
        maxBufferLength: 128,
        skipExistingTiles: true,
        retryFailedRequestTiles: true,
      );

      DownloadProgress? lastProgress;
      await for (final progress in download.downloadProgress) {
        lastProgress = progress;
        final progressRatio = (progress.percentageProgress / 100).clamp(0.0, 1.0);
        state = state.copyWith(
          isDownloading: true,
          progress: progressRatio,
          downloadedTiles: progress.successfulTilesCount,
          totalTiles: progress.maxTilesCount,
          statusMessage:
              'Descargando ${AppConfig.offlineRegionName}: ${progress.percentageProgress.toStringAsFixed(0)}% (${progress.successfulTilesCount}/${progress.maxTilesCount})',
          clearError: true,
        );
      }

      final stats = await _store.stats.all;
      final failedCount = (lastProgress?.failedTilesCount ?? 0) +
          (lastProgress?.failedRequestTilesCount ?? 0) +
          (lastProgress?.negativeResponseTilesCount ?? 0);

      state = state.copyWith(
        isDownloading: false,
        isReady: stats.length > 0,
        progress: failedCount == 0 ? 1 : state.progress,
        downloadedTiles: stats.length,
        totalTiles: lastProgress?.maxTilesCount ?? state.totalTiles,
        statusMessage: failedCount == 0
            ? 'Mapa instalado correctamente'
            : 'Descarga completada con algunos errores. El cache guardado sigue disponible.',
        errorMessage: failedCount == 0 ? null : 'Algunas teselas no pudieron descargarse. Revisa tu conexion.',
      );
      if (stats.length > 0) {
        await _markOfflinePackInstalled();
      }
      await refreshStatus();
    } catch (error) {
      state = state.copyWith(
        isDownloading: false,
        errorMessage: 'Descarga offline fallida: $error',
        statusMessage: 'No se pudo descargar el mapa offline',
      );
    }
  }

  Future<bool> _isOfflinePackInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_offlinePackInstalledKey) ?? false;
  }

  Future<void> _markOfflinePackInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlinePackInstalledKey, true);
  }

  Future<void> _clearOfflinePackInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlinePackInstalledKey);
  }
}

class OfflineMapDownloadButton extends ConsumerWidget {
  const OfflineMapDownloadButton({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineState = ref.watch(offlineMapProvider);
    final controller = ref.read(offlineMapProvider.notifier);

    return Container(
      width: 196,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppBrand.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppBrand.surfaceMuted),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offlineState.isReady
                      ? (AppConfig.hasDedicatedOfflineTileSource ? 'Mapa offline listo' : 'Cache del mapa lista')
                      : (AppConfig.hasDedicatedOfflineTileSource ? 'Descargar mapa' : 'Cache inteligente'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppBrand.accentYellow.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  offlineState.isReady ? Icons.check_circle_rounded : Icons.download_rounded,
                  color: AppBrand.primaryBlue,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            offlineState.statusMessage ??
                (AppConfig.hasDedicatedOfflineTileSource
                    ? 'Guarda ${AppConfig.offlineRegionName} para usar el mapa sin internet.'
                    : 'El mapa ira guardando automaticamente las zonas vistas para seguir mostrandolas si la señal baja.'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppBrand.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (offlineState.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              offlineState.errorMessage!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppBrand.danger,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (offlineState.isDownloading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: offlineState.progress,
              minHeight: 8,
              backgroundColor: AppBrand.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation(AppBrand.primaryBlue),
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 8),
            Text(
              '${(offlineState.progress * 100).toStringAsFixed(0)}% · ${offlineState.downloadedTiles}/${offlineState.totalTiles} tiles',
              style: const TextStyle(
                color: AppBrand.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                onPressed: AppConfig.hasDedicatedOfflineTileSource ? controller.downloadPotosiMap : controller.refreshStatus,
                icon: Icon(
                  AppConfig.hasDedicatedOfflineTileSource
                      ? (offlineState.isReady ? Icons.refresh_rounded : Icons.download_rounded)
                      : Icons.wifi_tethering_rounded,
                ),
                label: Text(
                  AppConfig.hasDedicatedOfflineTileSource
                      ? (offlineState.isReady ? 'Actualizar cache' : 'Guardar Potosi ciudad')
                      : 'Usar cache automatica',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppBrand.primaryBlue,
                  foregroundColor: AppBrand.surface,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OfflineMapReadyBadge extends ConsumerWidget {
  const OfflineMapReadyBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineState = ref.watch(offlineMapProvider);
    final hasOfflineSource = AppConfig.hasDedicatedOfflineTileSource;
    final isDownloading = offlineState.isDownloading;
    final isReady = offlineState.isReady;

    final accentColor = isDownloading
        ? AppBrand.accentYellow
        : isReady
            ? AppBrand.primaryBlue
            : AppBrand.accentYellow;
    final backgroundColor = isDownloading
        ? AppBrand.surface
        : isReady
            ? AppBrand.surface
            : AppBrand.surface;
    final borderColor = isDownloading
        ? const Color(0x33FACC15)
        : isReady
            ? const Color(0x330F6CBD)
            : const Color(0x33FACC15);
    final label = isDownloading
        ? 'Descargando offline'
        : isReady
            ? 'Offline listo'
            : 'Online';
    final detail = isDownloading
        ? '${(offlineState.progress * 100).toStringAsFixed(0)}%'
        : hasOfflineSource
            ? 'cache disponible'
            : 'solo online';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textPrimary,
                ),
              ),
              Text(
                detail,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppBrand.textSecondary,
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 42,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: offlineState.progress.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: AppBrand.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showOfflineMapSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final offlineState = ref.watch(offlineMapProvider);
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppBrand.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppBrand.surfaceMuted),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 28,
                      offset: Offset(0, -12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppBrand.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mapa offline de ${AppConfig.offlineRegionName}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppBrand.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppConfig.hasDedicatedOfflineTileSource
                            ? 'El mapa online sigue funcionando normal. Si inicias la descarga, puedes cerrar esta ventana y seguira avanzando.'
                            : 'El mapa funciona online y ademas guarda automaticamente en cache las zonas vistas para seguir mostrandolas si la señal baja.',
                        style: const TextStyle(
                          color: AppBrand.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const OfflineMapDownloadButton(),
                      if (offlineState.isReady) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppBrand.surfaceMuted,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x330F6CBD)),
                          ),
                          child: const Text(
                            'Mapa instalado correctamente. Ya puedes seguir viendo Potosi ciudad y usar el cache offline cuando la señal baje.',
                            style: TextStyle(
                              color: AppBrand.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (!AppConfig.hasDedicatedOfflineTileSource) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppBrand.surfaceMuted,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x33FACC15)),
                          ),
                          child: const Text(
                            'Modo online con cache inteligente activo. El mapa ira guardando automaticamente las zonas que recorras para seguir mostrandolas con poca señal. Cuando tengamos un paquete offline dedicado, esta misma pantalla permitira descargarlo completo.',
                            style: TextStyle(
                              color: AppBrand.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
