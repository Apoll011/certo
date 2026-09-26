import 'package:flutter/material.dart';

/// Central color palette for Verifi.
///
/// Mirrors the brand palette in `assets/color_pallete.txt`:
/// white · #13005A (navy) · #00337C (blue) · #1C82AD (cyan) · #03C988 (green).
class AppColors {
  AppColors._();

  // Surfaces
  static const Color background = Color(0xFFF3F6FB);
  static const Color card = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF13005A);
  static const Color textSecondary = Color(0xFF5B6B8F);

  // Brand
  static const Color primary = Color(0xFF00337C);
  static const Color primarySoft = Color(0xFFE2EBF7);
  static const Color secondary = Color(0xFF1C82AD);

  // Status
  static const Color success = Color(0xFF03C988);
  static const Color successSoft = Color(0xFFE0F8EF);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerSoft = Color(0xFFFDEBEC);
  static const Color info = Color(0xFF1C82AD);
  static const Color infoSoft = Color(0xFFE3F2F9);

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

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];
}
