import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/driver_trip.dart';
import 'trip_state_cache.dart';

final tripRepositoryProvider = Provider<DriverTripRepository>((ref) {
  return const DriverTripRepository();
});

final offeredTripProvider =
    NotifierProvider<DriverTripController, AsyncValue<DriverTrip?>>(
      DriverTripController.new,
    );
final driverOffersProvider =
    NotifierProvider<DriverOffersController, AsyncValue<List<DriverTrip>>>(
      DriverOffersController.new,
    );
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
      throw Exception(
        'No se pudo cargar el viaje activo (${response.statusCode})',
      );
    }

    if (response.body.trim() == 'null') {
      return null;
    }

    final item = jsonDecode(response.body) as Map<String, dynamic>;
    return DriverTrip(
      id: item['id']?.toString() ?? '',
      passengerPickup: item['pickup_address']?.toString() ?? 'Recojo',
      destination:
          item['destination_address']?.toString() ?? 'Destino no esta marcado',
      status: item['status']?.toString() ?? 'accepted',
      pickupLat: _toDouble(item['pickup_lat']),
      pickupLng: _toDouble(item['pickup_lng']),
      destinationLat: _toNullableDouble(item['destination_lat']),
      destinationLng: _toNullableDouble(item['destination_lng']),
      fareAmount: _toDouble(item['fare_amount']),
      requestedAt: item['requested_at']?.toString(),
      vehicleType: item['vehicle_type']?.toString(),
      vehicleLabel: _joinVehicleLabel(
        item['vehicle_brand'],
        item['vehicle_model'],
      ),
      vehiclePlate: item['vehicle_plate']?.toString(),
      vehicleColor: item['vehicle_color']?.toString(),
      passengerName: item['passenger_name']?.toString(),
      passengerPhone: item['passenger_phone']?.toString(),
      dispatchMode:
          item['dispatch_mode']?.toString() ?? item['dispatchMode']?.toString(),
      preferredDriverId:
          item['preferred_driver_id']?.toString() ??
          item['preferredDriverId']?.toString(),
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
    final offers = (payload['offers'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
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
      throw Exception(
        'No se pudo cargar el historial (${response.statusCode})',
      );
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
      body: jsonEncode({'tripId': trip.id, 'driverId': driverId}),
    );

    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response, 'No se pudo aceptar el viaje'));
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
      body: jsonEncode({'tripId': tripId, 'driverId': driverId}),
    );

    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response, 'No se pudo rechazar el viaje'));
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
      throw Exception(
        'No se pudo actualizar el viaje (${response.statusCode})',
      );
    }

    return trip.copyWith(status: status);
  }

  static Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  static String _errorMessage(http.Response response, String fallback) {
    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final message = payload['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return '$message (${response.statusCode})';
      }
    } catch (_) {
      // Use the stable fallback when the backend does not send JSON.
    }
    return '$fallback (${response.statusCode})';
  }

  static DriverTrip _mapTrip(
    Map<String, dynamic> item, {
    String fallbackStatus = 'accepted',
  }) {
    return DriverTrip(
      id: item['id']?.toString() ?? '',
      passengerPickup: item['pickup_address']?.toString() ?? 'Recojo',
      destination:
          item['destination_address']?.toString() ?? 'Destino no esta marcado',
      status: item['status']?.toString() ?? fallbackStatus,
      pickupLat: _toDouble(item['pickup_lat']),
      pickupLng: _toDouble(item['pickup_lng']),
      destinationLat: _toNullableDouble(item['destination_lat']),
      destinationLng: _toNullableDouble(item['destination_lng']),
      fareAmount: _toDouble(item['fare_amount']),
      requestedAt: item['requested_at']?.toString(),
      vehicleType: item['vehicle_type']?.toString(),
      vehicleLabel: _joinVehicleLabel(
        item['vehicle_brand'],
        item['vehicle_model'],
      ),
      vehiclePlate: item['vehicle_plate']?.toString(),
      vehicleColor: item['vehicle_color']?.toString(),
      passengerName: item['passenger_name']?.toString(),
      passengerPhone: item['passenger_phone']?.toString(),
      dispatchMode:
          item['dispatch_mode']?.toString() ?? item['dispatchMode']?.toString(),
      preferredDriverId:
          item['preferred_driver_id']?.toString() ??
          item['preferredDriverId']?.toString(),
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
  final DriverTripStateCache _cache = DriverTripStateCache();
  bool _restoredPersistedTrip = false;

  DriverTripRepository get _repository => ref.read(tripRepositoryProvider);

  @override
  AsyncValue<DriverTrip?> build() {
    if (!_restoredPersistedTrip) {
      _restoredPersistedTrip = true;
      Future<void>.microtask(_restorePersistedTrip);
    }
    return const AsyncData(null);
  }

  Future<void> _restorePersistedTrip() async {
    final cached = await _cache.readActiveTrip();
    if (cached == null) {
      return;
    }
    state = AsyncData(cached);
  }

  Future<void> _persistTrip() async {
    final trip = state.value;
    await _cache.writeActiveTrip(trip);
    await _cache.writeFlowMetadata(
      trip == null ? null : DriverTripStateCache.metadataFromTrip(trip),
    );
  }

  Future<void> loadOffer() async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn ||
        session.driverId.isEmpty ||
        session.token.isEmpty) {
      state = const AsyncData(null);
      await _persistTrip();
      return;
    }
    if (_isLoadingOffer) {
      return;
    }

    _isLoadingOffer = true;
    final previousTrip = state.value;
    if (state.value == null) {
      state = const AsyncLoading();
    }
    try {
      final trip = await _repository.fetchOffer(
        token: session.token,
        driverId: session.driverId,
      );
      state = AsyncData(trip);
      await _persistTrip();
    } catch (_) {
      final cached = await _cache.readActiveTrip();
      state = AsyncData(previousTrip ?? cached);
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
      await _persistTrip();
    } catch (error) {
      await clearTrip();
      await ref.read(driverOffersProvider.notifier).loadOffers();
      ref.invalidate(driverTripHistoryProvider);
      throw Exception(_friendlyAcceptError(error));
    } finally {
      ref.invalidate(driverTripHistoryProvider);
      ref.invalidate(driverOffersProvider);
    }
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
      await _persistTrip();
    } catch (error) {
      state = AsyncData(current);
      throw Exception(_friendlyTripStatusError(error));
    } finally {
      ref.invalidate(driverTripHistoryProvider);
    }
  }

  void setLocalStatus(String status) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(status: status));
    unawaited(_persistTrip());
  }

  Future<void> clearTrip() async {
    state = const AsyncData(null);
    await _persistTrip();
  }
}

