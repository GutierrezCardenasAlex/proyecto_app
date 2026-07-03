import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum DriverLocalNotificationKind {
  rideRequest,
  promotion,
}

class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    DriverLocalNotificationKind kind = DriverLocalNotificationKind.rideRequest,
  }) async {
    await ensureInitialized();
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          kind == DriverLocalNotificationKind.promotion ? 'rapigo_pro_driver_promo' : 'rapigo_pro_driver_trips',
          kind == DriverLocalNotificationKind.promotion ? 'RAPIGO - PRO promociones' : 'RAPIGO - PRO viajes',
          channelDescription: kind == DriverLocalNotificationKind.promotion
              ? 'Promociones y avisos prioritarios de RAPIGO - PRO'
              : 'Solicitudes y avisos prioritarios de viajes de RAPIGO - PRO',
          importance: Importance.high,
          priority: Priority.high,
          category: kind == DriverLocalNotificationKind.promotion ? AndroidNotificationCategory.promo : AndroidNotificationCategory.message,
        ),
      ),
    );
  }
}
