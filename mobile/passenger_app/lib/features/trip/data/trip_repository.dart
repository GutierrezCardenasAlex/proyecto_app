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

  Future<TripRequest?> fetchActiveTrip({
    required String token,
    required String passengerId,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/trips/active/passenger/$passengerId'),
      headers: _headers(token),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo cargar el viaje activo (${response.statusCode})');
    }

    if (response.body.trim() == 'null') {
      return null;
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return TripRequest(
      pickupAddress: payload['pickup_address']?.toString() ?? 'Mi ubicacion actual',
      destinationAddress: payload['destination_address']?.toString() ?? 'Destino por confirmar',
      status: payload['status']?.toString() ?? 'idle',
      activeTripId: payload['id']?.toString(),
      pickupLat: _toNullableDouble(payload['pickup_lat']),
      pickupLng: _toNullableDouble(payload['pickup_lng']),
      destinationLat: _toNullableDouble(payload['destination_lat']),
      destinationLng: _toNullableDouble(payload['destination_lng']),
      driverLat: _toNullableDouble(payload['driver_lat']),
      driverLng: _toNullableDouble(payload['driver_lng']),
      vehicleLabel: _joinVehicleLabel(payload['vehicle_brand'], payload['vehicle_model']),
      vehiclePlate: payload['vehicle_plate']?.toString(),
    );
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
      final brand = _stringValue(driver['brand'], fallback: 'Taxi');
      final model = _stringValue(driver['model'], fallback: 'Disponible');
      final color = _stringValue(driver['color'], fallback: 'Color por confirmar');
      final plate = _stringValue(driver['plate'], fallback: 'Sin placa');
      final distanceMeters = _toDouble(driver['distance_meters']);
      return NearbyDriver(
        driverId: id,
        lat: _toDouble(live['lat']),
        lng: _toDouble(live['lng']),
        distanceMeters: distanceMeters,
        rating: _toDouble(driver['rating'], fallback: 5),
        etaMinutes: (driver['eta_minutes'] as num?)?.toInt() ?? max(2, (distanceMeters / 350).round()),
        vehicleLabel: '$brand $model',
        vehicleDetail: '$color · $plate',
        priceLabel: 'Bs ${(8 + distanceMeters / 300).toStringAsFixed(0)}',
      );
    }).toList();
  }

  Future<TripRequest> requestTrip({
    required String token,
    required String passengerId,
    required LatLng pickup,
    required String pickupAddress,
    required String destinationAddress,
    String? preferredDriverId,
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
        if (preferredDriverId != null && preferredDriverId.isNotEmpty)
          'preferredDriverId': preferredDriverId,
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

  Future<TripRequest> updateTripStatus({
    required String token,
    required String tripId,
    required String status,
  }) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/trips/$tripId/status'),
      headers: _headers(token),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo actualizar el viaje (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return TripRequest(
      pickupAddress: payload['pickup_address']?.toString() ?? 'Mi ubicacion actual',
      destinationAddress: payload['destination_address']?.toString() ?? 'Destino por confirmar',
      status: payload['status']?.toString() ?? status,
      activeTripId: payload['id']?.toString() ?? tripId,
      pickupLat: _toNullableDouble(payload['pickup_lat']),
      pickupLng: _toNullableDouble(payload['pickup_lng']),
      destinationLat: _toNullableDouble(payload['destination_lat']),
      destinationLng: _toNullableDouble(payload['destination_lng']),
      driverLat: _toNullableDouble(payload['driver_lat']),
      driverLng: _toNullableDouble(payload['driver_lng']),
      vehicleLabel: _joinVehicleLabel(payload['vehicle_brand'], payload['vehicle_model']),
      vehiclePlate: payload['vehicle_plate']?.toString(),
    );
  }

  Future<void> submitRating({
    required String token,
    required String tripId,
    required String fromRole,
    required int score,
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/trips/$tripId/rating'),
      headers: _headers(token),
      body: jsonEncode({
        'fromRole': fromRole,
        'score': score,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo enviar la calificacion (${response.statusCode})');
    }
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

  static String _stringValue(Object? value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static double? _toNullableDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static String? _joinVehicleLabel(Object? brand, Object? model) {
    final brandText = brand?.toString().trim() ?? '';
    final modelText = model?.toString().trim() ?? '';
    final value = '$brandText $modelText'.trim();
    return value.isEmpty ? null : value;
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
        _repository.fetchActiveTrip(token: token, passengerId: passengerId),
        _repository.fetchNearbyDrivers(
          token: token,
          lat: userLocation.latitude,
          lng: userLocation.longitude,
        ),
      ]);

      state = state.copyWith(
        isLoading: false,
        history: results[0] as List<TripHistoryItem>,
        request: (results[1] as TripRequest?) ??
            state.request.copyWith(
              status: 'idle',
              clearTripId: true,
            ),
        nearbyDrivers: results[2] as List<NearbyDriver>,
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
    String? preferredDriverId,
  }) async {
    state = state.copyWith(isRequestingTrip: true, clearError: true);
    try {
      final request = await _repository.requestTrip(
        token: token,
        passengerId: passengerId,
        pickup: userLocation,
        pickupAddress: 'Mi ubicacion actual',
        destinationAddress: destinationAddress,
        preferredDriverId: preferredDriverId,
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

  void markTripAccepted({
    required String tripId,
    String status = 'accepted',
  }) {
    if (state.request.activeTripId != tripId) {
      return;
    }

    state = state.copyWith(
      request: state.request.copyWith(status: status),
      clearError: true,
    );
  }

  Future<void> updateTripStatus({
    required String token,
    required String tripId,
    required String status,
  }) async {
    try {
      final request = await _repository.updateTripStatus(
        token: token,
        tripId: tripId,
        status: status,
      );
      state = state.copyWith(request: request, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> submitRating({
    required String token,
    required String tripId,
    required int score,
    String? comment,
  }) async {
    await _repository.submitRating(
      token: token,
      tripId: tripId,
      fromRole: 'passenger',
      score: score,
      comment: comment,
    );

    state = state.copyWith(
      request: state.request.copyWith(
        status: 'idle',
        clearTripId: true,
      ),
      clearError: true,
    );
  }
}
