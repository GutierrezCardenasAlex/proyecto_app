import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_passenger/features/trip/domain/trip_request.dart';
import 'package:rapigo_passenger/features/trip/data/trip_state_cache.dart';
import 'package:rapigo_passenger/features/trip/data/trip_repository.dart';
import 'package:rapigo_passenger/features/trip/presentation/widgets/passenger_counter_offer_dialog.dart';

class _ActiveTripRepository extends TripRepository {
  TripRequest? next;

  @override
  Future<TripRequest?> fetchActiveTrip({
    required String token,
    required String passengerId,
  }) async => next;
}

void main() {
  test(
    'server recovery updates consent without requiring GPS and clears a cancelled reservation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = _ActiveTripRepository();
      final container = ProviderContainer(
        overrides: [tripRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(tripProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      const pending = TripRequest(
        pickupAddress: 'Origen',
        destinationAddress: 'Destino',
        status: 'accepted',
        activeTripId: 'trip',
        fareAmount: 10,
        counterOfferAmount: 15,
        counterOfferStatus: 'pending',
      );
      repository.next = pending;
      await controller.refreshCounterOffer(
        token: 'token',
        passengerId: 'passenger',
      );
      expect(container.read(tripProvider).request.hasPendingCounterOffer, true);
      repository.next = pending.copyWith(
        status: 'arriving',
        fareAmount: 15,
        counterOfferStatus: 'accepted',
      );
      await controller.refreshCounterOffer(
        token: 'token',
        passengerId: 'passenger',
      );
      expect(container.read(tripProvider).request.fareAmount, 15);
      expect(
        container.read(tripProvider).request.hasPendingCounterOffer,
        false,
      );
      repository.next = pending;
      await controller.refreshCounterOffer(
        token: 'token',
        passengerId: 'passenger',
      );
      repository.next = null;
      await controller.refreshCounterOffer(
        token: 'token',
        passengerId: 'passenger',
      );
      expect(container.read(tripProvider).request.status, 'cancelled');
      expect(
        container.read(tripProvider).request.hasPendingCounterOffer,
        false,
      );
    },
  );
  test('counteroffer consent stays pending after restoring the app', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = PassengerTripStateCache();
    const request = TripRequest(
      pickupAddress: 'Origen',
      destinationAddress: 'Destino',
      status: 'accepted',
      activeTripId: 'trip',
      fareAmount: 10,
      counterOfferAmount: 15,
      counterOfferStatus: 'pending',
    );
    await cache.writeRequest(request);
    final restored = (await cache.readRequest())!;
    expect(restored.hasPendingCounterOffer, true);
    expect(restored.fareAmount, 10);
    expect(restored.counterOfferAmount, 15);
    expect(
      restored
          .copyWith(
            status: 'arriving',
            counterOfferStatus: 'accepted',
            fareAmount: 15,
          )
          .hasPendingCounterOffer,
      false,
    );
  });

  for (final accept in [true, false]) {
    testWidgets(
      'passenger can ${accept ? 'accept' : 'reject'} with duplicate taps blocked',
      (tester) async {
        final pending = Completer<void>();
        final responses = <bool>[];
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PassengerCounterOfferDialog(
                originalFare: 10,
                counterFare: 15,
                driverName: 'Conductor',
                onRespond: (value) {
                  responses.add(value);
                  return pending.future;
                },
              ),
            ),
          ),
        );
        expect(find.text('Tu oferta: Bs 10.00'), findsOneWidget);
        await tester.tap(
          find.text(accept ? 'Aceptar Bs 15.00' : 'Rechazar y cancelar'),
        );
        await tester.pump();
        await tester.tap(find.text('Rechazar y cancelar'));
        expect(responses, [accept]);
        pending.completeError(Exception('Sin conexión'));
        await tester.pumpAndSettle();
        expect(find.text('Sin conexión'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
