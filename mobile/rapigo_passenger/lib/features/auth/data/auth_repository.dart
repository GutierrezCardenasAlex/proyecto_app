import 'dart:convert';
import 'dart:io';

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
    required this.deviceStatus,
    required this.completedTripCount,
    required this.promoProgressCount,
    required this.freeTripCredits,
    required this.promoEnabled,
    required this.promoCycleLength,
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
  final String deviceStatus;
  final int completedTripCount;
  final int promoProgressCount;
  final int freeTripCredits;
  final bool promoEnabled;
  final int promoCycleLength;
}

class SessionStatusResult {
  const SessionStatusResult({
    required this.deviceStatus,
    required this.profileCompleted,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.address,
    required this.completedTripCount,
    required this.promoProgressCount,
    required this.freeTripCredits,
    required this.promoEnabled,
    required this.promoCycleLength,
  });

  final String deviceStatus;
  final bool profileCompleted;
  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String address;
  final int completedTripCount;
  final int promoProgressCount;
  final int freeTripCredits;
  final bool promoEnabled;
  final int promoCycleLength;
}

class OtpRequestResult {
  const OtpRequestResult({
    required this.smsDelivered,
    this.otp,
    this.message,
  });

  final bool smsDelivered;
  final String? otp;
  final String? message;
}

class AuthRepository {
  const AuthRepository();

  bool _readPromoEnabled(Map<String, dynamic> payload) {
    final promo = payload['promo'] as Map<String, dynamic>?;
    return promo?['enabled'] != false;
  }

  int _readPromoCycleLength(Map<String, dynamic> payload) {
    final promo = payload['promo'] as Map<String, dynamic>?;
    final value = promo?['cycleLength'];
    return value is num ? value.toInt() : 5;
  }

