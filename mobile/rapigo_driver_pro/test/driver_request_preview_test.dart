import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapigo_driver_pro/driver/features/driver/presentation/widgets/driver_request_preview.dart';
import 'package:rapigo_driver_pro/driver/features/trip/domain/driver_trip.dart';

const trip = DriverTrip(
  id: 'trip',
  passengerName: 'María Fernanda Rodríguez',
  passengerPickup: 'Avenida Universitaria, entrada principal de la universidad',
  destination: 'Plaza 10 de Noviembre, esquina de la catedral',
  passengerPhone: '70000000',
  status: 'searching',
  pickupLat: -19.5,
  pickupLng: -65.7,
  destinationLat: -19.6,
  destinationLng: -65.8,
  fareAmount: 10,
);

void main() {
  testWidgets(
    'accept shows progress, blocks duplicates and displays server errors',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverRequestPreviewPanel(
              trip: trip,
              onReject: () {},
              onPropose: () {},
              onAccept: () {
                calls++;
                return pending.future;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aceptar'));
      await tester.pump();
      expect(find.text('Aceptando…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Aceptando…'));
      expect(calls, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Proponer'),
            )
            .onPressed,
        isNull,
      );
      pending.completeError(
        Exception('El servidor aún usa la aprobación del pasajero'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('El servidor aún usa la aprobación del pasajero'),
        findsOneWidget,
      );
      expect(find.text('Aceptar'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'route panel leaves map space and reveals additional data on demand',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var ignored = 0, proposed = 0, accepted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DriverRequestPreviewPanel(
                  trip: trip,
                  onReject: () => ignored++,
                  onPropose: () => proposed++,
                  onAccept: () => accepted++,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(DriverRequestPreviewPanel)).height,
        lessThan(210),
      );
      expect(find.text(trip.passengerPhone!), findsNothing);
      for (final label in ['Ignorar', 'Proponer', 'Aceptar']) {
        await tester.tap(find.text(label));
      }
      expect([ignored, proposed, accepted], [1, 1, 1]);
      await tester.tap(find.byTooltip('Mostrar datos del viaje'));
      await tester.pumpAndSettle();
      expect(find.text(trip.passengerPhone!), findsOneWidget);
      expect(find.text(trip.passengerPickup), findsOneWidget);
      expect(find.text(trip.destination), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Cerrar datos'));
      await tester.pumpAndSettle();
      expect(find.text(trip.passengerPhone!), findsNothing);
    },
  );

  testWidgets(
    'request cards have only route and ignore; large text remains usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var routes = 0, ignored = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    DriverRequestPreviewHeader(trip: trip, onBack: () {}),
                    DriverRequestListCard(
                      trip: trip,
                      onRoute: () => routes++,
                      onReject: () => ignored++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Ver detalle'), findsNothing);
      await tester.tap(find.text('Ver ruta'));
      await tester.tap(find.text('Ignorar'));
      expect([routes, ignored], [1, 1]);
      expect(tester.takeException(), isNull);
    },
  );
}
