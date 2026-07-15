import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/app_brand.dart';

class RapigoDriverPalette extends ThemeExtension<RapigoDriverPalette> {
  const RapigoDriverPalette({
    required this.backgroundBase,
    required this.backgroundRaised,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceInteractive,
    required this.surfaceMuted,
    required this.outlineSoft,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentBlue,
    required this.accentBlueSoft,
    required this.accentYellow,
    required this.accentGreen,
    required this.accentDanger,
    required this.shadowSoft,
  });

  final Color backgroundBase;
  final Color backgroundRaised;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceInteractive;
  final Color surfaceMuted;
  final Color outlineSoft;
  final Color outlineStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentBlue;
  final Color accentBlueSoft;
  final Color accentYellow;
  final Color accentGreen;
  final Color accentDanger;
  final Color shadowSoft;

  static const dark = RapigoDriverPalette(
    backgroundBase: Color(0xFF020617),
    backgroundRaised: Color(0xFF091223),
    surfacePrimary: Color(0xFF0F172A),
    surfaceSecondary: Color(0xFF131D33),
    surfaceInteractive: Color(0xFFF8FAFC),
    surfaceMuted: Color(0xFFF3F6FD),
    outlineSoft: Color(0x1FFFFFFF),
    outlineStrong: Color(0xFF243246),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFD6E1F0),
    textMuted: Color(0xFF94A3B8),
    accentBlue: AppBrand.primaryBlue,
    accentBlueSoft: Color(0xFF1FA6FF),
    accentYellow: AppBrand.accentYellow,
    accentGreen: AppBrand.success,
    accentDanger: Color(0xFFEF4444),
    shadowSoft: Color(0x33000000),
  );

  @override
  ThemeExtension<RapigoDriverPalette> copyWith({
    Color? backgroundBase,
    Color? backgroundRaised,
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? surfaceInteractive,
    Color? surfaceMuted,
    Color? outlineSoft,
    Color? outlineStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentBlue,
    Color? accentBlueSoft,
    Color? accentYellow,
    Color? accentGreen,
    Color? accentDanger,
    Color? shadowSoft,
  }) {
    return RapigoDriverPalette(
      backgroundBase: backgroundBase ?? this.backgroundBase,
      backgroundRaised: backgroundRaised ?? this.backgroundRaised,
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceInteractive: surfaceInteractive ?? this.surfaceInteractive,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      outlineSoft: outlineSoft ?? this.outlineSoft,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentBlue: accentBlue ?? this.accentBlue,
      accentBlueSoft: accentBlueSoft ?? this.accentBlueSoft,
      accentYellow: accentYellow ?? this.accentYellow,
      accentGreen: accentGreen ?? this.accentGreen,
      accentDanger: accentDanger ?? this.accentDanger,
      shadowSoft: shadowSoft ?? this.shadowSoft,
    );
  }

  @override
  ThemeExtension<RapigoDriverPalette> lerp(
    covariant ThemeExtension<RapigoDriverPalette>? other,
    double t,
  ) {
    if (other is! RapigoDriverPalette) {
      return this;
    }
    return RapigoDriverPalette(
      backgroundBase: Color.lerp(backgroundBase, other.backgroundBase, t)!,
      backgroundRaised: Color.lerp(backgroundRaised, other.backgroundRaised, t)!,
      surfacePrimary: Color.lerp(surfacePrimary, other.surfacePrimary, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      surfaceInteractive: Color.lerp(surfaceInteractive, other.surfaceInteractive, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      outlineSoft: Color.lerp(outlineSoft, other.outlineSoft, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      accentBlueSoft: Color.lerp(accentBlueSoft, other.accentBlueSoft, t)!,
      accentYellow: Color.lerp(accentYellow, other.accentYellow, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      accentDanger: Color.lerp(accentDanger, other.accentDanger, t)!,
      shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
    );
  }
}

class RapigoDriverMetrics extends ThemeExtension<RapigoDriverMetrics> {
  const RapigoDriverMetrics({
    required this.pagePadding,
    required this.sectionGap,
    required this.itemGap,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.radiusXLarge,
    required this.buttonHeight,
    required this.heroButtonHeight,
  });

  final double pagePadding;
  final double sectionGap;
  final double itemGap;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double radiusXLarge;
  final double buttonHeight;
  final double heroButtonHeight;

  static const dark = RapigoDriverMetrics(
    pagePadding: 18,
    sectionGap: 24,
    itemGap: 14,
    radiusSmall: 18,
    radiusMedium: 22,
    radiusLarge: 28,
    radiusXLarge: 34,
    buttonHeight: 58,
    heroButtonHeight: 64,
  );

  @override
  ThemeExtension<RapigoDriverMetrics> copyWith({
    double? pagePadding,
    double? sectionGap,
    double? itemGap,
    double? radiusSmall,
    double? radiusMedium,
    double? radiusLarge,
    double? radiusXLarge,
    double? buttonHeight,
    double? heroButtonHeight,
  }) {
    return RapigoDriverMetrics(
      pagePadding: pagePadding ?? this.pagePadding,
      sectionGap: sectionGap ?? this.sectionGap,
      itemGap: itemGap ?? this.itemGap,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      radiusXLarge: radiusXLarge ?? this.radiusXLarge,
      buttonHeight: buttonHeight ?? this.buttonHeight,
      heroButtonHeight: heroButtonHeight ?? this.heroButtonHeight,
    );
  }

  @override
  ThemeExtension<RapigoDriverMetrics> lerp(
    covariant ThemeExtension<RapigoDriverMetrics>? other,
    double t,
  ) {
    if (other is! RapigoDriverMetrics) {
      return this;
    }
    return RapigoDriverMetrics(
      pagePadding: lerpDouble(pagePadding, other.pagePadding, t)!,
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t)!,
      itemGap: lerpDouble(itemGap, other.itemGap, t)!,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t)!,
      radiusMedium: lerpDouble(radiusMedium, other.radiusMedium, t)!,
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge, t)!,
      radiusXLarge: lerpDouble(radiusXLarge, other.radiusXLarge, t)!,
      buttonHeight: lerpDouble(buttonHeight, other.buttonHeight, t)!,
      heroButtonHeight: lerpDouble(heroButtonHeight, other.heroButtonHeight, t)!,
    );
  }
}

