class DriverTrip {
  const DriverTrip({
    required this.id,
    required this.passengerPickup,
    required this.destination,
    required this.status,
  });

  final String id;
  final String passengerPickup;
  final String destination;
  final String status;

  DriverTrip copyWith({String? status}) {
    return DriverTrip(
      id: id,
      passengerPickup: passengerPickup,
      destination: destination,
      status: status ?? this.status,
    );
  }
}
