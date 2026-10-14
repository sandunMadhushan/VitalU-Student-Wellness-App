import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/assessments/assessment_screens.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/registration_screens.dart';
import '../features/blood/blood_upload_screen.dart';
import '../features/blood/report_explained_screen.dart';
import '../features/diet/budget_screen.dart';
import '../features/diet/diet_hub_screen.dart';
import '../features/diet/diversity_screen.dart';
import '../features/diet/meal_counter_screen.dart';
import '../features/diet/meal_log_screen.dart';
import '../features/diet/meal_planner_screen.dart';
import '../features/diet/nutrition_today_screen.dart';
import '../features/diet/pdqs_screen.dart';
import '../features/diet/plate_screen.dart';
import '../features/habits/habits_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/article_screen.dart';
import '../features/library/library_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/profile/about_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/progress/milestones_screen.dart';
import '../features/progress/notifications_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/support/consult_screen.dart';
import '../features/support/help_screen.dart';
import '../features/support/professionals_screen.dart';
import '../features/tools/activity_screen.dart';
import '../features/tools/bmi_screen.dart';
import '../features/tools/cycle_screen.dart';
import '../features/tools/heart_risk_screen.dart';
import '../features/tools/sleep_screen.dart';
import '../features/tools/stress_screen.dart';
import '../features/tools/tools_screen.dart';
import '../features/tools/water_screen.dart';
import '../features/tools/whr_screen.dart';
import 'app_state.dart';

/// Root navigator, also used to show app-wide pop-ups (badge celebrations).
final rootNavigatorKey = GlobalKey<NavigatorState>();

const _public = {'/', '/onboarding', '/auth/create', '/auth/login'};

Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: c),
    );

GoRoute _r(String path, Widget Function(GoRouterState s) b, {bool tab = false}) =>
    GoRoute(path: path, pageBuilder: tab ? (c, s) => _fade(s, b(s)) : null, builder: tab ? null : (c, s) => b(s));

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: AppState.instance,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    if (!AppState.instance.signedIn) return _public.contains(loc) ? null : '/auth/create';
    // Step 1 of registration is mandatory: until it is complete the only
    // screen a signed-in student can reach is step 1 itself.
    final p = AppState.instance.profile;
    if (p != null && !p.basicsComplete && loc != '/' && loc != '/register/1') return '/register/1';
    return null;
  },
  routes: [
    _r('/', (s) => const SplashScreen()),
    _r('/onboarding', (s) => const OnboardingScreen()),
    _r('/auth/create', (s) => const AuthScreen()),
    _r('/auth/login', (s) => const AuthScreen(login: true)),
    _r('/register/1', (s) => const RegistrationStep1()),
    _r('/register/2', (s) => const RegistrationStep2()),
    _r('/register/3', (s) => const RegistrationStep3()),
    _r('/register/done', (s) => const RegistrationComplete()),
    _r('/home', (s) => const HomeScreen(), tab: true),
    _r('/assessments', (s) => const AssessmentsStatusScreen()),
    _r('/assessments/run', (s) => const AssessmentRunScreen()),
    _r('/assessments/complete', (s) => AssessmentCompleteScreen(assessment: s.extra as Map<String, dynamic>?)),
    _r('/tools', (s) => const ToolsScreen(), tab: true),
    _r('/tools/bmi', (s) => const BmiScreen()),
    _r('/tools/whr', (s) => const WhrScreen()),
    _r('/tools/heart-risk', (s) => const HeartRiskScreen()),
    _r('/tools/water', (s) => const WaterScreen()),
    _r('/tools/stress', (s) => const StressScreen()),
    _r('/tools/activity', (s) => const ActivityScreen()),
    _r('/tools/sleep', (s) => const SleepScreen()),
    _r('/tools/cycle', (s) => const CycleScreen()),
    _r('/diet', (s) => const DietHubScreen(), tab: true),
    _r('/diet/log', (s) => MealLogScreen(initialType: s.uri.queryParameters['type'])),
    _r('/diet/counter', (s) => const MealCounterScreen()),
    _r('/diet/diversity', (s) => const DiversityScreen()),
    _r('/diet/plate', (s) => const PlateScreen()),
    _r('/diet/planner', (s) => const MealPlannerScreen()),
    _r('/diet/budget', (s) => const BudgetScreen()),
    _r('/diet/today', (s) => const NutritionTodayScreen()),
    _r('/diet/pdqs', (s) => const PdqsScreen()),
    _r('/progress', (s) => const ProgressScreen()),
    _r('/milestones', (s) => const MilestonesScreen()),
    _r('/notifications', (s) => const NotificationsScreen()),
    _r('/habits', (s) => const HabitsScreen(), tab: true),
    _r('/library', (s) => const LibraryScreen(), tab: true),
    _r('/library/article/:slug', (s) => ArticleScreen(slug: s.pathParameters['slug']!)),
    _r('/blood-report', (s) => const BloodUploadScreen()),
    _r('/blood-report/:id', (s) => ReportExplainedScreen(id: s.pathParameters['id']!)),
    _r('/profile', (s) => const ProfileScreen(), tab: true),
    _r('/profile/edit', (s) => const EditProfileScreen()),
    _r('/about', (s) => const AboutScreen()),
    _r('/professionals', (s) => const ProfessionalsScreen()),
    _r('/help', (s) => const HelpScreen()),
    _r('/consult', (s) => const ConsultScreen()),
  ],
);
