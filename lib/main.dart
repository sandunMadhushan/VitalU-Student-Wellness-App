import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_state.dart';
import 'core/config.dart';
import 'core/push.dart';
import 'core/router.dart';
import 'core/sfx.dart';
import 'ui/badge_ui.dart';
import 'ui/theme.dart';
import 'ui/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en');
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseKey);
  await AppState.instance.init();
  await AppState.instance.loadThemeMode();
  await Sfx.load();
  await Push.init();
  runApp(const VitalUApp());
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
        // AppColors is a set of global (non-context) getters, see ui/tokens.dart,
        // so flipping it requires forcing every widget below to rebuild from
        // scratch. We do that with a KeyedSubtree keyed on the resolved
        // brightness, which fully remounts the page content on change.
        AppColors.isDark = resolved == Brightness.dark;
        final dark = resolved == Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: resolved,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp.router(
          title: 'VitalU',
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
          themeMode: ThemeMode.light,
          theme: buildTheme(resolved),
          builder: (context, child) => KeyedSubtree(
            key: ValueKey(resolved),
            child: BadgeCelebrationHost(navigatorKey: rootNavigatorKey, child: child!),
          ),
        );
      },
    );
  }
}
