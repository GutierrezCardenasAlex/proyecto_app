import 'package:flutter/material.dart';

import '../features/driver/presentation/driver_home_page.dart';

class TaxiYaDriverApp extends StatelessWidget {
  const TaxiYaDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi Ya Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16354C),
          primary: const Color(0xFF16354C),
          secondary: const Color(0xFFDB5F2D),
        ),
        useMaterial3: true,
      ),
      home: const DriverHomePage(),
    );
  }
}
