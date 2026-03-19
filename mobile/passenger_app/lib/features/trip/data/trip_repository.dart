import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../domain/trip_request.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return const TripRepository();
});

final tripProvider = NotifierProvider<TripController, TripState>(TripController.new);

class TripRepository {
  const TripRepository();

  Future<List<TripHistoryItem>> fetchHistory({
    required String token,
    required String passengerId,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/trips/history/$passengerId'),
      headers: _headers(token),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo cargar el historial (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((item) => item as Map<String, dynamic>)
        .map(
          (item) => TripHistoryItem(
            id: item['id']?.toString() ?? '',
            status: item['status']?.toString() ?? 'unknown',
            pickupAddress: item['pickup_address']?.toString() ?? 'Origen',
            destinationAddress: item['destination_address']?.toString() ?? 'Destino',
            requestedAt: item['requested_at']?.toString() ?? '',
          ),
        )
        .toList();
  }

  Future<List<NearbyDriver>> fetchNearbyDrivers({
    required String token,
    required double lat,
    required double lng,
  }) async {
    final dispatchResponse = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/dispatch/nearby?lat=$lat&lng=$lng&radiusMeters=3000&limit=8'),
      headers: _headers(token),
    );

    if (dispatchResponse.statusCode >= 400) {
      throw Exception('No se pudo cargar autos cercanos (${dispatchResponse.statusCode})');
    }

    final locationResponse = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/locations/nearby?lat=$lat&lng=$lng&radiusMeters=3000&limit=8'),
      headers: _headers(token),
    );

    final dispatchPayload = jsonDecode(dispatchResponse.body) as Map<String, dynamic>;
    final dispatchDrivers = (dispatchPayload['drivers'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    final locationPayload = locationResponse.statusCode < 400
        ? jsonDecode(locationResponse.body) as Map<String, dynamic>
        : <String, dynamic>{};
    final locationDrivers = (locationPayload['drivers'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final locationById = {
      for (final driver in locationDrivers) driver['driver_id']?.toString() ?? '': driver,
    };

    return dispatchDrivers.map((driver) {
      final id = driver['driver_id']?.toString() ?? '';
      final live = locationById[id] ?? driver;
      return NearbyDriver(
        driverId: id,
        lat: _toDouble(live['lat']),
        lng: _toDouble(live['lng']),
        distanceMeters: _toDouble(driver['distance_meters']),
        rating: _toDouble(driver['rating'], fallback: 5),
        etaMinutes: (driver['eta_minutes'] as num?)?.toInt() ?? max(2, (_toDouble(driver['distance_meters']) / 350).round()),
      );
    }).toList();
  }

  Future<TripRequest> requestTrip({
    required String token,
    required String passengerId,
    required LatLng pickup,
    required String pickupAddress,
    required String destinationAddress,
  }) async {
    final destination = _deriveDestinationFromPickup(pickup);
    final distanceMeters = _estimateDistanceMeters(pickup, destination);
    final durationSeconds = max(300, (distanceMeters / 5.5).round());
    final fareAmount = max(10, (distanceMeters / 700).ceil() * 3).toDouble();

    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/trips'),
      headers: _headers(token),
      body: jsonEncode({
        'passengerId': passengerId,
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'pickupLat': pickup.latitude,
        'pickupLng': pickup.longitude,
        'destinationLat': destination.latitude,
        'destinationLng': destination.longitude,
        'estimatedDistanceMeters': distanceMeters,
        'estimatedDurationSeconds': durationSeconds,
        'fareAmount': fareAmount,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo solicitar el viaje (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return TripRequest(
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      status: payload['status']?.toString() ?? 'requested',
      activeTripId: payload['id']?.toString(),
    );
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static LatLng _deriveDestinationFromPickup(LatLng pickup) {
    return LatLng(pickup.latitude + 0.0085, pickup.longitude + 0.0065);
  }

  static int _estimateDistanceMeters(LatLng from, LatLng to) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, from, to).round();
  }

  static double _toDouble(Object? value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class TripController extends Notifier<TripState> {
  late final TripRepository _repository;

  @override
  TripState build() {
    _repository = ref.watch(tripRepositoryProvider);
    return TripState(
      request: const TripRequest(
        pickupAddress: 'Mi ubicacion actual',
        destinationAddress: 'Destino por confirmar',
        status: 'idle',
        activeTripId: null,
      ),
      isLoading: false,
      isRequestingTrip: false,
      history: const [],
      nearbyDrivers: const [],
      errorMessage: null,
    );
  }

  Future<void> loadDashboard({
    required String token,
    required String passengerId,
    required LatLng userLocation,
  }) async {
    if (token.isEmpty || passengerId.isEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repository.fetchHistory(token: token, passengerId: passengerId),
        _repository.fetchNearbyDrivers(
          token: token,
          lat: userLocation.latitude,
          lng: userLocation.longitude,
        ),
      ]);

      state = state.copyWith(
        isLoading: false,
        history: results[0] as List<TripHistoryItem>,
        nearbyDrivers: results[1] as List<NearbyDriver>,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> requestRide({
    required String token,
    required String passengerId,
    required LatLng userLocation,
    required String destinationAddress,
  }) async {
    state = state.copyWith(isRequestingTrip: true, clearError: true);
    try {
      final request = await _repository.requestTrip(
        token: token,
        passengerId: passengerId,
        pickup: userLocation,
        pickupAddress: 'Mi ubicacion actual',
        destinationAddress: destinationAddress,
      );

      state = state.copyWith(
        request: request,
        isRequestingTrip: false,
        clearError: true,
      );
      await loadDashboard(
        token: token,
        passengerId: passengerId,
        userLocation: userLocation,
      );
    } catch (error) {
      state = state.copyWith(
        isRequestingTrip: false,
        errorMessage: error.toString(),
      );
    }
  }
}
