import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/config/app_config.dart';
import '../domain/session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return const AuthRepository();
});

final sessionProvider = NotifierProvider<SessionController, Session>(SessionController.new);

class AuthRepository {
  const AuthRepository();

  Future<void> requestOtp(String phone) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'role': 'passenger',
        'fullName': 'Passenger Demo',
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo solicitar OTP (${response.statusCode})');
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
      }),
    );

    return response.statusCode < 400;
  }
}

class SessionController extends Notifier<Session> {
  late final AuthRepository _repository;

  @override
  Session build() {
    _repository = ref.watch(authRepositoryProvider);
    return const Session(
      phone: '',
      otpRequested: false,
      isAuthenticated: false,
      isLoading: false,
      errorMessage: null,
    );
  }

  Future<void> requestOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.requestOtp(phone);
      state = state.copyWith(
        phone: phone,
        otpRequested: true,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> verifyOtp(String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final valid = await _repository.verifyOtp(state.phone, otp);
      state = state.copyWith(
        isAuthenticated: valid,
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
