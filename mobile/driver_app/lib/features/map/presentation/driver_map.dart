import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DriverMap extends StatelessWidget {
  const DriverMap({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(-19.5836, -65.7531),
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'bo.taxiya.driver',
          ),
          MarkerLayer(
            markers: const [
              Marker(
                point: LatLng(-19.5842, -65.7525),
                width: 60,
                height: 60,
                child: Icon(Icons.local_taxi, size: 34, color: Color(0xFF16354C)),
              ),
              Marker(
                point: LatLng(-19.579, -65.748),
                width: 60,
                height: 60,
                child: Icon(Icons.location_on, size: 34, color: Color(0xFFDB5F2D)),
              ),
            ],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: const [
                  LatLng(-19.5842, -65.7525),
                  LatLng(-19.579, -65.748),
                ],
                strokeWidth: 4,
                color: const Color(0xFFDB5F2D),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
