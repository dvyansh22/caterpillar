import 'package:flutter/material.dart';

/// Neutral design tokens (from the design handoff). The app is a warm light theme.
class AppColors {
  static const bg = Color(0xFFFBF8F2);
  static const surface2 = Color(0xFFF3EFE6); // nav bar, info rows
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1D1B16);
  static const ink2 = Color(0xFF3D3A33);
  static const muted = Color(0xFF5F5B52);
  static const muted2 = Color(0xFF7A766C); // outline button border
  static const inputBorder = Color(0xFFC9C4B8);
  static const divider = Color(0x1A1D1B16); // rgba(29,27,22,0.10)
  static const dividerRow = Color(0x141D1B16); // rgba(29,27,22,0.08)
  static const successBg = Color(0xFFD7ECD6);
  static const successInk = Color(0xFF1E5B24);
  static const danger = Color(0xFFB3261E);
  static const dangerPressed = Color(0xFF8C1D18);
  static const errorText = Color(0xFFA1281C);
  static const errorBg = Color(0xFFFBE4E0);
  static const errorBorder = Color(0xFFE7A79F);
}

/// Per-vertical accent palette.
class AccentPalette {
  const AccentPalette({required this.base, required this.tint, required this.ink});
  final Color base;
  final Color tint;
  final Color ink;

  static const construction = AccentPalette(
    base: Color(0xFFF2B21B),
    tint: Color(0xFFFDEFC8),
    ink: Color(0xFF5C4300),
  );
  static const mining = AccentPalette(
    base: Color(0xFFEF8A3C),
    tint: Color(0xFFFDE3CF),
    ink: Color(0xFF6B2F00),
  );
}

/// Monospace style for IDs / timestamps / packets.
const kMono = TextStyle(fontFamily: 'monospace', fontFeatures: [FontFeature.tabularFigures()]);

/// Tabular figures for any displayed number (ETAs, timers, scores).
const kTabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

const kRadiusCard = 16.0;
const kRadiusSmall = 12.0;
const kRadiusInput = 8.0;
const kRadiusChip = 6.0;
