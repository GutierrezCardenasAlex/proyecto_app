import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
      clearError: true,
    );
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
      state = await _repository.updateAvailability(
        token: session.token,
        driverId: session.driverId,
        available: available,
        currentState: state,
      );

      if (available) {
        await _sendLocation();
        _gpsTimer?.cancel();
        _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
          await _sendLocation();
          await ref.read(offeredTripProvider.notifier).loadOffer();
        });
      } else {
        _gpsTimer?.cancel();
      }

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

  Future<void> _sendLocation() async {
    final session = ref.read(driverSessionProvider);
    final trip = ref.read(offeredTripProvider).value;
    final position = await _repository.getCurrentPosition();
    state = await _repository.sendLocation(
      token: session.token,
      driverId: session.driverId,
      position: position,
      currentState: state,
      activeTripId: trip?.status == 'accepted' ? trip?.id : null,
    );
  }
}
