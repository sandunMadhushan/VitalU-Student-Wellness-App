import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repo.dart';

/// The four phases, plus the few days before a period, which get their own
/// gentler messages.
enum CyclePhase { menstrual, follicular, ovulation, luteal, premenstrual }

/// Estimated phase for [day] (1-based) of a cycle. Ovulation is placed 14
/// days before the next period, the usual textbook estimate.
CyclePhase phaseForDay(int day, int cycleLen, int periodLen) {
  final ov = cycleLen - 14;
  if (day <= periodLen) return CyclePhase.menstrual;
  if (day < ov - 2) return CyclePhase.follicular;
  if (day <= ov + 2) return CyclePhase.ovulation;
  if (day > cycleLen - 5) return CyclePhase.premenstrual;
  return CyclePhase.luteal;
}

/// Phase as drawn on the four-step diagram (the premenstrual days are part
/// of the luteal phase there).
CyclePhase diagramPhase(CyclePhase p) => p == CyclePhase.premenstrual ? CyclePhase.luteal : p;

class PhaseCopy {
  const PhaseCopy({
    required this.name,
    required this.icon,
    required this.illustration,
    required this.greeting,
    required this.message,
    required this.mayNotice,
    required this.tryThis,
    required this.whyTitle,
    required this.why,
  });
  final String name;
  final IconData icon;
  final String illustration;

  /// Warm one-liner shown at the top of the phase card.
  final String greeting;
  final String message;
  final List<String> mayNotice;

  /// Self-care ideas: (icon, label). A label of 'Calm music' plays music.
  final List<(IconData, String)> tryThis;
  final String whyTitle;
  final String why;
}

const phaseCopy = <CyclePhase, PhaseCopy>{
  CyclePhase.menstrual: PhaseCopy(
    name: 'Menstrual',
    icon: Symbols.water_drop_rounded,
    illustration: 'cycle_menstrual',
    greeting: 'Be extra kind to yourself today',
    message: 'Your period is a time to slow down a little. It is completely okay to rest more, move gently and keep your plans light.',
    mayNotice: ['Cramps', 'Low energy', 'Lower back ache', 'Feeling tired', 'Wanting comfort food'],
    tryThis: [
      (Symbols.heat_rounded, 'Warm compress on your tummy'),
      (Symbols.self_improvement_rounded, 'Gentle stretching'),
      (Symbols.soup_kitchen_rounded, 'Iron-rich food like dhal and greens'),
      (Symbols.bedtime_rounded, 'An early night'),
      (Symbols.music_note_rounded, 'Calm music'),
    ],
    whyTitle: 'Why you might feel this way',
    why: 'Oestrogen and progesterone are at their lowest, and the womb contracts to shed its lining. Those contractions are what cause cramps. Everyone feels it differently.',
  ),
  CyclePhase.follicular: PhaseCopy(
    name: 'Follicular',
    icon: Symbols.eco_rounded,
    illustration: 'cycle_follicular',
    greeting: 'Your energy is on the rise',
    message: 'Many people feel fresher and more motivated in this phase. A great time to start new topics, try something new or plan your week.',
    mayNotice: ['More energy', 'Brighter mood', 'Clearer focus', 'Feeling motivated'],
    tryThis: [
      (Symbols.menu_book_rounded, 'Start a tough new topic'),
      (Symbols.directions_run_rounded, 'Try a new workout'),
      (Symbols.event_note_rounded, 'Plan your week'),
      (Symbols.groups_rounded, 'Catch up with friends'),
    ],
    whyTitle: 'What is behind it',
    why: 'Rising oestrogen helps rebuild the womb lining and often lifts mood and energy too.',
  ),
  CyclePhase.ovulation: PhaseCopy(
    name: 'Ovulation',
    icon: Symbols.wb_twilight_rounded,
    illustration: 'cycle_ovulation',
    greeting: 'You might be feeling your brightest',
    message: 'This is often a peak-energy window. Lean into group study, presentations and anything social, and keep a water bottle close.',
    mayNotice: ['High energy', 'Feeling social', 'A slight one-sided twinge', 'More discharge'],
    tryThis: [
      (Symbols.co_present_rounded, 'Practise a presentation'),
      (Symbols.groups_rounded, 'Group study session'),
      (Symbols.water_drop_rounded, 'Stay well hydrated'),
      (Symbols.sprint_rounded, 'A more active workout'),
    ],
    whyTitle: 'What is behind it',
    why: 'A surge of luteinising hormone (LH) releases an egg, and oestrogen is at its peak. Some people feel a brief twinge on one side when this happens.',
  ),
  CyclePhase.luteal: PhaseCopy(
    name: 'Luteal',
    icon: Symbols.bedtime_rounded,
    illustration: 'cycle_luteal',
    greeting: 'Time to slow down gently',
    message: 'Your body is shifting into a calmer rhythm. Regular meals, good sleep and steady study pacing help you feel your best.',
    mayNotice: ['Bigger appetite', 'Slightly lower energy', 'Wanting more rest'],
    tryThis: [
      (Symbols.restaurant_rounded, 'Regular, balanced meals'),
      (Symbols.bedtime_rounded, 'Protect your sleep'),
      (Symbols.local_cafe_rounded, 'Go easy on caffeine'),
      (Symbols.edit_note_rounded, 'Revise rather than cram'),
    ],
    whyTitle: 'What is behind it',
    why: 'Progesterone rises to keep the womb lining rich and soft. It can make you feel calmer, but also a little hungrier or sleepier.',
  ),
  CyclePhase.premenstrual: PhaseCopy(
    name: 'Before your period',
    icon: Symbols.favorite_rounded,
    illustration: 'cycle_premenstrual',
    greeting: 'Your period may be on its way',
    message: 'You might feel more sensitive, tired or irritable over the next few days. That is okay. These changes can be a normal part of your cycle, so give yourself a little extra care.',
    mayNotice: ['Mood changes', 'Irritability', 'Tiredness', 'Cravings', 'Bloating', 'Tender breasts'],
    tryThis: [
      (Symbols.directions_walk_rounded, 'A short walk'),
      (Symbols.self_improvement_rounded, 'Gentle stretching'),
      (Symbols.bedtime_rounded, 'Extra rest'),
      (Symbols.music_note_rounded, 'Calm music'),
      (Symbols.spa_rounded, 'A few minutes for yourself'),
    ],
    whyTitle: 'Why you might feel this way',
    why: 'Oestrogen and progesterone fall before a period, and these shifts may contribute to mood and energy changes. Symptoms vary a lot from person to person, and some people notice very little.',
  ),
};

