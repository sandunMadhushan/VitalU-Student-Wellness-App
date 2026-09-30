import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'text.dart';
import 'tokens.dart';

/// Material 3 theme built from the current [AppColors] palette.
/// [AppColors.isDark] must already match [brightness].
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.onTertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: AppColors.onTertiaryContainer,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    surfaceDim: AppColors.surfaceDim,
    surfaceBright: AppColors.surfaceBright,
    surfaceContainerLowest: AppColors.surfaceContainerLowest,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    surfaceContainerHighest: AppColors.surfaceContainerHighest,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    inverseSurface: AppColors.inverseSurface,
    onInverseSurface: AppColors.inverseOnSurface,
    inversePrimary: AppColors.inversePrimary,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
  var text = base.textTheme.apply(fontFamily: T.family, bodyColor: AppColors.onSurface, displayColor: AppColors.onSurface);
  // Collapsing large titles read in headlineSmall; give them real weight.
  text = text.copyWith(
    headlineSmall: text.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
    headlineMedium: text.headlineMedium?.copyWith(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1.0),
  );
  const pill = StadiumBorder();
  const buttonSize = Size(64, 52);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surface,
    canvasColor: AppColors.surface,
    textTheme: text,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    iconTheme: IconThemeData(color: AppColors.onSurfaceVariant, size: 24, weight: 400, opticalSize: 24),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.onSurface, size: 24),
      actionsIconTheme: IconThemeData(color: AppColors.onSurface, size: 24),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
    ),
    dividerTheme: DividerThemeData(color: AppColors.outlineVariant, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.onSurfaceVariant,
      titleTextStyle: T.bodyLg,
      subtitleTextStyle: T.bodySm.c(AppColors.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: Sp.md),
      minVerticalPadding: 10,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: buttonSize, shape: pill, textStyle: T.labelLg.w(FontWeight.w700)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(minimumSize: buttonSize, shape: pill, elevation: 0, textStyle: T.labelLg.w(FontWeight.w700)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: pill,
        foregroundColor: AppColors.onSurface,
        side: BorderSide(color: AppColors.outline.withValues(alpha: 0.45)),
        textStyle: T.labelLg.w(FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 44), foregroundColor: AppColors.primary, textStyle: T.labelLg.w(FontWeight.w700), shape: pill),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(44, 44))),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surfaceContainerLowest,
        foregroundColor: AppColors.onSurfaceVariant,
        selectedBackgroundColor: AppColors.primaryContainer,
        selectedForegroundColor: AppColors.onPrimaryContainer,
        side: BorderSide(color: AppColors.outlineVariant),
        textStyle: T.labelMd,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceContainerLowest,
      selectedColor: AppColors.primaryContainer,
      labelStyle: T.labelMd,
      side: BorderSide(color: AppColors.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill,
      hintStyle: T.bodyLg.c(AppColors.outline),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.base), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.base), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.base), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.base), borderSide: BorderSide(color: AppColors.error, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.base), borderSide: BorderSide(color: AppColors.error, width: 1.5)),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : AppColors.outline),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.surfaceContainerHigh,
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withValues(alpha: 0.12),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.primary, linearTrackColor: AppColors.surfaceContainerHigh, circularTrackColor: Colors.transparent),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: AppColors.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => T.labelSm.c(s.contains(WidgetState.selected) ? AppColors.onSurface : AppColors.onSurfaceVariant)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.surfaceContainerLowest,
      showDragHandle: true,
      dragHandleColor: AppColors.outlineVariant,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xl)),
      titleTextStyle: T.headlineSm,
      contentTextStyle: T.bodyMd.c(AppColors.onSurfaceVariant),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.inverseSurface,
      contentTextStyle: T.bodyMd.c(AppColors.inverseOnSurface),
      actionTextColor: AppColors.inversePrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.base)),
    ),
    datePickerTheme: DatePickerThemeData(backgroundColor: AppColors.surfaceContainerLowest, surfaceTintColor: Colors.transparent),
    timePickerTheme: TimePickerThemeData(backgroundColor: AppColors.surfaceContainerLowest),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
