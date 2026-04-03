import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'smart_job_studio_theme.dart';

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.midnight,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.midnight,
      onPrimary: Colors.white,
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      surface: AppColors.surface(brightness),
      onSurface: AppColors.text(brightness),
      error: AppColors.danger,
      onError: Colors.white,
    );

    final textTheme = AppTextStyles.textTheme(
      AppColors.text(brightness),
      AppColors.subtext(brightness),
    );

    final studioTheme = isDark
        ? const SmartJobStudioTheme(
            glassPanel: Color(0xCC162535),
            glassStrong: Color(0xF0192B3E),
            glassBorder: Color(0x66395573),
            sidebarGradientTop: Color(0xFF19324A),
            sidebarGradientBottom: Color(0xFF102131),
            highlight: Color(0xFF5D8CC3),
            mutedHighlight: Color(0x3321A4F3),
            previewPaper: Color(0xFFF5F2EC),
            exportBar: Color(0xE0142232),
          )
        : const SmartJobStudioTheme(
            glassPanel: Color(0xEAFDFBF7),
            glassStrong: Color(0xFFF8F2EA),
            glassBorder: Color(0x66C9B9A5),
            sidebarGradientTop: Color(0xFFFFFFFF),
            sidebarGradientBottom: Color(0xFFF1E6D9),
            highlight: Color(0xFF3B5C7A),
            mutedHighlight: Color(0x1F3B5C7A),
            previewPaper: Color(0xFFFEFCFA),
            exportBar: Color(0xF6FFF8F2),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: AppColors.canvas(brightness),
      colorScheme: scheme,
      textTheme: textTheme,
      dividerColor: AppColors.stroke(brightness),
      splashFactory: InkSparkle.splashFactory,
      extensions: [studioTheme],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text(brightness),
        titleTextStyle: textTheme.displaySmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface(brightness),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.subtext(brightness),
        ),
        labelStyle: textTheme.bodyMedium,
        helperStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: AppColors.stroke(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: AppColors.stroke(brightness)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.midnight, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.midnight,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text(brightness),
          side: BorderSide(color: AppColors.stroke(brightness)),
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.midnight,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: AppColors.surfaceMuted(brightness),
        disabledColor: AppColors.surfaceMuted(brightness),
        side: BorderSide(color: AppColors.stroke(brightness)),
        labelStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.text(brightness),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnight,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.midnight,
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        waitDuration: const Duration(milliseconds: 300),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.midnight
              : AppColors.surface(brightness),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.teal.withValues(alpha: 0.4)
              : AppColors.stroke(brightness),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
