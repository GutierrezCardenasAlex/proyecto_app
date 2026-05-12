import 'dart:convert';
import 'dart:io';

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
    required this.vehicleType,
    required this.accessStatus,
    required this.phone,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.address,
    required this.token,
    required this.profileCompleted,
    required this.deviceStatus,
  });

  final String userId;
  final String driverId;
  final String vehicleType;
  final String accessStatus;
  final String phone;
  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String address;
  final String token;
  final bool profileCompleted;
  final String deviceStatus;
}

class DriverOtpRequestResult {
  const DriverOtpRequestResult({
    required this.smsDelivered,
    this.otp,
    this.message,
  });

  final bool smsDelivered;
  final String? otp;
  final String? message;
}

class DriverProfileDetails {
  const DriverProfileDetails({
    required this.licenseNumber,
    required this.vehicleType,
    required this.driverId,
    required this.accessStatus,
    required this.plate,
    required this.brand,
    required this.model,
    required this.color,
    required this.year,
  });

  final String licenseNumber;
  final String vehicleType;
  final String driverId;
  final String accessStatus;
  final String plate;
  final String brand;
  final String model;
  final String color;
  final int? year;
}

class DriverSessionStatusResult {
  const DriverSessionStatusResult({
    required this.deviceStatus,
    required this.profileCompleted,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.address,
  });

  final String deviceStatus;
  final bool profileCompleted;
  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String address;
}

class DriverAuthRepository {
  const DriverAuthRepository();

