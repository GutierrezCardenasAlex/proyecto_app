class DriverTrip {
  const DriverTrip({
    required this.id,
    required this.passengerPickup,
    required this.destination,
    required this.status,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.fareAmount,
  });

  final String id;
  final String passengerPickup;
  final String destination;
  final String status;
  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;
  final double fareAmount;

  DriverTrip copyWith({
    String? id,
    String? passengerPickup,
    String? destination,
    String? status,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    double? fareAmount,
  }) {
    return DriverTrip(
      id: id ?? this.id,
      passengerPickup: passengerPickup ?? this.passengerPickup,
      destination: destination ?? this.destination,
      status: status ?? this.status,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      fareAmount: fareAmount ?? this.fareAmount,
    );
  }
}
