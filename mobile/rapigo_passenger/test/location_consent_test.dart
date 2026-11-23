import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rapigo_passenger/core/privacy/location_consent.dart';

void main() {
  testWidgets(
    'declining the disclosure does not request OS permissions or save consent',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var permissionCalls = 0;
      const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        permissionCalls++;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await LocationConsent.request(
                    context,
                    driver: false,
                  );
                },
                child: const Text('Conectar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Conectar'));
      await tester.pumpAndSettle();
      expect(find.text('Uso de tu ubicación'), findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(result, false);
      expect(permissionCalls, 0);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          LocationConsent.passengerKey,
        ),
        isNot(true),
      );
    },
  );
}
