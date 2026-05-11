import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';

final routeServiceProvider = Provider<RouteService>((ref) {
  return const RouteService();
});

class RouteService {
  const RouteService();

  static const Distance _distance = Distance();

  static final Map<String, List<LatLng>> _cache = <String, List<LatLng>>{};

  Future<List<LatLng>> fetchRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final cacheKey = _keyFor(start, end);
    final cached = _cache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    if (!AppConfig.hasRoutingSource) {
      return [start, end];
    }

    final base = AppConfig.mapRoutingUrlBase.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse(
      '$base/${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (response.statusCode >= 400) {
      throw Exception('No se pudo cargar la ruta (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = payload['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      return [start, end];
    }

    final geometry = (routes.first as Map<String, dynamic>)['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>? ?? const [];
    final points = coordinates
        .whereType<List<dynamic>>()
        .where((item) => item.length >= 2)
        .map(
          (item) => LatLng(
            (item[1] as num).toDouble(),
            (item[0] as num).toDouble(),
          ),
        )
        .toList(growable: false);

    if (points.length < 2) {
      return [start, end];
    }

    _cache[cacheKey] = points;
    return points;
  }

  String _keyFor(LatLng start, LatLng end) {
    return '${start.latitude.toStringAsFixed(5)},${start.longitude.toStringAsFixed(5)}'
        '>'
        '${end.latitude.toStringAsFixed(5)},${end.longitude.toStringAsFixed(5)}';
  }

  double distanceToRoute({
    required LatLng point,
    required List<LatLng> route,
  }) {
    if (route.isEmpty) {
      return double.infinity;
    }

    var best = double.infinity;
    for (final routePoint in route) {
      final current = _distance.as(LengthUnit.Meter, point, routePoint);
      if (current < best) {
        best = current;
      }
    }
    return best;
  }

  double pointDistance(LatLng from, LatLng to) {
    return _distance.as(LengthUnit.Meter, from, to);
  }
}