  Future<OtpRequestResult> requestRegistrationOtp(String phone, String firstName) async {
    final response = await _safeRequest(
      () => http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/register/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'role': 'passenger',
          'firstName': firstName,
        }),
      ),
      fallbackMessage: 'No se pudo solicitar el OTP',
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo solicitar el OTP');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return OtpRequestResult(
      smsDelivered: payload['smsDelivered'] == true,
      otp: payload['otp']?.toString(),
      message: payload['message']?.toString(),
    );
  }

  Future<AuthResult> completeRegistration({
    required String phone,
    required String firstName,
    required String otp,
    required String password,
  }) async {
    final device = await DeviceIdentityService.load();
    final response = await _safeRequest(
      () => http.post(
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
      ),
      fallbackMessage: 'No se pudo completar el registro',
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo completar el registro');
    return _parseAuthResult(response.body, fallbackPhone: phone);
  }

  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final device = await DeviceIdentityService.load();
    final response = await _safeRequest(
      () => http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
          'role': 'passenger',
          'deviceIdentifier': device.identifier,
          'deviceName': device.name,
          'platform': device.platform,
        }),
      ),
      fallbackMessage: 'No se pudo iniciar sesion',
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo iniciar sesion');
    return _parseAuthResult(response.body, fallbackPhone: phone);
  }

  Future<OtpRequestResult> requestPasswordResetOtp(String phone) async {
    final response = await _safeRequest(
      () => http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/password/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      ),
      fallbackMessage: 'No se pudo solicitar el OTP de recuperacion',
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo solicitar el OTP de recuperacion');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return OtpRequestResult(
      smsDelivered: payload['smsDelivered'] == true,
      otp: payload['otp']?.toString(),
      message: payload['message']?.toString(),
    );
  }

  Future<void> resetPassword({
    required String phone,
    required String otp,
    required String password,
  }) async {
    final response = await _safeRequest(
      () => http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'otp': otp,
          'password': password,
        }),
      ),
      fallbackMessage: 'No se pudo cambiar la contrasena',
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo cambiar la contrasena');
  }

  Future<AuthResult> completeProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String email,
    required String address,
  }) async {
    final response = await _safeRequest(
      () => http.post(
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
      ),
      fallbackMessage: 'No se pudo guardar tu perfil',
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
      deviceStatus: 'AUTORIZADO',
      completedTripCount: user['completedTripCount'] is num ? (user['completedTripCount'] as num).toInt() : 0,
      promoProgressCount: user['promoProgressCount'] is num ? (user['promoProgressCount'] as num).toInt() : 0,
      freeTripCredits: user['freeTripCredits'] is num ? (user['freeTripCredits'] as num).toInt() : 0,
      promoEnabled: _readPromoEnabled(payload),
      promoCycleLength: _readPromoCycleLength(payload),
    );
  }

  Future<SessionStatusResult> fetchSessionStatus({
    required String token,
  }) async {
    final device = await DeviceIdentityService.load();
    final response = await _safeRequest(
      () => http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/session-status?deviceIdentifier=${Uri.encodeQueryComponent(device.identifier)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
      fallbackMessage: 'No se pudo revisar el estado de la sesion',
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo revisar el estado de la sesion');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    return SessionStatusResult(
      deviceStatus: payload['deviceStatus']?.toString() ?? 'PENDIENTE',
      profileCompleted: user['profileCompleted'] == true,
      fullName: user['fullName']?.toString() ?? 'Pasajero RAPIGO',
      firstName: user['firstName']?.toString() ?? '',
      lastName: user['lastName']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      address: user['address']?.toString() ?? '',
      completedTripCount: user['completedTripCount'] is num ? (user['completedTripCount'] as num).toInt() : 0,
      promoProgressCount: user['promoProgressCount'] is num ? (user['promoProgressCount'] as num).toInt() : 0,
      freeTripCredits: user['freeTripCredits'] is num ? (user['freeTripCredits'] as num).toInt() : 0,
      promoEnabled: _readPromoEnabled(payload),
      promoCycleLength: _readPromoCycleLength(payload),
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

  Future<http.Response> _safeRequest(
    Future<http.Response> Function() request, {
    required String fallbackMessage,
  }) async {
    try {
      return await request();
    } on SocketException {
      throw Exception('No se pudo conectar con RAPIGO. Revisa internet o el acceso al servidor.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con RAPIGO. Revisa internet o el acceso al servidor.');
    }
  }

  AuthResult _parseAuthResult(String body, {required String fallbackPhone}) {
    final payload = jsonDecode(body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    final role = user['role']?.toString() ?? '';
    if (role.isNotEmpty && role != 'passenger') {
      throw Exception(
        'Esta cuenta pertenece a conductor y no puede entrar por el acceso de pasajero.',
      );
    }
    return AuthResult(
      userId: user['id']?.toString() ?? '',
      phone: user['phone']?.toString() ?? fallbackPhone,
      fullName: user['fullName']?.toString() ?? 'Pasajero RAPIGO',
      firstName: user['firstName']?.toString() ?? '',
      lastName: user['lastName']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      address: user['address']?.toString() ?? '',
      token: payload['token']?.toString() ?? '',
      profileCompleted: user['profileCompleted'] == true,
      deviceStatus: payload['status']?.toString() ?? 'AUTORIZADO',
      completedTripCount: user['completedTripCount'] is num ? (user['completedTripCount'] as num).toInt() : 0,
      promoProgressCount: user['promoProgressCount'] is num ? (user['promoProgressCount'] as num).toInt() : 0,
      freeTripCredits: user['freeTripCredits'] is num ? (user['freeTripCredits'] as num).toInt() : 0,
      promoEnabled: _readPromoEnabled(payload),
      promoCycleLength: _readPromoCycleLength(payload),
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
      fullName: 'Pasajero RAPIGO',
      firstName: '',
      lastName: '',
      email: '',
      address: '',
      token: '',
      otpRequested: false,
      isAuthenticated: false,
      profileCompleted: false,
      deviceStatus: 'AUTORIZADO',
      completedTripCount: 0,
      promoProgressCount: 0,
      freeTripCredits: 0,
      promoEnabled: true,
      promoCycleLength: 5,
      isLoading: false,
      errorMessage: null,
      isRestoring: true,
    );
    Future<void>.microtask(_restoreSession);
    return initial;
  }

  Future<OtpRequestResult?> requestRegistrationOtp(String phone, String firstName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.requestRegistrationOtp(phone, firstName);
      state = state.copyWith(
        phone: phone,
        firstName: firstName,
        fullName: firstName,
        otpRequested: true,
        isLoading: false,
        clearError: true,
      );
      return result;
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Exception: ', ''));
      return null;
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

  void cancelRegistrationOtp() {
    state = state.copyWith(
      otpRequested: false,
      isLoading: false,
      clearError: true,
    );
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
    await prefs.remove('session_device_status');
    await prefs.remove('session_completed_trip_count');
    await prefs.remove('session_promo_progress_count');
    await prefs.remove('session_free_trip_credits');
    await prefs.remove('session_promo_enabled');
    await prefs.remove('session_promo_cycle_length');
    state = const Session(
      userId: '',
      phone: '',
      fullName: 'Pasajero RAPIGO',
      firstName: '',
      lastName: '',
      email: '',
      address: '',
      token: '',
      otpRequested: false,
      isAuthenticated: false,
      profileCompleted: false,
      deviceStatus: 'AUTORIZADO',
      completedTripCount: 0,
      promoProgressCount: 0,
      freeTripCredits: 0,
      promoEnabled: true,
      promoCycleLength: 5,
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
    await prefs.setString('session_device_status', result.deviceStatus);
    await prefs.setInt('session_completed_trip_count', result.completedTripCount);
    await prefs.setInt('session_promo_progress_count', result.promoProgressCount);
    await prefs.setInt('session_free_trip_credits', result.freeTripCredits);
    await prefs.setBool('session_promo_enabled', result.promoEnabled);
    await prefs.setInt('session_promo_cycle_length', result.promoCycleLength);
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
      deviceStatus: result.deviceStatus,
      completedTripCount: result.completedTripCount,
      promoProgressCount: result.promoProgressCount,
      freeTripCredits: result.freeTripCredits,
      promoEnabled: result.promoEnabled,
      promoCycleLength: result.promoCycleLength,
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
      fullName: prefs.getString('session_full_name') ?? 'Pasajero RAPIGO',
      firstName: prefs.getString('session_first_name') ?? '',
      lastName: prefs.getString('session_last_name') ?? '',
      email: prefs.getString('session_email') ?? '',
      address: prefs.getString('session_address') ?? '',
      token: prefs.getString('session_token') ?? '',
      otpRequested: false,
      isAuthenticated: authenticated,
      profileCompleted: prefs.getBool('session_profile_completed') ?? false,
      deviceStatus: prefs.getString('session_device_status') ?? 'AUTORIZADO',
      completedTripCount: prefs.getInt('session_completed_trip_count') ?? 0,
      promoProgressCount: prefs.getInt('session_promo_progress_count') ?? 0,
      freeTripCredits: prefs.getInt('session_free_trip_credits') ?? 0,
      promoEnabled: prefs.getBool('session_promo_enabled') ?? true,
      promoCycleLength: prefs.getInt('session_promo_cycle_length') ?? 5,
      isRestoring: false,
      clearError: true,
    );
  }

  Future<bool> refreshSessionStatus() async {
    if (!state.isAuthenticated || state.token.isEmpty) {
      return false;
    }

    try {
      final status = await _repository.fetchSessionStatus(token: state.token);
      final previousCredits = state.freeTripCredits;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_device_status', status.deviceStatus);
      await prefs.setBool('session_profile_completed', status.profileCompleted);
      await prefs.setString('session_full_name', status.fullName);
      await prefs.setString('session_first_name', status.firstName);
      await prefs.setString('session_last_name', status.lastName);
      await prefs.setString('session_email', status.email);
      await prefs.setString('session_address', status.address);
      await prefs.setInt('session_completed_trip_count', status.completedTripCount);
      await prefs.setInt('session_promo_progress_count', status.promoProgressCount);
      await prefs.setInt('session_free_trip_credits', status.freeTripCredits);
      await prefs.setBool('session_promo_enabled', status.promoEnabled);
      await prefs.setInt('session_promo_cycle_length', status.promoCycleLength);
      state = state.copyWith(
        deviceStatus: status.deviceStatus,
        profileCompleted: status.profileCompleted,
        fullName: status.fullName,
        firstName: status.firstName,
        lastName: status.lastName,
        email: status.email,
        address: status.address,
        completedTripCount: status.completedTripCount,
        promoProgressCount: status.promoProgressCount,
        freeTripCredits: status.freeTripCredits,
        promoEnabled: status.promoEnabled,
        promoCycleLength: status.promoCycleLength,
        clearError: true,
      );
      return status.freeTripCredits > previousCredits;
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }
}
