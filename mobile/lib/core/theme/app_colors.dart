import 'package:flutter/material.dart';

/// Muallim Carpets brand palette - luxury emerald + gold + royal blue.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0F766E); // Deep emerald
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primaryDark = Color(0xFF0B5D57);
  static const Color accent = Color(0xFFD4A017); // Gold
  static const Color accentLight = Color(0xFFE8C766);
  static const Color secondary = Color(0xFF2563EB); // Royal blue
  static const Color secondaryLight = Color(0xFF60A5FA);
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFF87171);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoLight = Color(0xFF38BDF8);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFEC4899);

  /// Common soft gradient pairs used for gradient cards.
  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
  );
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4A017), Color(0xFFE8C766)],
  );
  static const LinearGradient royalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
  );
  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFF87171)],
  );
  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
  );
  static const LinearGradient violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
  );
  static const LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
  );
  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
  );

  // Light
  static const Color background = Color(0xFFF5F7F6);
  static const Color backgroundTop = Color(0xFFEAF3F1);
  static const Color surface = Colors.white;
  static const Color surfaceHigh = Color(0xFFEFF6F4);
  static const Color border = Color(0xFFE2EAE7);
  static const Color borderStrong = Color(0xFFCBDAD5);

  // Dark (deep black with emerald undertone)
  static const Color darkBackground = Color(0xFF0B1211);
  static const Color darkBackgroundTop = Color(0xFF0E1B19);
  static const Color darkSurface = Color(0xFF121C1A);
  static const Color darkSurfaceHigh = Color(0xFF1B2926);
  static const Color darkBorder = Color(0xFF233331);
  static const Color darkBorderStrong = Color(0xFF324944);

  static const Color textPrimary = Color(0xFF14201E);
  static const Color textSecondary = Color(0xFF66746F);
  static const Color darkTextPrimary = Color(0xFFF0F6F4);
  static const Color darkTextSecondary = Color(0xFFA7B8B3);
}
