class TripRequest {
  const TripRequest({
    required this.pickupAddress,
    required this.destinationAddress,
    required this.status,
  });

  final String pickupAddress;
  final String destinationAddress;
  final String status;

  TripRequest copyWith({String? status}) {
    return TripRequest(
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      status: status ?? this.status,
    );
  }
}
