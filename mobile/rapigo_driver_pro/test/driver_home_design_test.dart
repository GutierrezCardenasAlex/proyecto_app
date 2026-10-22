import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapigo_driver_pro/driver/features/driver/presentation/widgets/driver_home_design.dart';

void main() {
  testWidgets('availability and menu remain usable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var toggles = 0;
    var menus = 0;
    for (final available in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: DriverHomeHeader(
                available: available,
                onMenuTap: () => menus++,
                onAvailabilityTap: () => toggles++,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.text(available ? 'Estás disponible' : 'Estás desconectado'),
      );
      await tester.tap(find.byTooltip('Abrir menú del conductor'));
    }
    expect(toggles, 2);
    expect(menus, 2);
  });

  testWidgets('long addresses wrap without losing route information', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const address =
        'Avenida Universitaria, frente a la entrada principal de la universidad, Potosí';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: DriverRequestRoute(pickup: address, destination: ''),
            ),
          ),
        ),
      ),
    );
    expect(find.text(address), findsOneWidget);
    expect(find.text('Ubicación en el mapa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
