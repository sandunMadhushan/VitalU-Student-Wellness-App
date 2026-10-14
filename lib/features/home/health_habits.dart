import 'dart:math' as math;

import '../../data/repo.dart';

/// A habit VitalU noticed, either one to work on or one going well.
class HabitInsight {
  const HabitInsight({required this.image, required this.title, required this.detail, required this.source, required this.route, this.good = false});

  /// 3D icon in assets/icons3d.
  final String image;
  final String title;
  final String detail;

  /// Where it was noticed, e.g. "Last 7 days" or "Periodic assessment".
  final String source;
  final String route;
  final bool good;
}

/// Everything the habit rules look at.
class HabitSignals {
  HabitSignals({
    required this.waterByDay,
    required this.waterGoal,
    required this.stepsByDay,
    required this.minutesByDay,
    required this.stepGoal,
    required this.sleep,
    required this.diversity,
    this.pdqs,
    this.assessment,
    this.cycleLogs = const [],
  });

  final Map<String, int> waterByDay;
  final int waterGoal;
  final Map<String, int> stepsByDay;
  final Map<String, int> minutesByDay;
  final int stepGoal;
  final List<Rec> sleep;
  final List<Rec> diversity;
  final Rec? pdqs;

  /// The latest completed periodic assessment.
  final Rec? assessment;
  final List<Rec> cycleLogs;
}

const _week = 'Last 7 days';
const _assess = 'Periodic assessment';
const _diet = 'Diet quality check-in';

