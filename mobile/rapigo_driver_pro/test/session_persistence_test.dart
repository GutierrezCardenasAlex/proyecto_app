import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_driver_pro/driver/features/auth/data/auth_repository.dart';

class FakeRepository extends DriverAuthRepository {
  int calls = 0;
  int profileCalls = 0;
  Completer<DriverSessionStatusResult>? pending;
  bool fail = false;
  final result = const DriverSessionStatusResult(
    deviceStatus: 'AUTORIZADO',
    profileCompleted: true,
    fullName: 'Ana Flores',
    firstName: 'Ana',
    lastName: 'Flores',
    email: 'ana@example.com',
    address: 'Potosi',
  );
  @override
  Future<DriverSessionStatusResult> fetchSessionStatus({
    required String token,
  }) async {
    calls++;
    if (fail) throw Exception('offline');
    return pending == null ? result : await pending!.future;
  }

  @override
  Future<DriverProfileDetails> fetchDriverProfile({
    required String token,
    required String userId,
    bool forceRefresh = false,
  }) async {
    profileCalls++;
    return DriverProfileDetails.fromJson({
      'id': 'driver-1',
      'access_status': 'AUTORIZADO',
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeRepository repository;
  late ProviderContainer container;
  Future<void> restore() async {
    container.read(driverSessionProvider);
    for (
      var i = 0;
      i < 50 && container.read(driverSessionProvider).isRestoring;
      i++
    ) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(container.read(driverSessionProvider).isRestoring, false);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'driver_session_logged_in': true,
      'driver_session_user_id': 'user-1',
      'driver_session_token': 'token-1',
      'driver_session_profile_completed': true,
      'driver_session_full_name': 'Ana local',
    });
    repository = FakeRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    await restore();
  });
  tearDown(() => container.dispose());

  test('restores saved profile without a network request', () {
    expect(container.read(driverSessionProvider).fullName, 'Ana local');
    expect(container.read(driverSessionProvider).profileCompleted, true);
    expect(repository.calls, 0);
  });
  test(
    'persists refreshed profile, throttles polling and permits explicit refresh',
    () async {
      final controller = container.read(driverSessionProvider.notifier);
      await controller.refreshSessionStatus();
      await controller.refreshSessionStatus();
      expect(repository.calls, 1);
      await controller.refreshSessionStatus(force: true);
      expect(repository.calls, 2);
      container.dispose();
      container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      await restore();
      expect(container.read(driverSessionProvider).fullName, 'Ana Flores');
      expect(container.read(driverSessionProvider).profileCompleted, true);
      expect(repository.calls, 2);
    },
  );
  test(
    'coalesces overlapping refreshes and ignores results after logout',
    () async {
      repository.pending = Completer<DriverSessionStatusResult>();
      final controller = container.read(driverSessionProvider.notifier);
      final request = controller.refreshSessionStatus();
      await controller.refreshSessionStatus();
      expect(repository.calls, 1);
      await controller.logout();
      repository.pending!.complete(repository.result);
      await request;
      expect(container.read(driverSessionProvider).token, isEmpty);
      expect(container.read(driverSessionProvider).profileCompleted, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('driver_session_full_name'), isNull);
    },
  );
  test(
    'network failure retains profile and backs off repeated attempts',
    () async {
      repository.fail = true;
      final controller = container.read(driverSessionProvider.notifier);
      await controller.refreshSessionStatus();
      await controller.refreshSessionStatus();
      expect(repository.calls, 1);
      expect(container.read(driverSessionProvider).fullName, 'Ana local');
      expect(container.read(driverSessionProvider).profileCompleted, true);
    },
  );
}
