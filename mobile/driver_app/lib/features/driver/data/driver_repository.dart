import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/driver_state.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return const DriverRepository();
});

final driverStateProvider = NotifierProvider<DriverStateController, DriverState>(DriverStateController.new);

class DriverRepository {
  const DriverRepository();

  Future<void> updateAvailability(bool available) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

class DriverStateController extends Notifier<DriverState> {
  late final DriverRepository _repository;
  Timer? _timer;

  @override
  DriverState build() {
    _repository = ref.watch(driverRepositoryProvider);
    ref.onDispose(() => _timer?.cancel());
    return const DriverState(available: false, lastLocationPing: null);
  }

  Future<void> toggleAvailability(bool available) async {
    await _repository.updateAvailability(available);
    state = state.copyWith(available: available);
    _timer?.cancel();
    if (available) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        state = state.copyWith(lastLocationPing: DateTime.now());
      });
    }
  }
}
