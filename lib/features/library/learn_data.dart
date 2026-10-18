import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/repo.dart';
import '../../ui/tokens.dart';
import '../home/health_habits.dart';

/// A Learn topic. Keep the keys in step with `supabase/seed/build_learn.py`
/// and the admin dashboard.
class LearnTopic {
  const LearnTopic(this.key, this.title, this.short, this.intro, this.icon, this.color);
  final String key;
  final String title;

  /// Two-line name for topic cards.
  final String short;
  final String intro;
  final IconData icon;
  final Color Function() color;

  String get image => 'assets/learn/$key.webp';
}

final learnTopics = <LearnTopic>[
  LearnTopic('body', 'Body Confidence & Healthy Fitness', 'Body Confidence\n& Healthy Fitness',
      'Belly fat, healthy weight gain, strength and posture, with a positive view of your body. Real changes, no quick fixes.', Symbols.fitness_center_rounded, () => AppColors.activity),
  LearnTopic('womens', "Women's Health & Hormonal Balance", "Women's Health\n& Hormones",
      'Understand your cycle, PCOS, period pain and hormonal health, and know when to see a doctor.', Symbols.female_rounded, () => AppColors.cycle),
  LearnTopic('cravings', 'Food Cravings & Eating Habits', 'Food Cravings\n& Eating Habits',
      'Why you crave sweets, emotional eating, skipped meals and building a kinder relationship with food.', Symbols.cake_rounded, () => AppColors.warning),
  LearnTopic('heart', 'Heart Health & Disease Prevention', 'Heart Health\n& NCD Prevention',
      'Blood pressure, cholesterol, diabetes and fatty liver: what raises your risk and the habits that lower it.', Symbols.cardiology_rounded, () => AppColors.heart),
  LearnTopic('smoking', 'Smoking, Alcohol & Breaking Habits', 'Smoking, Alcohol\n& Breaking Habits',
      'What tobacco and alcohol do to your body, how cravings work, and real support for quitting.', Symbols.smoke_free_rounded, () => AppColors.onSurfaceVariant),
  LearnTopic('signs', 'Know the Signs: Health Conditions', 'Know the Signs\nHealth Conditions',
      'Anaemia, migraine, gastritis and other common student health problems: signs, causes and when to get checked.', Symbols.stethoscope_rounded, () => AppColors.water),
  LearnTopic('skin', 'Skin, Hair & Personal Care', 'Skin, Hair\n& Personal Care',
      'Acne, sweat and body odour, oral health and simple, realistic self-care.', Symbols.face_rounded, () => AppColors.body),
  LearnTopic('mind', 'Mind, Mood & Emotional Well-being', 'Mind, Mood\n& Well-being',
      'Stress, anxiety, relaxation and focus, and keeping healthy, supportive friendships.', Symbols.psychology_rounded, () => AppColors.mind),
  LearnTopic('sleep', 'Sleep, Energy & Recovery', 'Sleep, Energy\n& Recovery',
      'Better sleep in a busy hostel, resetting your body clock and beating daytime tiredness.', Symbols.bedtime_rounded, () => AppColors.sleep),
  LearnTopic('presence', 'Personal Presence & Career Confidence', 'Personal Presence\n& Career Confidence',
      'Interview confidence, communication, body language, posture and fitness for your career.', Symbols.work_rounded, () => AppColors.primary),
  LearnTopic('essentials', 'Everyday Health Essentials', 'Everyday Health\nEssentials',
      'Water, fibre, balanced Sri Lankan meals and eating well on a student budget.', Symbols.water_drop_rounded, () => AppColors.nutrition),
  LearnTopic('habits', 'Your Habits, Your Health', 'Your Habits,\nYour Health',
      'Reads picked for you from your own water, activity, sleep and meal logs, plus how to build habits that stick.', Symbols.insights_rounded, () => AppColors.tertiary),
  LearnTopic('sexual', 'Sexual Health & STIs', 'Sexual Health\n& STIs',
      'Know the facts about sexually transmitted infections, protection and free, confidential testing in Kandy.', Symbols.health_and_safety_rounded, () => AppColors.error),
];

LearnTopic? topicByKey(String? key) => learnTopics.where((t) => t.key == key).firstOrNull;

/// Articles shipped with the app, generated from
/// `supabase/seed/learn_articles.json`.
Future<List<Rec>> _bundled() async {
  try {
    return List<Rec>.from(jsonDecode(await rootBundle.loadString('assets/learn/articles.json')) as List);
  } catch (_) {
    return const [];
  }
}

