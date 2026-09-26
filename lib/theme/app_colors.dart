import 'package:flutter/material.dart';

/// Central color palette for Certo.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color background = Color(0xFFF5F5FA);
  static const Color card = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF8A8A94);

  // Brand
  static const Color primary = Color(0xFF4A5FEB);
  static const Color primarySoft = Color(0xFFEAEDFF);

  // Status
  static const Color success = Color(0xFF34C759);
  static const Color successSoft = Color(0xFFE6F9EC);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color dangerSoft = Color(0xFFFFECEC);
  static const Color info = Color(0xFF8B7CF6);
  static const Color infoSoft = Color(0xFFEFECFF);

  // Alarm / lock screen
  static const Color alarmBackground = Color(0xFF0E0F1A);

  // AI orb gradient: blue -> purple -> mint
  static const List<Color> orbGradient = [
    Color(0xFF4A7CFE),
    Color(0xFF8B7CF6),
    Color(0xFF6EE7C8),
  ];

  /// Pill avatar palette (rotate per medication) — [light, deep] pairs.
  static const List<List<Color>> pillPalette = [
    [Color(0xFFCFE1FF), Color(0xFF9DBDFF)], // pastel blue
    [Color(0xFFFFE9B8), Color(0xFFFFCE7A)], // pastel yellow/orange
    [Color(0xFFE2D9FF), Color(0xFFBEACFF)], // pastel lavender
    [Color(0xFFCFF5DE), Color(0xFF93E0B8)], // pastel mint
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];
}
