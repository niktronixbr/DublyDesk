import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// ThemeData do DublyDesk (dark + light) baseado no design system.
class AppTheme {
  AppTheme._();

  // ---------- Tipografia ----------
  static TextTheme _textTheme(Color primaryText, Color secondaryText) {
    final heading = GoogleFonts.plusJakartaSansTextTheme();
    final body = GoogleFonts.interTextTheme();

    return TextTheme(
      displayLarge: heading.displayLarge?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: primaryText,
        height: 44 / 36,
      ),
      headlineLarge: heading.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 40 / 32,
        letterSpacing: -0.02 * 32,
      ),
      headlineMedium: heading.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primaryText,
        height: 32 / 24,
      ),
      titleLarge: heading.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      bodyLarge: body.bodyLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: primaryText,
        height: 28 / 18,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primaryText,
        height: 24 / 16,
      ),
      bodySmall: body.bodySmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryText,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondaryText,
        letterSpacing: 0.05 * 12,
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondaryText,
        letterSpacing: 0.05 * 11,
      ),
    );
  }

  /// Estilo "label-caps" do design system (small caps, letter spacing).
  static TextStyle labelCaps({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05 * 12,
        color: color,
      );

  /// Tipo "financial-display" para valores grandes.
  static TextStyle financialDisplay({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 44 / 36,
        color: color,
      );

  // ---------- Themes ----------

  static ThemeData get darkTheme {
    final scheme = const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: Color(0xFF0D0096),
      secondary: AppColors.secondary,
      onSecondary: Color(0xFF003824),
      tertiary: AppColors.tertiary,
      surface: AppColors.darkBackground,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainer: AppColors.darkSurfaceContainer,
      surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
      outline: AppColors.darkOutline,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme:
          _textTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkOutline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          side: const BorderSide(color: AppColors.darkOutline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurfaceContainer,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: AppColors.darkOutline,
      iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
    );
  }

  static ThemeData get lightTheme {
    final scheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: Color(0xFF07006C),
      secondary: AppColors.secondaryDark,
      onSecondary: Colors.white,
      tertiary: AppColors.tertiary,
      surface: AppColors.lightBackground,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainer: AppColors.lightSurfaceContainer,
      surfaceContainerHigh: Color(0xFFFFFFFF),
      outline: AppColors.lightOutline,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme:
          _textTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightOutline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
        hintStyle: const TextStyle(color: AppColors.lightTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightTextPrimary,
          side: const BorderSide(color: AppColors.lightOutline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: AppColors.lightOutline,
      iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
    );
  }
}
