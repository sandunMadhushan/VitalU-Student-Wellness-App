import 'dart:async';

import '../data/repo.dart';
import '../data/catalog.dart' show minDietaryDiversity;
import '../features/diet/diet_science.dart' show diversityByDay, loggedDietQuality;
import 'app_state.dart';

/// The five VitalU badges, in display order. The server awards them with the
/// same rules (`refresh_badges`); keep the wording in step with the migration.
const badgeDefinitions = <Map<String, dynamic>>[
  {'code': 'aqua_achiever', 'title': 'Aqua Achiever', 'icon': 'water_drop', 'category': 'nourish', 'sort_order': 1, 'description': 'Reach your daily water goal 3 days in a row.'},
  {'code': 'active_aura', 'title': 'Active Aura', 'icon': 'directions_walk', 'category': 'nourish', 'sort_order': 2, 'description': 'Reach your step goal or 30 active minutes 7 days in a row.'},
  {
    'code': 'smart_eater',
    'title': 'Smart Eater',
    'icon': 'restaurant',
    'category': 'nourish',
    'sort_order': 3,
    'description': 'Log breakfast, lunch and dinner from 5 or more food groups for 7 days in a row, with a diet quality score of at least 22 out of 42 for that week.',
  },
  {
    'code': 'heart_minded',
    'title': 'Heart Minded',
    'icon': 'cardiology',
    'category': 'milestone',
    'sort_order': 4,
    'description': 'Know your numbers: complete the heart health check and log your blood pressure and a blood sugar or triglyceride result, all within 90 days.',
  },
  {'code': 'curious_learner', 'title': 'Curious Learner', 'icon': 'auto_stories', 'category': 'milestone', 'sort_order': 5, 'description': 'Read 5 health articles to the end, from at least 3 different topics.'},
];

const badgeCodes = ['aqua_achiever', 'active_aura', 'smart_eater', 'heart_minded', 'curious_learner'];

/// Smart Eater also needs a diet quality score (PDQS, estimated from the
/// week's meal logs) of at least this, out of 42: more than half the points.
const smartEaterPdqs = 22;

/// A streak badge: the goal has to be met on [StreakBadge.length] calendar
/// days in a row (three for water, seven for activity and Smart Eater). The
/// server (`refresh_badges`) awards it; the app tracks the streak locally so
/// it can show stars and "days remaining" as you go.
enum StreakKind { water, move, smart }

class StreakBadge {
  const StreakBadge(this.kind, this.code, this.title, this.goal, this.dayDone, {this.length = 3});
  final StreakKind kind;
  final String code;
  final String title;

  /// What counts as a completed day, in plain words.
  final String goal;

  /// Short line used when a day is completed, e.g. "Water goal reached".
  final String dayDone;

  /// Days in a row needed to earn the badge.
  final int length;

  static const water = StreakBadge(StreakKind.water, 'aqua_achiever', 'Aqua Achiever', 'Reach your daily water goal', 'Water goal reached');
  static const move = StreakBadge(StreakKind.move, 'active_aura', 'Active Aura', 'Reach your step goal or 30 active minutes', 'Movement goal reached', length: 7);
  static const smart = StreakBadge(StreakKind.smart, 'smart_eater', 'Smart Eater', 'Log breakfast, lunch and dinner with 5 or more food groups', 'Three meals and five food groups logged', length: 7);

  static StreakBadge of(StreakKind k) => switch (k) {
        StreakKind.water => water,
        StreakKind.move => move,
        StreakKind.smart => smart,
      };
}

class StreakInfo {
  const StreakInfo({required this.streak, required this.todayDone, required this.earned, this.length = 3, this.weekPdqs});

  /// Consecutive days the goal was met, ending today (or yesterday, when
  /// today is still in progress and the streak is alive).
  final int streak;
  final bool todayDone;
  final bool earned;

  /// Days needed for the badge, which is also the number of stars.
  final int length;

  /// Smart Eater only: diet quality score of the last 7 days' meal logs.
  final int? weekPdqs;

  /// Stars to light on the star track.
  int get stars => streak.clamp(0, length);
  int get remaining => length - stars;
}

class Streaks {
  Streaks._();

