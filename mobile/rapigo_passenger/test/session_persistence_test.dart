import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_passenger/features/auth/data/auth_repository.dart';

class FakeRepository extends AuthRepository {
  int calls = 0;
  int profileCalls = 0;
  Completer<SessionStatusResult>? pending;
  bool fail = false;
  final result = const SessionStatusResult(
    deviceStatus: 'AUTORIZADO',
    profileCompleted: true,
    fullName: 'Ana Flores',
    firstName: 'Ana',
    lastName: 'Flores',
    email: 'ana@example.com',
    address: 'Potosi',
    completedTripCount: 1,
    promoProgressCount: 1,
    freeTripCredits: 0,
    promoEnabled: true,
    promoCycleLength: 5,
  );
  @override
  Future<SessionStatusResult> fetchSessionStatus({
    required String token,
  }) async {
    calls++;
    if (fail) throw Exception('offline');
    return pending == null ? result : await pending!.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeRepository repository;
  late ProviderContainer container;
  Future<void> restore() async {
    container.read(sessionProvider);
    for (
      var i = 0;
      i < 50 && container.read(sessionProvider).isRestoring;
      i++
    ) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(container.read(sessionProvider).isRestoring, false);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'session_authenticated': true,
      'session_user_id': 'user-1',
      'session_token': 'token-1',
      'session_profile_completed': true,
      'session_full_name': 'Ana local',
    });
    repository = FakeRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    await restore();
  });
  tearDown(() => container.dispose());

  test('restores saved profile without a network request', () {
    expect(container.read(sessionProvider).fullName, 'Ana local');
    expect(container.read(sessionProvider).profileCompleted, true);
    expect(repository.calls, 0);
  });
  test(
    'persists refreshed profile, throttles polling and permits explicit refresh',
    () async {
      final controller = container.read(sessionProvider.notifier);
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
      expect(container.read(sessionProvider).fullName, 'Ana Flores');
      expect(container.read(sessionProvider).profileCompleted, true);
      expect(repository.calls, 2);
    },
  );
  test(
    'coalesces overlapping refreshes and ignores results after logout',
    () async {
      repository.pending = Completer<SessionStatusResult>();
      final controller = container.read(sessionProvider.notifier);
      final request = controller.refreshSessionStatus();
      await controller.refreshSessionStatus();
      expect(repository.calls, 1);
      await controller.signOut();
      repository.pending!.complete(repository.result);
      await request;
      expect(container.read(sessionProvider).token, isEmpty);
      expect(container.read(sessionProvider).profileCompleted, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('session_full_name'), isNull);
    },
  );
  test(
    'network failure retains profile and backs off repeated attempts',
    () async {
      repository.fail = true;
      final controller = container.read(sessionProvider.notifier);
      await controller.refreshSessionStatus();
      await controller.refreshSessionStatus();
      expect(repository.calls, 1);
      expect(container.read(sessionProvider).fullName, 'Ana local');
      expect(container.read(sessionProvider).profileCompleted, true);
    },
  );
}
