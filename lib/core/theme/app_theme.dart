import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class AppTheme {
  /// The main GrillPOS dark charcoal theme with warm orange accents.
  static ThemeData get darkTheme => _buildTheme(isDark: true);

  /// Professional light theme for GrillPOS.
  static ThemeData get lightTheme => _buildTheme(isDark: false);

  /// Get current theme based on AppColors.isDarkMode
  static ThemeData get currentTheme =>
      AppColors.isDarkMode ? darkTheme : lightTheme;

  /// Keep backward compatibility
  static ThemeData get grillTheme => currentTheme;

  static ThemeData _buildTheme({required bool isDark}) {
    final baseTextTheme = GoogleFonts.cairoTextTheme();

    final brightness = isDark ? Brightness.dark : Brightness.light;

    // Core colors
    final scaffoldBg = isDark ? const Color(0xFF111418) : const Color(0xFFF5F6FA);
    final surfaceColor = isDark ? const Color(0xFF1A1D24) : const Color(0xFFFFFFFF);
    final cardColor = isDark ? const Color(0xFF232730) : const Color(0xFFF8F9FC);
    final textPrimary = isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1D24);
    final textSecondary = isDark ? const Color(0xFFA1A5B7) : const Color(0xFF6B7280);
    final mutedColor = isDark ? const Color(0xFF5E6278) : const Color(0xFF9CA3AF);
    final borderColor = isDark ? const Color(0xFF2B2F3A) : const Color(0xFFE5E7EB);
    const warmOrange = Color(0xFFFF5722);
    const grillRed = Color(0xFFD32F2F);
    const ember = Color(0xFFFF9800);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: warmOrange,
        onPrimary: Colors.white,
        secondary: ember,
        onSecondary: Colors.white,
        surface: surfaceColor,
        onSurface: textPrimary,
        error: grillRed,
        onError: Colors.white,
        primaryContainer: cardColor,
        onPrimaryContainer: textPrimary,
        secondaryContainer: isDark ? const Color(0xFF1A1D24) : const Color(0xFFF3F5F8),
        onSecondaryContainer: textSecondary,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary,
        ),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w500, color: textSecondary,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16, fontWeight: FontWeight.normal, color: textPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14, fontWeight: FontWeight.normal, color: textSecondary,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 12, fontWeight: FontWeight.normal, color: mutedColor,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: warmOrange,
          foregroundColor: Colors.white,
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: warmOrange,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: warmOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1D24) : const Color(0xFFF3F5F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: warmOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: grillRed),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: mutedColor),
        labelStyle: TextStyle(color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
        ),
        titleTextStyle: baseTextTheme.headlineSmall?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1A1D24) : const Color(0xFFF3F5F8),
        labelStyle: TextStyle(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        ),
        side: BorderSide(color: borderColor),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: warmOrange,
        unselectedLabelColor: mutedColor,
        indicatorColor: warmOrange,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: textPrimary, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: warmOrange),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: warmOrange, foregroundColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return warmOrange;
          return mutedColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return warmOrange.withAlpha(80);
          return borderColor;
        }),
      ),
    );
  }
}
