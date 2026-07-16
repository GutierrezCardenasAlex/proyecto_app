import 'package:flutter/material.dart';

import '../core/update/app_update_gate.dart';
import '../driver/features/driver/home/driver_home_page.dart';
import '../shared/theme/rapigo_theme.dart';

class RapigoDriverProApp extends StatelessWidget {
  const RapigoDriverProApp({super.key});

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
