import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/trip_request.dart';

class PassengerTripStateCache {
  static const _requestKey = 'rapigo_passenger_trip_request_v1';

  Future<TripRequest?> readRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_requestKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final payload = jsonDecode(raw);
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    return TripRequest(
      pickupAddress: payload['pickupAddress']?.toString() ?? 'Mi ubicacion actual',
      destinationAddress:
          payload['destinationAddress']?.toString() ?? 'Destino no esta marcado',
      status: payload['status']?.toString() ?? 'idle',
      activeTripId: payload['activeTripId']?.toString(),
      pickupLat: _toNullableDouble(payload['pickupLat']),
      pickupLng: _toNullableDouble(payload['pickupLng']),
      destinationLat: _toNullableDouble(payload['destinationLat']),
      destinationLng: _toNullableDouble(payload['destinationLng']),
      driverLat: _toNullableDouble(payload['driverLat']),
      driverLng: _toNullableDouble(payload['driverLng']),
      vehicleType: payload['vehicleType']?.toString(),
      vehicleLabel: payload['vehicleLabel']?.toString(),
      vehiclePlate: payload['vehiclePlate']?.toString(),
      vehicleColor: payload['vehicleColor']?.toString(),
      driverName: payload['driverName']?.toString(),
      driverPhone: payload['driverPhone']?.toString(),
      etaMinutes: _toNullableInt(payload['etaMinutes']),
      isPromotional: payload['isPromotional'] == true,
    );
  }

  Future<void> writeRequest(TripRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _requestKey,
      jsonEncode(<String, dynamic>{
        'pickupAddress': request.pickupAddress,
        'destinationAddress': request.destinationAddress,
        'status': request.status,
        'activeTripId': request.activeTripId,
        'pickupLat': request.pickupLat,
        'pickupLng': request.pickupLng,
        'destinationLat': request.destinationLat,
        'destinationLng': request.destinationLng,
        'driverLat': request.driverLat,
        'driverLng': request.driverLng,
        'vehicleType': request.vehicleType,
        'vehicleLabel': request.vehicleLabel,
        'vehiclePlate': request.vehiclePlate,
        'vehicleColor': request.vehicleColor,
        'driverName': request.driverName,
        'driverPhone': request.driverPhone,
        'etaMinutes': request.etaMinutes,
        'isPromotional': request.isPromotional,
      }),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestKey);
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

  static int? _toNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }
}
