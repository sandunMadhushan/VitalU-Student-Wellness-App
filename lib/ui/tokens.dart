import 'package:flutter/material.dart';

/// One full set of colour roles for either appearance.
///
/// The legacy role names (primaryFixed, butterWash, ...) are kept so every
/// screen keeps compiling; their values now follow the neutral, data-first
/// system: grouped grey background, flat cards, one brand tint taken from the
/// app icon's leaf, and a fixed colour per health category.
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
    required this.primaryFixedDim,
    required this.onPrimaryFixedVariant,
    required this.secondaryFixedDim,
    required this.onSecondaryFixedVariant,
    required this.tertiaryFixedDim,
    required this.onTertiaryFixedVariant,
    required this.warning,
    required this.warningContainer,
    required this.water,
    required this.activity,
    required this.sleep,
    required this.nutrition,
    required this.heart,
    required this.mind,
    required this.cycle,
    required this.body,
    required this.tintAlpha,
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
  final Color primaryFixedDim;
  final Color onPrimaryFixedVariant;
  final Color secondaryFixedDim;
  final Color onSecondaryFixedVariant;
  final Color tertiaryFixedDim;
  final Color onTertiaryFixedVariant;
  final Color warning;
  final Color warningContainer;
  final Color water;
  final Color activity;
  final Color sleep;
  final Color nutrition;
  final Color heart;
  final Color mind;
  final Color cycle;
  final Color body;

  /// Opacity of a category colour when used as a soft fill behind its icon.
  final double tintAlpha;
}

const _light = _Palette(
  surface: Color(0xFFF8F5FD),
  surfaceDim: Color(0xFFEAE6F2),
  surfaceBright: Color(0xFFFFFFFF),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF3EFFA),
  surfaceContainer: Color(0xFFEDE9F5),
  surfaceContainerHigh: Color(0xFFE6E2F0),
  surfaceContainerHighest: Color(0xFFDDD8E8),
  onSurface: Color(0xFF111317),
  onSurfaceVariant: Color(0xFF5B5768),
  inverseSurface: Color(0xFF212429),
  inverseOnSurface: Color(0xFFF1F3F5),
  outline: Color(0xFF8B8699),
  outlineVariant: Color(0xFFE4DFEE),
  primary: Color(0xFF0B7A63),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD5EFE7),
  onPrimaryContainer: Color(0xFF053D31),
  inversePrimary: Color(0xFF5FD3B4),
  secondary: Color(0xFFCC2F55),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFFCE3E9),
  onSecondaryContainer: Color(0xFF6B0F27),
  tertiary: Color(0xFF1E8541),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFDDF2E3),
  onTertiaryContainer: Color(0xFF0B3D1A),
  error: Color(0xFFC62828),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFDE8E7),
  onErrorContainer: Color(0xFF7A1111),
  primaryFixedDim: Color(0xFFA6DFCD),
  onPrimaryFixedVariant: Color(0xFF0A5E4C),
  secondaryFixedDim: Color(0xFFF5B7C6),
  onSecondaryFixedVariant: Color(0xFFA0183C),
  tertiaryFixedDim: Color(0xFFA9DCB7),
  onTertiaryFixedVariant: Color(0xFF15662F),
  warning: Color(0xFFA35C00),
  warningContainer: Color(0xFFFFF0D9),
  water: Color(0xFF1A6FE0),
  activity: Color(0xFFE0590F),
  sleep: Color(0xFF5552D1),
  nutrition: Color(0xFF2E8F42),
  heart: Color(0xFFD1344E),
  mind: Color(0xFF7C4DD6),
  cycle: Color(0xFFD13C78),
  body: Color(0xFF0B7A63),
  tintAlpha: 0.12,
);

const _dark = _Palette(
  surface: Color(0xFF0F0E13),
  surfaceDim: Color(0xFF0F0E13),
  surfaceBright: Color(0xFF2D2C35),
  surfaceContainerLowest: Color(0xFF1A1920),
  surfaceContainerLow: Color(0xFF201F27),
  surfaceContainer: Color(0xFF26252D),
  surfaceContainerHigh: Color(0xFF2E2D36),
  surfaceContainerHighest: Color(0xFF393842),
  onSurface: Color(0xFFF1F3F5),
  onSurfaceVariant: Color(0xFFABA7B8),
  inverseSurface: Color(0xFFE8EAED),
  inverseOnSurface: Color(0xFF1B1D20),
  outline: Color(0xFF817D8F),
  outlineVariant: Color(0xFF2F2D38),
  primary: Color(0xFF4FD1B0),
  onPrimary: Color(0xFF00382C),
  primaryContainer: Color(0xFF12392F),
  onPrimaryContainer: Color(0xFFB4EFDE),
  inversePrimary: Color(0xFF0B7A63),
  secondary: Color(0xFFFF7D97),
  onSecondary: Color(0xFF4A0718),
  secondaryContainer: Color(0xFF45172A),
  onSecondaryContainer: Color(0xFFFFD9E1),
  tertiary: Color(0xFF63D385),
  onTertiary: Color(0xFF00391A),
  tertiaryContainer: Color(0xFF153B22),
  onTertiaryContainer: Color(0xFFBAF0C9),
  error: Color(0xFFFF6E66),
  onError: Color(0xFF410002),
  errorContainer: Color(0xFF481716),
  onErrorContainer: Color(0xFFFFDAD6),
  primaryFixedDim: Color(0xFF1C5A4B),
  onPrimaryFixedVariant: Color(0xFF7FE0C6),
  secondaryFixedDim: Color(0xFF6B2233),
  onSecondaryFixedVariant: Color(0xFFFFB0C2),
  tertiaryFixedDim: Color(0xFF1D5A33),
  onTertiaryFixedVariant: Color(0xFF87E0A3),
  warning: Color(0xFFF2B54A),
  warningContainer: Color(0xFF3A2C10),
  water: Color(0xFF63A2FF),
  activity: Color(0xFFFF8A4D),
  sleep: Color(0xFF9B98FF),
  nutrition: Color(0xFF5CCB77),
  heart: Color(0xFFFF7A90),
  mind: Color(0xFFB596FF),
  cycle: Color(0xFFFF7AAD),
  body: Color(0xFF4FD1B0),
  tintAlpha: 0.18,
);

