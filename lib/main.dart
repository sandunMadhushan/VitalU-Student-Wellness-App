import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_state.dart';
import 'core/config.dart';
import 'core/router.dart';
import 'ui/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en');
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseKey);
  await AppState.instance.init();
  await AppState.instance.loadThemeMode();
  runApp(const VitalUApp());
}

/// Builds a Material theme for the given brightness from the current
/// [AppColors] palette (light or dark — [AppColors.isDark] must already be
/// set to match before calling this).
ThemeData _buildTheme(Brightness brightness) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: AppColors.onSurface, displayColor: AppColors.onSurface),
    datePickerTheme: DatePickerThemeData(backgroundColor: AppColors.surface),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

class VitalUApp extends StatelessWidget {
  const VitalUApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final resolved = switch (AppState.instance.themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => platformBrightness,
        };
        // AppColors is a set of global (non-context) getters — see ui/tokens.dart —
        // so flipping it requires forcing every widget below to rebuild from
        // scratch. We do that with a KeyedSubtree keyed on the resolved
        // brightness, which fully remounts the page content on change.
        AppColors.isDark = resolved == Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: resolved == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: resolved,
          systemNavigationBarColor: AppColors.surface,
          systemNavigationBarIconBrightness: resolved == Brightness.dark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp.router(
          title: 'VitalU',
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
          themeMode: ThemeMode.light,
          theme: _buildTheme(resolved),
          builder: (context, child) => KeyedSubtree(key: ValueKey(resolved), child: child!),
        );
      },
    );
  }
}
