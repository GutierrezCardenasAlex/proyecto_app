import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/driver_login_card.dart';
import '../../map/presentation/driver_map.dart';
import '../../trip/data/trip_repository.dart';
import '../data/driver_repository.dart';

class DriverHomePage extends ConsumerWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(driverSessionProvider);
    final driverState = ref.watch(driverStateProvider);
    final trip = ref.watch(offeredTripProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taxi Ya Driver'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: Text('5s GPS ping')),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const DriverLoginCard(),
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  value: driverState.available,
                  onChanged: session.loggedIn
                      ? (value) => ref.read(driverStateProvider.notifier).toggleAvailability(value)
                      : null,
                  title: const Text('Driver availability'),
                  subtitle: Text(
                    driverState.lastLocationPing == null
                        ? 'No GPS ping sent yet'
                        : 'Last GPS ping: ${driverState.lastLocationPing}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: const DriverMap()),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trip offer: ${trip.id}'),
                      const SizedBox(height: 8),
                      Text('Pickup: ${trip.passengerPickup}'),
                      Text('Destination: ${trip.destination}'),
                      Text('Status: ${trip.status}'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: session.loggedIn && driverState.available
                              ? () => ref.read(offeredTripProvider.notifier).acceptTrip()
                              : null,
                          child: const Text('Accept Trip'),
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
