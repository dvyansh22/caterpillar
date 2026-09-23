/// Core theme for the Smart Operator Assistant.
///
/// CAT-branded Material 3 theme with vertical-adaptive color schemes
/// (construction = amber/earth, mining = deep orange/slate).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Caterpillar brand colors.
abstract final class CatColors {
  // Primary brand
  static const Color catYellow = Color(0xFFFFCB05);
  static const Color catBlack = Color(0xFF1A1A1A);

  // Construction vertical
  static const Color constructionPrimary = Color(0xFFFFCB05);
  static const Color constructionSecondary = Color(0xFF4A6741);
  static const Color constructionSurface = Color(0xFF1E1E2C);
  static const Color constructionSurfaceLight = Color(0xFF2A2A3C);

  // Mining vertical
  static const Color miningPrimary = Color(0xFFFF6B35);
  static const Color miningSecondary = Color(0xFF546E7A);
  static const Color miningSurface = Color(0xFF1A1A2E);
  static const Color miningSurfaceLight = Color(0xFF252540);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color danger = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // Text
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF707070);
}

/// Build the app [ThemeData] for a given vertical.
ThemeData buildCatTheme({required bool isMining}) {
  final primary = isMining ? CatColors.miningPrimary : CatColors.constructionPrimary;
  final secondary = isMining ? CatColors.miningSecondary : CatColors.constructionSecondary;
  final surface = isMining ? CatColors.miningSurface : CatColors.constructionSurface;
  final surfaceLight = isMining ? CatColors.miningSurfaceLight : CatColors.constructionSurfaceLight;

  final colorScheme = ColorScheme.dark(
    primary: primary,
    secondary: secondary,
    surface: surface,
    onPrimary: CatColors.catBlack,
    onSecondary: CatColors.textPrimary,
    onSurface: CatColors.textPrimary,
    error: CatColors.danger,
  );

  final textTheme = GoogleFonts.outfitTextTheme(
    ThemeData.dark().textTheme,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: surface,
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceLight,
      foregroundColor: CatColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: CatColors.textPrimary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceLight,
      indicatorColor: primary.withValues(alpha: 0.2),
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: CatColors.catBlack,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceLight,
      labelStyle: GoogleFonts.outfit(fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: DividerThemeData(
      color: CatColors.textMuted.withValues(alpha: 0.2),
      thickness: 1,
    ),
  );
}
