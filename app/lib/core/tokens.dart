import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Night Shift dark design tokens (design handoff `docs/design/handoff`).
/// Near-black work-site theme: dark cards with thin borders, CAT yellow/amber
/// as the one strong color. Same token names as before, dark values now.
class AppColors {
  static const bg = Color(0xFF141414);
  static const surface2 = Color(0xFF242321); // nav bar, info rows, table header
  static const card = Color(0xFF1D1C1A);
  static const cardHover = Color(0xFF22211F); // row hover / selected
  static const ink = Color(0xFFF5F3EE);
  static const ink2 = Color(0xFFCDCAC3);
  static const muted = Color(0xFFA3A19B); // app muted
  static const muted2 = Color(0xFF85837D); // outline button / inactive nav
  static const mutedDash = Color(0xFF97958F); // dashboard muted
  static const faint = Color(0xFF6F6D68); // dashboard faint ("—" cells)
  static const inputBorder = Color(0xFF3A3935);
  static const divider = Color(0xFF2E2D2A);
  static const dividerRow = Color(0xFF2A2927);
  static const strongBorder = Color(0xFF3A3935);
  static const historyFooter = Color(0xFF181817);
  static const successBg = Color(0xFF0F3A22);
  static const successInk = Color(0xFF3DF58A);
  static const danger = Color(0xFFE5484D);
  static const dangerPressed = Color(0xFFC4383D);
  static const errorText = Color(0xFFFF8589);
  static const errorBg = Color(0xFF3A1A1B);
  static const errorBorder = Color(0xFF6B2A2C);
  static const anomalyDot = Color(0xFFE0A21A);
  static const observationDot = Color(0xFF8A8882);
  static const onAccent = Color(0xFF141414); // text on accent fills — never white
}

/// Per-vertical accent palette (Night Shift).
class AccentPalette {
  const AccentPalette({required this.base, required this.tint, required this.ink});
  final Color base;
  final Color tint;
  final Color ink; // text color on the dark tint (the accent itself)

  static const construction = AccentPalette(
    base: Color(0xFFF6C611),
    tint: Color(0xFF2E2710),
    ink: Color(0xFFF6C611),
  );
  static const mining = AccentPalette(
    base: Color(0xFFF28C28),
    tint: Color(0xFF33230F),
    ink: Color(0xFFF28C28),
  );
}

// ---------------------------------------------------------------------------
// Fonts (google_fonts): Oswald (uppercase display), Inter (body), JetBrains
// Mono (IDs/times). Numbers use tabular figures.
// ---------------------------------------------------------------------------
const _tabular = [FontFeature.tabularFigures()];

/// Oswald — page/screen titles, big numbers, kickers/labels, buttons, chips, tabs.
/// Callers uppercase their own strings (design uses uppercase display everywhere).
TextStyle oswald({
  double size = 14,
  FontWeight weight = FontWeight.w600,
  double spacing = 0.8,
  Color? color,
  double? height,
}) =>
    GoogleFonts.oswald(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      color: color,
      height: height,
      fontFeatures: _tabular,
    );

/// Inter — body text, list items, values.
TextStyle inter({
  double size = 15,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
  double? spacing,
}) =>
    GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
    );

/// JetBrains Mono — IDs, times, GPS, packets.
TextStyle mono({double size = 13, FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color, fontFeatures: _tabular);

/// Monospace merge style (kept for existing `.merge(kMono)` call sites) — JetBrains Mono.
final kMono = GoogleFonts.jetBrainsMono(fontFeatures: _tabular);

/// Tabular-figures only (no family) for `.merge(kTabular)` on numbers.
const kTabular = TextStyle(fontFeatures: _tabular);

const kRadiusCard = 16.0;
const kRadiusSmall = 12.0;
const kRadiusButton = 10.0;
const kRadiusInput = 8.0;
const kRadiusChip = 12.0;
