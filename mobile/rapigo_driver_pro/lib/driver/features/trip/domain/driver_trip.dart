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
    this.dispatchMode,
    this.preferredDriverId,
    this.offerExpiresAt,
    this.paymentMethod = 'cash',
    this.isPromotional = false,
    this.counterOfferAmount,
    this.counterOfferStatus,
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
  final String? dispatchMode;
  final String? preferredDriverId;
  final String? offerExpiresAt;
  final String paymentMethod;
  final bool isPromotional;
  final double? counterOfferAmount;
  final String? counterOfferStatus;

  bool get hasPendingCounterOffer =>
      status == 'accepted' && counterOfferStatus == 'pending';

  String get paymentMethodLabel => paymentMethod == 'qr' ? 'QR' : 'Efectivo';

  bool get isDirectedRequest {
    final mode = dispatchMode?.trim().toLowerCase();
    final preferred = preferredDriverId?.trim() ?? '';
    return preferred.isNotEmpty || mode == 'nearby';
  }

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
    String? dispatchMode,
    String? preferredDriverId,
    String? offerExpiresAt,
    String? paymentMethod,
    bool? isPromotional,
    double? counterOfferAmount,
    String? counterOfferStatus,
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
      dispatchMode: dispatchMode ?? this.dispatchMode,
      preferredDriverId: preferredDriverId ?? this.preferredDriverId,
      offerExpiresAt: offerExpiresAt ?? this.offerExpiresAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPromotional: isPromotional ?? this.isPromotional,
      counterOfferAmount: counterOfferAmount ?? this.counterOfferAmount,
      counterOfferStatus: counterOfferStatus ?? this.counterOfferStatus,
    );
  }
}
