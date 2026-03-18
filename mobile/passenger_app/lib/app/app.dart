import 'package:flutter/material.dart';

import '../features/trip/presentation/passenger_home_page.dart';

class TaxiYaPassengerApp extends StatelessWidget {
  const TaxiYaPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi Ya Passenger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFDB5F2D),
          primary: const Color(0xFFDB5F2D),
          secondary: const Color(0xFF16354C),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5EFE6),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        useMaterial3: true,
      ),
      home: const PassengerHomePage(),
    );
  }
}
