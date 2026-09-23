import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Night Shift dark theme (design handoff `docs/design/handoff`). Neutral base;
/// per-vertical accents are applied per-widget via the signed-in user's
/// [AccentPalette]. Body text defaults to Inter; Oswald (uppercase) is applied
/// per-widget for display titles, labels, numbers and buttons.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AccentPalette.construction.base,
    brightness: Brightness.dark,
    surface: AppColors.bg,
  );
  final baseText = ThemeData(brightness: Brightness.dark).textTheme;

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme.copyWith(surface: AppColors.bg),
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    dividerColor: AppColors.divider,
    textTheme: GoogleFonts.interTextTheme(baseText).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: AppColors.muted),
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

/// Compatibility palette for the integrated P3 AR screens, mapped onto the
/// Night Shift tokens so those screens read consistently with the dark redesign.
class CatColors {
  static const catYellow = Color(0xFFF6C611); // construction accent
  static const catBlack = Color(0xFF141414); // bg / on-accent ink
  static const success = Color(0xFF3DF58A);
  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFE0A21A);
  static const info = Color(0xFF2D6CDF);
  static const textSecondary = Color(0xFFCDCAC3); // ink-2
  static const textMuted = Color(0xFFA3A19B); // muted
  static const textPrimary = Color(0xFFF5F3EE); // ink
  static const constructionSurface = Color(0xFF1D1C1A); // card
}
