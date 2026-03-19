import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PotosiMap extends StatelessWidget {
  const PotosiMap({
    super.key,
    required this.drivers,
    required this.userLocation,
    required this.destination,
  });

  final List<LatLng> drivers;
  final LatLng userLocation;
  final LatLng destination;

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
            userAgentPackageName: 'bo.taxiya.passenger',
          ),
          CircleLayer(
            circles: const [
              CircleMarker(
                point: LatLng(-19.5836, -65.7531),
                radius: 15000,
                useRadiusInMeter: true,
                color: Color(0x2216354C),
                borderColor: Color(0xFFDB5F2D),
                borderStrokeWidth: 2,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: userLocation,
                width: 60,
                height: 60,
                child: const Icon(Icons.my_location, color: Color(0xFF16354C), size: 32),
              ),
              Marker(
                point: destination,
                width: 60,
                height: 60,
                child: const Icon(Icons.flag, color: Color(0xFFDB5F2D), size: 32),
              ),
              ...drivers.map(
                (driver) => Marker(
                  point: driver,
                  width: 48,
                  height: 48,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF16354C),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_taxi, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [userLocation, destination],
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
