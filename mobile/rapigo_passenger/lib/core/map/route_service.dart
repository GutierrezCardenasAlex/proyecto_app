import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../../features/maps/services/route_cache_manager.dart';

final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService(
    cacheManager: RouteCacheManager(),
  );
});

class RoutePathBundle {
  const RoutePathBundle({
    required this.primary,
    this.alternatives = const <List<LatLng>>[],
    required this.start,
    required this.end,
    this.distanceMeters,
    this.durationSeconds,
  });

  final List<LatLng> primary;
  final List<List<LatLng>> alternatives;
  final LatLng start;
  final LatLng end;
  final double? distanceMeters;
  final double? durationSeconds;
}

class RouteService {
  RouteService({
    RouteCacheManager? cacheManager,
  }) : _cacheManager = cacheManager ?? RouteCacheManager();

  static const Distance _distance = Distance();

  static final Map<String, RoutePathBundle> _cache = <String, RoutePathBundle>{};
  final RouteCacheManager _cacheManager;

  Future<List<LatLng>> fetchRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final bundle = await fetchRouteBundle(start: start, end: end);
    return bundle.primary;
  }

  Future<RoutePathBundle> fetchRouteBundle({
    required LatLng start,
    required LatLng end,
  }) async {
    final cacheKey = _keyFor(start, end);
    final cached = _cache[cacheKey];
    if (cached != null && cached.primary.isNotEmpty) {
      return cached;
    }

    final persisted = await _readPersistedBundle(cacheKey);
    if (persisted != null && persisted.primary.isNotEmpty) {
      _cache[cacheKey] = persisted;
      return persisted;
    }

    if (!AppConfig.hasRoutingSource) {
      return _directBundle(
        start: start,
        end: end,
      );
    }

    try {
      final snappedStart = await _snapPointIfPossible(start);
      final snappedEnd = await _snapPointIfPossible(end);
      final base = AppConfig.mapRoutingUrlBase.replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse(
        '$base/${snappedStart.longitude},${snappedStart.latitude};${snappedEnd.longitude},${snappedEnd.latitude}'
        '?overview=full&geometries=geojson&alternatives=true&steps=false&continue_straight=false',
      );

      final response = await http.get(uri, headers: const {'Accept': 'application/json'});
      if (response.statusCode >= 400) {
        throw Exception('No se pudo cargar la ruta (${response.statusCode})');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = payload['routes'] as List<dynamic>? ?? const [];
      if (routes.isEmpty) {
        return _directBundle(
          start: start,
          end: end,
        );
      }

      final decodedRoutes = routes
          .whereType<Map<String, dynamic>>()
          .take(3)
          .map((route) => _decodeRouteGeometry(route, exactStart: start, exactEnd: end))
          .where((points) => points.length >= 2)
          .toList(growable: false);

      if (decodedRoutes.isEmpty) {
        return _directBundle(
          start: start,
          end: end,
        );
      }

      final firstRoute = routes.first as Map<String, dynamic>;
      final bundle = RoutePathBundle(
        primary: decodedRoutes.first,
        alternatives: decodedRoutes.length > 1 ? decodedRoutes.sublist(1) : const <List<LatLng>>[],
        start: start,
        end: end,
        distanceMeters: firstRoute['distance'] is num
            ? (firstRoute['distance'] as num).toDouble()
            : null,
        durationSeconds: firstRoute['duration'] is num
            ? (firstRoute['duration'] as num).toDouble()
            : null,
      );
      _cache[cacheKey] = bundle;
      await _persistBundle(cacheKey, bundle);
      return bundle;
    } catch (_) {
      if (persisted != null && persisted.primary.isNotEmpty) {
        return persisted;
      }
      return _directBundle(
        primary: <LatLng>[start, end],
        start: start,
        end: end,
      );
    }
  }

  RoutePathBundle _directBundle({
    required LatLng start,
    required LatLng end,
    List<LatLng>? primary,
  }) {
    return RoutePathBundle(
      primary: primary ?? <LatLng>[start, end],
      start: start,
      end: end,
      distanceMeters: pointDistance(start, end),
    );
  }

  String _keyFor(LatLng start, LatLng end) {
    return '${start.latitude.toStringAsFixed(5)},${start.longitude.toStringAsFixed(5)}'
        '>'
        '${end.latitude.toStringAsFixed(5)},${end.longitude.toStringAsFixed(5)}';
  }

  List<LatLng> _decodeRouteGeometry(
    Map<String, dynamic> route, {
    required LatLng exactStart,
    required LatLng exactEnd,
  }) {
    final geometry = route['geometry'] as Map<String, dynamic>?;
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
        .toList(growable: true);
    if (points.length < 2) {
      return <LatLng>[exactStart, exactEnd];
    }
    if (pointDistance(points.first, exactStart) > 3) {
      points.insert(0, exactStart);
    } else {
      points[0] = exactStart;
    }
    if (pointDistance(points.last, exactEnd) > 3) {
      points.add(exactEnd);
    } else {
      points[points.length - 1] = exactEnd;
    }
    return points;
  }

  Future<LatLng> _snapPointIfPossible(LatLng point) async {
    final snapBase = _nearestUrlBase();
    if (snapBase == null) {
      return point;
    }
    try {
      final uri = Uri.parse(
        '$snapBase/${point.longitude},${point.latitude}?number=1',
      );
      final response = await http.get(uri, headers: const {'Accept': 'application/json'});
      if (response.statusCode >= 400) {
        return point;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final waypoints = payload['waypoints'] as List<dynamic>? ?? const [];
      if (waypoints.isEmpty) {
        return point;
      }
      final location = (waypoints.first as Map<String, dynamic>)['location'] as List<dynamic>?;
      if (location == null || location.length < 2) {
        return point;
      }
      final snapped = LatLng(
        (location[1] as num).toDouble(),
        (location[0] as num).toDouble(),
      );
      if (pointDistance(point, snapped) > 250) {
        return point;
      }
      return snapped;
    } catch (_) {
      return point;
    }
  }

  Future<RoutePathBundle?> _readPersistedBundle(String cacheKey) async {
    final payload = await _cacheManager.read(cacheKey);
    if (payload == null) {
      return null;
    }
    try {
      final primary = _pointsFromJson(payload['primary']);
      if (primary.length < 2) {
        return null;
      }
      final start = _latLngFromJson(payload['start']);
      final end = _latLngFromJson(payload['end']);
      if (start == null || end == null) {
        return null;
      }
      final alternativesRaw = payload['alternatives'] as List<dynamic>? ?? const [];
      final alternatives = alternativesRaw
          .whereType<List<dynamic>>()
          .map(_pointsFromJson)
          .where((item) => item.length >= 2)
          .toList(growable: false);
      return RoutePathBundle(
        primary: primary,
        alternatives: alternatives,
        start: start,
        end: end,
        distanceMeters: (payload['distanceMeters'] as num?)?.toDouble(),
        durationSeconds: (payload['durationSeconds'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistBundle(String cacheKey, RoutePathBundle bundle) async {
    await _cacheManager.write(cacheKey, {
      'start': _latLngToJson(bundle.start),
      'end': _latLngToJson(bundle.end),
      'primary': _pointsToJson(bundle.primary),
      'alternatives': bundle.alternatives.map(_pointsToJson).toList(growable: false),
      'distanceMeters': bundle.distanceMeters,
      'durationSeconds': bundle.durationSeconds,
    });
  }

  Map<String, dynamic> _latLngToJson(LatLng point) => {
    'lat': point.latitude,
    'lng': point.longitude,
  };

  LatLng? _latLngFromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final lat = raw['lat'];
    final lng = raw['lng'];
    if (lat is! num || lng is! num) {
      return null;
    }
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  List<dynamic> _pointsToJson(List<LatLng> points) =>
      points.map(_latLngToJson).toList(growable: false);

  List<LatLng> _pointsFromJson(dynamic raw) {
    if (raw is! List<dynamic>) {
      return const <LatLng>[];
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_latLngFromJson)
        .whereType<LatLng>()
        .toList(growable: false);
  }

  String? _nearestUrlBase() {
    final base = AppConfig.mapRoutingUrlBase.trim().replaceAll(RegExp(r'/$'), '');
    if (base.contains('/route/v1/')) {
      return base.replaceFirst('/route/v1/', '/nearest/v1/');
    }
    return null;
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

  List<LatLng> trimRouteFromPoint({
    required LatLng point,
    required List<LatLng> route,
  }) {
    if (route.length < 2) {
      return route;
    }
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < route.length; index++) {
      final current = pointDistance(point, route[index]);
      if (current < bestDistance) {
        bestDistance = current;
        bestIndex = index;
      }
    }
    final trimmed = <LatLng>[point];
    trimmed.addAll(route.skip(bestIndex));
    if (trimmed.length < 2) {
      trimmed.add(route.last);
    }
    return trimmed;
  }
}
