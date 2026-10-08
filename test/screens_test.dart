// Renders app screens to PNG in light and dark mode for visual review.
//
//   flutter test test/screens_test.dart                  (all screens)
//   SCREENS=home,water flutter test test/screens_test.dart
//
// Output: .impeccable/review/screens/<name>_<light|dark>.png (git-ignored).
// Screens run against a sample profile with no backend, so remote lists show
// their empty or loading states.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vitalu/core/app_state.dart';
import 'package:vitalu/data/models.dart';
import 'package:vitalu/features/assessments/assessment_screens.dart';
import 'package:vitalu/features/auth/auth_screen.dart';
import 'package:vitalu/features/auth/registration_screens.dart';
import 'package:vitalu/features/blood/blood_upload_screen.dart';
import 'package:vitalu/features/diet/budget_screen.dart';
import 'package:vitalu/features/diet/diet_hub_screen.dart';
import 'package:vitalu/features/diet/diversity_screen.dart';
import 'package:vitalu/features/diet/meal_counter_screen.dart';
import 'package:vitalu/features/diet/meal_log_screen.dart';
import 'package:vitalu/features/diet/meal_planner_screen.dart';
import 'package:vitalu/features/diet/nutrition_today_screen.dart';
import 'package:vitalu/features/diet/plate_screen.dart';
import 'package:vitalu/features/home/home_screen.dart';
import 'package:vitalu/features/habits/habits_screen.dart';
import 'package:vitalu/features/library/library_screen.dart';
import 'package:vitalu/features/onboarding/onboarding_screen.dart';
import 'package:vitalu/features/profile/about_screen.dart';
import 'package:vitalu/features/profile/edit_profile_screen.dart';
import 'package:vitalu/features/profile/profile_screen.dart';
import 'package:vitalu/features/progress/milestones_screen.dart';
import 'package:vitalu/features/progress/notifications_screen.dart';
import 'package:vitalu/features/progress/progress_screen.dart';
import 'package:vitalu/features/support/help_screen.dart';
import 'package:vitalu/features/support/professionals_screen.dart';
import 'package:vitalu/features/tools/activity_screen.dart';
import 'package:vitalu/features/tools/bmi_screen.dart';
import 'package:vitalu/features/tools/cycle_screen.dart';
import 'package:vitalu/features/tools/heart_risk_screen.dart';
import 'package:vitalu/features/tools/screen_time_screen.dart';
import 'package:vitalu/features/tools/sleep_screen.dart';
import 'package:vitalu/features/tools/stress_screen.dart';
import 'package:vitalu/features/tools/tools_screen.dart';
import 'package:vitalu/features/tools/water_screen.dart';
import 'package:vitalu/features/tools/whr_screen.dart';
import 'package:vitalu/ui/theme.dart';
import 'package:vitalu/ui/tokens.dart';

final _sample = <String, dynamic>{
  'id': '00000000-0000-0000-0000-000000000001',
  'full_name': 'Nimal Perera',
  'email': 'nimal@agri.pdn.ac.lk',
  'sex': 'male',
  'date_of_birth': '2003-05-14',
  'faculty': 'Faculty of Agriculture',
  'academic_year': '23/24 Batch',
  'registration_number': 'AG/21/045',
  'name_with_initials': 'N.H. Perera',
  'username': 'nimalperera',
  'height_cm': 172,
  'weight_kg': 64,
  'waist_cm': 78,
  'hip_cm': 94,
  'measured_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
  'health_conditions': ['asthma_allergies', 'migraine'],
  'allergies': ['Penicillin'],
  'medications': [
    {'name': 'Vitamin D3'}
  ],
  'family_history': [
    {'relation': 'Father', 'condition': 'High blood pressure'}
  ],
  'water_goal_ml': 2300,
  'sleep_goal_hours': 8,
  'step_goal': 8000,
  'onboarding_completed': true,
  'registration_step': 4,
};

