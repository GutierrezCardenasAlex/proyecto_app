import 'package:flutter/services.dart';

class AppInstallInfo {
  const AppInstallInfo({
    required this.firstInstallTimeMillis,
    required this.lastUpdateTimeMillis,
  });

  final int firstInstallTimeMillis;
  final int lastUpdateTimeMillis;

  DateTime? get firstInstallDate => firstInstallTimeMillis <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(firstInstallTimeMillis).toLocal();

  DateTime? get lastUpdateDate => lastUpdateTimeMillis <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastUpdateTimeMillis).toLocal();

  factory AppInstallInfo.fromMap(Map<dynamic, dynamic> raw) {
    return AppInstallInfo(
      firstInstallTimeMillis: (raw['firstInstallTime'] as num?)?.toInt() ?? 0,
      lastUpdateTimeMillis: (raw['lastUpdateTime'] as num?)?.toInt() ?? 0,
    );
  }
}

class AndroidAppInstallInfo {
  static const MethodChannel _channel = MethodChannel('rapigo.updater');

  static Future<AppInstallInfo?> read() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppInstallInfo');
    if (raw == null) {
      return null;
    }
    return AppInstallInfo.fromMap(raw);
  }
}
