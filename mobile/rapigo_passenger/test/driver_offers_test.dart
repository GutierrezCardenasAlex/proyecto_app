import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_passenger/features/trip/data/trip_state_cache.dart';
import 'package:rapigo_passenger/features/trip/domain/driver_offer.dart';
import 'package:rapigo_passenger/features/trip/domain/trip_request.dart';
import 'package:rapigo_passenger/features/trip/presentation/widgets/passenger_driver_offers_dialog.dart';

const first = DriverOffer(
  id: 'one',
  driverId: 'driver-one',
  amount: 15,
  driverName: 'Ana',
  vehicle: 'Taxi Toyota',
  plate: '123 ABC',
  color: 'Blanco',
  rating: '4.9',
);
const second = DriverOffer(
  id: 'two',
  driverId: 'driver-two',
  amount: 12,
  driverName: 'Luis',
  vehicle: 'Moto',
  plate: '456 DEF',
  color: 'Azul',
  rating: '4.8',
);

void main() {
  test('all proposals survive restart without assigning a driver', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = PassengerTripStateCache();
    const request = TripRequest(
      pickupAddress: 'Origen',
      destinationAddress: 'Destino',
      status: 'searching',
      activeTripId: 'trip',
      fareAmount: 10,
      offers: [first, second],
    );
    await cache.writeRequest(request);
    final restored = (await cache.readRequest())!;
    expect(restored.hasDriverOffers, true);
    expect(restored.driverName, isNull);
    expect(restored.offers.map((o) => o.amount), [15, 12]);
    expect(restored.offers.last.plate, '456 DEF');
    expect(restored.copyWith(status: 'arriving').hasDriverOffers, false);
  });

  testWidgets('passenger compares drivers and chooses a specific offer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<void>();
    final decisions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassengerDriverOffersDialog(
            offers: const [first, second],
            onRespond: (offer, accept) {
              decisions.add('${offer.id}:$accept');
              return pending.future;
            },
          ),
        ),
      ),
    );
    expect(find.text('Bs 15.00'), findsOneWidget);
    expect(find.text('Bs 12.00'), findsOneWidget);
    final choose = find.widgetWithText(FilledButton, 'Elegir conductor').last;
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pump();
    await tester.tap(choose);
    expect(decisions, ['two:true']);
    pending.completeError(Exception('El conductor ya no está disponible'));
    await tester.pumpAndSettle();
    expect(find.text('El conductor ya no está disponible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ignoring removes just one proposal and allows another selection',
    (tester) async {
      var offers = <DriverOffer>[first, second];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PassengerDriverOffersDialog(
                offers: offers,
                onRespond: (offer, accept) async {
                  expect(accept, false);
                  setState(
                    () =>
                        offers = offers.where((o) => o.id != offer.id).toList(),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Ignorar').first);
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsNothing);
      expect(find.text('Luis'), findsOneWidget);
      expect(find.text('Elegir conductor'), findsOneWidget);
    },
  );
}
