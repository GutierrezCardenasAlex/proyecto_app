import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return const AuthRepository();
});

final sessionProvider = NotifierProvider<SessionController, Session>(SessionController.new);

class AuthRepository {
  const AuthRepository();

  Future<void> requestOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return otp == '123456';
  }
}

class SessionController extends Notifier<Session> {
  late final AuthRepository _repository;

  @override
  Session build() {
    _repository = ref.watch(authRepositoryProvider);
    return const Session(phone: '', otpRequested: false, isAuthenticated: false);
  }

  Future<void> requestOtp(String phone) async {
    await _repository.requestOtp(phone);
    state = state.copyWith(phone: phone, otpRequested: true);
  }

  Future<void> verifyOtp(String otp) async {
    final valid = await _repository.verifyOtp(state.phone, otp);
    state = state.copyWith(isAuthenticated: valid);
  }
}
