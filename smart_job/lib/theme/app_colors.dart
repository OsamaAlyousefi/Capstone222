import 'package:flutter/material.dart';

class AppColors {
  static const Color midnight = Color(0xFF19324A);
  static const Color teal = Color(0xFF5E8A86);
  static const Color sand = Color(0xFFD2AF7B);
  static const Color coral = Color(0xFFC97666);

  static const Color lightCanvas = Color(0xFFF5EFE7);
  static const Color lightSurface = Color(0xFFFFFBF7);
  static const Color lightSurfaceMuted = Color(0xFFF0E6DA);
  static const Color lightStroke = Color(0xFFDCCFBE);
  static const Color lightText = Color(0xFF162534);
  static const Color lightSubtext = Color(0xFF6C756E);

  static const Color darkCanvas = Color(0xFF0E1722);
  static const Color darkSurface = Color(0xFF132232);
  static const Color darkSurfaceMuted = Color(0xFF1B2C3E);
  static const Color darkStroke = Color(0xFF2A4258);
  static const Color darkText = Color(0xFFF5EFE7);
  static const Color darkSubtext = Color(0xFF94A2AE);

  static const Color success = Color(0xFF57A37B);
  static const Color warning = Color(0xFFD39A4D);
  static const Color danger = Color(0xFFBD6558);
  static const Color info = Color(0xFF5D8CC3);

  static Color canvas(Brightness brightness) =>
      brightness == Brightness.dark ? darkCanvas : lightCanvas;

  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color surfaceMuted(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurfaceMuted : lightSurfaceMuted;

  static Color stroke(Brightness brightness) =>
      brightness == Brightness.dark ? darkStroke : lightStroke;

  static Color text(Brightness brightness) =>
      brightness == Brightness.dark ? darkText : lightText;

  static Color subtext(Brightness brightness) =>
      brightness == Brightness.dark ? darkSubtext : lightSubtext;
}
