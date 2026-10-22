import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapigo_passenger/core/ui/top_notice.dart';
import 'package:rapigo_passenger/features/trip/domain/trip_request.dart';
import 'package:rapigo_passenger/features/trip/presentation/widgets/trip_status_banner.dart';
import 'package:rapigo_passenger/features/trip/presentation/widgets/trip_completion_dialog.dart';

void main() {
  testWidgets('Live states are legible at narrow widths with enlarged text', (
    tester,
  ) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final status in [
      'requested',
      'accepted',
      'arriving',
      'at_pickup',
      'in_progress',
      'completed',
      'cancelled',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(body: TripStatusBanner(status: status)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(TripStatusPresentation.fromStatus(status).title),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Notices keep the entire message and can be replaced and dismissed',
    (tester) async {
      late BuildContext noticeContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              noticeContext = context;
              return const Scaffold();
            },
          ),
        ),
      );
      const message =
          'No se pudo encontrar esa dirección. Elige otro lugar en el mapa para continuar con tu viaje.';
      showTopNotice(noticeContext, message, title: 'Revisa el destino');
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      showTopNotice(
        noticeContext,
        'El conductor va al punto de recogida.',
        title: 'Taxi en camino',
      );
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
      expect(find.text('Taxi en camino'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar aviso'));
      await tester.pumpAndSettle();
      expect(find.text('Taxi en camino'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Rating errors retain the summary and allow a successful retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TripCompletionDialog(
                  request: const TripRequest(
                    pickupAddress: 'Origen',
                    destinationAddress: 'Plaza',
                    status: 'completed',
                    activeTripId: 'test-trip',
                    fareAmount: 12,
                  ),
                  onRate: (score, comment) async {
                    attempts++;
                    if (attempts == 1) throw Exception('Offline');
                  },
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Bs 12.00'), findsOneWidget);
    await tester.tap(find.text('Calificar y terminar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos enviar'), findsOneWidget);
    await tester.tap(find.text('Calificar y terminar'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(TripCompletionDialog), findsNothing);
  });
}
