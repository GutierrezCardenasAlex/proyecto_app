import '../../trip/domain/driver_trip.dart';

class DriverEarnings {
  static List<DriverTrip> inRange(
    Iterable<DriverTrip> trips,
    DateTime now,
    String range,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final start = range == 'Semana'
        ? today.subtract(const Duration(days: 6))
        : range == 'Mes'
        ? DateTime(now.year, now.month)
        : today;
    return trips.where((trip) {
      final date = DateTime.tryParse(
        trip.completedAt ?? trip.requestedAt ?? '',
      )?.toLocal();
      return date != null && !date.isBefore(start) && !date.isAfter(now);
    }).toList();
  }

  static double total(Iterable<DriverTrip> trips) => trips
      .where(
        (trip) =>
            trip.status == 'completed' &&
            trip.fareAmount.isFinite &&
            trip.fareAmount >= 0,
      )
      .fold(0.0, (sum, trip) => sum + trip.fareAmount);
}
