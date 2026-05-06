import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/map/offline_map.dart';

class DriverMap extends ConsumerWidget {
  const DriverMap({
    super.key,
    required this.available,
    required this.tripAccepted,
    required this.driverLat,
    required this.driverLng,
    required this.vehicleType,
    this.tripStatus,
    this.pickupLat,
    this.pickupLng,
  });

  final bool available;
  final bool tripAccepted;
  final double driverLat;
  final double driverLng;
  final String vehicleType;
  final String? tripStatus;
  final double? pickupLat;
  final double? pickupLng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverPoint = LatLng(driverLat, driverLng);
    final pickupPoint = pickupLat != null && pickupLng != null ? LatLng(pickupLat!, pickupLng!) : null;
    final isOnPickupStage = const {'accepted', 'arriving', 'at_pickup'}.contains(tripStatus);
    final initialCenter = tripAccepted && pickupPoint != null ? pickupPoint : driverPoint;
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
              userAgentPackageName: 'bo.taxiya.driver',
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
            if (tripAccepted && pickupPoint != null && isOnPickupStage)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [driverPoint, pickupPoint],
                    strokeWidth: 4,
                    color: Color(0xFFF97316),
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
                      color: available ? const Color(0xFF17181B) : const Color(0xFF3A3A41),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: available ? const Color(0x66F97316) : const Color(0xFF55555E),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (available ? const Color(0xFFF97316) : const Color(0xFF0F0F10))
                              .withValues(alpha: 0.20),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _vehicleIcon(vehicleType),
                      color: available ? const Color(0xFFF97316) : const Color(0xFFFFF4EC),
                    ),
                  ),
                ),
                if (tripAccepted && pickupPoint != null)
                  Marker(
                    point: pickupPoint,
                    width: 54,
                    height: 54,
                    child: const Icon(Icons.place, color: Color(0xFFF97316), size: 34),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: const OfflineMapDownloadButton(),
        ),
      ],
    );
  }

  IconData _vehicleIcon(String type) {
    return type.toLowerCase() == 'moto'
        ? Icons.two_wheeler_rounded
        : Icons.directions_car_filled_rounded;
  }
}