/// Whether a database body is in the current article format.
bool _rich(Rec a) => (a['body'] as Map?)?['sections'] is List;

/// The library: database articles (admins may have edited, hidden or added
/// some) merged with the bundled ones, so the full library shows even before
/// the database has it. Database rows keep their ids for bookmarks.
Future<List<Rec>> loadArticles() async {
  final bundled = await _bundled();
  List<Rec> db = const [];
  try {
    // A slow or offline connection falls back to the bundled library.
    db = await Repo.articles().timeout(const Duration(seconds: 3));
  } catch (_) {}
  final bySlug = {for (final b in bundled) b['slug'] as String: b};
  final out = <Rec>[];
  for (final a in db) {
    if (a['hidden'] == true) continue;
    final b = bySlug[a['slug']];
    out.add(b != null && !_rich(a) ? {...a, ...b, 'id': a['id']} : a);
  }
  final have = out.map((a) => a['slug']).toSet();
  out.addAll(bundled.where((b) => !have.contains(b['slug'])));
  out.sort((a, b) => ((a['sort_order'] as num?) ?? 100).compareTo((b['sort_order'] as num?) ?? 100));
  return out;
}

Future<Rec?> loadArticle(String slug) async => (await loadArticles()).where((a) => a['slug'] == slug).firstOrNull;

/// An article picked for the student, with the reason.
class Pick {
  const Pick(this.slug, this.reason);
  final String slug;
  final String reason;
}

/// Articles that match the student's own logs and health checks.
Future<List<Pick>> personalPicks() async {
  final p = AppState.instance.profile;
  final now = DateTime.now();
  final from = dayStart(now).subtract(const Duration(days: 6));
  Future<T> safe<T>(Future<T> f, T fallback) async {
    try {
      return await f;
    } catch (_) {
      return fallback;
    }
  }

  final r = await Future.wait<Object?>([
    safe(Repo.waterByDay(7), <String, int>{}),
    safe(Repo.stepsByDay(from, now), <String, int>{}),
    safe(Repo.minutesByDay(from, now), <String, int>{}),
    safe(Repo.sleepBetween(from, now), <Rec>[]),
    safe(Repo.diversityBetween(from, now), <Rec>[]),
    safe(Repo.latestToolResult('pdqs'), null),
    safe(Repo.latestToolResult('stress'), null),
  ]);
  final habits = healthHabits(HabitSignals(
    waterByDay: r[0] as Map<String, int>,
    waterGoal: p?.waterGoalMl ?? 2500,
    stepsByDay: r[1] as Map<String, int>,
    minutesByDay: r[2] as Map<String, int>,
    stepGoal: p?.stepGoal ?? 8000,
    sleep: r[3] as List<Rec>,
    diversity: r[4] as List<Rec>,
    pdqs: r[5] as Rec?,
  ));
  final picks = <Pick>[];
  void add(String slug, String reason) {
    if (!picks.any((x) => x.slug == slug)) picks.add(Pick(slug, reason));
  }

  for (final h in habits.where((h) => !h.good)) {
    switch (h.image) {
      case 'water':
        add('hydration-2pm', h.title);
      case 'steps':
        add('small-habits', h.title);
        add('dopamine-screen-breaks', h.title);
      case 'sleep':
        add('sleep-hygiene', h.title);
        add('circadian-reset', h.title);
      case 'tg':
        add('sugar-cravings', h.title);
        add('emotional-eating', h.title);
      case 'diet':
        add('budget-balanced-meals', h.title);
        add('constipation-fibre', h.title);
    }
  }
  final bmi = p?.bmi;
  if (bmi != null && bmi >= 25) add('belly-fat', 'Your BMI is above the healthy range');
  if (bmi != null && bmi < 18.5) add('healthy-weight-gain', 'Your BMI is below the healthy range');
  final stress = (r[6] as Rec?)?['category'] as String?;
  if (stress != null && stress != 'Normal') add('478-breathing', 'Your stress check showed $stress stress');
  final conds = p?.conditions ?? const <String>[];
  if (conds.contains('anaemia')) add('iron-deficiency', 'From your health profile');
  if (conds.contains('pcos')) add('pcos-awareness', 'From your health profile');
  if (conds.contains('gastritis')) add('gastritis-care', 'From your health profile');
  return picks;
}
