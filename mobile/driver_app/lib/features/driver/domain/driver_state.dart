class DriverState {
  const DriverState({
    required this.available,
    required this.lastLocationPing,
  });

  final bool available;
  final DateTime? lastLocationPing;

  DriverState copyWith({
    bool? available,
    DateTime? lastLocationPing,
  }) {
    return DriverState(
      available: available ?? this.available,
      lastLocationPing: lastLocationPing ?? this.lastLocationPing,
    );
  }
}
