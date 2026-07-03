import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/app_brand.dart';

class RapigoTheme {
  static ThemeData light() {
    final textTheme = GoogleFonts.manropeTextTheme().apply(
      bodyColor: AppBrand.textPrimary,
      displayColor: AppBrand.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppBrand.surfaceSoft,
      colorScheme: const ColorScheme.light(
        primary: AppBrand.primaryBlue,
        secondary: AppBrand.accentYellow,
        surface: AppBrand.surface,
        onPrimary: Colors.white,
        onSecondary: AppBrand.textPrimary,
        onSurface: AppBrand.textPrimary,
        error: AppBrand.danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppBrand.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppBrand.primaryBlue),
      ),
      cardTheme: CardThemeData(
        color: AppBrand.surface,
        elevation: 0.8,
        shadowColor: const Color(0x140F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppBrand.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppBrand.surfaceMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppBrand.primaryBlue, width: 1.4),
        ),
        helperStyle: const TextStyle(
          color: AppBrand.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppBrand.primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppBrand.primaryBlue,
          side: const BorderSide(color: AppBrand.surfaceMuted),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppBrand.surface,
        selectedItemColor: AppBrand.primaryBlue,
        unselectedItemColor: AppBrand.textSecondary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppBrand.surface,
        indicatorColor: AppBrand.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? AppBrand.primaryBlue
                : AppBrand.textSecondary,
          );
        }),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppBrand.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
