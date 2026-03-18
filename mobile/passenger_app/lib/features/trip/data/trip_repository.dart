import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trip_request.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return const TripRepository();
});

final tripProvider = NotifierProvider<TripController, TripRequest>(TripController.new);

class TripRepository {
  const TripRepository();

  Future<TripRequest> requestTrip(TripRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return request.copyWith(status: 'searching');
  }
}

class TripController extends Notifier<TripRequest> {
  late final TripRepository _repository;

  @override
  TripRequest build() {
    _repository = ref.watch(tripRepositoryProvider);
    return const TripRequest(
      pickupAddress: 'Plaza 10 de Noviembre',
      destinationAddress: 'Terminal de Buses Potosi',
      status: 'idle',
    );
  }

  Future<void> requestRide() async {
    state = await _repository.requestTrip(state);
  }
}
