import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Typography scale (Plus Jakarta Sans) from DESIGN.md.
class T {
  T._();

  static TextStyle _b(double size, double lh, FontWeight w, [double ls = 0]) => GoogleFonts.plusJakartaSans(
        fontSize: size,
        height: lh / size,
        fontWeight: w,
        letterSpacing: ls * size,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineXl => _b(40, 48, FontWeight.w700, -0.02);
  static TextStyle get headlineXlMobile => _b(32, 40, FontWeight.w700, -0.02);
  static TextStyle get headlineLg => _b(28, 36, FontWeight.w700, -0.015);
  static TextStyle get headlineMd => _b(22, 30, FontWeight.w600, -0.01);
  static TextStyle get headlineSm => _b(18, 26, FontWeight.w600);
  static TextStyle get bodyLg => _b(17, 26, FontWeight.w400);
  static TextStyle get bodyMd => _b(15, 23, FontWeight.w400);
  static TextStyle get bodySm => _b(13, 19, FontWeight.w400);
  static TextStyle get labelLg => _b(15, 20, FontWeight.w600, 0.01);
  static TextStyle get labelMd => _b(13, 18, FontWeight.w600, 0.015);
  static TextStyle get labelSm => _b(11, 15, FontWeight.w600, 0.02);

  static TextStyle custom(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height, double? spacing}) =>
      GoogleFonts.plusJakartaSans(
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
  TextStyle get upper => copyWith(letterSpacing: 0.8);
  TextStyle tracking(double v) => copyWith(letterSpacing: v);
  TextStyle lh(double v) => copyWith(height: v);
}