/// Works out the student's main habits, the ones to work on first.
List<HabitInsight> healthHabits(HabitSignals s) {
  final attention = <HabitInsight>[];
  final good = <HabitInsight>[];
  final answers = Map<String, dynamic>.from(s.assessment?['answers'] ?? const {});
  final pdqs = Map<String, dynamic>.from((s.pdqs?['data'] as Map?)?['answers'] ?? const {});
  int? pdqsFreq(String k) => (pdqs[k] as num?)?.toInt();

  // Fruit.
  final fruitDays = s.diversity.where((r) => const {'fruits', 'other_fruit', 'vita_veg_fruit'}.contains(r['food_group'])).map((r) => r['log_date']).toSet().length;
  final loggedDays = s.diversity.map((r) => r['log_date']).toSet().length;
  final fruitPdqs = [pdqsFreq('citrus'), pdqsFreq('other_fruit')].whereType<int>().toList();
  if (fruitPdqs.length == 2 && fruitPdqs.every((f) => f == 0)) {
    attention.add(const HabitInsight(image: 'diet', title: 'Low fruit consumption', detail: 'Fruit came up 0 to 1 times last week. A banana or papaya between lectures is an easy start.', source: _diet, route: '/diet/pdqs'));
  } else if (loggedDays >= 3 && fruitDays <= 1) {
    attention.add(const HabitInsight(image: 'diet', title: 'Low fruit consumption', detail: 'Fruit appeared on one day or less of the meals you logged this week. Try adding one fruit a day.', source: _week, route: '/diet/diversity'));
  } else if (const ['0-1', '2-3'].contains(answers['d_fruitveg'] ?? answers['fruit_veg'])) {
    attention.add(const HabitInsight(image: 'diet', title: 'Low fruit and vegetable intake', detail: 'You eat fewer than four servings a day. Aim for five, spread across your meals.', source: _assess, route: '/diet/diversity'));
  } else if (fruitPdqs.any((f) => f == 2)) {
    good.add(const HabitInsight(image: 'diet', title: 'Plenty of fruit', detail: 'You had fruit four or more times last week. Lovely.', source: _diet, route: '/diet/pdqs', good: true));
  }

  // Sugar.
  final sweetCravings = s.cycleLogs.where((l) => l['cravings'] == 'Sweet' || l['cravings'] == 'Chocolate').length;
  if (pdqsFreq('ssb') == 2 || pdqsFreq('sweets') == 2) {
    attention.add(const HabitInsight(image: 'tg', title: 'Frequent sugary foods and drinks', detail: 'Sweet drinks or desserts came up four or more times last week. Swap one for water or fruit each day.', source: _diet, route: '/diet/pdqs'));
  } else if (sweetCravings >= 3) {
    attention.add(HabitInsight(image: 'tg', title: 'Frequent cravings for sugary foods', detail: 'You logged sweet cravings on $sweetCravings days recently. Keep fruit, curd or nuts handy for those moments.', source: 'Cycle tracker', route: '/tools/cycle'));
  } else if ((answers['d_sugary'] ?? answers['sugary']) == '2+') {
    attention.add(const HabitInsight(image: 'tg', title: 'Frequent sugary drinks', detail: 'Two or more sugary drinks a day adds up. Try plain tea, water or king coconut instead.', source: _assess, route: '/diet'));
  }

  // Water.
  final waterDays = s.waterByDay.values.where((v) => v > 0).length;
  if (waterDays >= 2) {
    final avg = s.waterByDay.values.fold<int>(0, (a, b) => a + b) / 7;
    if (avg < s.waterGoal * 0.8) {
      attention.add(HabitInsight(
          image: 'water',
          title: 'Inadequate water intake',
          detail: 'You averaged ${(avg / 1000).toStringAsFixed(1)} L a day against a ${(s.waterGoal / 1000).toStringAsFixed(1)} L goal. Refill a bottle between lectures.',
          source: _week,
          route: '/tools/water'));
    } else if (avg >= s.waterGoal * 0.95) {
      good.add(const HabitInsight(image: 'water', title: 'Well hydrated', detail: 'You are meeting your water goal most days. Keep it up.', source: _week, route: '/tools/water', good: true));
    }
  }

  // Activity.
  final minutes = s.minutesByDay.values.fold<int>(0, (a, b) => a + b);
  final stepDays = s.stepsByDay.values.where((v) => v > 0).toList();
  final avgSteps = stepDays.isEmpty ? 0 : stepDays.fold<int>(0, (a, b) => a + b) / stepDays.length;
  if (stepDays.length >= 3 || minutes > 0) {
    if (minutes < 150 && avgSteps < 6000) {
      attention.add(HabitInsight(
          image: 'steps',
          title: 'Insufficient physical activity',
          detail: '$minutes active minutes this week (aim for 150). A brisk 20-minute walk a day closes the gap.',
          source: _week,
          route: '/tools/activity'));
    } else if (minutes >= 150 || avgSteps >= s.stepGoal) {
      good.add(const HabitInsight(image: 'steps', title: 'Active week', detail: 'You are reaching the recommended activity level.', source: _week, route: '/tools/activity', good: true));
    }
  } else if (const ['0', '1-2'].contains(answers['m_active_days'])) {
    attention.add(const HabitInsight(image: 'steps', title: 'Insufficient physical activity', detail: 'You are active on fewer than three days a week. Short walks between classes all count.', source: _assess, route: '/tools/activity'));
  }

  // Sleep.
  if (s.sleep.length >= 3) {
    final bedMinutes = [
      for (final r in s.sleep)
        () {
          final b = DateTime.parse(r['bedtime']).toLocal();
          final m = b.hour * 60 + b.minute;
          return m < 12 * 60 ? m + 24 * 60 : m; // after midnight counts as late evening
        }()
    ];
    final mean = bedMinutes.reduce((a, b) => a + b) / bedMinutes.length;
    final sd = math.sqrt(bedMinutes.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) / bedMinutes.length);
    final hours = s.sleep.map(Repo.sleepMinutes).reduce((a, b) => a + b) / s.sleep.length / 60;
    if (sd > 60) {
      attention.add(HabitInsight(
          image: 'sleep',
          title: 'Irregular sleep pattern',
          detail: 'Your bedtime varies by about ${(sd / 60).toStringAsFixed(1)} hours. A steady bedtime, even before exams, helps energy and mood.',
          source: _week,
          route: '/tools/sleep'));
    } else if (hours < 6.5) {
      attention.add(HabitInsight(image: 'sleep', title: 'Short sleep', detail: 'You averaged ${hours.toStringAsFixed(1)} hours a night. Most students need 7 to 9.', source: _week, route: '/tools/sleep'));
    } else if (hours >= 7 && hours <= 9.5) {
      good.add(const HabitInsight(image: 'sleep', title: 'Steady, restful sleep', detail: 'Regular bedtimes and 7 or more hours a night.', source: _week, route: '/tools/sleep', good: true));
    }
  } else if (answers['s_regular'] == 'rarely') {
    attention.add(const HabitInsight(image: 'sleep', title: 'Irregular sleep pattern', detail: 'You rarely sleep and wake at the same times. Try a fixed wake-up time first.', source: _assess, route: '/tools/sleep'));
  }

  return [...attention, ...good];
}
