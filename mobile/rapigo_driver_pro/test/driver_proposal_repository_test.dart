import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rapigo_driver_pro/driver/features/trip/data/trip_repository.dart';
import 'package:rapigo_driver_pro/driver/features/trip/domain/driver_trip.dart';

void main() {
  const trip = DriverTrip(
    id: 'trip',
    passengerPickup: 'Origen',
    destination: 'Destino',
    status: 'searching',
    pickupLat: -19.5,
    pickupLng: -65.7,
    destinationLat: null,
    destinationLng: null,
    fareAmount: 10,
  );

  for (final price in <double?>[null, 10, 15]) {
    test(
      'original price confirms immediately; a different price stays pending: $price',
      () async {
        final direct = price == null || price == 10;
        final requests = <http.Request>[];
        final repository = DriverTripRepository(
          client: MockClient((request) async {
            requests.add(request);
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body.containsKey('counterFare'), price != null);
            expect(body['counterFare'], price);
            expect(body['expectedFare'], 10);
            return http.Response(
              jsonEncode({
                'accepted': direct,
                if (direct)
                  'trip': {
                    'id': 'trip',
                    'driver_id': 'driver',
                    'status': 'arriving',
                    'fare_amount': '10.00',
                  },
                'proposal': {
                  'trip_id': 'trip',
                  'driver_id': 'driver',
                  'status': direct ? 'accepted' : 'pending',
                  'amount': (price ?? 10).toStringAsFixed(2),
                },
              }),
              200,
            );
          }),
        );
        final result = await repository.sendProposal(
          token: 'token',
          driverId: 'driver',
          trip: trip,
          counterFare: price,
        );
        expect(requests.single.url.path, '/api/dispatch/proposals');
        expect(result.status, direct ? 'arriving' : 'searching');
        expect(result.fareAmount, 10);
        expect(result.myOfferAmount, price ?? 10);
        expect(result.myOfferStatus, direct ? 'accepted' : 'pending');
      },
    );
  }

  for (final body in [
    'null',
    '{}',
    '{"proposal":null}',
    '{"trip":{"status":"accepted"}}',
    '[]',
    '<html>Error</html>',
    '{"proposal":{"trip_id":"trip","driver_id":"driver","status":"accepted","amount":15}}',
    '{"proposal":{"trip_id":"other","driver_id":"driver","status":"pending","amount":15}}',
    '{"proposal":{"trip_id":"trip","driver_id":"driver","status":"pending","amount":null}}',
  ]) {
    test(
      'invalid response $body produces a readable error instead of a cast crash',
      () async {
        final repository = DriverTripRepository(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          repository.sendProposal(
            token: 'token',
            driverId: 'driver',
            trip: trip,
            counterFare: 15,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('El servidor no confirmó'),
            ),
          ),
        );
      },
    );
  }

  test('an old backend cannot silently leave direct acceptance pending', () async {
    final repository = DriverTripRepository(client: MockClient((_) async => http.Response(jsonEncode({
      'proposal': {'trip_id': 'trip', 'driver_id': 'driver', 'status': 'pending', 'amount': 10},
    }), 200)));
    await expectLater(repository.sendProposal(token: 'token', driverId: 'driver', trip: trip),
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('aceptación directa'))));
  });

  test('a counteroffer cannot be treated as an immediate assignment', () async {
    final repository = DriverTripRepository(client: MockClient((_) async => http.Response(jsonEncode({
      'accepted': true,
      'proposal': {'trip_id': 'trip', 'driver_id': 'driver', 'status': 'accepted', 'amount': 15},
      'trip': {'id': 'trip', 'driver_id': 'driver', 'status': 'arriving', 'fare_amount': 15},
    }), 200)));
    await expectLater(repository.sendProposal(token: 'token', driverId: 'driver', trip: trip, counterFare: 15),
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('no confirmó correctamente'))));
  });

  for (final status in [404, 405]) {
    test(
      'old server $status does not fall back to accepting the trip',
      () async {
        final paths = <String>[];
        final repository = DriverTripRepository(
          client: MockClient((request) async {
            paths.add(request.url.path);
            return http.Response('{}', status);
          }),
        );
        await expectLater(
          repository.sendProposal(
            token: 'token',
            driverId: 'driver',
            trip: trip,
            counterFare: 15,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Debe actualizarse'),
            ),
          ),
        );
        expect(paths, ['/api/dispatch/proposals']);
      },
    );
  }
}
