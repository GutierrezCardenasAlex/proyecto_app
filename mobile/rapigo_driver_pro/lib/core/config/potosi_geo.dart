import 'dart:math';

class PotosiGeo {
  static const double centerLat = -19.5836;
  static const double centerLng = -65.7531;
  static const double maxRadiusKm = 15;

  static bool isInside(double lat, double lng) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat - centerLat);
    final dLng = _toRadians(lng - centerLng);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(centerLat)) *
            cos(_toRadians(lat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final distance = 2 * earthRadiusKm * atan2(sqrt(a), sqrt(1 - a));
    return distance <= maxRadiusKm;
  }

  static double _toRadians(double value) => value * pi / 180;
}
