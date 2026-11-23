import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Geometry in local meters: route segments, rather than sparse route vertices.
double distanceToDriverRoute(LatLng point, List<LatLng> route) {
  final projected = projectDriverToRoute(point, route);
  return projected == null
      ? double.infinity
      : const Distance()(point, projected);
}

/// Projects onto the road centerline, including between geometry vertices.
LatLng? projectDriverToRoute(LatLng point, List<LatLng> route) {
  if (route.isEmpty) return null;
  if (route.length == 1) return route.first;
  final xScale = 111320 * math.cos(point.latitude * math.pi / 180);
  var nearestSquared = double.infinity;
  LatLng? nearest;
  for (var i = 1; i < route.length; i++) {
    final ax = (route[i - 1].longitude - point.longitude) * xScale;
    final ay = (route[i - 1].latitude - point.latitude) * 111320;
    final bx = (route[i].longitude - point.longitude) * xScale;
    final by = (route[i].latitude - point.latitude) * 111320;
    final dx = bx - ax, dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
    final x = ax + dx * t, y = ay + dy * t;
    if (x * x + y * y < nearestSquared) {
      nearestSquared = x * x + y * y;
      nearest = LatLng(
        point.latitude + y / 111320,
        point.longitude + x / xScale,
      );
    }
  }
  return nearest;
}

double shortestHeadingDelta(double from, double to) =>
    (to - from + 540) % 360 - 180;

class DriverRerouteGate {
  DateTime? _lastAttempt;
  int _outsideSamples = 0;

  void markAttempt(DateTime now) {
    _lastAttempt = now;
    _outsideSamples = 0;
  }

  bool shouldRefresh({
    required DateTime now,
    required double distanceMeters,
    required bool missingRoute,
  }) {
    _outsideSamples = distanceMeters > 60 ? _outsideSamples + 1 : 0;
    if (_lastAttempt != null &&
        now.difference(_lastAttempt!) < const Duration(seconds: 20)) {
      return false;
    }
    return missingRoute || _outsideSamples >= 3;
  }
}

/// Follows the measured GPS cadence without extrapolating an unknown position.
class DriverMotionCadence {
  Duration? _lastSample;
  double _intervalMs = 1000;

  Duration next(Duration elapsed) {
    final previous = _lastSample;
    _lastSample = elapsed;
    if (previous != null) {
      final interval = (elapsed - previous).inMilliseconds;
      if (interval <= 0) return Duration(milliseconds: _intervalMs.round());
      if (interval > 3000) {
        _intervalMs = 1000;
        return const Duration(milliseconds: 450);
      }
      _intervalMs = (_intervalMs * 0.35 + interval * 0.65).clamp(250, 1500);
    }
    return Duration(milliseconds: _intervalMs.round());
  }
}
