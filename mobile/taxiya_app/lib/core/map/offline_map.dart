import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';

const _potosiStoreName = 'potosi';
const _offlineMinZoom = 12;
const _offlineMaxZoom = 16;

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
      urlTemplate: AppConfig.mapTilesUrlTemplate,
      userAgentPackageName: userAgentPackageName,
      tileProvider: buildTileProvider(),
      minZoom: _offlineMinZoom.toDouble(),
      maxZoom: _offlineMaxZoom.toDouble(),
      maxNativeZoom: _offlineMaxZoom,
      tileBounds: AppConfig.potosiViewBounds,
      keepBuffer: 4,
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
            ? 'Mapa offline de ${AppConfig.offlineRegionName} listo'
            : (AppConfig.hasDedicatedOfflineTileSource
                  ? 'Modo online listo. Puedes descargar ${AppConfig.offlineRegionName} cuando quieras.'
                  : 'Modo online activo con OpenStreetMap.'),
        clearError: true,
      );
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
        statusMessage: 'El mapa sigue funcionando online. La descarga offline se activa cuando configures MAP_OFFLINE_TILES_URL_TEMPLATE.',
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
          urlTemplate: AppConfig.mapOfflineTilesUrlTemplate,
          userAgentPackageName: 'bo.flashgo.offline',
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
      await refreshStatus();
    } catch (error) {
      state = state.copyWith(
        isDownloading: false,
        errorMessage: 'Descarga offline fallida: $error',
        statusMessage: 'No se pudo descargar el mapa offline',
      );
    }
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
        color: const Color(0xFF17181B).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x33F97316)),
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
                  offlineState.isReady ? 'Mapa offline listo' : 'Descargar mapa',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFF4EC),
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  offlineState.isReady ? Icons.check_circle_rounded : Icons.download_rounded,
                  color: const Color(0xFFF97316),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            offlineState.statusMessage ?? 'Guarda ${AppConfig.offlineRegionName} para usar el mapa sin internet.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFD8BF),
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
                color: Color(0xFFFF9B9B),
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
              backgroundColor: const Color(0xFF25252B),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF97316)),
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 8),
            Text(
              '${(offlineState.progress * 100).toStringAsFixed(0)}% · ${offlineState.downloadedTiles}/${offlineState.totalTiles} tiles',
              style: const TextStyle(
                color: Color(0xFFFFF4EC),
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
                onPressed: AppConfig.hasDedicatedOfflineTileSource ? controller.downloadPotosiMap : null,
                icon: Icon(offlineState.isReady ? Icons.refresh_rounded : Icons.download_rounded),
                label: Text(offlineState.isReady ? 'Actualizar cache' : 'Guardar Potosi ciudad'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: const Color(0xFF0F0F10),
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
        ? const Color(0xFFF97316)
        : isReady
            ? const Color(0xFF22C55E)
            : const Color(0xFF38BDF8);
    final backgroundColor = isDownloading
        ? const Color(0xFF23160F)
        : isReady
            ? const Color(0xFF0F1512)
            : const Color(0xFF101722);
    final borderColor = isDownloading
        ? const Color(0x55F97316)
        : isReady
            ? const Color(0x4D22C55E)
            : const Color(0x5538BDF8);
    final label = isDownloading
        ? 'Descargando offline'
        : isReady
            ? 'Offline listo'
            : 'Online';
    final detail = isDownloading
        ? '${(offlineState.progress * 100).toStringAsFixed(0)}%'
        : hasOfflineSource
            ? 'cache disponible'
            : 'OpenStreetMap';

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
                  color: const Color(0xFFFFF4EC),
                ),
              ),
              Text(
                detail,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFD8BF),
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
                  backgroundColor: const Color(0xFF2A2B31),
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
                  color: const Color(0xFF121214),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x33F97316)),
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
                            color: const Color(0x33FFF4EC),
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
                          color: const Color(0xFFFFF4EC),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'El mapa online sigue funcionando normal. Si inicias la descarga, puedes cerrar esta ventana y seguira avanzando.',
                        style: TextStyle(
                          color: Color(0xFFFFD8BF),
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
                            color: const Color(0xFF102015),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x5522C55E)),
                          ),
                          child: const Text(
                            'Mapa instalado correctamente. Ya puedes seguir viendo Potosi ciudad y usar el cache offline cuando la señal baje.',
                            style: TextStyle(
                              color: Color(0xFFE8FFF0),
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
                            color: const Color(0xFF2A1812),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x55F97316)),
                          ),
                          child: const Text(
                            'Ahora mismo estas en modo online con OpenStreetMap. Para activar la descarga offline sin tocar ese modo, configura MAP_OFFLINE_TILES_URL_TEMPLATE con tu servidor de tiles propio.',
                            style: TextStyle(
                              color: Color(0xFFFFD8BF),
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
