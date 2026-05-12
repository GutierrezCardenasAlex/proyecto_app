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
    this.requestedAt,
    this.vehicleType,
    this.vehicleLabel,
    this.vehiclePlate,
    this.vehicleColor,
    this.passengerName,
    this.passengerPhone,
    this.isPromotional = false,
  });

  final String id;
  final String passengerPickup;
  final String destination;
  final String status;
  final double pickupLat;
  final double pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final double fareAmount;
  final String? requestedAt;
  final String? vehicleType;
  final String? vehicleLabel;
  final String? vehiclePlate;
  final String? vehicleColor;
  final String? passengerName;
  final String? passengerPhone;
  final bool isPromotional;

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
    String? requestedAt,
    String? vehicleType,
    String? vehicleLabel,
    String? vehiclePlate,
    String? vehicleColor,
    String? passengerName,
    String? passengerPhone,
    bool? isPromotional,
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
      requestedAt: requestedAt ?? this.requestedAt,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      isPromotional: isPromotional ?? this.isPromotional,
    );
  }
}
