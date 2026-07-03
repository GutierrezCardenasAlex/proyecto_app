import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/driver/home/driver_home_page.dart';

class TaxiYaDriverApp extends StatelessWidget {
  const TaxiYaDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAPIGO - PRO',
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
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF1650D7),
          selectionColor: Color(0x331650D7),
          selectionHandleColor: Color(0xFF1650D7),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFA3AEC9),
            fontWeight: FontWeight.w500,
          ),
          labelStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF1746B5),
            fontWeight: FontWeight.w700,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD5DCF2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD5DCF2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF1650D7), width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1746B5),
          ),
          contentTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4E5E89),
          ),
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
      home: const DriverHomePage(),
    );
  }
}
