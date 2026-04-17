import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color canvasTop = Color(0xFFFFFFFF);
  static const Color canvasBottom = Color(0xFFFDFBF7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFFFFCF8);
  static const Color surfaceAlt = Color(0xFFFBF8F3);
  static const Color border = Color(0xFFE8DCC9);
  static const Color borderStrong = Color(0xFFD9C2A0);
  static const Color ink = Color(0xFF181410);
  static const Color inkSoft = Color(0xFF6F6556);
  static const Color inkMuted = Color(0xFF9B907E);
  static const Color gold = Color(0xFFC7911D);
  static const Color goldDeep = Color(0xFF9B6B17);
  static const Color goldSoft = Color(0xFFF3E4BF);
  static const Color green = Color(0xFF15803D);
  static const Color emerald = Color(0xFF0F9F72);
  static const Color blue = Color(0xFF315EA8);
  static const Color red = Color(0xFFB91C1C);
  static const Color amber = Color(0xFFB7791F);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.goldDeep,
    brightness: Brightness.light,
    primary: AppColors.goldDeep,
    secondary: AppColors.gold,
    surface: AppColors.surface,
    error: AppColors.red,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
  );

  final textTheme = GoogleFonts.instrumentSansTextTheme(base.textTheme)
      .copyWith(
        displayLarge: GoogleFonts.instrumentSans(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          height: 1.08,
          color: AppColors.ink,
        ),
        displayMedium: GoogleFonts.instrumentSans(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.08,
          color: AppColors.ink,
        ),
        headlineMedium: GoogleFonts.instrumentSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.12,
          color: AppColors.ink,
        ),
        titleLarge: GoogleFonts.instrumentSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: AppColors.ink,
        ),
        titleMedium: GoogleFonts.instrumentSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.instrumentSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: AppColors.ink,
        ),
        bodyMedium: GoogleFonts.instrumentSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: AppColors.inkSoft,
        ),
        labelLarge: GoogleFonts.instrumentSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.1,
          color: AppColors.ink,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: AppColors.ink),
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.goldDeep, width: 1.3),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.goldDeep,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.goldDeep,
        side: const BorderSide(color: AppColors.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceAlt,
      selectedColor: AppColors.goldSoft,
      side: const BorderSide(color: AppColors.border),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerColor: AppColors.border,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
