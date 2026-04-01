import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DriverMap extends StatelessWidget {
  const DriverMap({
    super.key,
    required this.available,
    required this.tripAccepted,
    required this.driverLat,
    required this.driverLng,
    this.tripStatus,
    this.pickupLat,
    this.pickupLng,
  });

  final bool available;
  final bool tripAccepted;
  final double driverLat;
  final double driverLng;
  final String? tripStatus;
  final double? pickupLat;
  final double? pickupLng;

  @override
  Widget build(BuildContext context) {
    final driverPoint = LatLng(driverLat, driverLng);
    final pickupPoint = pickupLat != null && pickupLng != null ? LatLng(pickupLat!, pickupLng!) : null;
    final isOnPickupStage = const {'accepted', 'arriving', 'at_pickup'}.contains(tripStatus);
    final initialCenter = tripAccepted && pickupPoint != null ? pickupPoint : driverPoint;

    return FlutterMap(
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 14.2,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'bo.taxiya.driver',
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
        if (tripAccepted && pickupPoint != null && isOnPickupStage)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [driverPoint, pickupPoint],
                strokeWidth: 4,
                color: Color(0xFF00AFC3),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: driverPoint,
              width: 56,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  color: available ? const Color(0xFF000003) : const Color(0xFF77767C),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_taxi,
                  color: available ? const Color(0xFF00E3FD) : Colors.white,
                ),
              ),
            ),
            if (tripAccepted && pickupPoint != null)
              Marker(
                point: pickupPoint,
                width: 54,
                height: 54,
                child: const Icon(Icons.place, color: Color(0xFF000003), size: 34),
              ),
          ],
        ),
      ],
    );
  }
}
