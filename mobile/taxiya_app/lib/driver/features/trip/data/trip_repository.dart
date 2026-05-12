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
final driverOffersProvider =
    NotifierProvider<DriverOffersController, AsyncValue<List<DriverTrip>>>(DriverOffersController.new);
final driverTripHistoryProvider = FutureProvider<List<DriverTrip>>((ref) async {
  final session = ref.watch(driverSessionProvider);
  if (!session.loggedIn || session.driverId.isEmpty || session.token.isEmpty) {
    return const [];
  }

  final repository = ref.watch(tripRepositoryProvider);
  return repository.fetchHistory(
    token: session.token,
    driverId: session.driverId,
  );
});

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
      destination: item['destination_address']?.toString() ?? 'Destino no esta marcado',
      status: item['status']?.toString() ?? 'accepted',
      pickupLat: _toDouble(item['pickup_lat']),
      pickupLng: _toDouble(item['pickup_lng']),
      destinationLat: _toNullableDouble(item['destination_lat']),
      destinationLng: _toNullableDouble(item['destination_lng']),
      fareAmount: _toDouble(item['fare_amount']),
      requestedAt: item['requested_at']?.toString(),
      vehicleType: item['vehicle_type']?.toString(),
      vehicleLabel: _joinVehicleLabel(item['vehicle_brand'], item['vehicle_model']),
      vehiclePlate: item['vehicle_plate']?.toString(),
      vehicleColor: item['vehicle_color']?.toString(),
      passengerName: item['passenger_name']?.toString(),
      passengerPhone: item['passenger_phone']?.toString(),
      isPromotional: item['promotional_trip'] == true,
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
    return _mapTrip(item, fallbackStatus: 'requested');
  }

  Future<List<DriverTrip>> fetchOffers({
    required String token,
    required String driverId,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/dispatch/offers/$driverId'),
      headers: _headers(token),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudieron cargar ofertas (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final offers = (payload['offers'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => _mapTrip(item, fallbackStatus: 'requested'))
        .toList(growable: false);
    return offers;
  }

  Future<List<DriverTrip>> fetchHistory({
    required String token,
    required String driverId,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/trips/history/driver/$driverId'),
      headers: _headers(token),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo cargar el historial (${response.statusCode})');
    }

    final payload = (jsonDecode(response.body) as List<dynamic>? ?? const []);
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => _mapTrip(item))
        .toList(growable: false);
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

  Future<void> reject({
    required String token,
    required String driverId,
    required String tripId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/dispatch/reject'),
      headers: _headers(token),
      body: jsonEncode({
        'tripId': tripId,
        'driverId': driverId,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('No se pudo rechazar el viaje (${response.statusCode})');
    }
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

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static DriverTrip _mapTrip(Map<String, dynamic> item, {String fallbackStatus = 'accepted'}) {
    return DriverTrip(
      id: item['id']?.toString() ?? '',
      passengerPickup: item['pickup_address']?.toString() ?? 'Recojo',
      destination: item['destination_address']?.toString() ?? 'Destino no esta marcado',
      status: item['status']?.toString() ?? fallbackStatus,
      pickupLat: _toDouble(item['pickup_lat']),
      pickupLng: _toDouble(item['pickup_lng']),
      destinationLat: _toNullableDouble(item['destination_lat']),
      destinationLng: _toNullableDouble(item['destination_lng']),
      fareAmount: _toDouble(item['fare_amount']),
      requestedAt: item['requested_at']?.toString(),
      vehicleType: item['vehicle_type']?.toString(),
      vehicleLabel: _joinVehicleLabel(item['vehicle_brand'], item['vehicle_model']),
      vehiclePlate: item['vehicle_plate']?.toString(),
      vehicleColor: item['vehicle_color']?.toString(),
      passengerName: item['passenger_name']?.toString(),
      passengerPhone: item['passenger_phone']?.toString(),
      isPromotional: item['promotional_trip'] == true,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
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

class DriverTripController extends Notifier<AsyncValue<DriverTrip?>> {
  bool _isLoadingOffer = false;

  DriverTripRepository get _repository => ref.read(tripRepositoryProvider);

  @override
  AsyncValue<DriverTrip?> build() {
    return const AsyncData(null);
  }

  Future<void> loadOffer() async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn || session.driverId.isEmpty || session.token.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    if (_isLoadingOffer) {
      return;
    }

    _isLoadingOffer = true;
    if (state.value == null) {
      state = const AsyncLoading();
    }
    try {
      state = await AsyncValue.guard(() => _repository.fetchOffer(
            token: session.token,
            driverId: session.driverId,
          ));
    } finally {
      _isLoadingOffer = false;
    }
  }

  Future<void> acceptTrip([DriverTrip? trip]) async {
    final session = ref.read(driverSessionProvider);
    final current = trip ?? state.value;
    if (current == null || session.driverId.isEmpty || session.token.isEmpty) {
      return;
    }

    try {
      final acceptedTrip = await _repository.accept(
        token: session.token,
        driverId: session.driverId,
        trip: current,
      );
      state = AsyncData(acceptedTrip);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
    ref.invalidate(driverTripHistoryProvider);
    ref.invalidate(driverOffersProvider);
  }

  Future<void> updateTripStatus(String status) async {
    final session = ref.read(driverSessionProvider);
    final current = state.value;
    if (current == null || session.token.isEmpty) {
      return;
    }

    try {
      final updatedTrip = await _repository.updateStatus(
        token: session.token,
        trip: current,
        status: status,
      );
      state = AsyncData(updatedTrip);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
    ref.invalidate(driverTripHistoryProvider);
  }

  void setLocalStatus(String status) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(status: status));
  }
}

class DriverOffersController extends Notifier<AsyncValue<List<DriverTrip>>> {
  bool _isLoadingOffers = false;

  DriverTripRepository get _repository => ref.read(tripRepositoryProvider);

  @override
  AsyncValue<List<DriverTrip>> build() {
    return const AsyncData([]);
  }

  Future<void> loadOffers() async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn || session.driverId.isEmpty || session.token.isEmpty) {
      state = const AsyncData([]);
      return;
    }
    if (_isLoadingOffers) {
      return;
    }

    _isLoadingOffers = true;
    if ((state.value ?? const <DriverTrip>[]).isEmpty) {
      state = const AsyncLoading();
    }
    try {
      state = await AsyncValue.guard(() => _repository.fetchOffers(
            token: session.token,
            driverId: session.driverId,
          ));
    } finally {
      _isLoadingOffers = false;
    }
  }

  Future<void> rejectOffer(String tripId) async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn || session.driverId.isEmpty || session.token.isEmpty) {
      return;
    }
    try {
      await _repository.reject(
        token: session.token,
        driverId: session.driverId,
        tripId: tripId,
      );
      final current = [...(state.value ?? const <DriverTrip>[])];
      current.removeWhere((trip) => trip.id == tripId);
      state = AsyncData(current);
      ref.invalidate(driverTripHistoryProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void removeOfferLocally(String tripId) {
    final current = [...(state.value ?? const <DriverTrip>[])];
    current.removeWhere((trip) => trip.id == tripId);
    state = AsyncData(current);
  }
}
