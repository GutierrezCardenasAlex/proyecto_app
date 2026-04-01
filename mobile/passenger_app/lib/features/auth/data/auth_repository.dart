import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.address,
    required this.token,
    required this.profileCompleted,
  });

  final String userId;
  final String phone;
  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String address;
  final String token;
  final bool profileCompleted;
}

class AuthRepository {
  const AuthRepository();

  Future<void> requestRegistrationOtp(String phone, String firstName) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/register/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'role': 'passenger',
        'firstName': firstName,
      }),
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo solicitar el OTP');
  }

  Future<AuthResult> completeRegistration({
    required String phone,
    required String firstName,
    required String otp,
    required String password,
  }) async {
    final device = await DeviceIdentityService.load();
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/register/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
        'password': password,
        'role': 'passenger',
        'firstName': firstName,
        'deviceIdentifier': device.identifier,
        'deviceName': device.name,
        'platform': device.platform,
      }),
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo completar el registro');
    return _parseAuthResult(response.body, fallbackPhone: phone);
  }

  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final device = await DeviceIdentityService.load();
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'deviceIdentifier': device.identifier,
        'deviceName': device.name,
        'platform': device.platform,
      }),
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo iniciar sesion');
    return _parseAuthResult(response.body, fallbackPhone: phone);
  }

  Future<AuthResult> completeProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String email,
    required String address,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'address': address,
        'markCompleted': true,
      }),
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo guardar tu perfil');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    return AuthResult(
      userId: user['id']?.toString() ?? '',
      phone: user['phone']?.toString() ?? '',
      fullName: user['fullName']?.toString() ?? '$firstName $lastName'.trim(),
      firstName: user['firstName']?.toString() ?? firstName,
      lastName: user['lastName']?.toString() ?? lastName,
      email: user['email']?.toString() ?? email,
      address: user['address']?.toString() ?? address,
      token: token,
      profileCompleted: user['profileCompleted'] == true,
    );
  }

  Future<void> _throwIfError(http.Response response, {required String fallbackMessage}) async {
    if (response.statusCode < 400) {
      return;
    }

    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final message = payload['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
    } on FormatException {
      // Continue with fallback message when body is not JSON.
    }
    throw Exception('$fallbackMessage (${response.statusCode})');
  }

  AuthResult _parseAuthResult(String body, {required String fallbackPhone}) {
    final payload = jsonDecode(body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    return AuthResult(
      userId: user['id']?.toString() ?? '',
      phone: user['phone']?.toString() ?? fallbackPhone,
      fullName: user['fullName']?.toString() ?? 'Pasajero Taxi Ya',
      firstName: user['firstName']?.toString() ?? '',
      lastName: user['lastName']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      address: user['address']?.toString() ?? '',
      token: payload['token']?.toString() ?? '',
      profileCompleted: user['profileCompleted'] == true,
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
      firstName: '',
      lastName: '',
      email: '',
      address: '',
      token: '',
      otpRequested: false,
      isAuthenticated: false,
      profileCompleted: false,
      isLoading: false,
      errorMessage: null,
      isRestoring: true,
    );
    Future<void>.microtask(_restoreSession);
    return initial;
  }

  Future<void> requestRegistrationOtp(String phone, String firstName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.requestRegistrationOtp(phone, firstName);
      state = state.copyWith(
        phone: phone,
        firstName: firstName,
        fullName: firstName,
        otpRequested: true,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> completeRegistration(String otp, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.completeRegistration(
        phone: state.phone,
        firstName: state.firstName,
        otp: otp,
        password: password,
      );
      await _persistSession(result);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> login(String phone, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.login(phone: phone, password: password);
      await _persistSession(result);
      state = state.copyWith(otpRequested: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> completeProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String address,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.completeProfile(
        token: state.token,
        firstName: firstName,
        lastName: lastName,
        email: email,
        address: address,
      );
      await _persistSession(result);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_authenticated');
    await prefs.remove('session_user_id');
    await prefs.remove('session_phone');
    await prefs.remove('session_full_name');
    await prefs.remove('session_first_name');
    await prefs.remove('session_last_name');
    await prefs.remove('session_email');
    await prefs.remove('session_address');
    await prefs.remove('session_token');
    await prefs.remove('session_profile_completed');
    state = const Session(
      userId: '',
      phone: '',
      fullName: 'Pasajero Taxi Ya',
      firstName: '',
      lastName: '',
      email: '',
      address: '',
      token: '',
      otpRequested: false,
      isAuthenticated: false,
      profileCompleted: false,
      isLoading: false,
      errorMessage: null,
      isRestoring: false,
    );
  }

  Future<void> _persistSession(AuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_authenticated', true);
    await prefs.setString('session_user_id', result.userId);
    await prefs.setString('session_phone', result.phone);
    await prefs.setString('session_full_name', result.fullName);
    await prefs.setString('session_first_name', result.firstName);
    await prefs.setString('session_last_name', result.lastName);
    await prefs.setString('session_email', result.email);
    await prefs.setString('session_address', result.address);
    await prefs.setString('session_token', result.token);
    await prefs.setBool('session_profile_completed', result.profileCompleted);
    state = state.copyWith(
      userId: result.userId,
      phone: result.phone,
      fullName: result.fullName,
      firstName: result.firstName,
      lastName: result.lastName,
      email: result.email,
      address: result.address,
      token: result.token,
      isAuthenticated: true,
      otpRequested: true,
      profileCompleted: result.profileCompleted,
      isLoading: false,
      clearError: true,
    );
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final authenticated = prefs.getBool('session_authenticated') ?? false;

    state = state.copyWith(
      userId: prefs.getString('session_user_id') ?? '',
      phone: prefs.getString('session_phone') ?? '',
      fullName: prefs.getString('session_full_name') ?? 'Pasajero Taxi Ya',
      firstName: prefs.getString('session_first_name') ?? '',
      lastName: prefs.getString('session_last_name') ?? '',
      email: prefs.getString('session_email') ?? '',
      address: prefs.getString('session_address') ?? '',
      token: prefs.getString('session_token') ?? '',
      otpRequested: false,
      isAuthenticated: authenticated,
      profileCompleted: prefs.getBool('session_profile_completed') ?? false,
      isRestoring: false,
      clearError: true,
    );
  }
}
