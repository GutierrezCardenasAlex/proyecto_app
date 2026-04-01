import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/device/device_identity.dart';
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
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.address,
    required this.token,
    required this.profileCompleted,
  });

  final String userId;
  final String driverId;
  final String phone;
  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String address;
  final String token;
  final bool profileCompleted;
}

class DriverAuthRepository {
  const DriverAuthRepository();

  Future<void> requestRegistrationOtp(String phone, String firstName) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/register/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'role': 'driver',
        'firstName': firstName,
      }),
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo solicitar el OTP');
  }

  Future<DriverAuthResult> completeRegistration({
    required String phone,
    required String firstName,
    required String otp,
    required String password,
  }) async {
    final device = await DeviceIdentityService.load();
    final verify = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/register/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
        'password': password,
        'role': 'driver',
        'firstName': firstName,
        'deviceIdentifier': device.identifier,
        'deviceName': device.name,
        'platform': device.platform,
      }),
    );
    await _throwIfError(verify, fallbackMessage: 'No se pudo completar el registro');
    return _resolveDriverAuth(verify.body, fallbackPhone: phone);
  }

  Future<DriverAuthResult> login({
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
    return _resolveDriverAuth(response.body, fallbackPhone: phone);
  }

  Future<DriverAuthResult> completeProfile({
    required String token,
    required String userId,
    required String driverId,
    required String phone,
    required String firstName,
    required String lastName,
    required String email,
    required String address,
    required String licenseNumber,
    required String vehicleType,
    required String plate,
    required String brand,
    required String model,
    required String color,
    required int? year,
  }) async {
    final authProfileResponse = await http.post(
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
    await _throwIfError(authProfileResponse, fallbackMessage: 'No se pudo guardar el perfil');

    final driverProfileResponse = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/drivers/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'userId': userId,
        'licenseNumber': licenseNumber,
        'vehicle': {
          'type': vehicleType,
          'plate': plate,
          'brand': brand,
          'model': model,
          'color': color,
          'year': year,
        },
      }),
    );
    await _throwIfError(driverProfileResponse, fallbackMessage: 'No se pudo guardar el vehiculo');

    final payload = jsonDecode(authProfileResponse.body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    return DriverAuthResult(
      userId: user['id']?.toString() ?? userId,
      driverId: driverId,
      phone: user['phone']?.toString() ?? phone,
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
      // fallback below
    }
    throw Exception('$fallbackMessage (${response.statusCode})');
  }

  Future<DriverAuthResult> _resolveDriverAuth(String body, {required String fallbackPhone}) async {
    final payload = jsonDecode(body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    final token = payload['token']?.toString() ?? '';
    final userId = user['id']?.toString() ?? '';

    final ensureProfile = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/drivers/ensure-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'userId': userId,
        'fullName': user['fullName']?.toString() ?? '',
        'phone': user['phone']?.toString() ?? fallbackPhone,
      }),
    );
    await _throwIfError(ensureProfile, fallbackMessage: 'No se pudo crear el perfil del conductor');

    final ensurePayload = jsonDecode(ensureProfile.body) as Map<String, dynamic>;
    final driver = ensurePayload['driver'] as Map<String, dynamic>? ?? const {};

    return DriverAuthResult(
      userId: userId,
      driverId: driver['id']?.toString() ?? '',
      phone: user['phone']?.toString() ?? fallbackPhone,
      fullName: user['fullName']?.toString() ?? 'Conductor Taxi Ya',
      firstName: user['firstName']?.toString() ?? '',
      lastName: user['lastName']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      address: user['address']?.toString() ?? '',
      token: token,
      profileCompleted: user['profileCompleted'] == true,
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
      firstName: '',
      lastName: '',
      email: '',
      address: '',
      token: '',
      otpRequested: false,
      loggedIn: false,
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
    required String licenseNumber,
    required String vehicleType,
    required String plate,
    required String brand,
    required String model,
    required String color,
    required int? year,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.completeProfile(
        token: state.token,
        userId: state.userId,
        driverId: state.driverId,
        phone: state.phone,
        firstName: firstName,
        lastName: lastName,
        email: email,
        address: address,
        licenseNumber: licenseNumber,
        vehicleType: vehicleType,
        plate: plate,
        brand: brand,
        model: model,
        color: color,
        year: year,
      );
      await _persistSession(result);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('driver_session_logged_in');
    await prefs.remove('driver_session_user_id');
    await prefs.remove('driver_session_driver_id');
    await prefs.remove('driver_session_phone');
    await prefs.remove('driver_session_full_name');
    await prefs.remove('driver_session_first_name');
    await prefs.remove('driver_session_last_name');
    await prefs.remove('driver_session_email');
    await prefs.remove('driver_session_address');
    await prefs.remove('driver_session_token');
    await prefs.remove('driver_session_profile_completed');

    state = const DriverSession(
      userId: '',
      driverId: '',
      phone: '',
      fullName: 'Conductor Taxi Ya',
      firstName: '',
      lastName: '',
      email: '',
      address: '',
      token: '',
      otpRequested: false,
      loggedIn: false,
      profileCompleted: false,
      isLoading: false,
      errorMessage: null,
      isRestoring: false,
    );
  }

  Future<void> updateDriverId(String driverId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driver_session_driver_id', driverId);
    state = state.copyWith(driverId: driverId, clearError: true);
  }

  Future<void> _persistSession(DriverAuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_session_logged_in', true);
    await prefs.setString('driver_session_user_id', result.userId);
    await prefs.setString('driver_session_driver_id', result.driverId);
    await prefs.setString('driver_session_phone', result.phone);
    await prefs.setString('driver_session_full_name', result.fullName);
    await prefs.setString('driver_session_first_name', result.firstName);
    await prefs.setString('driver_session_last_name', result.lastName);
    await prefs.setString('driver_session_email', result.email);
    await prefs.setString('driver_session_address', result.address);
    await prefs.setString('driver_session_token', result.token);
    await prefs.setBool('driver_session_profile_completed', result.profileCompleted);

    state = state.copyWith(
      userId: result.userId,
      driverId: result.driverId,
      phone: result.phone,
      fullName: result.fullName,
      firstName: result.firstName,
      lastName: result.lastName,
      email: result.email,
      address: result.address,
      token: result.token,
      otpRequested: true,
      loggedIn: true,
      profileCompleted: result.profileCompleted,
      isLoading: false,
      clearError: true,
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
      firstName: prefs.getString('driver_session_first_name') ?? '',
      lastName: prefs.getString('driver_session_last_name') ?? '',
      email: prefs.getString('driver_session_email') ?? '',
      address: prefs.getString('driver_session_address') ?? '',
      token: prefs.getString('driver_session_token') ?? '',
      otpRequested: false,
      loggedIn: loggedIn,
      profileCompleted: prefs.getBool('driver_session_profile_completed') ?? false,
      isRestoring: false,
      clearError: true,
    );
  }
}