class DriverOffersController extends Notifier<AsyncValue<List<DriverTrip>>> {
  bool _isLoadingOffers = false;
  final DriverTripStateCache _cache = DriverTripStateCache();
  bool _restoredPersistedOffers = false;

  DriverTripRepository get _repository => ref.read(tripRepositoryProvider);

  @override
  AsyncValue<List<DriverTrip>> build() {
    if (!_restoredPersistedOffers) {
      _restoredPersistedOffers = true;
      Future<void>.microtask(_restorePersistedOffers);
    }
    return const AsyncData([]);
  }

  Future<void> _restorePersistedOffers() async {
    final cached = await _cache.readOffers();
    if (cached.isEmpty) {
      return;
    }
    state = AsyncData(cached);
  }

  Future<void> _persistOffers() async {
    await _cache.writeOffers(state.value ?? const <DriverTrip>[]);
  }

  Future<void> loadOffers() async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn ||
        session.driverId.isEmpty ||
        session.token.isEmpty) {
      state = const AsyncData([]);
      await _persistOffers();
      return;
    }
    if (_isLoadingOffers) {
      return;
    }

    final activeTrip = ref.read(offeredTripProvider).value;
    if (activeTrip != null &&
        const {
          'accepted',
          'arriving',
          'at_pickup',
          'in_progress',
        }.contains(activeTrip.status)) {
      state = const AsyncData([]);
      await _persistOffers();
      return;
    }

    _isLoadingOffers = true;
    final previousOffers = state.value ?? const <DriverTrip>[];
    if ((state.value ?? const <DriverTrip>[]).isEmpty) {
      state = const AsyncLoading();
    }
    try {
      final offers = await _repository.fetchOffers(
        token: session.token,
        driverId: session.driverId,
      );
      state = AsyncData(offers);
      await _persistOffers();
    } catch (_) {
      final cached = await _cache.readOffers();
      state = AsyncData(cached.isNotEmpty ? cached : previousOffers);
    } finally {
      _isLoadingOffers = false;
    }
  }

  Future<void> rejectOffer(String tripId) async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn ||
        session.driverId.isEmpty ||
        session.token.isEmpty) {
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
      await _persistOffers();
      ref.invalidate(driverTripHistoryProvider);
    } catch (error) {
      state = AsyncData(state.value ?? const <DriverTrip>[]);
      throw Exception(_friendlyRejectError(error));
    }
  }

  void removeOfferLocally(String tripId) {
    final current = [...(state.value ?? const <DriverTrip>[])];
    current.removeWhere((trip) => trip.id == tripId);
    state = AsyncData(current);
    unawaited(_persistOffers());
  }

  Future<void> clearOffers() async {
    state = const AsyncData([]);
    await _persistOffers();
  }
}

String _friendlyAcceptError(Object error) {
  final raw = error.toString();
  final normalized = raw.toLowerCase();
  if (normalized.contains('no fue ofertado') ||
      normalized.contains('solicitud ya no esta disponible')) {
    return 'La oferta vencio y paso al siguiente conductor disponible.';
  }
  if (normalized.contains('conductor ya no esta libre')) {
    return 'Tu estado cambio a ocupado. Vuelve a ponerte disponible para recibir solicitudes.';
  }
  if (normalized.contains('being processed')) {
    return 'Estamos confirmando esta solicitud. Intenta otra vez en un momento.';
  }
  if (raw.contains('409')) {
    return 'Este viaje ya fue aceptado por otro conductor.';
  }
  if (raw.contains('403')) {
    return 'Esta solicitud ya no esta disponible para tu conductor.';
  }
  return 'No se pudo aceptar el viaje. Intenta con otra solicitud.';
}

String _friendlyTripStatusError(Object error) {
  final raw = error.toString();
  if (raw.contains('403')) {
    return 'No puedes actualizar este viaje con esta cuenta de conductor.';
  }
  if (raw.contains('409')) {
    return 'El estado del viaje cambio. Actualiza e intenta de nuevo.';
  }
  if (raw.contains('404')) {
    return 'Este viaje ya no esta disponible.';
  }
  return 'No se pudo actualizar el viaje. Revisa tu conexion e intenta de nuevo.';
}

String _friendlyRejectError(Object error) {
  final raw = error.toString();
  if (raw.contains('403')) {
    return 'No puedes rechazar esta solicitud con esta cuenta de conductor.';
  }
  if (raw.contains('404')) {
    return 'Esta solicitud ya no esta disponible.';
  }
  return 'No se pudo ignorar la solicitud. Revisa tu conexion e intenta de nuevo.';
}
