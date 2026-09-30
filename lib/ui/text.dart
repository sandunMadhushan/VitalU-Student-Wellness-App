import 'package:flutter/material.dart';

import 'tokens.dart';

/// Type scale, set in Manrope (bundled). Headings and numbers use the heavy
/// cuts with tight tracking; body copy stays at regular/medium weight.
class T {
  T._();

  /// Brand face. Bundled in assets/fonts and declared in pubspec.yaml.
  static String? family = 'Manrope';

  static TextStyle _b(double size, double lh, FontWeight w, [double ls = 0]) => TextStyle(
        fontFamily: family,
        fontSize: size,
        height: lh / size,
        fontWeight: w,
        letterSpacing: ls,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineXl => _b(32, 38, FontWeight.w800, -0.9);
  static TextStyle get headlineXlMobile => _b(28, 34, FontWeight.w800, -0.7);
  static TextStyle get headlineLg => _b(24, 30, FontWeight.w800, -0.5);
  static TextStyle get headlineMd => _b(19, 25, FontWeight.w700, -0.3);
  static TextStyle get headlineSm => _b(16, 22, FontWeight.w700, -0.15);
  static TextStyle get bodyLg => _b(15.5, 22, FontWeight.w500, -0.1);
  static TextStyle get bodyMd => _b(14.5, 21, FontWeight.w500, -0.05);
  static TextStyle get bodySm => _b(12.5, 17, FontWeight.w500);
  static TextStyle get labelLg => _b(15, 20, FontWeight.w600, -0.1);
  static TextStyle get labelMd => _b(13, 18, FontWeight.w600);
  static TextStyle get labelSm => _b(11.5, 15, FontWeight.w600, 0.1);

  /// Large metric numbers, with tabular figures so values don't jitter.
  static TextStyle metric(double size, {FontWeight weight = FontWeight.w800}) =>
      _b(size, size * 1.08, weight, -size * 0.035).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle custom(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height, double? spacing}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.onSurface,
        height: height,
        letterSpacing: spacing,
      );
}

extension TextStyleX on TextStyle {
  TextStyle c(Color color) => copyWith(color: color);
  TextStyle w(FontWeight weight) => copyWith(fontWeight: weight);
  TextStyle s(double size) => copyWith(fontSize: size);
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
  TextStyle get semi => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get upper => copyWith(letterSpacing: 0.4);
  TextStyle get tnum => copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  TextStyle tracking(double v) => copyWith(letterSpacing: v);
  TextStyle lh(double v) => copyWith(height: v);
}
