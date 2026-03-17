import 'package:flutter/material.dart';

class AppColors {
  static bool isDarkMode = false;

  // ─── GrillPOS Brand Colors (always same) ──────────────────────────────
  static const Color warmOrange = Color(0xFFFF5722);       // Primary accent — Grill flame core
  static const Color grillRed = Color(0xFFD32F2F);         // Danger / Error
  static const Color ember = Color(0xFFFF9800);             // Secondary accent — Amber skewer
  static const Color successGreen = Color(0xFF4CAF50);      // Success
  static const Color flameLight = Color(0xFFC7A857);        // Gold highlight

  // ─── Theme-aware Colors (switch based on isDarkMode) ──────────────────
  static Color get charcoalDark => isDarkMode
      ? const Color(0xFF111418)
      : const Color(0xFFF5F6FA);

  static Color get charcoalMedium => isDarkMode
      ? const Color(0xFF1A1D24)
      : const Color(0xFFFFFFFF);

  static Color get charcoalLight => isDarkMode
      ? const Color(0xFF232730)
      : const Color(0xFFF8F9FC);

  static Color get cream => isDarkMode
      ? const Color(0xFFF5F5F7)
      : const Color(0xFF1A1D24);

  static Color get creamMuted => isDarkMode
      ? const Color(0xFFA1A5B7)
      : const Color(0xFF6B7280);

  static Color get surfaceDark => charcoalMedium;

  // ─── Semantic Aliases ────────────────────────────────────────────────
  static const Color primaryColor = warmOrange;
  static const Color primaryForeground = Colors.white;
  static const Color secondaryColor = ember;
  static const Color accentColor = flameLight;

  // Surfaces
  static Color get backgroundColor => charcoalDark;
  static Color get surfaceColor => surfaceDark;

  // Status
  static const Color errorColor = grillRed;
  static const Color successColor = successGreen;
  static const Color warningColor = ember;

  // Text
  static Color get textPrimary => cream;
  static Color get textSecondary => creamMuted;

  static Color get mutedColor => isDarkMode
      ? const Color(0xFF5E6278)
      : const Color(0xFF9CA3AF);

  static Color get borderColor => isDarkMode
      ? const Color(0xFF2B2F3A)
      : const Color(0xFFE5E7EB);

  // Legacy aliases
  static const Color accentGold = ember;
  static const Color darkGold = Color(0xFFE65100);
  static Color get kPrimaryBlue => charcoalLight;
  static const Color kSuccessGreen = successGreen;
  static const Color kDangerRed = grillRed;
  static Color get kDarkChip => cream;
  static Color get kCardBackground => surfaceDark;

  // ─── Gradient Presets ────────────────────────────────────────────────
  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warmOrange, ember],
  );

  static LinearGradient get charcoalGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [charcoalDark, charcoalMedium],
  );

  static const LinearGradient fireGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [flameLight, warmOrange, grillRed],
  );

  static LinearGradient get sidebarGradient => isDarkMode
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14171E), Color(0xFF0F1116)],
        )
      : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F9FC), Color(0xFFEDF0F7)],
        );
}
