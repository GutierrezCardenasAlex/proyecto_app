import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/map/offline_map.dart';

class PotosiMapDriverMarker {
  const PotosiMapDriverMarker({
    required this.point,
    this.vehicleType,
  });

  final LatLng point;
  final String? vehicleType;
}

class PotosiMap extends ConsumerWidget {
  const PotosiMap({
    super.key,
    required this.drivers,
    required this.userLocation,
    this.routeTarget,
    this.showRoute = false,
    this.showTargetMarker = true,
  });

  final List<PotosiMapDriverMarker> drivers;
  final LatLng userLocation;
  final LatLng? routeTarget;
  final bool showRoute;
  final bool showTargetMarker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialCenter = routeTarget ?? userLocation;
    final offlineMap = ref.read(offlineMapProvider.notifier);
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 14.2,
            minZoom: 12,
            maxZoom: 16,
          ),
          children: [
            offlineMap.buildTileLayer(
              userAgentPackageName: 'bo.taxiya.passenger',
            ),
            CircleLayer(
              circles: const [
                CircleMarker(
                  point: LatLng(-19.5836, -65.7531),
                  radius: 15000,
                  useRadiusInMeter: true,
                  color: Color(0x1AF97316),
                  borderColor: Color(0x55F97316),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            if (showRoute && routeTarget != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [userLocation, routeTarget!],
                    strokeWidth: 4,
                    color: const Color(0xFFF97316),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: userLocation,
                  width: 56,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF97316).withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_pin_circle, color: Color(0xFFF97316), size: 40),
                  ),
                ),
                if (showTargetMarker && routeTarget != null)
                  Marker(
                    point: routeTarget!,
                    width: 54,
                    height: 54,
                    child: const Icon(Icons.place, color: Color(0xFFF97316), size: 34),
                  ),
                ...drivers.map(
                  (driver) => Marker(
                    point: driver.point,
                    width: 46,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16171A),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x66F97316)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        _vehicleIcon(driver.vehicleType),
                        color: const Color(0xFFF97316),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const Positioned(
          left: 16,
          bottom: 16,
          child: OfflineMapReadyBadge(),
        ),
      ],
    );
  }

  IconData _vehicleIcon(String? vehicleType) {
    return switch ((vehicleType ?? '').toLowerCase()) {
      'moto' => Icons.two_wheeler_rounded,
      _ => Icons.directions_car_filled_rounded,
    };
  }
}