final _screens = <String, Widget Function()>{
  'splash_onboarding': () => const OnboardingScreen(),
  'auth_create': () => const AuthScreen(),
  'auth_login': () => const AuthScreen(login: true),
  'register1': () => const RegistrationStep1(),
  'register2': () => const RegistrationStep2(),
  'register3': () => const RegistrationStep3(),
  'register_done': () => const RegistrationComplete(),
  'home': () => const HomeScreen(),
  'assessments': () => const AssessmentsStatusScreen(),
  'assessment_run': () => const AssessmentRunScreen(),
  'assessment_complete': () => const AssessmentCompleteScreen(assessment: null),
  'tools': () => const ToolsScreen(),
  'bmi': () => const BmiScreen(),
  'whr': () => const WhrScreen(),
  'heart_risk': () => const HeartRiskScreen(),
  'water': () => const WaterScreen(),
  'stress': () => const StressScreen(),
  'activity': () => const ActivityScreen(),
  'sleep': () => const SleepScreen(),
  'cycle': () => const CycleScreen(),
  'screen_time': () => const ScreenTimeScreen(),
  'diet': () => const DietHubScreen(),
  'meal_log': () => const MealLogScreen(),
  'meal_counter': () => const MealCounterScreen(),
  'diversity': () => const DiversityScreen(),
  'plate': () => const PlateScreen(),
  'planner': () => const MealPlannerScreen(),
  'budget': () => const BudgetScreen(),
  'nutrition_today': () => const NutritionTodayScreen(),
  'progress': () => const ProgressScreen(),
  'milestones': () => const MilestonesScreen(),
  'notifications': () => const NotificationsScreen(),
  'habits': () => const HabitsScreen(),
  'library': () => const LibraryScreen(),
  'blood_upload': () => const BloodUploadScreen(),
  'profile': () => const ProfileScreen(),
  'edit_profile': () => const EditProfileScreen(),
  'about': () => const AboutScreen(),
  'professionals': () => const ProfessionalsScreen(),
  'help': () => const HelpScreen(),
};

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  final filter = Platform.environment['SCREENS']?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
  const size = Size(390, 1500);
  const dpr = 2.0;

  setUpAll(() async {
    const mf = 'C:/src/flutter/bin/cache/artifacts/material_fonts';
    await _font('Roboto', ['$mf/roboto-light.ttf', '$mf/roboto-regular.ttf', '$mf/roboto-medium.ttf', '$mf/roboto-bold.ttf']);
    await _font('Manrope', [for (final w in [400, 500, 600, 700, 800]) 'assets/fonts/Manrope-$w.ttf']);
    final sym = '${Platform.environment['LOCALAPPDATA']}/Pub/Cache/hosted/pub.dev/material_symbols_icons-4.2960.0/lib/fonts';
    await _font('packages/material_symbols_icons/MaterialSymbolsRounded', ['$sym/MaterialSymbolsRounded.ttf']);
    await initializeDateFormatting('en');
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(url: 'https://example.supabase.co', anonKey: 'test-key');
    } catch (_) {}
  });

  for (final entry in _screens.entries) {
    if (filter != null && !filter.contains(entry.key)) continue;
    for (final dark in [false, true]) {
      testWidgets('${entry.key} ${dark ? 'dark' : 'light'}', (tester) async {
        AppColors.isDark = dark;
        AppState.instance.profile = Profile(Map.of(_sample));
        tester.view.physicalSize = size * dpr;
        tester.view.devicePixelRatio = dpr;
        tester.view.padding = const FakeViewPadding(top: 24 * dpr, bottom: 16 * dpr);
        addTearDown(tester.view.reset);

        final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => entry.value())]);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildTheme(dark ? Brightness.dark : Brightness.light), routerConfig: router),
        ));
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: dpr);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final out = File('.impeccable/review/screens/${entry.key}_${dark ? 'dark' : 'light'}.png')..createSync(recursive: true);
          out.writeAsBytesSync(png!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        tester.takeException();
      });
    }
  }
}
