import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_driver_pro/driver/features/auth/data/auth_repository.dart';
import 'package:rapigo_driver_pro/driver/features/auth/domain/driver_session.dart';
import 'package:rapigo_driver_pro/driver/features/trip/data/trip_repository.dart';
import 'package:rapigo_driver_pro/driver/features/trip/data/trip_state_cache.dart';
import 'driver_trip_details_test.dart' show trip;
import 'package:rapigo_driver_pro/driver/features/trip/domain/driver_trip.dart';

class Session extends DriverSessionController {
  @override
  DriverSession build() => const DriverSession(userId: 'u', driverId: 'd', vehicleType: 'taxi', accessStatus: 'active', phone: '', fullName: '', firstName: '', lastName: '', email: '', address: '', token: 'token', otpRequested: false, loggedIn: true, profileCompleted: true, deviceStatus: 'active', isLoading: false, errorMessage: null, isRestoring: false);
}
class Repository extends DriverTripRepository {
  final response = Completer<DriverTrip?>();
  final started = Completer<void>();
  int calls = 0;
  @override
  Future<DriverTrip?> fetchOffer({required String token, required String driverId}) {
    calls++;
    started.complete();
    return response.future;
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('completed summary survives refresh and restart until explicitly cleared', () async {
    await DriverTripStateCache().writeActiveTrip(trip);
    final repository = Repository();
    final container = ProviderContainer(overrides: [driverSessionProvider.overrideWith(Session.new), tripRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    final controller = container.read(offeredTripProvider.notifier);
    await controller.loadOffer();
    await controller.loadOffer();
    expect(container.read(offeredTripProvider).value?.status, 'completed');
    expect(repository.calls, 0);
    expect(DriverTripStateCache.metadataFromTrip(trip).restoreProgressPage, isTrue);
    await controller.clearTrip();
    expect(container.read(offeredTripProvider).value, isNull);
    expect(await DriverTripStateCache().readActiveTrip(), isNull);
  });
  test('a refresh started before completion cannot erase the final summary', () async {
    await DriverTripStateCache().writeActiveTrip(trip.copyWith(status: 'in_progress'));
    final repository = Repository();
    final container = ProviderContainer(overrides: [driverSessionProvider.overrideWith(Session.new), tripRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    final controller = container.read(offeredTripProvider.notifier);
    final refresh = controller.loadOffer();
    await repository.started.future;
    controller.setLocalStatus('completed');
    repository.response.complete(null);
    await refresh;
    expect(container.read(offeredTripProvider).value?.status, 'completed');
    await Future<void>.delayed(Duration.zero);
    expect((await DriverTripStateCache().readActiveTrip())?.status, 'completed');
  });
}
