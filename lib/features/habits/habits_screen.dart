import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// One everyday habit worth a gentle nudge, drawn from what students most
/// often report: emotional or stress eating, long sitting stretches,
/// smoking or vaping, heavy screen time, low fruit intake, skipped
/// breakfasts, sugary drinks and frequent fast food.
class _Habit {
  const _Habit(this.key, this.icon, this.color, this.title, this.insight, this.tip, this.actionLabel, this.route);
  final String key;
  final IconData icon;
  final Color Function() color;
  final String title;
  final String insight;
  final String tip;
  final String actionLabel;
  final String route;
}

final _habits = <_Habit>[
  _Habit('sweet_cravings', Symbols.icecream_rounded, () => AppColors.nutrition, 'Sweet cravings when stressed',
      "Reaching for something sweet when you're tired or stressed is a normal response, not a lack of willpower — sugar gives a quick, short-lived lift.",
      "Next time a craving hits, pause for one minute and name what you're actually feeling. A short walk, water or a chat with a friend can meet the same need.",
      'Check in with yourself', '/tools/stress'),
  _Habit('sitting', Symbols.weekend_rounded, () => AppColors.activity, 'Long stretches of sitting',
      "Lecture halls, the library and screens make most of a student's day seated by default — it's the environment, not a character flaw.",
      'Stand and move for two to three minutes every hour. A reminder between lecture blocks makes it automatic rather than a decision.',
      'Log some movement', '/tools/activity'),
  _Habit('smoking', Symbols.smoke_free_rounded, () => AppColors.heart, 'Smoking or vaping',
      'Nicotine is genuinely addictive — this is a habit loop, not a failure of character. Most people who quit succeed after more than one attempt.',
      'Next time you reach for one, delay by ten minutes. Cravings usually peak and fade within that window.',
      'Get support to quit', '/professionals'),
  _Habit('screen_time', Symbols.hourglass_bottom_rounded, () => AppColors.mind, 'High screen time',
      "Apps are built to keep you scrolling — the pull you feel is by design, not a discipline problem.",
      'Try the 20-20-20 rule, and keep your phone out of arm\'s reach during focused study blocks.',
      'Track your screen time', '/tools/screen-time'),
  _Habit('low_fruit', Symbols.nutrition_rounded, () => AppColors.nutrition, 'Not enough fruit',
      'Fruit is easy to forget on a busy campus day, especially when canteen options lean toward rice and fried food.',
      'Keep a banana or an orange in your bag. The easiest habit changes need no decision in the moment.',
      'Check this week\'s variety', '/diet/diversity'),
  _Habit('skip_breakfast', Symbols.bakery_dining_rounded, () => AppColors.warning, 'Skipping breakfast',
      'Rushed mornings make breakfast the easiest meal to drop — but skipping it often leads to overeating later in the day.',
      'Keep something that needs zero prep ready to grab: leftover roti and dhal, or a boiled egg from the night before.',
      'Log breakfast', '/diet/log?type=breakfast'),
  _Habit('sugary_drinks', Symbols.emoji_food_beverage_rounded, () => AppColors.warning, 'Sugar-sweetened drinks',
      "Sweet drinks are everywhere on campus and easy to reach for without thinking — one bottle can hold a full day's added sugar.",
      'Swap one sweet drink a day for water or plain tea. Taste preferences shift within a couple of weeks.',
      'Log your water', '/tools/water'),
  _Habit('junk_food', Symbols.fastfood_rounded, () => AppColors.error, 'Frequent fried and packaged food',
      'Convenience and cost often make fried and packaged food the default near campus — it is not a lack of willpower.',
      'Try the healthy plate guide for just one meal today: more vegetables, less fried food.',
      'Open the plate guide', '/diet/plate'),
];

const _affirmations = [
  'Small, repeated choices shape health more than one big effort ever could.',
  "A slip isn't a failure — it's information. Notice it, and start again today.",
  'You are not your habits. You are the person choosing, one small moment at a time.',
  'Progress here is quiet and gradual — it rarely feels dramatic while it is happening.',
];

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});
  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  bool _loading = true;
  Map<String, DateTime> _active = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Repo.habitPledges();
      _active = {for (final r in rows) r['habit_key'] as String: DateTime.parse(r['started_at'])};
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(_Habit h) async {
    final on = !_active.containsKey(h.key);
    setState(() => on ? _active[h.key] = DateTime.now() : _active.remove(h.key));
    try {
      await Repo.setHabitPledge(h.key, on);
    } catch (_) {
      if (mounted) {
        setState(() => on ? _active.remove(h.key) : _active[h.key] = DateTime.now());
        toast(context, 'Could not save that right now.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _affirmations[DateTime.now().day % _affirmations.length];
    return VPage(
      header: const MainHeader('Habits'),
      nav: NavTab.habits,
      topPadding: 0,
      onRefresh: _load,
      children: [
        HeroBanner(
          title: 'Small changes,\nbig difference',
          subtitle: quote,
          accent: AppColors.cycle,
          illustration: 'mindfulness_scgo',
          illustrationHeight: 96,
        ),
        Text(
          "Small, steady swaps — not strict rules. Pick one that fits your week, pledge it, and build from there.",
          style: T.bodyMd.c(AppColors.onSurfaceVariant),
        ),
        if (_active.isNotEmpty)
          VCard(
            child: Row(children: [
              IconCircle(Symbols.flag_circle_rounded, size: 40, iconSize: 20, fg: AppColors.primary, fill: 1),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_active.length} active ${_active.length == 1 ? 'pledge' : 'pledges'}', style: T.labelLg.semi),
                  Text('Keep going, a little each day adds up.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
        if (_loading) const Loading() else for (final h in _habits) _card(h),
        const PrivacyNote('A supportive nudge, not a judgement. Your pledges are private to you.'),
      ],
    );
  }

  Widget _card(_Habit h) {
    final since = _active[h.key];
    final on = since != null;
    final days = on ? DateTime.now().difference(since).inDays + 1 : 0;
    final c = h.color();
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(h.icon, size: 40, iconSize: 20, fg: c, fill: 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.title, style: T.headlineSm),
              if (on) Text('Day $days of this pledge', style: T.labelMd.c(c)),
            ]),
          ),
          Switch(value: on, onChanged: (_) => _toggle(h)),
        ]),
        const SizedBox(height: 10),
        Text(h.insight, style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.45)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.tint(c), borderRadius: BorderRadius.circular(Rad.base)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.lightbulb_rounded, size: 18, color: c, fill: 1),
            const SizedBox(width: 8),
            Expanded(child: Text(h.tip, style: T.bodyMd.c(AppColors.onSurface))),
          ]),
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: TextLinkButton(h.actionLabel, leading: Symbols.arrow_forward_rounded, onTap: () => context.push(h.route))),
      ]),
    );
  }
}
