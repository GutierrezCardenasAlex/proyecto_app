import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_card.dart';
import '../../map/presentation/potosi_map.dart';
import '../data/trip_repository.dart';

class PassengerHomePage extends ConsumerWidget {
  const PassengerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final trip = ref.watch(tripProvider);
    final nearbyDrivers = const [
      LatLng(-19.586, -65.755),
      LatLng(-19.580, -65.748),
      LatLng(-19.592, -65.751),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taxi Ya Passenger'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: Text('Potosi only')),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const LoginCard(),
              const SizedBox(height: 16),
              Expanded(
                child: PotosiMap(
                  drivers: nearbyDrivers,
                  pickup: const LatLng(-19.5854, -65.7542),
                  destination: const LatLng(-19.5747, -65.7454),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Passenger: ${session.phone.isEmpty ? "not authenticated" : session.phone}'),
                      const SizedBox(height: 8),
                      Text('Pickup: ${trip.pickupAddress}'),
                      Text('Destination: ${trip.destinationAddress}'),
                      Text('Trip status: ${trip.status}'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: session.isAuthenticated
                              ? () => ref.read(tripProvider.notifier).requestRide()
                              : null,
                          child: const Text('Request Ride'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