  Future<DriverProfileDetails> fetchDriverProfile({
    required String token,
    required String userId,
  }) async {
    final response = await _safeRequest(
      () => http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/drivers/by-user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
      fallbackMessage: 'No se pudo cargar el perfil del conductor',
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo cargar el perfil del conductor');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final vehicle = payload['vehicle'] as Map<String, dynamic>? ?? const {};
    return DriverProfileDetails(
      licenseNumber: payload['license_number']?.toString() ?? payload['licenseNumber']?.toString() ?? '',
      vehicleType: vehicle['vehicle_type']?.toString() ?? vehicle['type']?.toString() ?? 'taxi',
      driverId: payload['id']?.toString() ?? '',
      accessStatus: payload['access_status']?.toString() ?? 'AUTORIZADO',
      plate: vehicle['plate']?.toString() ?? '',
      brand: vehicle['brand']?.toString() ?? '',
      model: vehicle['model']?.toString() ?? '',
      color: vehicle['color']?.toString() ?? '',
      year: vehicle['year'] is num ? (vehicle['year'] as num).toInt() : int.tryParse(vehicle['year']?.toString() ?? ''),
    );
  }

  Future<DriverOtpRequestResult> requestRegistrationOtp(String phone, String firstName) async {
    final response = await _safeRequest(
      () => http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/register/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'role': 'driver',
          'firstName': firstName,
        }),
      ),
      fallbackMessage: 'No se pudo solicitar el OTP',
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo solicitar el OTP');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return DriverOtpRequestResult(
      smsDelivered: payload['smsDelivered'] == true,
      otp: payload['otp']?.toString(),
      message: payload['message']?.toString(),
    );
  }

  Future<DriverAuthResult> completeRegistration({
    required String phone,
    required String firstName,
    required String otp,
    required String password,
  }) async {
    final device = await DeviceIdentityService.load();
    final verify = await _safeRequest(
      () => http.post(
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
      ),
      fallbackMessage: 'No se pudo completar el registro',
    );
    await _throwIfError(verify, fallbackMessage: 'No se pudo completar el registro');
    return _resolveDriverAuth(verify.body, fallbackPhone: phone);
  }

  Future<DriverAuthResult> login({
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
          'role': 'driver',
          'deviceIdentifier': device.identifier,
          'deviceName': device.name,
          'platform': device.platform,
        }),
      ),
      fallbackMessage: 'No se pudo iniciar sesion',
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo iniciar sesion');
    return _resolveDriverAuth(response.body, fallbackPhone: phone);
  }

  Future<DriverOtpRequestResult> requestPasswordResetOtp(String phone) async {
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
    return DriverOtpRequestResult(
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
    final authProfileResponse = await _safeRequest(
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
      fallbackMessage: 'No se pudo guardar el perfil',
    );
    await _throwIfError(authProfileResponse, fallbackMessage: 'No se pudo guardar el perfil');

    final driverProfileResponse = await _safeRequest(
      () => http.post(
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
      ),
      fallbackMessage: 'No se pudo guardar el vehiculo',
    );
    await _throwIfError(driverProfileResponse, fallbackMessage: 'No se pudo guardar el vehiculo');

    final payload = jsonDecode(authProfileResponse.body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    final driverPayload = jsonDecode(driverProfileResponse.body) as Map<String, dynamic>;
    final driver = driverPayload['driver'] as Map<String, dynamic>? ?? const {};
    return DriverAuthResult(
      userId: user['id']?.toString() ?? userId,
      driverId: driverId,
      vehicleType: vehicleType,
      accessStatus: driver['access_status']?.toString() ?? 'AUTORIZADO',
      phone: user['phone']?.toString() ?? phone,
      fullName: user['fullName']?.toString() ?? '$firstName $lastName'.trim(),
      firstName: user['firstName']?.toString() ?? firstName,
      lastName: user['lastName']?.toString() ?? lastName,
      email: user['email']?.toString() ?? email,
      address: user['address']?.toString() ?? address,
      token: token,
      profileCompleted: user['profileCompleted'] == true,
      deviceStatus: 'AUTORIZADO',
    );
  }

  Future<DriverSessionStatusResult> fetchSessionStatus({
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
      fallbackMessage: 'No se pudo revisar el estado del conductor',
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo revisar el estado del conductor');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    return DriverSessionStatusResult(
      deviceStatus: payload['deviceStatus']?.toString() ?? 'PENDIENTE',
      profileCompleted: user['profileCompleted'] == true,
      fullName: user['fullName']?.toString() ?? 'Conductor Flash Go',
      firstName: user['firstName']?.toString() ?? '',
      lastName: user['lastName']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      address: user['address']?.toString() ?? '',
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

  Future<http.Response> _safeRequest(
    Future<http.Response> Function() request, {
    required String fallbackMessage,
  }) async {
    try {
      return await request();
    } on SocketException {
      throw Exception('No se pudo conectar con Flash Go. Revisa internet o el acceso al servidor.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con Flash Go. Revisa internet o el acceso al servidor.');
    }
  }

  Future<DriverAuthResult> _resolveDriverAuth(String body, {required String fallbackPhone}) async {
    final payload = jsonDecode(body) as Map<String, dynamic>;
    final user = payload['user'] as Map<String, dynamic>? ?? const {};
    final token = payload['token']?.toString() ?? '';
    final userId = user['id']?.toString() ?? '';
    final role = user['role']?.toString() ?? '';

    if (role.isNotEmpty && role != 'driver') {
      throw Exception('Este numero ya esta registrado con rol de pasajero. La central debe habilitar un conductor aparte.');
    }

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
    final vehicle = driver['vehicle'] as Map<String, dynamic>? ?? const {};

    return DriverAuthResult(
      userId: userId,
      driverId: driver['id']?.toString() ?? '',
      vehicleType: vehicle['vehicle_type']?.toString() ?? vehicle['type']?.toString() ?? 'taxi',
      accessStatus: driver['access_status']?.toString() ?? 'AUTORIZADO',
      phone: user['phone']?.toString() ?? fallbackPhone,
      fullName: user['fullName']?.toString() ?? 'Conductor Flash Go',
      firstName: user['firstName']?.toString() ?? '',
      lastName: user['lastName']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      address: user['address']?.toString() ?? '',
      token: token,
      profileCompleted: user['profileCompleted'] == true,
      deviceStatus: ensurePayload['status']?.toString() ?? 'AUTORIZADO',
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
      vehicleType: 'taxi',
      accessStatus: 'AUTORIZADO',
      phone: '',
      fullName: 'Conductor Flash Go',
      firstName: '',
      lastName: '',
      email: '',
      address: '',
      token: '',
      otpRequested: false,
      loggedIn: false,
      profileCompleted: false,
      deviceStatus: 'AUTORIZADO',
      isLoading: false,
      errorMessage: null,
      isRestoring: true,
    );
    Future<void>.microtask(_restoreSession);
    return initial;
  }

  Future<DriverOtpRequestResult?> requestRegistrationOtp(String phone, String firstName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.requestRegistrationOtp(phone, firstName);
      state = state.copyWith(
        phone: phone,
        firstName: firstName,
        fullName: firstName,
        vehicleType: state.vehicleType,
        accessStatus: state.accessStatus,
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
    await prefs.remove('driver_session_vehicle_type');
    await prefs.remove('driver_session_access_status');
    await prefs.remove('driver_session_phone');
    await prefs.remove('driver_session_full_name');
    await prefs.remove('driver_session_first_name');
    await prefs.remove('driver_session_last_name');
    await prefs.remove('driver_session_email');
    await prefs.remove('driver_session_address');
    await prefs.remove('driver_session_token');
    await prefs.remove('driver_session_profile_completed');
    await prefs.remove('driver_session_device_status');
    await prefs.remove('driver_desired_availability');

    state = const DriverSession(
      userId: '',
      driverId: '',
      vehicleType: 'taxi',
      accessStatus: 'AUTORIZADO',
      phone: '',
      fullName: 'Conductor Flash Go',
      firstName: '',
      lastName: '',
      email: '',
      address: '',
      token: '',
      otpRequested: false,
      loggedIn: false,
      profileCompleted: false,
      deviceStatus: 'AUTORIZADO',
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

  Future<void> refreshAccessStatus() async {
    if (!state.loggedIn || state.token.isEmpty || state.userId.isEmpty) {
      return;
    }

    try {
      final profile = await _repository.fetchDriverProfile(
        token: state.token,
        userId: state.userId,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_session_access_status', profile.accessStatus);
      if (profile.driverId.isNotEmpty) {
        await prefs.setString('driver_session_driver_id', profile.driverId);
      }
      if (profile.vehicleType.isNotEmpty) {
        await prefs.setString('driver_session_vehicle_type', profile.vehicleType);
      }
      state = state.copyWith(
        accessStatus: profile.accessStatus,
        driverId: profile.driverId.isNotEmpty ? profile.driverId : state.driverId,
        vehicleType: profile.vehicleType.isNotEmpty ? profile.vehicleType : state.vehicleType,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _persistSession(DriverAuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_session_logged_in', true);
    await prefs.setString('driver_session_user_id', result.userId);
    await prefs.setString('driver_session_driver_id', result.driverId);
    await prefs.setString('driver_session_vehicle_type', result.vehicleType);
    await prefs.setString('driver_session_access_status', result.accessStatus);
    await prefs.setString('driver_session_phone', result.phone);
    await prefs.setString('driver_session_full_name', result.fullName);
    await prefs.setString('driver_session_first_name', result.firstName);
    await prefs.setString('driver_session_last_name', result.lastName);
    await prefs.setString('driver_session_email', result.email);
    await prefs.setString('driver_session_address', result.address);
    await prefs.setString('driver_session_token', result.token);
    await prefs.setBool('driver_session_profile_completed', result.profileCompleted);
    await prefs.setString('driver_session_device_status', result.deviceStatus);

    state = state.copyWith(
      userId: result.userId,
      driverId: result.driverId,
      vehicleType: result.vehicleType,
      accessStatus: result.accessStatus,
      phone: result.phone,
      fullName: result.fullName,
      firstName: result.firstName,
      lastName: result.lastName,
      email: result.email,
      address: result.address,
      token: result.token,
      otpRequested: false,
      loggedIn: true,
      profileCompleted: result.profileCompleted,
      deviceStatus: result.deviceStatus,
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
      vehicleType: prefs.getString('driver_session_vehicle_type') ?? 'taxi',
      accessStatus: prefs.getString('driver_session_access_status') ?? 'AUTORIZADO',
      phone: prefs.getString('driver_session_phone') ?? '',
      fullName: prefs.getString('driver_session_full_name') ?? 'Conductor Flash Go',
      firstName: prefs.getString('driver_session_first_name') ?? '',
      lastName: prefs.getString('driver_session_last_name') ?? '',
      email: prefs.getString('driver_session_email') ?? '',
      address: prefs.getString('driver_session_address') ?? '',
      token: prefs.getString('driver_session_token') ?? '',
      otpRequested: false,
      loggedIn: loggedIn,
      profileCompleted: prefs.getBool('driver_session_profile_completed') ?? false,
      deviceStatus: prefs.getString('driver_session_device_status') ?? 'AUTORIZADO',
      isRestoring: false,
      clearError: true,
    );
  }

  Future<void> refreshSessionStatus() async {
    if (!state.loggedIn || state.token.isEmpty) {
      return;
    }

    try {
      final status = await _repository.fetchSessionStatus(token: state.token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_session_device_status', status.deviceStatus);
      await prefs.setBool('driver_session_profile_completed', status.profileCompleted);
      await prefs.setString('driver_session_full_name', status.fullName);
      await prefs.setString('driver_session_first_name', status.firstName);
      await prefs.setString('driver_session_last_name', status.lastName);
      await prefs.setString('driver_session_email', status.email);
      await prefs.setString('driver_session_address', status.address);
      state = state.copyWith(
        deviceStatus: status.deviceStatus,
        profileCompleted: status.profileCompleted,
        fullName: status.fullName,
        firstName: status.firstName,
        lastName: status.lastName,
        email: status.email,
        address: status.address,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString().replaceFirst('Exception: ', ''));
    }
  }
}
