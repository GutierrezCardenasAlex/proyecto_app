import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class OfflineRegionInfo {
  const OfflineRegionInfo({
    required this.id,
    required this.name,
    required this.isAvailable,
    required this.tileCount,
    required this.cacheSizeKiB,
    required this.lastUpdated,
    this.bounds,
  });

  final String id;
  final String name;
  final bool isAvailable;
  final int tileCount;
  final double cacheSizeKiB;
  final DateTime? lastUpdated;
  final LatLngBounds? bounds;
}

class MapCacheManager {
  MapCacheManager({
    String storeName = 'potosi_online_map_v3',
    String regionId = 'potosi',
    String regionName = 'Potosi ciudad',
    LatLngBounds? bounds,
  }) : _store = FMTCStore(storeName),
       _regionId = regionId,
       _regionName = regionName,
       _bounds = bounds;

  final FMTCStore _store;
  final String _regionId;
  final String _regionName;
  final LatLngBounds? _bounds;

  Future<bool> hasOfflineRegion() async {
    final stats = await _safeStats();
    return stats != null && stats.length > 0;
  }

  Future<List<OfflineRegionInfo>> getAvailableRegions() async {
    return [await _buildRegionInfo()];
  }

  Future<int> getTileCount() async {
    final stats = await _safeStats();
    return stats?.length ?? 0;
  }

  Future<double> getCacheSize() async {
    final stats = await _safeStats();
    return stats?.size ?? 0;
  }

  Future<bool> isRegionAvailable([String? regionId]) async {
    if (regionId != null && regionId != _regionId) {
      return false;
    }
    return hasOfflineRegion();
  }

  Future<OfflineRegionInfo> refreshRegionMetadata() async {
    final info = await _buildRegionInfo();
    await _store.metadata.setBulk(
      kvs: {
        'region_id': info.id,
        'region_name': info.name,
        'tile_count': info.tileCount.toString(),
        'cache_size_kib': info.cacheSizeKiB.toStringAsFixed(2),
        'last_updated': (info.lastUpdated ?? DateTime.now()).toIso8601String(),
      },
    );
    return info;
  }

  Future<void> clearObsoleteMetadata({Duration maxAge = const Duration(days: 45)}) async {
    final metadata = await _safeMetadata();
    final lastUpdatedRaw = metadata['last_updated'];
    final lastUpdated = DateTime.tryParse(lastUpdatedRaw ?? '');
    if (lastUpdated == null) {
      return;
    }
    if (DateTime.now().difference(lastUpdated) > maxAge) {
      await _store.metadata.reset();
    }
  }

  Future<OfflineRegionInfo> _buildRegionInfo() async {
    final stats = await _safeStats();
    final metadata = await _safeMetadata();
    final storedUpdated = DateTime.tryParse(metadata['last_updated'] ?? '');
    return OfflineRegionInfo(
      id: metadata['region_id'] ?? _regionId,
      name: metadata['region_name'] ?? _regionName,
      isAvailable: (stats?.length ?? 0) > 0,
      tileCount: stats?.length ?? int.tryParse(metadata['tile_count'] ?? '') ?? 0,
      cacheSizeKiB: stats?.size ?? double.tryParse(metadata['cache_size_kib'] ?? '') ?? 0,
      lastUpdated: storedUpdated,
      bounds: _bounds,
    );
  }

  Future<({double size, int length, int hits, int misses})?> _safeStats() async {
    if (!await _store.manage.ready) {
      return null;
    }
    return _store.stats.all;
  }

  Future<Map<String, String>> _safeMetadata() async {
    if (!await _store.manage.ready) {
      return const {};
    }
    return _store.metadata.read;
  }
}
