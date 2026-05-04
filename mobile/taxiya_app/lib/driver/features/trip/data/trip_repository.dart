import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/driver_trip.dart';

final tripRepositoryProvider = Provider<DriverTripRepository>((ref) {
  return const DriverTripRepository();
});

final offeredTripProvider =
    NotifierProvider<DriverTripController, AsyncValue<DriverTrip?>>(DriverTripController.new);

class DriverTripRepository {
  const DriverTripRepository();

  Future<DriverTrip?> fetchActiveTrip({
    required String token,
    required String driverId,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/trips/active/driver/$driverId'),
      headers: _headers(token),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo cargar el viaje activo (${response.statusCode})');
    }

    if (response.body.trim() == 'null') {
      return null;
    }

    final item = jsonDecode(response.body) as Map<String, dynamic>;
    return DriverTrip(
      id: item['id']?.toString() ?? '',
      passengerPickup: item['pickup_address']?.toString() ?? 'Recojo',
      destination: item['destination_address']?.toString() ?? 'Destino',
      status: item['status']?.toString() ?? 'accepted',
      pickupLat: _toDouble(item['pickup_lat']),
      pickupLng: _toDouble(item['pickup_lng']),
      destinationLat: _toDouble(item['destination_lat']),
      destinationLng: _toDouble(item['destination_lng']),
      fareAmount: _toDouble(item['fare_amount']),
      vehicleType: item['vehicle_type']?.toString(),
    );
  }

  Future<DriverTrip?> fetchOffer({
    required String token,
    required String driverId,
  }) async {
    final activeTrip = await fetchActiveTrip(token: token, driverId: driverId);
    if (activeTrip != null) {
      return activeTrip;
    }

    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/dispatch/offers/$driverId'),
      headers: _headers(token),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudieron cargar ofertas (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final offers = (payload['offers'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    if (offers.isEmpty) {
      return null;
    }

    final item = offers.first;
    return DriverTrip(
      id: item['id']?.toString() ?? '',
      passengerPickup: item['pickup_address']?.toString() ?? 'Recojo',
      destination: item['destination_address']?.toString() ?? 'Destino',
      status: item['status']?.toString() ?? 'requested',
      pickupLat: _toDouble(item['pickup_lat']),
      pickupLng: _toDouble(item['pickup_lng']),
      destinationLat: _toDouble(item['destination_lat']),
      destinationLng: _toDouble(item['destination_lng']),
      fareAmount: _toDouble(item['fare_amount']),
      vehicleType: item['vehicle_type']?.toString(),
    );
  }

  Future<DriverTrip> accept({
    required String token,
    required String driverId,
    required DriverTrip trip,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/dispatch/accept'),
      headers: _headers(token),
      body: jsonEncode({
        'tripId': trip.id,
        'driverId': driverId,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo aceptar el viaje (${response.statusCode})');
    }

    return trip.copyWith(status: 'accepted');
  }

  Future<DriverTrip> updateStatus({
    required String token,
    required DriverTrip trip,
    required String status,
  }) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/trips/${trip.id}/status'),
      headers: _headers(token),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo actualizar el viaje (${response.statusCode})');
    }

    return trip.copyWith(status: status);
  }

  Future<void> submitRating({
    required String token,
    required String tripId,
    required int score,
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/trips/$tripId/rating'),
      headers: _headers(token),
      body: jsonEncode({
        'fromRole': 'driver',
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

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class DriverTripController extends Notifier<AsyncValue<DriverTrip?>> {
  late final DriverTripRepository _repository;

  @override
  AsyncValue<DriverTrip?> build() {
    _repository = ref.watch(tripRepositoryProvider);
    return const AsyncData(null);
  }

  Future<void> loadOffer() async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn || session.driverId.isEmpty || session.token.isEmpty) {
      state = const AsyncData(null);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.fetchOffer(
          token: session.token,
          driverId: session.driverId,
        ));
  }

  Future<void> acceptTrip() async {
    final session = ref.read(driverSessionProvider);
    final current = state.value;
    if (current == null || session.driverId.isEmpty || session.token.isEmpty) {
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.accept(
          token: session.token,
          driverId: session.driverId,
          trip: current,
        ));
  }

  Future<void> updateTripStatus(String status) async {
    final session = ref.read(driverSessionProvider);
    final current = state.value;
    if (current == null || session.token.isEmpty) {
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.updateStatus(
          token: session.token,
          trip: current,
          status: status,
        ));
  }

  Future<void> submitRating({
    required int score,
    String? comment,
  }) async {
    final session = ref.read(driverSessionProvider);
    final current = state.value;
    if (current == null || session.token.isEmpty) {
      return;
    }

    await _repository.submitRating(
      token: session.token,
      tripId: current.id,
      score: score,
      comment: comment,
    );
    state = const AsyncData(null);
  }

  void setLocalStatus(String status) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(status: status));
  }
}
