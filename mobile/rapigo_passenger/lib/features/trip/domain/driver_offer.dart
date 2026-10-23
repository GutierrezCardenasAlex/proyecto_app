class DriverOffer {
  const DriverOffer({
    required this.id,
    required this.driverId,
    required this.amount,
    required this.driverName,
    required this.vehicle,
    required this.plate,
    required this.color,
    required this.rating,
  });
  final String id;
  final String driverId;
  final double amount;
  final String driverName;
  final String vehicle;
  final String plate;
  final String color;
  final String rating;

  factory DriverOffer.fromJson(Map<String, dynamic> json) => DriverOffer(
    id: json['id'].toString(),
    driverId: json['driver_id'].toString(),
    amount: double.tryParse(json['amount'].toString()) ?? 0,
    driverName: json['driver_name']?.toString() ?? 'Conductor',
    vehicle: [
      json['vehicle_type'],
      json['brand'],
      json['model'],
    ].where((v) => v != null && v.toString().trim().isNotEmpty).join(' · '),
    plate: json['plate']?.toString() ?? '',
    color: json['color']?.toString() ?? '',
    rating: json['rating']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'driver_id': driverId,
    'amount': amount,
    'driver_name': driverName,
    'vehicle_type': vehicle,
    'plate': plate,
    'color': color,
    'rating': rating,
  };
}
