import 'dart:async';

import '../data/repo.dart';
import 'app_state.dart';

/// A streak badge: the goal has to be met on [StreakBadge.length] calendar
/// days in a row (three for water and food, seven for activity). The server
/// (`refresh_badges`) awards it; the app tracks the streak locally so it can
/// show stars and "days remaining" as you go.
enum StreakKind { water, food, move, smart }

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
  static const food = StreakBadge(StreakKind.food, 'rainbow_plate', 'Rainbow Plate', 'Eat from 5 or more food groups', 'Five food groups today');
  static const move = StreakBadge(StreakKind.move, 'active_aura', 'Active Aura', 'Reach your step goal or 30 active minutes', 'Movement goal reached', length: 7);
  static const smart = StreakBadge(StreakKind.smart, 'smart_eater', 'Smart Eater', 'Log breakfast, lunch and dinner with 5 or more food groups', 'Three meals and five food groups logged', length: 7);

  static StreakBadge of(StreakKind k) => switch (k) {
        StreakKind.water => water,
        StreakKind.food => food,
        StreakKind.move => move,
        StreakKind.smart => smart,
      };
}

class StreakInfo {
  const StreakInfo({required this.streak, required this.todayDone, required this.earned, this.length = 3});

  /// Consecutive days the goal was met, ending today (or yesterday, when
  /// today is still in progress and the streak is alive).
  final int streak;
  final bool todayDone;
  final bool earned;

  /// Days needed for the badge, which is also the number of stars.
  final int length;

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
    switch (kind) {
      case StreakKind.water:
        final goal = p?.waterGoalMl ?? 2500;
        (await Repo.waterByDay(10)).forEach((d, ml) {
          if (ml >= goal) done.add(d);
        });
      case StreakKind.food || StreakKind.smart:
        final groups = <String, Set<String>>{};
        for (final r in await Repo.diversityBetween(from, now)) {
          groups.putIfAbsent(r['log_date'] as String, () => {}).add(r['food_group'] as String);
        }
        groups.forEach((d, g) {
          if (g.length >= 5) done.add(d);
        });
        if (kind == StreakKind.smart) {
          final meals = <String, Set<String>>{};
          for (final m in await Repo.mealsBetween(from, now)) {
            if (m['status'] == 'logged') meals.putIfAbsent(m['meal_date'] as String, () => {}).add(m['meal_type'] as String);
          }
          done.removeWhere((d) => !(meals[d]?.containsAll(const ['breakfast', 'lunch', 'dinner']) ?? false));
        }
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
    return StreakInfo(streak: streak, todayDone: todayDone, earned: earned, length: StreakBadge.of(kind).length);
  }
}

/// Broadcasts badge codes the server has just awarded, so a single host at
/// the app root can celebrate them wherever the student happens to be.
class BadgeCenter {
  BadgeCenter._();

  static final _ctrl = StreamController<List<String>>.broadcast();
  static Stream<List<String>> get earned => _ctrl.stream;

  static void announce(List<String> codes) {
    if (codes.isNotEmpty) _ctrl.add(codes);
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
