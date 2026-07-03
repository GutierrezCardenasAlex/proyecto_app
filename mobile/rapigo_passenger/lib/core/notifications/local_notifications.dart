import 'package:flutter/material.dart';
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
      NotificationDetails(
        android: AndroidNotificationDetails(
          'taxiya_passenger_channel',
          'RAPIGO pasajero',
          channelDescription: 'Notificaciones del pasajero',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFFF97316),
          colorized: true,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.message,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: 'RAPIGO',
          ),
        ),
      ),
    );
  }
}
