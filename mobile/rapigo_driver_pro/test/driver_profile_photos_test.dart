import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rapigo_driver_pro/driver/features/auth/data/auth_repository.dart';
import 'package:rapigo_driver_pro/driver/features/driver/presentation/widgets/driver_profile_photo_card.dart';

Map<String, dynamic> savedProfile() => {
  'documents_folder': 'drivers/ana',
  'driver_photo_url': 'https://example.com/driver.jpg',
  'driver_photo_public_id': 'drivers/ana/driver',
  'license_photo_url': 'https://example.com/license.jpg',
  'license_photo_public_id': 'drivers/ana/license',
  'license_category': 'A',
  'license_issue_date': '2024-01-01',
  'license_expiry_date': '2029-01-01',
  'vehicle': {
    'vehicle_photo_url': 'https://example.com/vehicle.jpg',
    'vehicle_photo_public_id': 'drivers/ana/vehicle',
  },
};

void main() {
  test('loads all three registration photos including vehicle photo', () {
    final profile = DriverProfileDetails.fromJson(savedProfile());
    expect(profile.driverPhoto?.publicId, 'drivers/ana/driver');
    expect(profile.licensePhoto?.publicId, 'drivers/ana/license');
    expect(profile.vehiclePhoto?.publicId, 'drivers/ana/vehicle');
    expect(profile.vehiclePhoto?.folder, 'drivers/ana');
    expect(DriverProfileDetails.fromJson({}).driverPhoto, isNull);
  });

  for (final replaceDriverPhoto in [false, true]) {
    test(
      'save preserves existing photos; replace driver: $replaceDriverPhoto',
      () async {
        final profile = DriverProfileDetails.fromJson(savedProfile());
        Map<String, dynamic>? body;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/drivers/profile')) {
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"driver":{"id":"driver-1"}}', 200);
          }
          return http.Response('{"user":{"profileCompleted":true}}', 200);
        });
        await http.runWithClient(
          () => const DriverAuthRepository().completeProfile(
            token: 'test-token',
            userId: 'user-1',
            driverId: 'driver-1',
            phone: '70000000',
            firstName: 'Ana',
            lastName: 'Flores',
            email: '',
            address: 'Calle Mayor 123',
            licenseNumber: '123456',
            licenseCategory: profile.licenseCategory,
            licenseIssueDate: profile.licenseIssueDate,
            licenseExpiryDate: profile.licenseExpiryDate,
            vehicleType: 'taxi',
            plate: '1234ABC',
            brand: 'Toyota',
            model: 'Corolla',
            color: 'Blanco',
            year: null,
            driverPhoto: replaceDriverPhoto
                ? const DriverUploadedDocument(
                    url: 'https://example.com/new.jpg',
                    publicId: 'drivers/ana/new',
                    folder: 'drivers/ana',
                  )
                : profile.driverPhoto,
            licensePhoto: profile.licensePhoto,
            vehiclePhoto: profile.vehiclePhoto,
          ),
          () => client,
        );
        final documents = body!['documents'] as Map<String, dynamic>;
        expect(
          documents['driverPhoto']['publicId'],
          replaceDriverPhoto ? 'drivers/ana/new' : 'drivers/ana/driver',
        );
        expect(documents['licensePhoto'], profile.licensePhoto!.toJson());
        expect(documents['vehiclePhoto'], profile.vehiclePhoto!.toJson());
        expect(body!['licenseExpiryDate'], '2029-01-01');
        expect((body!['vehicle'] as Map).containsKey('year'), isFalse);
      },
    );
  }

  testWidgets('photo upload stays visible on narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var picks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: DriverProfilePhotoCard(
                  title: 'Foto de la licencia',
                  description: 'Documento completo y datos legibles.',
                  icon: Icons.badge_outlined,
                  url: null,
                  onPick: () => picks++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Subir foto'));
    expect(picks, 1);
  });
}
