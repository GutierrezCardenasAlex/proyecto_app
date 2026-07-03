class DriverState {
  const DriverState({
    required this.available,
    required this.backendStatus,
    required this.lastLocationPing,
    required this.lat,
    required this.lng,
    required this.headingDegrees,
    required this.speedKph,
    required this.isUpdatingAvailability,
    required this.errorMessage,
  });

  final bool available;
  final String backendStatus;
  final DateTime? lastLocationPing;
  final double lat;
  final double lng;
  final double? headingDegrees;
  final double? speedKph;
  final bool isUpdatingAvailability;
  final String? errorMessage;

  DriverState copyWith({
    bool? available,
    String? backendStatus,
    DateTime? lastLocationPing,
    double? lat,
    double? lng,
    double? headingDegrees,
    double? speedKph,
    bool? isUpdatingAvailability,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriverState(
      available: available ?? this.available,
      backendStatus: backendStatus ?? this.backendStatus,
      lastLocationPing: lastLocationPing ?? this.lastLocationPing,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      speedKph: speedKph ?? this.speedKph,
      isUpdatingAvailability: isUpdatingAvailability ?? this.isUpdatingAvailability,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
