import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/app_brand.dart';

class RapigoTheme {
  static ThemeData dark() {
    final textTheme = GoogleFonts.manropeTextTheme().apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppBrand.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppBrand.primaryBlue,
        secondary: AppBrand.accentYellow,
        surface: AppBrand.darkSurface,
        onPrimary: Colors.white,
        onSecondary: AppBrand.textPrimary,
        onSurface: Colors.white,
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
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: AppBrand.accentYellow),
      ),
      cardTheme: CardThemeData(
        color: AppBrand.darkSurface,
        elevation: 0.8,
        shadowColor: Colors.black.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF131C2E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFF243246)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppBrand.accentYellow, width: 1.4),
        ),
        helperStyle: const TextStyle(
          color: Color(0xFFB7C4D6),
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppBrand.accentYellow,
          foregroundColor: AppBrand.textPrimary,
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
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF243246)),
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
        backgroundColor: AppBrand.darkSurface,
        selectedItemColor: AppBrand.accentYellow,
        unselectedItemColor: Color(0xFF94A3B8),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppBrand.darkSurface,
        indicatorColor: const Color(0xFF1E3A5F),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? AppBrand.accentYellow
                : const Color(0xFF94A3B8),
          );
        }),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppBrand.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
