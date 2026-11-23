import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationConsent {
  static const driverKey = 'driver_location_consent_v2';
  static const passengerKey = 'passenger_location_consent_v2';

  static Future<bool> request(
    BuildContext context, {
    required bool driver,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = driver ? driverKey : passengerKey;
    if (prefs.getBool(key) != true) {
      if (!context.mounted) return false;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Uso de tu ubicación'),
          content: SingleChildScrollView(
            child: Text(
              driver
                  ? 'RAPIGO PRO recopila tu ubicación precisa y la envía a la central para ofrecerte solicitudes cercanas y compartir el seguimiento con el pasajero durante el viaje. Mientras estés disponible o en un viaje, también utiliza tu ubicación en segundo plano, cuando la app no está visible. Puedes desconectarte al terminar de trabajar. No usamos tu ubicación para publicidad.'
                  : 'RAPIGO usa tu ubicación mientras utilizas la app para mostrar el mapa y ayudarte a elegir la recogida. Al solicitar un viaje, la recogida y el destino se envían a la central y al conductor. Puedes elegir la recogida manualmente si no das permiso. No usamos tu ubicación para publicidad.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (accepted != true) return false;
      await prefs.setBool(key, true);
    }
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted && !status.isLimited) return false;
    if (driver && context.mounted) {
      final background = await Permission.locationAlways.status;
      if (!background.isGranted) await Permission.locationAlways.request();
    }
    return true;
  }
}