class RapigoTheme {
  static ThemeData dark() {
    final palette = RapigoDriverPalette.dark;
    final metrics = RapigoDriverMetrics.dark;
    final baseTextTheme = GoogleFonts.manropeTextTheme();
    final textTheme = baseTextTheme.copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        height: 1.04,
        color: palette.textPrimary,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 30,
        fontWeight: FontWeight.w900,
        height: 1.06,
        color: palette.textPrimary,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 25,
        fontWeight: FontWeight.w800,
        height: 1.08,
        color: palette.textPrimary,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: palette.textPrimary,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: palette.textPrimary,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: palette.textSecondary,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: palette.textSecondary,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: palette.textMuted,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: palette.textPrimary,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: palette.textMuted,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: palette.textMuted,
      ),
    ).apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.backgroundBase,
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
      extensions: const <ThemeExtension<dynamic>>[
        RapigoDriverPalette.dark,
        RapigoDriverMetrics.dark,
      ],
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppBrand.accentYellow,
        selectionColor: Color(0x3338BDF8),
        selectionHandleColor: AppBrand.accentYellow,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineLarge,
        iconTheme: const IconThemeData(color: AppBrand.accentYellow),
      ),
      cardTheme: CardThemeData(
        color: palette.surfacePrimary,
        elevation: 0,
        shadowColor: palette.shadowSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(metrics.radiusLarge),
          side: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: textTheme.bodyLarge?.copyWith(color: palette.textMuted),
        labelStyle: textTheme.titleMedium?.copyWith(color: palette.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radiusMedium),
          borderSide: BorderSide(color: palette.outlineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radiusMedium),
          borderSide: const BorderSide(color: AppBrand.accentYellow, width: 1.4),
        ),
        helperStyle: textTheme.bodySmall?.copyWith(color: const Color(0xFFB7C4D6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppBrand.accentYellow,
          foregroundColor: AppBrand.textPrimary,
          minimumSize: Size.fromHeight(metrics.buttonHeight),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(metrics.radiusMedium),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.outlineStrong),
          minimumSize: Size.fromHeight(metrics.buttonHeight - 2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(metrics.radiusMedium),
          ),
          textStyle: textTheme.labelLarge,
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfacePrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(metrics.radiusSmall),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

extension RapigoDriverThemeContext on BuildContext {
  RapigoDriverPalette get rapigoPalette =>
      Theme.of(this).extension<RapigoDriverPalette>() ?? RapigoDriverPalette.dark;

  RapigoDriverMetrics get rapigoMetrics =>
      Theme.of(this).extension<RapigoDriverMetrics>() ?? RapigoDriverMetrics.dark;
}
