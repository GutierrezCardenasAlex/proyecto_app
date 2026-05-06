import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import '../core/map/offline_map.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineMapBootstrap.ensureInitialized();
  runApp(const ProviderScope(child: TaxiYaDriverApp()));
}
