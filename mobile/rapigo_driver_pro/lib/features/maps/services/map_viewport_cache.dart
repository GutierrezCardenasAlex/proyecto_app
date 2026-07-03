import 'package:shared_preferences/shared_preferences.dart';

class CachedMapViewport {
  const CachedMapViewport({
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.bearing,
    required this.updatedAt,
  });

  final double centerLat;
  final double centerLng;
  final double zoom;
  final double bearing;
  final DateTime updatedAt;
}

class MapViewportCache {
  MapViewportCache({String? namespace})
      : _prefix = namespace == null || namespace.trim().isEmpty
            ? 'driver_map_viewport'
            : 'driver_map_viewport_${namespace.trim()}';

  final String _prefix;

  Future<CachedMapViewport?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('$_prefix.lat');
    final lng = prefs.getDouble('$_prefix.lng');
    final zoom = prefs.getDouble('$_prefix.zoom');
    final bearing = prefs.getDouble('$_prefix.bearing');
    final updated = prefs.getString('$_prefix.updated_at');
    if (lat == null || lng == null || zoom == null || bearing == null) {
      return null;
    }
    return CachedMapViewport(
      centerLat: lat,
      centerLng: lng,
      zoom: zoom,
      bearing: bearing,
      updatedAt: DateTime.tryParse(updated ?? '') ?? DateTime.now(),
    );
  }

  Future<void> write({
    required double centerLat,
    required double centerLng,
    required double zoom,
    required double bearing,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_prefix.lat', centerLat);
    await prefs.setDouble('$_prefix.lng', centerLng);
    await prefs.setDouble('$_prefix.zoom', zoom);
    await prefs.setDouble('$_prefix.bearing', bearing);
    await prefs.setString('$_prefix.updated_at', DateTime.now().toIso8601String());
  }
}
