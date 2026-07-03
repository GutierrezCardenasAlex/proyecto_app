import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/map/map_style_cache.dart';
import 'core/map/offline_map.dart';
import 'core/map/rapigo_map_runtime.dart';
import 'driver/features/driver/home/driver_initial_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DriverStartupTrace.markMainStarted();
  await OfflineMapBootstrap.ensureInitialized();
  await MapStyleCache.preload(rapigoLightStyle.assetPath);
  runApp(const ProviderScope(child: RapigoDriverProApp()));
}
