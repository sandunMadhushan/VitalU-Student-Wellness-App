import 'package:flutter/material.dart';

/// One full set of colour roles, either the light or dark side of the
/// "Serene Pastel Sanctuary" design system (DESIGN.md).
class _Palette {
  const _Palette({
    required this.surface,
    required this.surfaceDim,
    required this.surfaceBright,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.inverseSurface,
    required this.inverseOnSurface,
    required this.outline,
    required this.outlineVariant,
    required this.surfaceTint,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.inversePrimary,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.primaryFixed,
    required this.primaryFixedDim,
    required this.onPrimaryFixed,
    required this.onPrimaryFixedVariant,
    required this.secondaryFixed,
    required this.secondaryFixedDim,
    required this.onSecondaryFixed,
    required this.onSecondaryFixedVariant,
    required this.tertiaryFixed,
    required this.tertiaryFixedDim,
    required this.onTertiaryFixed,
    required this.onTertiaryFixedVariant,
    required this.background,
    required this.surfaceVariant,
    required this.charcoal,
    required this.slate,
    required this.lavenderInteractive,
    required this.lavenderWash,
    required this.pinkAccent,
    required this.pinkWash,
    required this.mintAccent,
    required this.mintWash,
    required this.skyWash,
    required this.skyAccent,
    required this.butterWash,
    required this.butterAccent,
    required this.inputFill,
    required this.shadowTint,
  });

  final Color surface;
  final Color surfaceDim;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color inverseSurface;
  final Color inverseOnSurface;
  final Color outline;
  final Color outlineVariant;
  final Color surfaceTint;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color inversePrimary;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color primaryFixed;
  final Color primaryFixedDim;
  final Color onPrimaryFixed;
  final Color onPrimaryFixedVariant;
  final Color secondaryFixed;
  final Color secondaryFixedDim;
  final Color onSecondaryFixed;
  final Color onSecondaryFixedVariant;
  final Color tertiaryFixed;
  final Color tertiaryFixedDim;
  final Color onTertiaryFixed;
  final Color onTertiaryFixedVariant;
  final Color background;
  final Color surfaceVariant;
  final Color charcoal;
  final Color slate;
  final Color lavenderInteractive;
  final Color lavenderWash;
  final Color pinkAccent;
  final Color pinkWash;
  final Color mintAccent;
  final Color mintWash;
  final Color skyWash;
  final Color skyAccent;
  final Color butterWash;
  final Color butterAccent;
  final Color inputFill;
  final Color shadowTint;
}

const _light = _Palette(
  surface: Color(0xFFFCF8FF),
  surfaceDim: Color(0xFFDDD7E9),
  surfaceBright: Color(0xFFFCF8FF),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF7F1FF),
  surfaceContainer: Color(0xFFF1EBFD),
  surfaceContainerHigh: Color(0xFFEBE6F7),
  surfaceContainerHighest: Color(0xFFE5E0F2),
  onSurface: Color(0xFF1C1A26),
  onSurfaceVariant: Color(0xFF484555),
  inverseSurface: Color(0xFF312F3C),
  inverseOnSurface: Color(0xFFF4EEFF),
  outline: Color(0xFF797587),
  outlineVariant: Color(0xFFC9C4D8),
  surfaceTint: Color(0xFF5D3FE0),
  primary: Color(0xFF5B3CDD),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFF7459F7),
  onPrimaryContainer: Color(0xFFFFFBFF),
  inversePrimary: Color(0xFFC9BFFF),
  secondary: Color(0xFF984062),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFFD93B8),
  onSecondaryContainer: Color(0xFF792749),
  tertiary: Color(0xFF006A45),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFF008558),
  onTertiaryContainer: Color(0xFFF6FFF6),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF93000A),
  primaryFixed: Color(0xFFE5DEFF),
  primaryFixedDim: Color(0xFFC9BFFF),
  onPrimaryFixed: Color(0xFF1A0063),
  onPrimaryFixedVariant: Color(0xFF441CC8),
  secondaryFixed: Color(0xFFFFD9E3),
  secondaryFixedDim: Color(0xFFFFB0C9),
  onSecondaryFixed: Color(0xFF3E001E),
  onSecondaryFixedVariant: Color(0xFF7B294A),
  tertiaryFixed: Color(0xFF7EFABC),
  tertiaryFixedDim: Color(0xFF60DDA2),
  onTertiaryFixed: Color(0xFF002112),
  onTertiaryFixedVariant: Color(0xFF005234),
  background: Color(0xFFFCF8FF),
  surfaceVariant: Color(0xFFE5E0F2),
  charcoal: Color(0xFF2D2B38),
  slate: Color(0xFF787389),
  lavenderInteractive: Color(0xFF7B61FF),
  lavenderWash: Color(0xFFE8DEFF),
  pinkAccent: Color(0xFFFF94B9),
  pinkWash: Color(0xFFFFDEEB),
  mintAccent: Color(0xFF48C78E),
  mintWash: Color(0xFFD1F4E0),
  skyWash: Color(0xFFD7EEFF),
  skyAccent: Color(0xFF4BA3E3),
  butterWash: Color(0xFFFFF4CC),
  butterAccent: Color(0xFFD4A017),
  inputFill: Color(0xFFF4F2F8),
  shadowTint: Color(0xFF2D2B38),
);

