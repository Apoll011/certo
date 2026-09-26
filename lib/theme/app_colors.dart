import 'package:flutter/material.dart';

/// Central color palette for Verifi.
///
/// Brand source (`assets/color_pallete.txt`):
/// white · #13005A (navy) · #00337C (blue) · #1C82AD (cyan) · #03C988 (green).
///
/// Prefer [ColorScheme] roles from [Theme.of] in widgets; keep these tokens for
/// brand accents and the few places that need a fixed palette (pill avatars,
/// alarm canvas).
class AppColors {
  AppColors._();

  // Surfaces
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEEF1F6);
  static const Color card = surface;

  // Text
  static const Color textPrimary = Color(0xFF13005A);
  static const Color textSecondary = Color(0xFF5A6B88);
  static const Color textTertiary = Color(0xFF8A97AD);

  // Brand
  static const Color primary = Color(0xFF00337C);
  static const Color primarySoft = Color(0xFFE4ECF7);
  static const Color secondary = Color(0xFF1C82AD);
  static const Color navy = Color(0xFF13005A);

  // Borders / dividers
  static const Color outline = Color(0xFFD5DCE8);
  static const Color outlineSubtle = Color(0xFFE8ECF2);
  static const Color divider = Color(0xFFEEF1F6);

  // Status
  static const Color success = Color(0xFF03C988);
  static const Color successSoft = Color(0xFFE0F8EF);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerSoft = Color(0xFFFDEBEC);
  static const Color info = Color(0xFF1C82AD);
  static const Color infoSoft = Color(0xFFE3F2F9);
  static const Color warning = Color(0xFFE6A23C);
  static const Color warningSoft = Color(0xFFFFF6E8);

  // Alarm / lock screen
  static const Color alarmBackground = Color(0xFF13005A);

  // AI orb gradient: blue -> cyan -> green
  static const List<Color> orbGradient = [
    Color(0xFF00337C),
    Color(0xFF1C82AD),
    Color(0xFF03C988),
  ];

  /// Pill avatar palette (rotate per medication) — [light, deep] pairs.
  static const List<List<Color>> pillPalette = [
    [Color(0xFFD6E7FF), Color(0xFF9FC1FF)], // pastel blue
    [Color(0xFFCDF0FB), Color(0xFF8BDCF5)], // pastel cyan
    [Color(0xFFD3F6E4), Color(0xFF9BEBC6)], // pastel mint
    [Color(0xFFDCDCF4), Color(0xFFB6B6E6)], // pastel navy
  ];

  /// Soft elevation — prefer outline; use sparingly for floating chrome only.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A13005A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> navShadow = [
    BoxShadow(
      color: Color(0x0A13005A),
      blurRadius: 16,
      offset: Offset(0, -2),
    ),
  ];
}