/// Colour tokens. They resolve to the light or dark palette depending on
/// [AppColors.isDark], which the app root keeps in sync with the user's
/// light/dark/system choice (see `VitalUApp` in main.dart, which remounts the
/// tree when it flips).
class AppColors {
  AppColors._();

  static bool isDark = false;
  static _Palette get _p => isDark ? _dark : _light;

  // Neutral surfaces, in order of elevation: page ground, then cards.
  static Color get surface => _p.surface;
  static Color get background => _p.surface;
  static Color get surfaceDim => _p.surfaceDim;
  static Color get surfaceBright => _p.surfaceBright;
  static Color get surfaceContainerLowest => _p.surfaceContainerLowest;
  static Color get surfaceContainerLow => _p.surfaceContainerLow;
  static Color get surfaceContainer => _p.surfaceContainer;
  static Color get surfaceContainerHigh => _p.surfaceContainerHigh;
  static Color get surfaceContainerHighest => _p.surfaceContainerHighest;
  static Color get surfaceVariant => _p.surfaceContainerHighest;
  static Color get inputFill => _p.surfaceContainer;

  static Color get onSurface => _p.onSurface;
  static Color get onSurfaceVariant => _p.onSurfaceVariant;
  static Color get outline => _p.outline;
  static Color get outlineVariant => _p.outlineVariant;
  static Color get inverseSurface => _p.inverseSurface;
  static Color get inverseOnSurface => _p.inverseOnSurface;
  static Color get charcoal => _p.onSurface;
  static Color get slate => _p.onSurfaceVariant;
  static Color get shadowTint => const Color(0xFF000000);

  static Color get primary => _p.primary;
  static Color get surfaceTint => _p.primary;
  static Color get onPrimary => _p.onPrimary;
  static Color get primaryContainer => _p.primaryContainer;
  static Color get onPrimaryContainer => _p.onPrimaryContainer;
  static Color get inversePrimary => _p.inversePrimary;
  static Color get lavenderInteractive => _p.primary;

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
  static Color get warning => _p.warning;
  static Color get warningContainer => _p.warningContainer;

  // Legacy "fixed" roles are soft tinted fills plus their readable foreground.
  static Color get primaryFixed => _p.primaryContainer;
  static Color get primaryFixedDim => _p.primaryFixedDim;
  static Color get onPrimaryFixed => _p.onPrimaryContainer;
  static Color get onPrimaryFixedVariant => _p.onPrimaryFixedVariant;
  static Color get secondaryFixed => _p.secondaryContainer;
  static Color get secondaryFixedDim => _p.secondaryFixedDim;
  static Color get onSecondaryFixed => _p.onSecondaryContainer;
  static Color get onSecondaryFixedVariant => _p.onSecondaryFixedVariant;
  static Color get tertiaryFixed => _p.tertiaryContainer;
  static Color get tertiaryFixedDim => _p.tertiaryFixedDim;
  static Color get onTertiaryFixed => _p.onTertiaryContainer;
  static Color get onTertiaryFixedVariant => _p.onTertiaryFixedVariant;

  // Health categories. Each metric keeps its colour on every screen.
  static Color get water => _p.water;
  static Color get activity => _p.activity;
  static Color get sleep => _p.sleep;
  static Color get nutrition => _p.nutrition;
  static Color get heart => _p.heart;
  static Color get mind => _p.mind;
  static Color get cycle => _p.cycle;
  static Color get body => _p.body;

  /// Soft fill of a category colour, for the tile behind its icon.
  static Color tint(Color c) => c.withValues(alpha: _p.tintAlpha);

  // Legacy wash/accent names, mapped onto categories.
  static Color get lavenderWash => tint(_p.mind);
  static Color get pinkAccent => _p.cycle;
  static Color get pinkWash => tint(_p.cycle);
  static Color get mintAccent => _p.nutrition;
  static Color get mintWash => tint(_p.nutrition);
  static Color get skyAccent => _p.water;
  static Color get skyWash => tint(_p.water);
  static Color get butterAccent => _p.warning;
  static Color get butterWash => _p.warningContainer;
}

/// Spacing scale on a 4pt grid.
class Sp {
  Sp._();
  static const double margin = 16;
  static const double gutter = 12;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner radii. Cards stay at 12-16; full rounding is for small controls.
class Rad {
  Rad._();
  static const double sm = 8;
  static const double base = 12;
  static const double r2xl = 12;
  static const double r3xl = 16;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 24;
  static const double full = 999;
}

/// Cards use one soft, two-layer shadow in light mode (see VCard); dark mode
/// relies on surface tiers. The other presets are kept empty for old call sites.
class Shadows {
  Shadows._();
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -6),
    BoxShadow(color: Color(0x0D101828), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> soft = [];
  static const List<BoxShadow> tiny = [];
  static const List<BoxShadow> floating = [];
  static List<BoxShadow> tinted(Color c, {double opacity = 0.12, double blur = 20, double y = 8, double spread = -6}) => const [];
}
