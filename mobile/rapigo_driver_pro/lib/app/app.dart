import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/map/offline_map.dart';
import '../core/update/app_update_gate.dart';
import '../driver/features/driver/home/driver_home_page.dart';
import '../shared/theme/rapigo_theme.dart';

class RapigoDriverProApp extends ConsumerStatefulWidget {
  const RapigoDriverProApp({super.key});

  @override
  ConsumerState<RapigoDriverProApp> createState() => _RapigoDriverProAppState();
}

class _RapigoDriverProAppState extends ConsumerState<RapigoDriverProApp> {
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(offlineMapProvider.notifier).ensureOfflineAvailability();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAPIGO - PRO',
      debugShowCheckedModeBanner: false,
      theme: RapigoTheme.dark(),
      home: const DriverAppUpdateGate(
        appId: 'rapigo_driver_pro',
        child: DriverHomePage(),
      ),
    );
  }
}
