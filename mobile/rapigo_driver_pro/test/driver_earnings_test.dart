import 'package:flutter_test/flutter_test.dart';
import 'package:rapigo_driver_pro/driver/features/driver/domain/driver_earnings.dart';
import 'package:rapigo_driver_pro/driver/features/trip/domain/driver_trip.dart';

DriverTrip trip(
  String id,
  double amount,
  String status,
  DateTime requested, {
  DateTime? completed,
}) => DriverTrip(
  id: id,
  passengerPickup: 'Origen',
  destination: 'Destino',
  status: status,
  pickupLat: 0,
  pickupLng: 0,
  destinationLat: 0,
  destinationLng: 0,
  fareAmount: amount,
  requestedAt: requested.toIso8601String(),
  completedAt: completed?.toIso8601String(),
);

void main() {
  test('earnings include only finite non-negative completed fares', () {
    final now = DateTime(2026, 11, 23, 12);
    expect(
      DriverEarnings.total([
        trip('1', 15, 'completed', now),
        trip('2', 40, 'cancelled', now),
        trip('3', 25, 'in_progress', now),
        trip('4', double.nan, 'completed', now),
        trip('5', -10, 'completed', now),
        trip('6', 0, 'completed', now),
      ]),
      15,
    );
  });
  test('today uses completion date and excludes future entries', () {
    final now = DateTime(2026, 11, 23, 12);
    final entries = [
      trip(
        'overnight',
        15,
        'completed',
        DateTime(2026, 11, 22, 23),
        completed: DateTime(2026, 11, 23, 1),
      ),
      trip('old', 10, 'completed', DateTime(2026, 11, 22, 18)),
      trip('future', 20, 'completed', DateTime(2026, 11, 24)),
    ];
    expect(DriverEarnings.inRange(entries, now, 'Dia').map((t) => t.id), [
      'overnight',
    ]);
  });
  test('week includes seven calendar dates, month excludes previous month', () {
    final now = DateTime(2026, 11, 3, 12);
    final entries = [
      trip('included', 15, 'completed', DateTime(2026, 10, 28)),
      trip('excluded', 15, 'completed', DateTime(2026, 10, 27, 23)),
    ];
    expect(DriverEarnings.inRange(entries, now, 'Semana').length, 1);
    expect(DriverEarnings.inRange(entries, now, 'Mes'), isEmpty);
  });
}