  static Future<StreakInfo> of(StreakKind kind) async {
    final now = DateTime.now();
    final from = dayStart(now).subtract(const Duration(days: 9));
    final p = AppState.instance.profile;
    final done = <String>{};
    int? pdqs;
    switch (kind) {
      case StreakKind.water:
        final goal = p?.waterGoalMl ?? 2500;
        (await Repo.waterByDay(10)).forEach((d, ml) {
          if (ml >= goal) done.add(d);
        });
      case StreakKind.smart:
        diversityByDay(await Repo.diversityBetween(from, now)).forEach((d, g) {
          if (g.length >= minDietaryDiversity) done.add(d);
        });
        final meals = <String, Set<String>>{};
        final mealRows = await Repo.mealsBetween(from, now);
        for (final m in mealRows) {
          if (m['status'] == 'logged') meals.putIfAbsent(m['meal_date'] as String, () => {}).add(m['meal_type'] as String);
        }
        done.removeWhere((d) => !(meals[d]?.containsAll(const ['breakfast', 'lunch', 'dinner']) ?? false));
        final weekStart = isoDate(dayStart(now).subtract(const Duration(days: 6)));
        pdqs = loggedDietQuality([for (final m in mealRows) if ((m['meal_date'] as String).compareTo(weekStart) >= 0) m]).score;
      case StreakKind.move:
        final goal = p?.stepGoal ?? 8000;
        final steps = <String, int>{}, mins = <String, int>{};
        for (final r in await Repo.activityBetween(from, now)) {
          final d = r['activity_date'] as String;
          steps[d] = (steps[d] ?? 0) + (r['steps'] as num).toInt();
          mins[d] = (mins[d] ?? 0) + (r['active_minutes'] as num).toInt();
        }
        for (final d in {...steps.keys, ...mins.keys}) {
          if ((steps[d] ?? 0) >= goal || (mins[d] ?? 0) >= 30) done.add(d);
        }
    }
    final todayDone = done.contains(isoDate(now));
    var day = todayDone ? dayStart(now) : dayStart(now).subtract(const Duration(days: 1));
    var streak = 0;
    while (done.contains(isoDate(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    bool earned = false;
    try {
      earned = (await Repo.earnedBadges()).containsKey(StreakBadge.of(kind).code);
    } catch (_) {}
    return StreakInfo(streak: streak, todayDone: todayDone, earned: earned, length: StreakBadge.of(kind).length, weekPdqs: pdqs);
  }
}

/// One condition on the way to a badge.
class BadgeStep {
  const BadgeStep(this.label, this.done, {this.detail, this.route});
  final String label;
  final bool done;
  final String? detail;

  /// Where to go to work on it.
  final String? route;
}

/// What is left to earn Heart Minded or Curious Learner, mirroring the rules
/// in `refresh_badges`.
Future<List<BadgeStep>> badgeSteps(String code) async {
  final since = DateTime.now().subtract(const Duration(days: 90));
  bool recent(Rec r) => DateTime.parse(r['created_at']).isAfter(since);
  switch (code) {
    case 'heart_minded':
      final r = await Future.wait<Object>([Repo.toolResults('cvd', limit: 5), Repo.toolResults('vitals', limit: 30), Repo.reports()]);
      final cvd = (r[0] as List<Rec>).any(recent);
      final vitals = [for (final v in r[1] as List<Rec>) if (recent(v)) Map<String, dynamic>.from(v['data'] ?? {})];
      final bp = vitals.any((d) => d['systolic'] != null);
      final labs = vitals.any((d) => d['fasting_glucose'] != null || d['triglycerides'] != null) || (r[2] as List<Rec>).any((b) => b['status'] == 'done' && recent(b));
      return [
        BadgeStep('Complete the heart health check', cvd, route: '/tools/heart-risk'),
        BadgeStep('Log a blood pressure reading', bp, route: '/home'),
        BadgeStep('Log a blood sugar or triglyceride result', labs, detail: 'Or upload a blood report', route: '/blood-report'),
      ];
    case 'curious_learner':
      final reads = await Repo.articleReads();
      final topics = reads.map((e) => e.$2).whereType<String>().toSet();
      return [
        BadgeStep('Read 5 articles to the end', reads.length >= 5, detail: '${reads.length.clamp(0, 5)} of 5 read', route: '/library'),
        BadgeStep('From at least 3 different topics', topics.length >= 3, detail: '${topics.length.clamp(0, 3)} of 3 topics', route: '/library'),
      ];
  }
  return const [];
}

/// Broadcasts badge codes the server has just awarded, so a single host at
/// the app root can celebrate them wherever the student happens to be.
class BadgeCenter {
  BadgeCenter._();

  static final _ctrl = StreamController<List<String>>.broadcast();
  static Stream<List<String>> get earned => _ctrl.stream;

  static void announce(List<String> codes) {
    final kept = codes.where(badgeCodes.contains).toList();
    if (kept.isNotEmpty) _ctrl.add(kept);
  }

  static Map<String, Rec>? _meta;

  /// Title and description for a badge code, cached after the first load.
  static Future<Rec?> meta(String code) async {
    try {
      _meta ??= {for (final b in await Repo.badges()) b['code'] as String: b};
    } catch (_) {}
    return _meta?[code];
  }
}
