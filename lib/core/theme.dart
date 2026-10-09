import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system carried over from the Milestone 02 Figma library.
/// Colour names match the Figma style names so the report can map them 1:1.
class AppColors {
  static const primary = Color(0xFF0B6E4F); // Primary / Green
  static const primaryDark = Color(0xFF084A36); // Primary / Dark (staff top bars)
  static const accent = Color(0xFFF2A03D); // Accent / Orange (near turn, priority)
  static const danger = Color(0xFFC63A2E); // Semantic / Danger
  static const success = Color(0xFF2E9E5B); // Semantic / Success
  static const n900 = Color(0xFF111827);
  static const n600 = Color(0xFF4B5563);
  static const n400 = Color(0xFF9CA3AF);
  static const n200 = Color(0xFFE5E7EB);
  static const n50 = Color(0xFFF9FAFB);
}

/// Spacing grid (8 px), corner radius (12 px) and minimum touch target
/// (48 px) from the design system's "spacing and sizing rules" (NF2).
class AppSizes {
  static const grid = 8.0;
  static const radius = 12.0;
  static const minTouch = 48.0;
}

class AppTheme {
  static ThemeData build({required bool highContrast, required bool staff}) {
    final primary = highContrast ? Colors.black : AppColors.primary;
    final barColor = highContrast ? Colors.black : (staff ? AppColors.primaryDark : AppColors.primary);
    final surface = highContrast ? Colors.white : AppColors.n50;
    final textColor = highContrast ? Colors.black : AppColors.n900;
    final borderColor = highContrast ? Colors.black : AppColors.n200;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: primary,
        secondary: AppColors.accent,
        error: AppColors.danger,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
    );

    // Noto Sans renders Latin; Sinhala/Tamil glyphs fall back to the Noto
    // Sinhala/Tamil families shipped with Android.
    final textTheme = GoogleFonts.notoSansTextTheme(base.textTheme).copyWith(
      headlineMedium:
          GoogleFonts.notoSans(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.bold, color: textColor),
      titleLarge: GoogleFonts.notoSans(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, color: textColor),
      bodyLarge: GoogleFonts.notoSans(fontSize: 18, height: 26 / 18, color: textColor),
      bodyMedium: GoogleFonts.notoSans(fontSize: 16, height: 24 / 16, color: textColor),
      bodySmall:
          GoogleFonts.notoSans(fontSize: 13, height: 18 / 13, color: highContrast ? Colors.black : AppColors.n600),
    );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius));

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: barColor,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(AppSizes.minTouch),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(AppSizes.minTouch),
          side: BorderSide(color: primary, width: highContrast ? 2 : 1.2),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(AppSizes.minTouch, AppSizes.minTouch),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          borderSide: BorderSide(color: borderColor, width: highContrast ? 2 : 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          side: BorderSide(color: borderColor, width: highContrast ? 2 : 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        indicatorColor: primary.withValues(alpha: 0.15),
      ),
    );
  }
}
