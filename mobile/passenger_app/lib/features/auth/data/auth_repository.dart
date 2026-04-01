import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../core/config/app_config.dart';
import '../../../core/device/device_identity.dart';
import '../domain/session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return const AuthRepository();
});

final sessionProvider = NotifierProvider<SessionController, Session>(SessionController.new);

class AuthResult {
  const AuthResult({
    required this.userId,
    required this.phone,
    required this.fullName,
    required this.token,
  });

  final String userId;
  final String phone;
  final String fullName;
  final String token;
}

class AuthRepository {
  const AuthRepository();

  Future<void> requestOtp(String phone, String fullName) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'role': 'passenger',
        'fullName': fullName,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo solicitar OTP (${response.statusCode})');
    }
  }

  Future<AuthResult> verifyOtp(String phone, String otp) async {
    final device = await DeviceIdentityService.load();
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
        'deviceIdentifier': device.identifier,
        'deviceName': device.name,
        'platform': device.platform,
      }),
    );

    if (response.statusCode == 202 || response.statusCode == 403) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(payload['message']?.toString() ?? 'La central debe autorizar este dispositivo.');
    }

    if (response.statusCode >= 400) {
      throw Exception('OTP invalido (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    return AuthResult(
      userId: user['id']?.toString() ?? '',
      phone: user['phone']?.toString() ?? phone,
      fullName: user['fullName']?.toString() ?? 'Pasajero Taxi Ya',
      token: payload['token']?.toString() ?? '',
    );
  }
}

class SessionController extends Notifier<Session> {
  late final AuthRepository _repository;

  @override
  Session build() {
    _repository = ref.watch(authRepositoryProvider);
    final initial = const Session(
      userId: '',
      phone: '',
      fullName: 'Pasajero Taxi Ya',
      token: '',
      otpRequested: false,
      isAuthenticated: false,
      isLoading: false,
      errorMessage: null,
      isRestoring: true,
    );
    Future<void>.microtask(_restoreSession);
    return initial;
  }

  Future<void> requestOtp(String phone, String fullName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.requestOtp(phone, fullName);
      state = state.copyWith(
        phone: phone,
        fullName: fullName,
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
      final result = await _repository.verifyOtp(state.phone, otp);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('session_authenticated', true);
      await prefs.setString('session_user_id', result.userId);
      await prefs.setString('session_phone', result.phone);
      await prefs.setString('session_full_name', result.fullName);
      await prefs.setString('session_token', result.token);
      state = state.copyWith(
        userId: result.userId,
        phone: result.phone,
        fullName: result.fullName,
        token: result.token,
        isAuthenticated: true,
        isLoading: false,
        otpRequested: true,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_authenticated');
    await prefs.remove('session_user_id');
    await prefs.remove('session_phone');
    await prefs.remove('session_full_name');
    await prefs.remove('session_token');
    state = const Session(
      userId: '',
      phone: '',
      fullName: 'Pasajero Taxi Ya',
      token: '',
      otpRequested: false,
      isAuthenticated: false,
      isLoading: false,
      errorMessage: null,
      isRestoring: false,
    );
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final authenticated = prefs.getBool('session_authenticated') ?? false;
    final userId = prefs.getString('session_user_id') ?? '';
    final phone = prefs.getString('session_phone') ?? '';
    final fullName = prefs.getString('session_full_name') ?? 'Pasajero Taxi Ya';
    final token = prefs.getString('session_token') ?? '';

    state = state.copyWith(
      userId: userId,
      phone: phone,
      fullName: fullName,
      token: token,
      otpRequested: authenticated,
      isAuthenticated: authenticated,
      isRestoring: false,
      clearError: true,
    );
  }
}
