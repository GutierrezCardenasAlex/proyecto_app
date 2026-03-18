import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/driver_session.dart';

final authRepositoryProvider = Provider<DriverAuthRepository>((ref) {
  return const DriverAuthRepository();
});

final driverSessionProvider =
    NotifierProvider<DriverSessionController, DriverSession>(DriverSessionController.new);

class DriverAuthRepository {
  const DriverAuthRepository();

  Future<bool> login(String phone, String otp) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return otp == '123456';
  }
}

class DriverSessionController extends Notifier<DriverSession> {
  late final DriverAuthRepository _repository;

  @override
  DriverSession build() {
    _repository = ref.watch(authRepositoryProvider);
    return const DriverSession(phone: '', loggedIn: false);
  }

  Future<void> login(String phone, String otp) async {
    final valid = await _repository.login(phone, otp);
    state = state.copyWith(phone: phone, loggedIn: valid);
  }
}
