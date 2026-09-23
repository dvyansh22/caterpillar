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
