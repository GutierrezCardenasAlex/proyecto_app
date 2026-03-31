import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PotosiMap extends StatelessWidget {
  const PotosiMap({
    super.key,
    required this.drivers,
    required this.userLocation,
    this.routeTarget,
    this.showRoute = false,
    this.showTargetMarker = true,
  });

  final List<LatLng> drivers;
  final LatLng userLocation;
  final LatLng? routeTarget;
  final bool showRoute;
  final bool showTargetMarker;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: userLocation,
        initialZoom: 14.2,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'bo.taxiya.passenger',
        ),
        CircleLayer(
          circles: const [
            CircleMarker(
              point: LatLng(-19.5836, -65.7531),
              radius: 15000,
              useRadiusInMeter: true,
              color: Color(0x16006875),
              borderColor: Color(0x3300E3FD),
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
                color: const Color(0xFF00AFC3),
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
                      color: const Color(0xFF00E3FD).withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.person_pin_circle, color: Color(0xFF001F24), size: 40),
              ),
            ),
            if (showTargetMarker && routeTarget != null)
              Marker(
                point: routeTarget!,
                width: 54,
                height: 54,
                child: const Icon(Icons.place, color: Color(0xFF000003), size: 34),
              ),
            ...drivers.map(
              (driver) => Marker(
                point: driver,
                width: 46,
                height: 46,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF000003),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_taxi, color: Color(0xFF00E3FD), size: 22),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
