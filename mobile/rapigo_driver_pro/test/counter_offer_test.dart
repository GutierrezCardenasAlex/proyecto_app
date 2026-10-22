import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_driver_pro/driver/features/driver/presentation/widgets/driver_counter_offer_dialog.dart';
import 'package:rapigo_driver_pro/driver/features/driver/presentation/widgets/driver_home_fab.dart';
import 'package:rapigo_driver_pro/driver/features/trip/domain/driver_trip.dart';
import 'package:rapigo_driver_pro/driver/features/trip/data/trip_state_cache.dart';

void main() {
  test(
    'pending counteroffer survives restart without changing original fare',
    () async {
      SharedPreferences.setMockInitialValues({});
      const trip = DriverTrip(
        id: 'trip',
        passengerPickup: 'Origen',
        destination: 'Destino',
        status: 'accepted',
        pickupLat: -19.5,
        pickupLng: -65.7,
        destinationLat: null,
        destinationLng: null,
        fareAmount: 10,
        counterOfferAmount: 15,
        counterOfferStatus: 'pending',
      );
      final cache = DriverTripStateCache();
      await cache.writeActiveTrip(trip);
      final restored = (await cache.readActiveTrip())!;
      expect(restored.hasPendingCounterOffer, true);
      expect(restored.fareAmount, 10);
      expect(restored.counterOfferAmount, 15);
      expect(
        DriverTripStateCache.metadataFromTrip(restored).restoreProgressPage,
        false,
      );
      expect(
        restored.copyWith(status: 'cancelled').hasPendingCounterOffer,
        false,
      );
    },
  );

  testWidgets(
    'invalid price is blocked and an in-flight counteroffer cannot be sent twice',
    (tester) async {
      final completer = Completer<void>();
      final sent = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverCounterOfferDialog(
              originalFare: 10,
              onSubmit: (amount) {
                sent.add(amount);
                return completer.future;
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '9');
      await tester.tap(find.text('Enviar contraoferta'));
      await tester.pump();
      expect(sent, isEmpty);
      await tester.enterText(find.byType(TextField), '15,50');
      await tester.tap(find.text('Enviar contraoferta'));
      await tester.pump();
      await tester.tap(find.text('Enviando…'));
      expect(sent, [15.5]);
      completer.completeError(Exception('Sin conexión'));
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Enviar contraoferta'), findsOneWidget);
    },
  );

  testWidgets('FAB opens all actions and closes after selecting one', (
    tester,
  ) async {
    var center = 0;
    var map = 0;
    var offers = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: DriverHomeFab(
              vehicleLabel: 'Moto',
              onCenter: () => center++,
              onMapMode: () => map++,
              onOffers: () => offers++,
            ),
          ),
        ),
      ),
    );
    for (final label in [
      'Centro del conductor',
      'Moto · Vista del mapa',
      'Solicitudes',
    ]) {
      await tester.tap(find.byTooltip('Abrir accesos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsNothing);
    }
    expect([center, map, offers], [1, 1, 1]);
    expect(tester.takeException(), isNull);
  });
}