/// Dark side of the palette. Several roles reuse the "fixed"/"inverse" tones
/// already produced by the Material tonal palette generator for the light
/// scheme, since those are (by construction) the correct dark-scheme values.
const _dark = _Palette(
  surface: Color(0xFF141218),
  surfaceDim: Color(0xFF141218),
  surfaceBright: Color(0xFF3B383E),
  surfaceContainerLowest: Color(0xFF0F0D13),
  surfaceContainerLow: Color(0xFF1D1B20),
  surfaceContainer: Color(0xFF211F26),
  surfaceContainerHigh: Color(0xFF2B2930),
  surfaceContainerHighest: Color(0xFF36343B),
  onSurface: Color(0xFFE6E0E9),
  onSurfaceVariant: Color(0xFFCBC4D0),
  inverseSurface: Color(0xFFE6E0E9),
  inverseOnSurface: Color(0xFF322F35),
  outline: Color(0xFF948F99),
  outlineVariant: Color(0xFF49454E),
  surfaceTint: Color(0xFFC9BFFF),
  primary: Color(0xFFC9BFFF),
  onPrimary: Color(0xFF2A1264),
  primaryContainer: Color(0xFF4B33B8),
  onPrimaryContainer: Color(0xFFE4DEFF),
  inversePrimary: Color(0xFF5B3CDD),
  secondary: Color(0xFFFFB0C9),
  onSecondary: Color(0xFF5C1132),
  secondaryContainer: Color(0xFF7B294A),
  onSecondaryContainer: Color(0xFFFFD9E3),
  tertiary: Color(0xFF60DDA2),
  onTertiary: Color(0xFF00391F),
  tertiaryContainer: Color(0xFF005234),
  onTertiaryContainer: Color(0xFF7EFABC),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  primaryFixed: Color(0xFFE5DEFF),
  primaryFixedDim: Color(0xFFC9BFFF),
  onPrimaryFixed: Color(0xFF1A0063),
  onPrimaryFixedVariant: Color(0xFF441CC8),
  secondaryFixed: Color(0xFFFFD9E3),
  secondaryFixedDim: Color(0xFFFFB0C9),
  onSecondaryFixed: Color(0xFF3E001E),
  onSecondaryFixedVariant: Color(0xFF7B294A),
  tertiaryFixed: Color(0xFF7EFABC),
  tertiaryFixedDim: Color(0xFF60DDA2),
  onTertiaryFixed: Color(0xFF002112),
  onTertiaryFixedVariant: Color(0xFF005234),
  background: Color(0xFF141218),
  surfaceVariant: Color(0xFF49454E),
  charcoal: Color(0xFF000000),
  slate: Color(0xFF9791A6),
  lavenderInteractive: Color(0xFF9A85FF),
  lavenderWash: Color(0xFF2C2650),
  pinkAccent: Color(0xFFFFA8C8),
  pinkWash: Color(0xFF3A2430),
  mintAccent: Color(0xFF5FDA9F),
  mintWash: Color(0xFF1C3A2B),
  skyWash: Color(0xFF17293A),
  skyAccent: Color(0xFF6BB8F0),
  butterWash: Color(0xFF3A331A),
  butterAccent: Color(0xFFE8B93A),
  inputFill: Color(0xFF232029),
  shadowTint: Color(0xFF000000),
);

/// Colour tokens from the "Serene Pastel Sanctuary" design system (DESIGN.md).
///
/// These resolve to either [_light] or [_dark] depending on [AppColors.isDark],
/// which the app root keeps in sync with the user's light/dark/system choice.
/// Because that flag is global (not read from [BuildContext]), switching it
/// requires forcing a full rebuild of the widget subtree below `MaterialApp`
/// (see `VitalUApp` in main.dart) for every widget to pick up the new colours.
class AppColors {
  AppColors._();

  static bool isDark = false;
  static _Palette get _p => isDark ? _dark : _light;

