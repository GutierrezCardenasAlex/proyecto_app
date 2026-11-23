import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapigo_driver_pro/driver/features/driver/presentation/widgets/driver_trip_details.dart';
import 'package:rapigo_driver_pro/driver/features/trip/domain/driver_trip.dart';

const trip = DriverTrip(
  id: 'viaje-123',
  status: 'completed',
  passengerName: 'María Rodríguez',
  passengerPhone: '70000000',
  passengerPickup: 'Avenida Universitaria',
  destination: 'Plaza 10 de Noviembre',
  pickupLat: -19.5,
  pickupLng: -65.7,
  destinationLat: -19.6,
  destinationLng: -65.8,
  fareAmount: 15,
  paymentMethod: 'qr',
  requestedAt: '2026-10-23T10:30:00',
  vehicleLabel: 'Toyota Corolla',
  vehiclePlate: '1234 ABC',
  vehicleColor: 'Blanco',
);

void main() {
  for (final completed in [false, true]) {
    testWidgets(
      'details completed=$completed show real data without journey actions',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var closes = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: DriverTripDetailsView(
                trip: trip,
                vehicleType: 'taxi',
                completed: completed,
                onClose: () => closes++,
              ),
            ),
          ),
        );
        expect(find.text('Bs 15.00'), findsOneWidget);
        expect(find.text('Pago: QR'), findsOneWidget);
        expect(find.text(trip.passengerPickup), findsOneWidget);
        expect(find.text(trip.destination), findsOneWidget);
        expect(find.text('Taxi'), findsOneWidget);
        expect(find.text('Toyota Corolla'), findsOneWidget);
        expect(find.text('1234 ABC'), findsOneWidget);
        expect(find.text('23/10/2026 · 10:30'), findsOneWidget);
        expect(find.text('Llamar'), findsNothing);
        expect(find.text('Cancelar'), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        if (completed) {
          expect(find.byIcon(Icons.check_rounded), findsOneWidget);
          expect(find.text('¡Viaje finalizado!'), findsOneWidget);
          expect(find.byType(FilledButton), findsOneWidget);
          await tester.ensureVisible(find.text('Volver al inicio'));
          await tester.tap(find.text('Volver al inicio'));
        } else {
          expect(find.byType(FilledButton), findsNothing);
          await tester.tap(find.byType(BackButton));
        }
        expect(closes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
