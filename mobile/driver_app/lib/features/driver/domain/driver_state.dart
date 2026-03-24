class DriverState {
  const DriverState({
    required this.available,
    required this.lastLocationPing,
    required this.lat,
    required this.lng,
    required this.isUpdatingAvailability,
    required this.errorMessage,
  });

  final bool available;
  final DateTime? lastLocationPing;
  final double lat;
  final double lng;
  final bool isUpdatingAvailability;
  final String? errorMessage;

  DriverState copyWith({
    bool? available,
    DateTime? lastLocationPing,
    double? lat,
    double? lng,
    bool? isUpdatingAvailability,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriverState(
      available: available ?? this.available,
      lastLocationPing: lastLocationPing ?? this.lastLocationPing,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isUpdatingAvailability: isUpdatingAvailability ?? this.isUpdatingAvailability,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
