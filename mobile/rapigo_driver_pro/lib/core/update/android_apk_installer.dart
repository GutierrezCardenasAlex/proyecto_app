import 'package:flutter/services.dart';

class AndroidApkInstaller {
  static const MethodChannel _channel = MethodChannel('rapigo.updater');

  static Future<void> installApk({
    required String filePath,
    required String authority,
  }) async {
    await _channel.invokeMethod<void>('installApk', {
      'filePath': filePath,
      'authority': authority,
    });
  }
}
