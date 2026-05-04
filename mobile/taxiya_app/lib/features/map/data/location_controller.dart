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
  @override
  PassengerLocationState build() {
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
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Activa el GPS para mostrar autos cercanos.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Permiso de ubicacion denegado.',
        );
        return;
      }

      final current = await Geolocator.getCurrentPosition();
      if (!PotosiGeo.isInside(current.latitude, current.longitude)) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'La app solo opera dentro de Potosi.',
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        position: LatLng(current.latitude, current.longitude),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo obtener tu ubicacion.',
      );
    }
  }
}
