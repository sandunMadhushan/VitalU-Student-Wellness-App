import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state.dart';
import '../../data/catalog.dart';
import '../../data/food_db.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import 'pdqs_screen.dart' show pdqsGroups, pdqsPoints;

/// Physical activity level (PAL) for each activity option in the profile.
/// Multipliers follow the standard FAO/WHO/UNU activity bands.
(double, String) activityFactor(String level) => switch (level) {
      'Mostly sitting' => (1.2, 'mostly sitting'),
      'Light Walking (Campus)' => (1.375, 'lightly active'),
      'Active / Sports' => (1.725, 'very active'),
      _ => (1.55, 'moderately active'),
    };

/// How a student's calorie target was worked out, step by step.
class EnergyPlan {
  const EnergyPlan({
    required this.bmr,
    required this.pal,
    required this.palLabel,
    required this.tdee,
    required this.adjustment,
    required this.target,
    required this.category,
    required this.goal,
    required this.floor,
  });

  /// Basal metabolic rate (Mifflin-St Jeor), kcal a day.
  final int bmr;
  final double pal;
  final String palLabel;

  /// Total daily energy expenditure, BMR × PAL, rounded to 50 kcal.
  final int tdee;

  /// Added (+) or taken away (−) for the BMI-based goal.
  final int adjustment;
  final int target;
  final String category;
  final String goal;

  /// The lowest target VitalU will suggest, for safety.
  final int floor;
}

/// Mifflin-St Jeor BMR: 10 × weight (kg) + 6.25 × height (cm) − 5 × age
/// (years) + 5 for men, − 161 for women. TDEE = BMR × PAL. The target then
/// moves gently from TDEE by BMI category: +350 kcal when underweight,
/// −400 when overweight and −500 with obesity, never below a floor of
/// 1,500 kcal (men) or 1,300 kcal (women).
EnergyPlan? energyPlan() {
  final p = AppState.instance.profile;
  if (p == null || p.weightKg == null || p.heightCm == null || p.age == null || p.sex == null) return null;
  final male = p.sex == 'male';
  final bmr = (10 * p.weightKg! + 6.25 * p.heightCm! - 5 * p.age! + (male ? 5 : -161)).round();
  final (pal, palLabel) = activityFactor(p.activityLevel);
  final tdee = ((bmr * pal) / 50).round() * 50;
  final category = p.bmi == null ? 'Unknown' : Calc.bmiCategory(p.bmi!);
  final floor = male ? 1500 : 1300;
  final (adj, goal) = switch (category) {
    'Underweight' => (350, 'gain weight gradually'),
    'Overweight' => (-400, 'lose weight gradually'),
    'Obesity' => (-500, 'lose weight steadily and safely'),
    _ => (0, 'keep your weight steady'),
  };
  final target = (tdee + adj).clamp(floor, 99999);
  return EnergyPlan(bmr: bmr, pal: pal, palLabel: palLabel, tdee: tdee, adjustment: target - tdee, target: target, category: category, goal: goal, floor: floor);
}

const _customKey = 'calorie_target_custom';

/// The daily target in use: the student's own number if they set one,
/// otherwise the personal estimate, otherwise the profile default.
Future<int> effectiveCalorieTarget() async {
  final p = AppState.instance.profile;
  var custom = false;
  try {
    custom = (await SharedPreferences.getInstance()).getBool(_customKey) ?? false;
  } catch (_) {}
  if (custom) return p?.calorieTarget ?? 2100;
  return energyPlan()?.target ?? p?.calorieTarget ?? 2100;
}

Future<void> setCustomCalorieTarget(int? kcal) async {
  final prefs = await SharedPreferences.getInstance();
  if (kcal == null) {
    await prefs.setBool(_customKey, false);
  } else {
    await prefs.setBool(_customKey, true);
    await AppState.instance.updateProfile({'calorie_target': kcal});
  }
}

/// A flexible way to spread the day's energy across meals.
const mealSplit = <(String, String, double)>[
  ('breakfast', 'Breakfast', 0.25),
  ('lunch', 'Lunch', 0.35),
  ('dinner', 'Dinner', 0.30),
  ('snack', 'Snacks', 0.10),
];

/// The foods logged in a meal, from meals.items when present.
List<LoggedItem> mealItems(Rec m) => [for (final i in (m['items'] as List? ?? const [])) if (i is Map) LoggedItem.fromJson(Map<String, dynamic>.from(i))];

/// Diet quality estimated from meal logs with the Prime Diet Quality Score
/// method: each logged food counts as one serving of its PDQS groups over
/// the last 7 days, scored 0, 1 or 2 per group, 0 to 42 in total.
class LoggedDietQuality {
  const LoggedDietQuality(this.score, this.daysLogged, this.servings);
  final int score;
  final int daysLogged;
  final Map<String, int> servings;

  /// Enough logging to be meaningful (at least 4 of the 7 days).
  bool get reliable => daysLogged >= 4;
}

LoggedDietQuality loggedDietQuality(List<Rec> mealsLast7Days) {
  final servings = <String, int>{};
  final days = <String>{};
  for (final m in mealsLast7Days.where((m) => m['status'] == 'logged')) {
    final items = mealItems(m);
    if (items.isEmpty) continue;
    days.add(m['meal_date'] as String);
    for (final i in items) {
      for (final g in i.pdqs) {
        servings[g] = (servings[g] ?? 0) + 1;
      }
    }
  }
  int freq(int n) => n <= 1 ? 0 : (n <= 3 ? 1 : 2);
  final score = days.isEmpty ? 0 : pdqsGroups.fold<int>(0, (a, g) => a + pdqsPoints(g, freq(servings[g.key] ?? 0)));
  return LoggedDietQuality(score, days.length, servings);
}

/// MDD-W food groups eaten on each day (old 8-group keys are mapped).
Map<String, Set<String>> diversityByDay(List<Rec> diversityLogs) {
  final m = <String, Set<String>>{};
  for (final r in diversityLogs) {
    final key = legacyGroupKey(r['food_group'] as String);
    if (key == null) continue;
    m.putIfAbsent(r['log_date'] as String, () => {}).add(key);
  }
  return m;
}

/// Energy used today: resting and everyday living (BMR × 1.2) plus the
/// activity the student actually logged or the phone counted.
Future<(int, int)?> energyOutToday() async {
  final plan = energyPlan();
  if (plan == null) return null;
  int active = 0;
  try {
    active = ((await Repo.activityTotals(DateTime.now()))['kcal'] as num).round();
  } catch (_) {}
  return ((plan.bmr * 1.2).round(), active);
}
