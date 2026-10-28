import 'package:flutter/material.dart';

/// Design tokens. Every screen should use these instead of raw numbers/colors
/// so the look stays consistent and easy to change.
class AppColors {
  AppColors._();

  static const navy = Color(0xFF0F1B3D);
  static const blue = Color(0xFF3B6CF6);
  static const purple = Color(0xFF7C4DFF);
  static const lightBackground = Color(0xFFF7F8FC);
  static const darkBackground = Color(0xFF0B1022);
  static const darkSurface = Color(0xFF151C33);

  // Activity accents (kept distinct so the three cards are easy to tell apart)
  static const speaking = Color(0xFF3B6CF6);
  static const listening = Color(0xFF7C4DFF);
  static const writing = Color(0xFF00A98F);

  static const brandGradient = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  AppRadius._();

  static const double card = 20;
  static const double button = 16;
  static const double chip = 12;
}
