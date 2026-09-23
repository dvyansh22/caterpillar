import 'package:flutter/material.dart';

import 'vertical.dart';

/// Rugged, industrial, high-contrast theme. Dark by default (night shifts + glare).
/// The seed color comes from the active [Vertical] so the whole app re-skins on switch.
ThemeData buildTheme(Vertical vertical, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: vertical.accent,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.dark ? const Color(0xFF121212) : null,
    cardTheme: CardThemeData(
      elevation: 0,
      color: brightness == Brightness.dark ? const Color(0xFF1E1E1E) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56), // large, glove-friendly targets
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
    navigationBarTheme: const NavigationBarThemeData(height: 68),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

/// Semantic safety colors (independent of vertical).
class SafetyColors {
  static const pass = Color(0xFF2E7D32);
  static const danger = Color(0xFFD32F2F);
  static const warning = Color(0xFFF9A825);
}
