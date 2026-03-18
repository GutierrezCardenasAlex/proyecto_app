import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/driver_trip.dart';

final tripRepositoryProvider = Provider<DriverTripRepository>((ref) {
  return const DriverTripRepository();
});

final offeredTripProvider =
    NotifierProvider<DriverTripController, DriverTrip>(DriverTripController.new);

class DriverTripRepository {
  const DriverTripRepository();

  Future<DriverTrip> accept(DriverTrip trip) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return trip.copyWith(status: 'accepted');
  }
}

class DriverTripController extends Notifier<DriverTrip> {
  late final DriverTripRepository _repository;

  @override
  DriverTrip build() {
    _repository = ref.watch(tripRepositoryProvider);
    return const DriverTrip(
      id: 'trip-demo-01',
      passengerPickup: 'Mercado Central',
      destination: 'Hospital Daniel Bracamonte',
      status: 'offered',
    );
  }

  Future<void> acceptTrip() async {
    state = await _repository.accept(state);
  }
}
