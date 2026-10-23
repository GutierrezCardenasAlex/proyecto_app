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

  for (final price in <double?>[null, 15]) {
    test(
      'proposal at $price never calls acceptance or changes trip status',
      () async {
        final requests = <http.Request>[];
        final repository = DriverTripRepository(
          client: MockClient((request) async {
            requests.add(request);
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body.containsKey('counterFare'), price != null);
            expect(body['counterFare'], price);
            return http.Response(
              jsonEncode({
                'proposal': {
                  'trip_id': 'trip',
                  'driver_id': 'driver',
                  'status': 'pending',
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
        expect(result.status, 'searching');
        expect(result.fareAmount, 10);
        expect(result.myOfferAmount, price ?? 10);
        expect(result.myOfferStatus, 'pending');
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
