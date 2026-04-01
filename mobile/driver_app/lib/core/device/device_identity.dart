import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceIdentity {
  const DeviceIdentity({
    required this.identifier,
    required this.name,
    required this.platform,
  });

  final String identifier;
  final String name;
  final String platform;
}

class DeviceIdentityService {
  const DeviceIdentityService._();

  static Future<DeviceIdentity> load() async {
    final plugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      final identifier = info.id.isNotEmpty
          ? info.id
          : '${info.brand}-${info.model}-${info.device}';
      final name = '${info.brand} ${info.model}'.trim();
      return DeviceIdentity(
        identifier: identifier,
        name: name.isEmpty ? 'Android' : name,
        platform: 'android',
      );
    }

    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return DeviceIdentity(
        identifier: info.identifierForVendor ?? info.utsname.machine,
        name: info.name,
        platform: 'ios',
      );
    }

    return const DeviceIdentity(
      identifier: 'unknown-device',
      name: 'Dispositivo desconocido',
      platform: 'unknown',
    );
  }
}
