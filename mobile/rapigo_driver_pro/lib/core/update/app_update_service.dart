import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import 'android_apk_installer.dart';
import 'app_update_manifest.dart';

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.localBuildNumber,
    required this.localVersion,
    required this.packageName,
    required this.update,
  });

  final int localBuildNumber;
  final String localVersion;
  final String packageName;
  final AppUpdateManifest? update;
}

class AppUpdateService {
  AppUpdateService({
    required this.appId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String appId;
  final http.Client _client;

  static String _ignoredBuildKey(String appId) => 'rapigo_update_ignored_build_$appId';

  List<Uri> _manifestCandidates() {
    final primary = Uri.parse(
      AppConfig.appUpdateManifestUrl(appId: appId, platform: 'android'),
    );
    final fallback = Uri.parse(
      'https://rapigo.cybernovatech.space/api/app-updates/manifest/$appId/android',
    );
    final unique = <String>{};
    final ordered = <Uri>[];
    for (final uri in [primary, fallback]) {
      final key = uri.toString();
      if (unique.add(key)) {
        ordered.add(uri);
      }
    }
    return ordered;
  }

  Future<AppUpdateManifest?> fetchLatestManifest() async {
    for (final uri in _manifestCandidates()) {
      try {
        final response = await _client
            .get(uri, headers: const {'accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) {
          if (kDebugMode) {
            debugPrint(
              '[Updater][$appId] Manifest no disponible en $uri (${response.statusCode})',
            );
          }
          continue;
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final manifest = AppUpdateManifest.fromJson(data);
        if (kDebugMode) {
          debugPrint(
            '[Updater][$appId] Manifest cargado desde $uri -> version=${manifest.version} build=${manifest.buildNumber}',
          );
        }
        return manifest;
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[Updater][$appId] Error consultando $uri -> $error');
        }
        continue;
      }
    }
    return null;
  }

  Future<AppUpdateCheckResult> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final localBuild = int.tryParse(info.buildNumber) ?? 0;
    final manifest = await fetchLatestManifest();
    if (manifest == null) {
      return AppUpdateCheckResult(
        localBuildNumber: localBuild,
        localVersion: info.version,
        packageName: info.packageName,
        update: null,
      );
    }
    if (manifest.apkUrl.trim().isEmpty || manifest.buildNumber <= localBuild) {
      if (kDebugMode) {
        debugPrint(
          '[Updater][$appId] Sin update. Local ${info.version}+$localBuild, remoto ${manifest.version}+${manifest.buildNumber}.',
        );
      }
      return AppUpdateCheckResult(
        localBuildNumber: localBuild,
        localVersion: info.version,
        packageName: info.packageName,
        update: null,
      );
    }
    if (!manifest.mandatory) {
      final prefs = await SharedPreferences.getInstance();
      final ignoredBuild = prefs.getInt(_ignoredBuildKey(appId)) ?? 0;
      if (ignoredBuild == manifest.buildNumber) {
        return AppUpdateCheckResult(
          localBuildNumber: localBuild,
          localVersion: info.version,
          packageName: info.packageName,
          update: null,
        );
      }
    }
    return AppUpdateCheckResult(
      localBuildNumber: localBuild,
      localVersion: info.version,
      packageName: info.packageName,
      update: manifest,
    );
  }

  Future<void> ignoreVersion(int buildNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ignoredBuildKey(appId), buildNumber);
  }

  Future<void> downloadAndInstall(
    AppUpdateManifest manifest, {
    required String packageName,
    void Function(double progress)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(manifest.apkUrl));
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException('No se pudo descargar el APK (${response.statusCode})');
    }

    final tempDir = await getTemporaryDirectory();
    final updatesDir = Directory('${tempDir.path}${Platform.pathSeparator}updates');
    if (!updatesDir.existsSync()) {
      await updatesDir.create(recursive: true);
    }
    final file = File(
      '${updatesDir.path}${Platform.pathSeparator}$appId-${manifest.buildNumber}.apk',
    );
    if (file.existsSync()) {
      await file.delete();
    }

    final sink = file.openWrite();
    final total = response.contentLength ?? 0;
    var received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onProgress?.call(received / total);
      }
    }
    await sink.flush();
    await sink.close();

    try {
      await AndroidApkInstaller.installApk(
        filePath: file.path,
        authority: '$packageName.fileprovider',
      );
    } catch (_) {
      final launched = await launchUrl(
        Uri.parse(manifest.apkUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        rethrow;
      }
    }
  }
}
