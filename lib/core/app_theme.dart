import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_colors.dart'; // Asegúrate de que la ruta coincida con tu estructura de carpetas

class AppTheme {
  // --- MODO OSCURO ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.graphite,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        surfaceContainerLow: AppColors.darkCard,
        surfaceContainerHighest: AppColors.darkSurfaceHighest,
        outlineVariant: AppColors.darkBorder,
      ),
      textTheme: _buildTextTheme(
        textColor: AppColors.darkText,
        subtextColor: AppColors.darkSubtext,
      ),
    );
  }

  // --- MODO CLARO ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.forestGreen,
        onPrimary: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        surfaceContainerLow: AppColors.lightCard,
        surfaceContainerHighest: AppColors.lightSurfaceHigh,
        outlineVariant: AppColors.lightBorder,
      ),
      textTheme: _buildTextTheme(
        textColor: AppColors.lightText,
        subtextColor: AppColors.lightSubtext,
      ),
    );
  }

  // Helper para reutilizar la tipografía en ambos temas
  static TextTheme _buildTextTheme({
    required Color textColor,
    required Color subtextColor,
  }) {
    return TextTheme(
      headlineLarge: GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: textColor,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 15,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 13,
        color: textColor,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 11,
        color: subtextColor,
      ),
    );
  }
}