  static Color get surface => _p.surface;
  static Color get surfaceDim => _p.surfaceDim;
  static Color get surfaceBright => _p.surfaceBright;
  static Color get surfaceContainerLowest => _p.surfaceContainerLowest;
  static Color get surfaceContainerLow => _p.surfaceContainerLow;
  static Color get surfaceContainer => _p.surfaceContainer;
  static Color get surfaceContainerHigh => _p.surfaceContainerHigh;
  static Color get surfaceContainerHighest => _p.surfaceContainerHighest;
  static Color get onSurface => _p.onSurface;
  static Color get onSurfaceVariant => _p.onSurfaceVariant;
  static Color get inverseSurface => _p.inverseSurface;
  static Color get inverseOnSurface => _p.inverseOnSurface;
  static Color get outline => _p.outline;
  static Color get outlineVariant => _p.outlineVariant;
  static Color get surfaceTint => _p.surfaceTint;
  static Color get primary => _p.primary;
  static Color get onPrimary => _p.onPrimary;
  static Color get primaryContainer => _p.primaryContainer;
  static Color get onPrimaryContainer => _p.onPrimaryContainer;
  static Color get inversePrimary => _p.inversePrimary;
  static Color get secondary => _p.secondary;
  static Color get onSecondary => _p.onSecondary;
  static Color get secondaryContainer => _p.secondaryContainer;
  static Color get onSecondaryContainer => _p.onSecondaryContainer;
  static Color get tertiary => _p.tertiary;
  static Color get onTertiary => _p.onTertiary;
  static Color get tertiaryContainer => _p.tertiaryContainer;
  static Color get onTertiaryContainer => _p.onTertiaryContainer;
  static Color get error => _p.error;
  static Color get onError => _p.onError;
  static Color get errorContainer => _p.errorContainer;
  static Color get onErrorContainer => _p.onErrorContainer;
  static Color get primaryFixed => _p.primaryFixed;
  static Color get primaryFixedDim => _p.primaryFixedDim;
  static Color get onPrimaryFixed => _p.onPrimaryFixed;
  static Color get onPrimaryFixedVariant => _p.onPrimaryFixedVariant;
  static Color get secondaryFixed => _p.secondaryFixed;
  static Color get secondaryFixedDim => _p.secondaryFixedDim;
  static Color get onSecondaryFixed => _p.onSecondaryFixed;
  static Color get onSecondaryFixedVariant => _p.onSecondaryFixedVariant;
  static Color get tertiaryFixed => _p.tertiaryFixed;
  static Color get tertiaryFixedDim => _p.tertiaryFixedDim;
  static Color get onTertiaryFixed => _p.onTertiaryFixed;
  static Color get onTertiaryFixedVariant => _p.onTertiaryFixedVariant;
  static Color get background => _p.background;
  static Color get surfaceVariant => _p.surfaceVariant;

  // Auxiliary washes from DESIGN.md
  static Color get charcoal => _p.charcoal;
  static Color get slate => _p.slate;
  static Color get lavenderInteractive => _p.lavenderInteractive;
  static Color get lavenderWash => _p.lavenderWash;
  static Color get pinkAccent => _p.pinkAccent;
  static Color get pinkWash => _p.pinkWash;
  static Color get mintAccent => _p.mintAccent;
  static Color get mintWash => _p.mintWash;
  static Color get skyWash => _p.skyWash;
  static Color get skyAccent => _p.skyAccent;
  static Color get butterWash => _p.butterWash;
  static Color get butterAccent => _p.butterAccent;
  static Color get inputFill => _p.inputFill;
  static Color get shadowTint => _p.shadowTint;
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
  static List<BoxShadow> get card => [
        BoxShadow(color: AppColors.shadowTint.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 12), spreadRadius: -8),
        BoxShadow(color: const Color(0x0A7B61FF), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -2),
      ];
  static List<BoxShadow> get soft => [
        BoxShadow(color: AppColors.shadowTint.withValues(alpha: 0.06), blurRadius: 28, offset: const Offset(0, 10), spreadRadius: -6),
      ];
  static List<BoxShadow> get tiny => [
        BoxShadow(color: AppColors.shadowTint.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
      ];
  static List<BoxShadow> get floating => [
        BoxShadow(color: AppColors.shadowTint.withValues(alpha: 0.12), blurRadius: 48, offset: const Offset(0, 20), spreadRadius: -12),
      ];
  static List<BoxShadow> tinted(Color c, {double opacity = 0.12, double blur = 20, double y = 8, double spread = -6}) => [
        BoxShadow(color: c.withValues(alpha: opacity), blurRadius: blur, offset: Offset(0, y), spreadRadius: spread),
      ];
}
