import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/potosi_geo.dart';
import '../../auth/data/auth_repository.dart';
import '../../trip/data/trip_repository.dart';
import '../domain/driver_state.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return const DriverRepository();
});

final driverStateProvider = NotifierProvider<DriverStateController, DriverState>(DriverStateController.new);

class DriverRepository {
  const DriverRepository();

  static const _desiredAvailabilityKey = 'driver_desired_availability';

  bool _isInsidePotosi(double lat, double lng) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat - PotosiGeo.centerLat);
    final dLng = _toRadians(lng - PotosiGeo.centerLng);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRadians(PotosiGeo.centerLat)) *
            cos(_toRadians(lat)) *
            (sin(dLng / 2) * sin(dLng / 2));
    final distance = 2 * earthRadiusKm * atan2(sqrt(a), sqrt(1 - a));
    return distance <= PotosiGeo.maxRadiusKm;
  }

  Future<DriverState> updateAvailability({
    required String token,
    required String driverId,
    required bool available,
    required DriverState currentState,
  }) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/drivers/availability'),
      headers: _headers(token),
      body: jsonEncode({
        'driverId': driverId,
        'isAvailable': available,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo actualizar disponibilidad (${response.statusCode})');
    }

    return currentState.copyWith(
      available: available,
      backendStatus: available ? 'available' : 'offline',
      clearError: true,
    );
  }

  Future<String> ensureDriverProfile({
    required String token,
    required String userId,
    required String fullName,
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/drivers/ensure-profile'),
      headers: _headers(token),
      body: jsonEncode({
        'userId': userId,
        'fullName': fullName,
        'phone': phone,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo restaurar el perfil del conductor (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final driver = payload['driver'] as Map<String, dynamic>? ?? const {};
    final driverId = driver['id']?.toString() ?? '';
    if (driverId.isEmpty) {
      throw Exception('El servidor no devolvio un conductor valido.');
    }
    return driverId;
  }

  Future<Position> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Activa el GPS para operar como conductor.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicacion denegado.');
    }

    final current = await Geolocator.getCurrentPosition();
    if (!_isInsidePotosi(current.latitude, current.longitude)) {
      throw Exception('La app del conductor solo opera dentro de Potosi.');
    }

    return current;
  }

  Future<DriverSnapshot> fetchDriverSnapshot({
    required String token,
    required String driverId,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/drivers/$driverId'),
      headers: _headers(token),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo consultar el estado del conductor (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return DriverSnapshot(
      isAvailable: payload['is_available'] == true,
      status: payload['status']?.toString() ?? 'offline',
    );
  }

  Future<void> persistDesiredAvailability(bool available) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_desiredAvailabilityKey, available);
  }

  Future<bool?> readDesiredAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_desiredAvailabilityKey)) {
      return null;
    }
    return prefs.getBool(_desiredAvailabilityKey);
  }

  Future<void> clearDesiredAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_desiredAvailabilityKey);
  }

  Future<DriverState> sendLocation({
    required String token,
    required String driverId,
    required Position position,
    required DriverState currentState,
    String? activeTripId,
  }) async {
    final heading = position.heading.isFinite ? position.heading : null;
    final speedKph = position.speed.isFinite && position.speed >= 0 ? position.speed * 3.6 : null;
    final payload = <String, Object>{
      'driverId': driverId,
      'lat': position.latitude,
      'lng': position.longitude,
    };
    if (activeTripId != null && activeTripId.isNotEmpty) {
      payload['tripId'] = activeTripId;
    }
    if (heading != null) {
      payload['heading'] = heading;
    }
    if (speedKph != null) {
      payload['speedKph'] = speedKph;
    }
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/locations/drivers'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo enviar GPS (${response.statusCode})');
    }

    return currentState.copyWith(
      lastLocationPing: DateTime.now(),
      lat: position.latitude,
      lng: position.longitude,
      clearError: true,
    );
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  double _toRadians(double value) => (value * pi) / 180;
}

class DriverStateController extends Notifier<DriverState> {
  late final DriverRepository _repository;
  Timer? _gpsTimer;

  @override
  DriverState build() {
    _repository = ref.watch(driverRepositoryProvider);
    ref.onDispose(() => _gpsTimer?.cancel());
    return const DriverState(
      available: false,
      backendStatus: 'offline',
      lastLocationPing: null,
      lat: -19.5842,
      lng: -65.7525,
      isUpdatingAvailability: false,
      errorMessage: null,
    );
  }

  Future<void> toggleAvailability(bool available) async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn || session.driverId.isEmpty || session.token.isEmpty) {
      state = state.copyWith(errorMessage: 'Inicia sesion para activar disponibilidad.');
      return;
    }

    state = state.copyWith(isUpdatingAvailability: true, clearError: true);
    try {
      var effectiveDriverId = session.driverId;
      try {
        state = await _repository.updateAvailability(
          token: session.token,
          driverId: effectiveDriverId,
          available: available,
          currentState: state,
        );
      } catch (error) {
        final message = error.toString();
        if (message.contains('(404)')) {
          effectiveDriverId = await _repository.ensureDriverProfile(
            token: session.token,
            userId: session.userId,
            fullName: session.fullName,
            phone: session.phone,
          );
          await ref.read(driverSessionProvider.notifier).updateDriverId(effectiveDriverId);
          state = await _repository.updateAvailability(
            token: session.token,
            driverId: effectiveDriverId,
            available: available,
            currentState: state,
          );
        } else {
          rethrow;
        }
      }

      if (available) {
        await _sendLocation();
        _gpsTimer?.cancel();
        _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
          await _sendLocation();
        });
      } else {
        _gpsTimer?.cancel();
      }

      await _repository.persistDesiredAvailability(available);

      state = state.copyWith(isUpdatingAvailability: false, clearError: true);
    } catch (error) {
      state = state.copyWith(
        isUpdatingAvailability: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> refreshLocation() async {
    try {
      await _sendLocation();
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> restoreOperationalState({bool force = false}) async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn || session.driverId.isEmpty || session.token.isEmpty) {
      return;
    }

    try {
      final snapshot = await _repository.fetchDriverSnapshot(
        token: session.token,
        driverId: session.driverId,
      );
      final desiredAvailability = await _repository.readDesiredAvailability();
      final shouldBeAvailable = force
          ? snapshot.isAvailable
          : (desiredAvailability ?? snapshot.isAvailable);

      state = state.copyWith(
        available: shouldBeAvailable,
        backendStatus: snapshot.status,
        clearError: true,
      );

      if (snapshot.isAvailable != shouldBeAvailable) {
        state = await _repository.updateAvailability(
          token: session.token,
          driverId: session.driverId,
          available: shouldBeAvailable,
          currentState: state,
        );
      }

      await _repository.persistDesiredAvailability(shouldBeAvailable);

      if (shouldBeAvailable) {
        await _sendLocation();
        _gpsTimer?.cancel();
        _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
          await _sendLocation();
        });
      } else {
        _gpsTimer?.cancel();
      }
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> _sendLocation() async {
    final session = ref.read(driverSessionProvider);
    final trip = ref.read(offeredTripProvider).value;
    final position = await _repository.getCurrentPosition();
    state = await _repository.sendLocation(
      token: session.token,
      driverId: session.driverId,
      position: position,
      currentState: state,
      activeTripId: trip == null
          ? null
          : const {'accepted', 'arriving', 'at_pickup', 'in_progress'}.contains(trip.status)
          ? trip.id
          : null,
    );
  }
}

class DriverSnapshot {
  const DriverSnapshot({
    required this.isAvailable,
    required this.status,
  });

  final bool isAvailable;
  final String status;
}
