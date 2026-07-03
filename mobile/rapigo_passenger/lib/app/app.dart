import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/map/offline_map.dart';
import '../core/update/app_update_gate.dart';
import '../features/trip/presentation/passenger_home_page.dart';
import '../shared/theme/rapigo_theme.dart';

class RapigoPassengerApp extends ConsumerStatefulWidget {
  const RapigoPassengerApp({super.key});

  @override
  ConsumerState<RapigoPassengerApp> createState() => _RapigoPassengerAppState();
}

class _RapigoPassengerAppState extends ConsumerState<RapigoPassengerApp> {
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
      title: 'RAPIGO',
      debugShowCheckedModeBanner: false,
      theme: RapigoTheme.light(),
      home: const PassengerAppUpdateGate(
        appId: 'rapigo_passenger',
        child: PassengerHomePage(),
      ),
    );
  }
}
