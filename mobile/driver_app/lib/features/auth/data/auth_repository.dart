import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../domain/driver_session.dart';

final authRepositoryProvider = Provider<DriverAuthRepository>((ref) {
  return const DriverAuthRepository();
});

final driverSessionProvider =
    NotifierProvider<DriverSessionController, DriverSession>(DriverSessionController.new);

class DriverAuthResult {
  const DriverAuthResult({
    required this.userId,
    required this.driverId,
    required this.phone,
    required this.fullName,
    required this.token,
  });

  final String userId;
  final String driverId;
  final String phone;
  final String fullName;
  final String token;
}

class DriverAuthRepository {
  const DriverAuthRepository();

  Future<void> requestOtp(String phone, String fullName) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'role': 'driver',
        'fullName': fullName,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo solicitar OTP (${response.statusCode})');
    }
  }

  Future<DriverAuthResult> verifyOtp(String phone, String otp) async {
    final verify = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
      }),
    );

    if (verify.statusCode >= 400) {
      throw Exception('OTP invalido (${verify.statusCode})');
    }

    final payload = jsonDecode(verify.body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    final token = payload['token']?.toString() ?? '';
    final userId = user['id']?.toString() ?? '';
    final fullName = user['fullName']?.toString() ?? 'Conductor Taxi Ya';

    final ensureProfile = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/drivers/ensure-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'userId': userId,
        'fullName': fullName,
        'phone': user['phone']?.toString() ?? phone,
      }),
    );

    if (ensureProfile.statusCode >= 400) {
      throw Exception('No se pudo crear el perfil del conductor (${ensureProfile.statusCode})');
    }

    final ensurePayload = jsonDecode(ensureProfile.body) as Map<String, dynamic>;
    final driver = ensurePayload['driver'] as Map<String, dynamic>? ?? const {};

    return DriverAuthResult(
      userId: userId,
      driverId: driver['id']?.toString() ?? '',
      phone: user['phone']?.toString() ?? phone,
      fullName: fullName,
      token: token,
    );
  }
}

class DriverSessionController extends Notifier<DriverSession> {
  late final DriverAuthRepository _repository;

  @override
  DriverSession build() {
    _repository = ref.watch(authRepositoryProvider);
    final initial = const DriverSession(
      userId: '',
      driverId: '',
      phone: '',
      fullName: 'Conductor Taxi Ya',
      token: '',
      otpRequested: false,
      loggedIn: false,
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
      await prefs.setBool('driver_session_logged_in', true);
      await prefs.setString('driver_session_user_id', result.userId);
      await prefs.setString('driver_session_driver_id', result.driverId);
      await prefs.setString('driver_session_phone', result.phone);
      await prefs.setString('driver_session_full_name', result.fullName);
      await prefs.setString('driver_session_token', result.token);

      state = state.copyWith(
        userId: result.userId,
        driverId: result.driverId,
        phone: result.phone,
        fullName: result.fullName,
        token: result.token,
        otpRequested: true,
        loggedIn: true,
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('driver_session_logged_in');
    await prefs.remove('driver_session_user_id');
    await prefs.remove('driver_session_driver_id');
    await prefs.remove('driver_session_phone');
    await prefs.remove('driver_session_full_name');
    await prefs.remove('driver_session_token');

    state = const DriverSession(
      userId: '',
      driverId: '',
      phone: '',
      fullName: 'Conductor Taxi Ya',
      token: '',
      otpRequested: false,
      loggedIn: false,
      isLoading: false,
      errorMessage: null,
      isRestoring: false,
    );
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('driver_session_logged_in') ?? false;
    state = state.copyWith(
      userId: prefs.getString('driver_session_user_id') ?? '',
      driverId: prefs.getString('driver_session_driver_id') ?? '',
      phone: prefs.getString('driver_session_phone') ?? '',
      fullName: prefs.getString('driver_session_full_name') ?? 'Conductor Taxi Ya',
      token: prefs.getString('driver_session_token') ?? '',
      otpRequested: loggedIn,
      loggedIn: loggedIn,
      isRestoring: false,
      clearError: true,
    );
  }
}
