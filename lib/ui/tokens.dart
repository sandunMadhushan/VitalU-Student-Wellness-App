import 'package:flutter/material.dart';

/// Colour tokens from the "Serene Pastel Sanctuary" design system (DESIGN.md).
class AppColors {
  AppColors._();

  static const surface = Color(0xFFFCF8FF);
  static const surfaceDim = Color(0xFFDDD7E9);
  static const surfaceBright = Color(0xFFFCF8FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF7F1FF);
  static const surfaceContainer = Color(0xFFF1EBFD);
  static const surfaceContainerHigh = Color(0xFFEBE6F7);
  static const surfaceContainerHighest = Color(0xFFE5E0F2);
  static const onSurface = Color(0xFF1C1A26);
  static const onSurfaceVariant = Color(0xFF484555);
  static const inverseSurface = Color(0xFF312F3C);
  static const inverseOnSurface = Color(0xFFF4EEFF);
  static const outline = Color(0xFF797587);
  static const outlineVariant = Color(0xFFC9C4D8);
  static const surfaceTint = Color(0xFF5D3FE0);
  static const primary = Color(0xFF5B3CDD);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF7459F7);
  static const onPrimaryContainer = Color(0xFFFFFBFF);
  static const inversePrimary = Color(0xFFC9BFFF);
  static const secondary = Color(0xFF984062);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFFD93B8);
  static const onSecondaryContainer = Color(0xFF792749);
  static const tertiary = Color(0xFF006A45);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF008558);
  static const onTertiaryContainer = Color(0xFFF6FFF6);
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);
  static const primaryFixed = Color(0xFFE5DEFF);
  static const primaryFixedDim = Color(0xFFC9BFFF);
  static const onPrimaryFixed = Color(0xFF1A0063);
  static const onPrimaryFixedVariant = Color(0xFF441CC8);
  static const secondaryFixed = Color(0xFFFFD9E3);
  static const secondaryFixedDim = Color(0xFFFFB0C9);
  static const onSecondaryFixed = Color(0xFF3E001E);
  static const onSecondaryFixedVariant = Color(0xFF7B294A);
  static const tertiaryFixed = Color(0xFF7EFABC);
  static const tertiaryFixedDim = Color(0xFF60DDA2);
  static const onTertiaryFixed = Color(0xFF002112);
  static const onTertiaryFixedVariant = Color(0xFF005234);
  static const background = Color(0xFFFCF8FF);
  static const surfaceVariant = Color(0xFFE5E0F2);

  // Auxiliary washes from DESIGN.md
  static const charcoal = Color(0xFF2D2B38);
  static const slate = Color(0xFF787389);
  static const lavenderInteractive = Color(0xFF7B61FF);
  static const lavenderWash = Color(0xFFE8DEFF);
  static const pinkAccent = Color(0xFFFF94B9);
  static const pinkWash = Color(0xFFFFDEEB);
  static const mintAccent = Color(0xFF48C78E);
  static const mintWash = Color(0xFFD1F4E0);
  static const skyWash = Color(0xFFD7EEFF);
  static const skyAccent = Color(0xFF4BA3E3);
  static const butterWash = Color(0xFFFFF4CC);
  static const butterAccent = Color(0xFFD4A017);
  static const inputFill = Color(0xFFF4F2F8);
}

/// Spacing scale (px) from the tailwind config.
class Sp {
  Sp._();
  static const double margin = 20;
  static const double gutter = 16;
  static const double xs = 6;
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 40;
}

/// Radius scale. Tailwind overrides: DEFAULT 1rem, lg 2rem, xl 3rem.
class Rad {
  Rad._();
  static const double sm = 8;
  static const double base = 16; // `rounded`
  static const double r2xl = 16; // tailwind rounded-2xl
  static const double r3xl = 24; // tailwind rounded-3xl
  static const double md = 24;
  static const double lg = 32; // `rounded-lg`
  static const double xl = 48; // `rounded-xl`
  static const double full = 999;
}

class Shadows {
  Shadows._();
  static List<BoxShadow> card = const [
    BoxShadow(color: Color(0x0F2D2B38), blurRadius: 32, offset: Offset(0, 12), spreadRadius: -8),
    BoxShadow(color: Color(0x0A7B61FF), blurRadius: 12, offset: Offset(0, 4), spreadRadius: -2),
  ];
  static List<BoxShadow> soft = const [
    BoxShadow(color: Color(0x0F2D2B38), blurRadius: 28, offset: Offset(0, 10), spreadRadius: -6),
  ];
  static List<BoxShadow> tiny = const [
    BoxShadow(color: Color(0x0F2D2B38), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static List<BoxShadow> floating = const [
    BoxShadow(color: Color(0x1F2D2B38), blurRadius: 48, offset: Offset(0, 20), spreadRadius: -12),
  ];
  static List<BoxShadow> tinted(Color c, {double opacity = 0.12, double blur = 20, double y = 8, double spread = -6}) => [
        BoxShadow(color: c.withValues(alpha: opacity), blurRadius: blur, offset: Offset(0, y), spreadRadius: spread),
      ];
}
