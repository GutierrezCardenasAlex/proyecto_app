class TripRequest {
  const TripRequest({
    required this.pickupAddress,
    required this.destinationAddress,
    required this.status,
    required this.activeTripId,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.driverLat,
    this.driverLng,
    this.vehicleLabel,
    this.vehiclePlate,
    this.etaMinutes,
  });

  final String pickupAddress;
  final String destinationAddress;
  final String status;
  final String? activeTripId;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? driverLat;
  final double? driverLng;
  final String? vehicleLabel;
  final String? vehiclePlate;
  final int? etaMinutes;

  TripRequest copyWith({
    String? pickupAddress,
    String? destinationAddress,
    String? status,
    String? activeTripId,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    double? driverLat,
    double? driverLng,
    String? vehicleLabel,
    String? vehiclePlate,
    int? etaMinutes,
    bool clearTripId = false,
  }) {
    return TripRequest(
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      status: status ?? this.status,
      activeTripId: clearTripId ? null : activeTripId ?? this.activeTripId,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      etaMinutes: etaMinutes ?? this.etaMinutes,
    );
  }
}

class TripHistoryItem {
  const TripHistoryItem({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.requestedAt,
  });

  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final String requestedAt;
}

class NearbyDriver {
  const NearbyDriver({
    required this.driverId,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.rating,
    required this.etaMinutes,
    required this.vehicleLabel,
    required this.vehicleDetail,
    required this.priceLabel,
  });

  final String driverId;
  final double lat;
  final double lng;
  final double distanceMeters;
  final double rating;
  final int etaMinutes;
  final String vehicleLabel;
  final String vehicleDetail;
  final String priceLabel;
}

class TripState {
  const TripState({
    required this.request,
    required this.isLoading,
    required this.isRequestingTrip,
    required this.history,
    required this.nearbyDrivers,
    required this.errorMessage,
  });

  final TripRequest request;
  final bool isLoading;
  final bool isRequestingTrip;
  final List<TripHistoryItem> history;
  final List<NearbyDriver> nearbyDrivers;
  final String? errorMessage;

  TripState copyWith({
    TripRequest? request,
    bool? isLoading,
    bool? isRequestingTrip,
    List<TripHistoryItem>? history,
    List<NearbyDriver>? nearbyDrivers,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TripState(
      request: request ?? this.request,
      isLoading: isLoading ?? this.isLoading,
      isRequestingTrip: isRequestingTrip ?? this.isRequestingTrip,
      history: history ?? this.history,
      nearbyDrivers: nearbyDrivers ?? this.nearbyDrivers,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
