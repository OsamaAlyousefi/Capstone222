import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  static TextTheme textTheme(Color bodyColor, Color mutedColor) {
    final base = GoogleFonts.manropeTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.sora(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -1.3,
        color: bodyColor,
      ),
      displayMedium: GoogleFonts.sora(
        fontSize: 27,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.8,
        color: bodyColor,
      ),
      displaySmall: GoogleFonts.sora(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.4,
        color: bodyColor,
      ),
      headlineMedium: GoogleFonts.sora(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: bodyColor,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: bodyColor,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: bodyColor,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: 0.1,
        color: mutedColor,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        color: bodyColor,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: mutedColor,
      ),
    );
  }
}
