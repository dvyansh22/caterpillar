import 'package:flutter/material.dart';

import 'tokens.dart';

/// Warm light theme from the design handoff. Vertical accents are applied per-widget
/// via [accentProvider]; this theme covers the neutral base.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AccentPalette.construction.base,
    brightness: Brightness.light,
    surface: AppColors.bg,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    dividerColor: AppColors.divider,
    textTheme: const TextTheme().apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
      titleTextStyle: TextStyle(fontSize: 20, color: AppColors.ink, fontWeight: FontWeight.w400),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
      ),
    ),
  );
}

/// Compatibility palette for the integrated P3 AR screens (from PR #2), mapped onto
/// the current design tokens so those screens read consistently with the redesign.
class CatColors {
  static const catYellow = Color(0xFFF2B21B); // construction accent
  static const catBlack = Color(0xFF1D1B16); // ink
  static const success = Color(0xFF1E5B24);
  static const danger = Color(0xFFB3261E);
  static const warning = Color(0xFFF9A825);
  static const info = Color(0xFF2D6CDF);
  static const textSecondary = Color(0xFF5F5B52); // muted
  static const textMuted = Color(0xFF7A766C); // muted-2
  static const textPrimary = Color(0xFF1D1B16); // ink
  static const constructionSurface = Color(0xFF1E1E2C); // dark surface
}
