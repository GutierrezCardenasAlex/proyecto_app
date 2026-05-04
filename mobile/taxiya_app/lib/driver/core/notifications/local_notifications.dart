import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  }) async {
    await ensureInitialized();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'taxiya_driver_channel',
          'Taxi Ya conductor',
          channelDescription: 'Notificaciones del conductor',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
