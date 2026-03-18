import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/config/app_config.dart';
import '../domain/driver_session.dart';

final authRepositoryProvider = Provider<DriverAuthRepository>((ref) {
  return const DriverAuthRepository();
});

final driverSessionProvider =
    NotifierProvider<DriverSessionController, DriverSession>(DriverSessionController.new);

class DriverAuthRepository {
  const DriverAuthRepository();

  Future<bool> login(String phone, String otp) async {
    final requestOtp = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'role': 'driver',
        'fullName': 'Driver Demo',
      }),
    );

    if (requestOtp.statusCode >= 400) {
      throw Exception('No se pudo solicitar OTP (${requestOtp.statusCode})');
    }

    final verify = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
      }),
    );

    return verify.statusCode < 400;
  }
}

class DriverSessionController extends Notifier<DriverSession> {
  late final DriverAuthRepository _repository;

  @override
  DriverSession build() {
    _repository = ref.watch(authRepositoryProvider);
    return const DriverSession(
      phone: '',
      loggedIn: false,
      isLoading: false,
      errorMessage: null,
    );
  }

  Future<void> login(String phone, String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final valid = await _repository.login(phone, otp);
      state = state.copyWith(
        phone: phone,
        loggedIn: valid,
        isLoading: false,
        errorMessage: valid ? null : 'OTP invalido',
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }
}
