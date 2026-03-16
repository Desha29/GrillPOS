import 'package:flutter/material.dart';

class AppColors {
  // Theme Management Flag
  static bool isDarkMode = true;

  // ─── GrillPOS Brand Colors ─────────────────────────────────────────────
  static Color get charcoalDark => isDarkMode ? const Color(0xFF111418) : const Color(0xFFF9FAFC);     // Main scaffold
  static Color get charcoalMedium => isDarkMode ? const Color(0xFF1A1D24) : const Color(0xFFFFFFFF);   // Standard card background
  static Color get charcoalLight => isDarkMode ? const Color(0xFF232730) : const Color(0xFFF3F5F8);    // Elevated cards / Dialogs / Hover states
  static Color get warmOrange => const Color(0xFFFF5722);       // Primary accent — Grill flame core
  static Color get grillRed => const Color(0xFFD32F2F);         // Highlight / danger — Grill body
  static Color get cream => isDarkMode ? const Color(0xFFF5F5F7) : const Color(0xFF1A1D24);            // High contrast text
  static Color get creamMuted => isDarkMode ? const Color(0xFFA1A5B7) : const Color(0xFF6B7280);       // Secondary text
  static Color get ember => const Color(0xFFFF9800);            // Secondary accent — Amber skewer
  static Color get successGreen => const Color(0xFF4CAF50);     // Success
  static Color get surfaceDark => charcoalMedium;               // Alias for standard cards
  static Color get flameLight => const Color(0xFFFFC107);       // Tertiary — tip highlight

  // ─── Semantic Aliases ─────────────────────────────────────────────────
  static Color get primaryColor => warmOrange;
  static Color get primaryForeground => Colors.white;
  static Color get secondaryColor => ember;
  static Color get accentColor => flameLight;

  // Surfaces
  static Color get backgroundColor => charcoalDark;
  static Color get surfaceColor => surfaceDark;

  // Status Colors
  static Color get errorColor => grillRed;
  static Color get successColor => successGreen;
  static Color get warningColor => ember;

  // Text Colors
  static Color get textPrimary => cream;
  static Color get textSecondary => creamMuted;
  static Color get mutedColor => isDarkMode ? const Color(0xFF5E6278) : const Color(0xFF9CA3AF);       // Icons and very muted text
  static Color get borderColor => isDarkMode ? const Color(0xFF2B2F3A) : const Color(0xFFE5E7EB);      // Subtle borders

  // Legacy/Feature Specific
  static Color get accentGold => ember;
  static Color get darkGold => const Color(0xFFE65100);
  static Color get kPrimaryBlue => charcoalLight;
  static Color get kSuccessGreen => successGreen;
  static Color get kDangerRed => grillRed;
  static Color get kDarkChip => cream;
  static Color get kCardBackground => surfaceDark;

  // ─── Gradient Presets ─────────────────────────────────────────────────
  static LinearGradient get orangeGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warmOrange, ember],
  );

  static LinearGradient get charcoalGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [charcoalDark, charcoalMedium],
  );

  static LinearGradient get fireGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [flameLight, warmOrange, grillRed],
  );

  static LinearGradient get sidebarGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDarkMode ? const [Color(0xFF14171E), Color(0xFF0F1116)] : const [Color(0xFFFFFFFF), Color(0xFFF3F5F8)],
  );
}
