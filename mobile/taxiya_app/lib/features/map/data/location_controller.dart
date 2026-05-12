import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/potosi_geo.dart';

final passengerLocationProvider =
    NotifierProvider<PassengerLocationController, PassengerLocationState>(PassengerLocationController.new);

class PassengerLocationState {
  const PassengerLocationState({
    required this.isLoading,
    required this.position,
    required this.errorMessage,
  });

  final bool isLoading;
  final LatLng? position;
  final String? errorMessage;

  PassengerLocationState copyWith({
    bool? isLoading,
    LatLng? position,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PassengerLocationState(
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class PassengerLocationController extends Notifier<PassengerLocationState> {
  StreamSubscription<Position>? _positionSubscription;

  @override
  PassengerLocationState build() {
    ref.onDispose(() {
      _positionSubscription?.cancel();
    });
    Future<void>.microtask(loadCurrentLocation);
    return const PassengerLocationState(
      isLoading: true,
      position: null,
      errorMessage: null,
    );
  }

  Future<void> loadCurrentLocation() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _ensureLocationReady();
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _applyPosition(current);
      await _startTracking();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo obtener tu ubicacion.',
      );
    }
  }

  Future<void> _ensureLocationReady() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Activa el GPS para mostrar autos cercanos.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicacion denegado.');
    }
  }

  Future<void> _startTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen(
      _applyPosition,
      onError: (_) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No se pudo seguir tu ubicacion en segundo plano.',
        );
      },
    );
  }

  LocationSettings _locationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
        intervalDuration: const Duration(seconds: 4),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Flash Go activo',
          notificationText: 'Seguimos actualizando tu ubicacion para viajes y alertas.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 8,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    );
  }

  void _applyPosition(Position position) {
    if (!PotosiGeo.isInside(position.latitude, position.longitude)) {
      state = state.copyWith(
        isLoading: false,
        position: LatLng(position.latitude, position.longitude),
        errorMessage: 'La app solo opera dentro de Potosi.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      position: LatLng(position.latitude, position.longitude),
      clearError: true,
    );
  }
}
