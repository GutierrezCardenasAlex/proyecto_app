import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_driver_pro/driver/features/driver/presentation/widgets/driver_journey_design.dart';
import 'package:rapigo_driver_pro/driver/features/driver/presentation/widgets/driver_counter_offer_dialog.dart';
import 'package:rapigo_driver_pro/driver/features/trip/domain/driver_trip.dart';
import 'package:rapigo_driver_pro/driver/features/trip/data/trip_state_cache.dart';

const trip = DriverTrip(
  id: 'accepted-trip',
  status: 'arriving',
  passengerName: 'María Fernanda Rodríguez',
  passengerPhone: '70000000',
  passengerPickup: 'Avenida Universitaria, entrada principal',
  destination: 'Plaza 10 de Noviembre',
  pickupLat: -19.5,
  pickupLng: -65.7,
  destinationLat: -19.6,
  destinationLng: -65.8,
  fareAmount: 15,
  paymentMethod: 'qr',
);

void main() {
  test(
    'original fare is preserved across restart and distinguished from a counteroffer',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cache = DriverTripStateCache();
      await cache.rememberRequestedFare('trip-a', 10);
      await cache.rememberRequestedFare('trip-b', 20);
      expect(
        await DriverTripStateCache().acceptedOriginalFare('trip-a', 10),
        true,
      );
      expect(await cache.acceptedOriginalFare('trip-a', 15), false);
      expect(await cache.acceptedOriginalFare('trip-b', 20), true);
      expect(await cache.acceptedOriginalFare('unknown', 10), false);
    },
  );

  testWidgets('direct acceptance shows its own confirmation and agreed fare', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DriverAcceptedView(
          trip: trip.copyWith(fareAmount: 10),
          acceptedOriginalFare: true,
          onContinue: () {},
        ),
      ),
    );
    expect(find.text('¡Aceptaste el viaje!'), findsOneWidget);
    expect(find.text('Bs 10.00'), findsOneWidget);
    expect(find.text(trip.passengerPickup), findsOneWidget);
    expect(find.text(trip.destination), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 700), const Size(700, 320)]) {
    testWidgets(
      'journey canvas fills $size with a compact header and anchored bottom panel',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var mapTaps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DriverJourneyCanvas(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      key: const Key('map'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => mapTaps++,
                      child: const ColoredBox(color: Colors.blueGrey),
                    ),
                  ),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('Recorrido')],
                  ),
                  const Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: SizedBox(
                      key: Key('panel'),
                      height: 100,
                      child: ColoredBox(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byKey(const Key('map'))), size);
        expect(
          tester.getBottomLeft(find.byKey(const Key('panel'))).dy,
          size.height - 16,
        );
        await tester.tapAt(Offset(size.width / 2, size.height / 2));
        expect(mapTaps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'acceptance acknowledgement survives restart and is specific to the trip',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await DriverTripStateCache().hasAcknowledgedAcceptance(trip.id),
        false,
      );
      await DriverTripStateCache().acknowledgeAcceptance(trip.id);
      expect(
        await DriverTripStateCache().hasAcknowledgedAcceptance(trip.id),
        true,
      );
      expect(
        await DriverTripStateCache().hasAcknowledgedAcceptance('next-trip'),
        false,
      );
    },
  );

  testWidgets(
    'acceptance shows agreed fare and full details before continuing',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var continued = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DriverAcceptedView(trip: trip, onContinue: () => continued++),
        ),
      );
      expect(find.text('¡Tu viaje fue aceptado!'), findsOneWidget);
      expect(find.text('Bs 15.00'), findsOneWidget);
      expect(find.text(trip.passengerPickup), findsOneWidget);
      expect(find.text(trip.destination), findsOneWidget);
      expect(find.text(trip.passengerPhone!), findsOneWidget);
      expect(continued, 0);
      await tester.ensureVisible(find.text('Continuar al recojo'));
      await tester.tap(find.text('Continuar al recojo'));
      expect(continued, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['accepted', 'arriving', 'at_pickup', 'in_progress']) {
    testWidgets(
      '$status has the correct action, contacts and route on narrow screens',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var primary = 0, calls = 0, messages = 0;
        final current = trip.copyWith(status: status);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DriverJourneyHeader(
                        trip: current,
                        title: trip.passengerPickup,
                        subtitle: '',
                        distanceLabel: '1 km',
                        pickupStage: status != 'in_progress',
                      ),
                      DriverJourneyPanel(
                        trip: current,
                        etaLabel: '5 min',
                        distanceLabel: '1 km',
                        detailsExpanded: false,
                        onNavigate: () {},
                        onExpand: () {},
                        onPrimary: () => primary++,
                        onCall: () => calls++,
                        onChat: () => messages++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.text(journeyAction(status)));
        await tester.tap(find.text(journeyAction(status)));
        await tester.tap(find.byTooltip('Llamar al pasajero'));
        await tester.tap(find.byTooltip('Mensaje al pasajero'));
        expect([primary, calls, messages], [1, 1, 1]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an acceptance arriving during submission does not get popped by the offer dialog',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final sent = Completer<void>();
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Inicio')),
        ),
      );
      final dialog = showDialog<bool>(
        context: navigator.currentContext!,
        builder: (_) => DriverCounterOfferDialog(
          originalFare: 10,
          onSubmit: (_) => sent.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '15');
      await tester.tap(find.text('Enviar oferta'));
      await tester.pump();
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Text('Confirmación del viaje')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      sent.complete();
      await tester.pumpAndSettle();
      result = await dialog;
      expect(result, true);
      expect(find.text('Confirmación del viaje'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
