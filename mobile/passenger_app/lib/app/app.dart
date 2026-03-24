import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/trip/presentation/passenger_home_page.dart';

class TaxiYaPassengerApp extends StatelessWidget {
  const TaxiYaPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi Ya Passenger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.manropeTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E3FD),
          primary: const Color(0xFF000003),
          secondary: const Color(0xFF006875),
          surface: const Color(0xFFF9F9FB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F9FB),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF000003),
          ),
        ),
        useMaterial3: true,
      ),
      home: const PassengerHomePage(),
    );
  }
}
