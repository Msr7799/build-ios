import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF1E293B);
  static const Color primaryLight = Color(0xFF334155);
  static const Color accent = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  // Channel colors
  static const Color booking = Color(0xFF6366F1);
  static const Color airbnb = Color(0xFFEF4444);
  static const Color agoda = Color(0xFF10B981);
  static const Color manual = Color(0xFF64748B);

  static Color channelColor(String channel) {
    switch (channel.toUpperCase()) {
      case 'BOOKING':
        return booking;
      case 'AIRBNB':
        return airbnb;
      case 'AGODA':
        return agoda;
      case 'MANUAL':
        return manual;
      default:
        return textSecondary;
    }
  }

  static ThemeData lightTheme(String locale) {
    final isAr = locale == 'ar';
    final textTheme = isAr
        ? GoogleFonts.cairoTextTheme()
        : GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: surface,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: textPrimary),
      scaffoldBackgroundColor: surface,
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardBg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Responsive breakpoints
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;
}
 