import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DriverLocalNotificationKind { rideRequest, promotion }

class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const String _soundEnabledKey =
      'rapigo_pro_driver_request_sound_enabled';

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
    final isPromotion = kind == DriverLocalNotificationKind.promotion;
    final playSound = isPromotion ? true : await isRequestSoundEnabled();
    final channelSuffix = playSound ? 'sound' : 'silent';
    final vibrationPattern = Int64List.fromList([0, 220, 90, 260]);
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isPromotion
              ? 'rapigo_pro_driver_promo_v2_$channelSuffix'
              : 'rapigo_pro_driver_trips_rapigo_v3_$channelSuffix',
          isPromotion ? 'RAPIGO - PRO promociones' : 'RAPIGO - PRO viajes',
          channelDescription: isPromotion
              ? 'Promociones y avisos prioritarios de RAPIGO - PRO'
              : 'Solicitudes y avisos prioritarios de viajes de RAPIGO - PRO',
          importance: Importance.high,
          priority: Priority.high,
          playSound: playSound,
          sound: playSound
              ? const RawResourceAndroidNotificationSound('rapigo_request')
              : null,
          enableVibration: playSound,
          vibrationPattern: playSound ? vibrationPattern : null,
          ticker: 'Nueva solicitud RAPIGO',
          visibility: NotificationVisibility.public,
          category: isPromotion
              ? AndroidNotificationCategory.promo
              : AndroidNotificationCategory.message,
        ),
      ),
    );
  }

  static Future<bool> isRequestSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEnabledKey) ?? true;
  }

  static Future<void> setRequestSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
  }
}
