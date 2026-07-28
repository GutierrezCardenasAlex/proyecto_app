import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/driver_trip.dart';

class DriverTripFlowMetadata {
  const DriverTripFlowMetadata({
    required this.tripId,
    required this.status,
    required this.stage,
    required this.routeStage,
    required this.restoreProgressPage,
    required this.savedAtIso,
  });

  final String tripId;
  final String status;
  final String stage;
  final String routeStage;
  final bool restoreProgressPage;
  final String savedAtIso;
}

class DriverTripStateCache {
  static const _activeTripKey = 'rapigo_driver_active_trip_v1';
  static const _offersKey = 'rapigo_driver_offers_v1';
  static const _previewTripIdKey = 'rapigo_driver_preview_trip_id_v1';
  static const _flowMetadataKey = 'rapigo_driver_trip_flow_metadata_v1';

  Future<DriverTrip?> readActiveTrip() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeTripKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final payload = jsonDecode(raw);
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    return _tripFromMap(payload);
  }

  Future<void> writeActiveTrip(DriverTrip? trip) async {
    final prefs = await SharedPreferences.getInstance();
    if (trip == null) {
      await prefs.remove(_activeTripKey);
      return;
    }
    await prefs.setString(_activeTripKey, jsonEncode(_tripToMap(trip)));
  }

  Future<List<DriverTrip>> readOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_offersKey);
    if (raw == null || raw.isEmpty) {
      return const <DriverTrip>[];
    }
    final payload = jsonDecode(raw);
    if (payload is! List) {
      return const <DriverTrip>[];
    }
    return payload
        .whereType<Map<String, dynamic>>()
        .map(_tripFromMap)
        .toList(growable: false);
  }

  Future<void> writeOffers(List<DriverTrip> offers) async {
    final prefs = await SharedPreferences.getInstance();
    if (offers.isEmpty) {
      await prefs.remove(_offersKey);
      return;
    }
    await prefs.setString(
      _offersKey,
      jsonEncode(offers.map(_tripToMap).toList(growable: false)),
    );
  }

  Future<String?> readPreviewTripId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_previewTripIdKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw;
  }

  Future<void> writePreviewTripId(String? tripId) async {
    final prefs = await SharedPreferences.getInstance();
    if (tripId == null || tripId.trim().isEmpty) {
      await prefs.remove(_previewTripIdKey);
      return;
    }
    await prefs.setString(_previewTripIdKey, tripId);
  }

  Future<DriverTripFlowMetadata?> readFlowMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_flowMetadataKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final payload = jsonDecode(raw);
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      final tripId = payload['tripId']?.toString() ?? '';
      if (tripId.isEmpty) {
        return null;
      }
      return DriverTripFlowMetadata(
        tripId: tripId,
        status: payload['status']?.toString() ?? 'requested',
        stage: payload['stage']?.toString() ?? 'offer',
        routeStage: payload['routeStage']?.toString() ?? 'pickup',
        restoreProgressPage: payload['restoreProgressPage'] == true,
        savedAtIso: payload['savedAtIso']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeFlowMetadata(DriverTripFlowMetadata? metadata) async {
    final prefs = await SharedPreferences.getInstance();
    if (metadata == null) {
      await prefs.remove(_flowMetadataKey);
      return;
    }
    await prefs.setString(
      _flowMetadataKey,
      jsonEncode(<String, dynamic>{
        'tripId': metadata.tripId,
        'status': metadata.status,
        'stage': metadata.stage,
        'routeStage': metadata.routeStage,
        'restoreProgressPage': metadata.restoreProgressPage,
        'savedAtIso': metadata.savedAtIso,
      }),
    );
  }

  Map<String, dynamic> _tripToMap(DriverTrip trip) {
    return <String, dynamic>{
      'id': trip.id,
      'passengerPickup': trip.passengerPickup,
      'destination': trip.destination,
      'status': trip.status,
      'pickupLat': trip.pickupLat,
      'pickupLng': trip.pickupLng,
      'destinationLat': trip.destinationLat,
      'destinationLng': trip.destinationLng,
      'fareAmount': trip.fareAmount,
      'requestedAt': trip.requestedAt,
      'vehicleType': trip.vehicleType,
      'vehicleLabel': trip.vehicleLabel,
      'vehiclePlate': trip.vehiclePlate,
      'vehicleColor': trip.vehicleColor,
      'passengerName': trip.passengerName,
      'passengerPhone': trip.passengerPhone,
      'dispatchMode': trip.dispatchMode,
      'preferredDriverId': trip.preferredDriverId,
      'offerExpiresAt': trip.offerExpiresAt,
      'isPromotional': trip.isPromotional,
    };
  }

  DriverTrip _tripFromMap(Map<String, dynamic> payload) {
    return DriverTrip(
      id: payload['id']?.toString() ?? '',
      passengerPickup: payload['passengerPickup']?.toString() ?? 'Recojo',
      destination:
          payload['destination']?.toString() ?? 'Destino no esta marcado',
      status: payload['status']?.toString() ?? 'requested',
      pickupLat: _toDouble(payload['pickupLat']),
      pickupLng: _toDouble(payload['pickupLng']),
      destinationLat: _toNullableDouble(payload['destinationLat']),
      destinationLng: _toNullableDouble(payload['destinationLng']),
      fareAmount: _toDouble(payload['fareAmount']),
      requestedAt: payload['requestedAt']?.toString(),
      vehicleType: payload['vehicleType']?.toString(),
      vehicleLabel: payload['vehicleLabel']?.toString(),
      vehiclePlate: payload['vehiclePlate']?.toString(),
      vehicleColor: payload['vehicleColor']?.toString(),
      passengerName: payload['passengerName']?.toString(),
      passengerPhone: payload['passengerPhone']?.toString(),
      dispatchMode: payload['dispatchMode']?.toString(),
      preferredDriverId: payload['preferredDriverId']?.toString(),
      offerExpiresAt: payload['offerExpiresAt']?.toString(),
      isPromotional: payload['isPromotional'] == true,
    );
  }

  double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _toNullableDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static DriverTripFlowMetadata metadataFromTrip(DriverTrip trip) {
    final status = trip.status.trim().toLowerCase();
    final routeStage = status == 'in_progress' || status == 'completed'
        ? 'destination'
        : 'pickup';
    final stage = switch (status) {
      'accepted' => 'accepted',
      'arriving' => 'pickup_navigation',
      'at_pickup' => 'pickup_arrived',
      'in_progress' => 'destination_navigation',
      'completed' => 'summary',
      _ => 'offer',
    };
    final restoreProgressPage = const {
      'accepted',
      'arriving',
      'at_pickup',
      'in_progress',
    }.contains(status);
    return DriverTripFlowMetadata(
      tripId: trip.id,
      status: trip.status,
      stage: stage,
      routeStage: routeStage,
      restoreProgressPage: restoreProgressPage,
      savedAtIso: DateTime.now().toIso8601String(),
    );
  }
}