// -----------------------------------------------------------------------------
// Notification preferences and scheduling

class CycleNotifyPrefs {
  CycleNotifyPrefs(this.on);
  final Map<String, bool> on;

  static const keys = <(String, String, String)>[
    ('period_soon', 'Period coming soon', 'A heads-up 2 days before your estimated period'),
    ('premenstrual', 'Before your period', 'Gentle self-care ideas for the days before it starts'),
    ('menstrual', 'Period days', 'Comfort tips when your period is expected'),
    ('follicular', 'Energy rising', 'When the follicular phase is likely to begin'),
    ('ovulation', 'Ovulation window', 'Around your estimated ovulation'),
    ('luteal', 'Luteal phase', 'When your body is likely winding down'),
  ];

  bool get master => on['master'] ?? true;
  bool enabled(String k) => master && (on[k] ?? true);

  static Future<CycleNotifyPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return CycleNotifyPrefs({
      'master': p.getBool('cycle_notify_master') ?? true,
      for (final k in keys) k.$1: p.getBool('cycle_notify_${k.$1}') ?? true,
    });
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('cycle_notify_master', master);
    for (final k in keys) {
      await p.setBool('cycle_notify_${k.$1}', on[k.$1] ?? true);
    }
  }
}

/// Replaces the cycle's upcoming in-app notifications with fresh ones for
/// the next ~6 weeks, worked out from the latest logged start date. Every
/// message is worded as an estimate.
Future<void> rescheduleCycleNotifications({required DateTime? lastStart, required int cycleLen, required int periodLen}) async {
  final prefs = await CycleNotifyPrefs.load();
  await Repo.clearScheduled('/tools/cycle');
  if (lastStart == null || !prefs.master) return;

  final now = DateTime.now();
  final horizon = now.add(const Duration(days: 42));
  final ov = cycleLen - 14;
  final rows = <Rec>[];
  void add(String key, DateTime day, String title, String body, String icon) {
    final at = DateTime(day.year, day.month, day.day, 9);
    if (!prefs.enabled(key) || at.isBefore(now) || at.isAfter(horizon)) return;
    rows.add({'title': title, 'body': body, 'category': 'care', 'label': 'Cycle', 'icon': icon, 'route': '/tools/cycle', 'scheduled_for': utc(at)});
  }

  var start = dayStart(lastStart);
  while (start.add(Duration(days: cycleLen)).isBefore(dayStart(now))) {
    start = start.add(Duration(days: cycleLen));
  }
  for (int k = 0; k < 3; k++) {
    final s = start.add(Duration(days: cycleLen * k));
    final next = s.add(Duration(days: cycleLen));
    if (k > 0) {
      add('menstrual', s, 'Your period may start around today',
          'Be gentle with yourself. A warm drink, a heat pack and an easy evening can help. This is an estimate, so your body may run a little early or late.', 'water_drop');
    }
    add('follicular', s.add(Duration(days: periodLen)), 'Energy on the rise',
        'You are likely entering your follicular phase. Many people feel more motivated now, so it is a good time to start something new.', 'eco');
    add('ovulation', s.add(Duration(days: ov - 3)), 'Your ovulation window may be starting',
        'You might feel extra energetic and social over the next few days. A great time for group study and presentations. Remember to keep hydrated.', 'auto_awesome');
    add('luteal', s.add(Duration(days: ov + 2)), 'Time to slow down gently',
        'You are probably in your luteal phase. Regular meals, good sleep and kinder study pacing can help you feel balanced.', 'bedtime');
    add('premenstrual', next.subtract(const Duration(days: 5)), 'A little extra care this week',
        'In the days before a period you may feel more sensitive, tired or irritable. Hormone changes may play a part, and everyone is different. A short walk, stretching or calming music can help.', 'favorite');
    add('period_soon', next.subtract(const Duration(days: 2)), 'Period coming soon',
        'Your next period is estimated in about 2 days. Pop some pads or a cup in your bag, just in case.', 'event_upcoming');
  }
  await Repo.scheduleMany(rows);
}
