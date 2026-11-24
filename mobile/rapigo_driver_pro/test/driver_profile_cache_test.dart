import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_driver_pro/driver/features/auth/data/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'driver_session_user_id': 'one',
      'driver_session_token': 'token',
    }),
  );

  test(
    'reuses persisted details and forces fresh authorization checks',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(jsonEncode({'id': 'driver-$calls'}), 200);
      });
      await http.runWithClient(() async {
        const repository = DriverAuthRepository();
        final first = await repository.fetchDriverProfile(
          token: 'token',
          userId: 'one',
        );
        final second = await repository.fetchDriverProfile(
          token: 'token',
          userId: 'one',
        );
        expect(first.driverId, second.driverId);
        expect(calls, 1);
        await repository.fetchDriverProfile(
          token: 'token',
          userId: 'one',
          forceRefresh: true,
        );
        expect(calls, 2);
        await repository.fetchDriverProfile(token: 'other', userId: 'two');
        expect(calls, 3);
      }, () => client);
    },
  );

  for (final saved in [
    'broken-json',
    jsonEncode({
      'savedAt': 0,
      'profile': {'id': 'expired'},
    }),
  ]) {
    test('fetches again for invalid or expired cache: $saved', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_profile_v1_one', saved);
      var calls = 0;
      await http.runWithClient(
        () async {
          final profile = await const DriverAuthRepository().fetchDriverProfile(
            token: 'token',
            userId: 'one',
          );
          expect(profile.driverId, 'fresh');
          expect(calls, 1);
        },
        () => MockClient((_) async {
          calls++;
          return http.Response('{"id":"fresh"}', 200);
        }),
      );
    });
  }
}
