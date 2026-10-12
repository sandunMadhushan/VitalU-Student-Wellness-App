import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../core/push.dart';
import '../../core/step_sync.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../assessments/assessment_data.dart';
import 'breathing.dart';

const moods = <(String, IconData, String)>[
  ('Centered', Symbols.self_improvement_rounded, 'Clear and steady'),
  ('Calm', Symbols.sentiment_calm_rounded, 'Relaxed'),
  ('Joyful', Symbols.sentiment_very_satisfied_rounded, 'Good energy'),
  ('Tired', Symbols.bedtime_rounded, 'Needs rest'),
  ('Stressed', Symbols.sentiment_stressed_rounded, 'Heavy workload'),
  ('Anxious', Symbols.sentiment_worried_rounded, 'Racing thoughts'),
];

(String, IconData, String) moodInfo(String? m) => moods.firstWhere((e) => e.$1 == m, orElse: () => moods.first);

Future<void> showMoodPicker(BuildContext context, {VoidCallback? onSaved}) async {
  String? picked;
  final note = TextEditingController();
  await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('How are you feeling?', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('Only you can see this.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in moods) VChip(m.$1, icon: m.$2, selected: picked == m.$1, selectedColor: AppColors.mind, onTap: () => set(() => picked = m.$1)),
          ]),
          const SizedBox(height: Sp.md),
          VTextField(controller: note, hint: 'Add a note (optional)', maxLines: 3),
          const SizedBox(height: Sp.md),
          PrimaryButton('Save', onTap: picked == null
              ? null
              : () async {
                  await Repo.addMood(picked!, note: note.text.trim().isEmpty ? null : note.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                  onSaved?.call();
                }),
        ]);
      }));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _loading = true;
  int _water = 0;
  int _steps = 0;
  int _activeMinutes = 0;
  int _mealsToday = 0;
  int _diversityToday = 0;
  int _diversityWeek = 0;
  Rec? _sleep;
  Rec? _mood;
  Rec? _openWindow;
  Rec? _nextWindow;
  Rec? _assessment;

  // Weekly snapshots used to compare this week's average against each
  // tracker's baseline requirement.
  Map<String, int> _waterWeek = {};
  Map<String, int> _stepsWeek = {};
  Map<String, int> _minutesWeek = {};
  List<Rec> _sleepWeek = [];
  List<Rec> _moodWeek = [];

  /// WHO/IPAQ baseline: at least 150 minutes of moderate activity a week.
  static const _activeMinutesBaseline = 150;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => Push.askOnce());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refreshes steps (and everything else) when the student comes back to
    // the app, so the dashboard reflects what the phone counted meanwhile.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      // Picks up fresh steps from the phone's sensor so the dashboard is
      // current even if the student never opens the Activity tracker.
      await StepSync.sync();
      final now = DateTime.now();
      final today = isoDate(now);
      final ws = weekStart(now);
      final results = await Future.wait([
        Repo.waterTotal(now),
        Repo.activityTotals(now),
        Repo.sleepLatest(),
        Repo.moodLatest(),
        Repo.currentAndNextWindow(),
        Repo.mealsOn(now),
        Repo.diversityBetween(ws, now),
        Repo.waterByDay(7),
        Repo.stepsByDay(ws, ws.add(const Duration(days: 6))),
        Repo.minutesByDay(ws, ws.add(const Duration(days: 6))),
        Repo.sleepBetween(ws, now),
        Repo.moodsSince(ws),
      ]);
      _water = results[0] as int;
      final act = results[1] as Rec;
      _steps = act['steps'] as int;
      _activeMinutes = act['minutes'] as int;
      final s = results[2] as Rec?;
      _sleep = (s != null && now.difference(DateTime.parse(s['sleep_date'])).inDays <= 1) ? s : null;
      final m = results[3] as Rec?;
      _mood = (m != null && now.difference(DateTime.parse(m['logged_at']).toLocal()).inHours < 24) ? m : null;
      final (open, next) = results[4] as (Rec?, Rec?);
      _openWindow = open;
      _nextWindow = next;
      _assessment = open == null ? null : await Repo.assessmentFor(open['id']);
      _mealsToday = (results[5] as List).length;
      final diversityRows = results[6] as List<Rec>;
      _diversityToday = diversityRows.where((r) => r['log_date'] == today).map((r) => r['food_group']).toSet().length;
      _diversityWeek = diversityRows.map((r) => r['food_group']).toSet().length;
      _waterWeek = results[7] as Map<String, int>;
      _stepsWeek = results[8] as Map<String, int>;
      _minutesWeek = results[9] as Map<String, int>;
      _sleepWeek = results[10] as List<Rec>;
      _moodWeek = results[11] as List<Rec>;
      await AppState.instance.refreshUnread();
    } catch (e) {
      debugPrint('home load: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool get _windowActive => _openWindow != null && _assessment?['status'] != 'completed';

  Future<void> _go(String path) async {
    await context.push(path);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final name = AppState.instance.profile?.firstName;
        return VPage(
          header: MainHeader(name == null ? _greeting : '$_greeting, $name'),
          nav: NavTab.home,
          onRefresh: _load,
          topPadding: 0,
          children: _loading ? [const Loading()] : _children(),
        );
      },
    );
  }

  List<Widget> _children() {
    final p = AppState.instance.profile;
    final waterGoal = p?.waterGoalMl ?? 2500;
    final stepGoal = p?.stepGoal ?? 8000;
    final sleepGoalMin = ((p?.sleepGoalHours ?? 8) * 60).round();
    final sleepMin = _sleep == null ? 0 : Repo.sleepMinutes(_sleep!);
    final mood = _mood == null ? null : moodInfo(_mood!['mood']);

    return [
      HeroBanner(
        title: 'Track your health,\nstay in control',
        subtitle: DateFormat('EEEE, d MMMM').format(DateTime.now()),
        accent: AppColors.primary,
        illustration: 'healthy_habit_bh5w',
      ),
      if (_windowActive) _assessmentCard(),
      _todayCard(
        water: (_water, waterGoal),
        steps: (_steps, stepGoal),
        sleep: (sleepMin, sleepGoalMin),
        activeMinutes: _activeMinutes,
      ),
      TileGrid(children: [
        MetricTile(
          label: 'Meals',
          icon: Symbols.restaurant_rounded,
          color: AppColors.nutrition,
          value: '$_mealsToday',
          unit: 'logged',
          caption: _mealsToday == 0 ? 'Nothing yet today' : 'Today',
          onTap: () => _go('/diet'),
        ),
        MetricTile(
          label: 'Food variety',
          icon: Symbols.nutrition_rounded,
          color: AppColors.nutrition,
          value: '$_diversityToday',
          unit: 'of 8',
          caption: 'Food groups today',
          progress: _diversityToday / 8,
          onTap: () => _go('/diet/diversity'),
        ),
        MetricTile(
          label: 'Mood',
          icon: mood?.$2 ?? Symbols.mood_rounded,
          color: AppColors.mind,
          value: mood?.$1 ?? '–',
          caption: mood?.$3 ?? 'Tap to check in',
          onTap: () => showMoodPicker(context, onSaved: _load),
        ),
      ]),
      SectionHeader('Body', trailing: p?.measuredAt == null ? null : Text('Updated ${DateFormat('d MMM').format(p!.measuredAt!.toLocal())}', style: T.labelMd.c(AppColors.onSurfaceVariant))),
      bodyMetricTiles(p, _go),
      SectionHeader('Progress', subtitle: 'This week versus your baseline', trailing: TextLinkButton('Full view', onTap: () => _go('/progress'))),
      _progressSection(p, waterGoal: waterGoal, stepGoal: stepGoal, sleepGoalMin: sleepGoalMin),
      if (!_windowActive && _nextWindow != null)
        ListGroup(children: [
          ListRow(
            icon: Symbols.assignment_rounded,
            color: AppColors.primary,
            title: 'Next health assessment',
            value: DateFormat('d MMM').format(DateTime.parse(_nextWindow!['opens_at']).toLocal()),
            onTap: () => _go('/assessments'),
          ),
        ]),
      const SectionHeader('Explore'),
      ListGroup(children: [
        ListRow(icon: Symbols.air_rounded, color: AppColors.mind, title: 'Breathing exercise', subtitle: 'One minute to reset', onTap: () => showBreathing(context)),
        ListRow(icon: Symbols.menu_book_rounded, color: AppColors.water, title: 'Health library', subtitle: 'Short reads on sleep, food and stress', onTap: () => _go('/library')),
        ListRow(icon: Symbols.lab_profile_rounded, color: AppColors.heart, title: 'Blood report reader', subtitle: 'Understand your lab results', onTap: () => _go('/blood-report')),
        ListRow(icon: Symbols.stethoscope_rounded, color: AppColors.primary, title: 'Talk to a professional', subtitle: 'Campus counsellors and doctors', onTap: () => _go('/professionals')),
      ]),
      ListGroup(children: [
        ListRow(
          icon: Symbols.emergency_rounded,
          color: AppColors.error,
          title: 'Emergency & support lines',
          subtitle: '1990 ambulance · 1926 mental health',
          onTap: () => _go('/help'),
        ),
      ]),
    ];
  }

  /// Hero summary: water, steps and sleep as a row of soft pastel ring cards.
  Widget _todayCard({required (int, int) water, required (int, int) steps, required (int, int) sleep, required int activeMinutes}) {
    return VCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Today', style: T.headlineMd)),
          if (activeMinutes > 0) TagPill('$activeMinutes min active', icon: Symbols.bolt_rounded, fill: 1, bg: AppColors.tint(AppColors.activity), fg: AppColors.activity),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: MetricRingCard(
              icon: Symbols.water_drop_rounded,
              color: AppColors.water,
              label: 'Water',
              value: Fmt.litres(water.$1),
              unit: 'L',
              goal: '${Fmt.litres(water.$2)} L',
              progress: water.$2 == 0 ? 0 : water.$1 / water.$2,
              onTap: () => _go('/tools/water'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MetricRingCard(
              icon: Symbols.directions_walk_rounded,
              color: AppColors.activity,
              label: 'Steps',
              value: Fmt.thousands(steps.$1),
              goal: Fmt.thousands(steps.$2),
              progress: steps.$2 == 0 ? 0 : steps.$1 / steps.$2,
              onTap: () => _go('/tools/activity'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MetricRingCard(
              icon: Symbols.bedtime_rounded,
              color: AppColors.sleep,
              label: 'Sleep',
              value: sleep.$1 == 0 ? '0h' : Fmt.hm(sleep.$1).replaceAll(' 0m', ''),
              goal: '${(sleep.$2 / 60).round()} h',
              progress: sleep.$2 == 0 ? 0 : sleep.$1 / sleep.$2,
              onTap: () => _go('/tools/sleep'),
            ),
          ),
        ]),
      ]),
    );
  }

  /// This week's average for every tracked habit, each measured against its
  /// own baseline requirement (a personal goal, or a health guideline for
  /// activity), with the fluctuation shown as a delta.
  Widget _progressSection(Profile? p, {required int waterGoal, required int stepGoal, required int sleepGoalMin}) {
    final now = DateTime.now();
    final ws = weekStart(now);
    final daysSoFar = now.difference(ws).inDays + 1;

    final waterAvg = _waterWeek.values.isEmpty ? 0 : (_waterWeek.values.fold<int>(0, (a, b) => a + b) / daysSoFar).round();
    final stepsAvg = _stepsWeek.values.isEmpty ? 0 : (_stepsWeek.values.fold<int>(0, (a, b) => a + b) / daysSoFar).round();
    final activeMinutesWeek = _minutesWeek.values.fold<int>(0, (a, b) => a + b);
    final sleepAvgMin = _sleepWeek.isEmpty ? 0 : (_sleepWeek.map(Repo.sleepMinutes).fold<int>(0, (a, b) => a + b) / _sleepWeek.length).round();
    final moodDays = _moodWeek.map((m) => isoDate(DateTime.parse(m['logged_at']).toLocal())).toSet().length;

    return ListGroup(children: [
      _progressRow('Water', Symbols.water_drop_rounded, AppColors.water, Fmt.litres(waterAvg), 'L/day avg', waterAvg, waterGoal, onTap: () => _go('/tools/water')),
      _progressRow('Sleep', Symbols.bedtime_rounded, AppColors.sleep, (sleepAvgMin / 60).toStringAsFixed(1), 'h/night avg', sleepAvgMin, sleepGoalMin, onTap: () => _go('/tools/sleep')),
      _progressRow('Steps', Symbols.directions_walk_rounded, AppColors.activity, Fmt.thousands(stepsAvg), '/day avg', stepsAvg, stepGoal, onTap: () => _go('/tools/activity')),
      _progressRow('Active minutes', Symbols.bolt_rounded, AppColors.activity, '$activeMinutesWeek', 'min this week', activeMinutesWeek, _activeMinutesBaseline, onTap: () => _go('/tools/activity')),
      _progressRow('Food variety', Symbols.nutrition_rounded, AppColors.nutrition, '$_diversityWeek', 'of 8 groups this week', _diversityWeek, 8, onTap: () => _go('/diet/diversity')),
      _progressRow('Mood check-ins', Symbols.mood_rounded, AppColors.mind, '$moodDays', 'of $daysSoFar days so far', moodDays, daysSoFar, onTap: () => showMoodPicker(context, onSaved: _load)),
    ]);
  }

  Widget _progressRow(String label, IconData icon, Color c, String value, String unit, num actual, num baseline, {required VoidCallback onTap}) {
    final pct = baseline <= 0 ? 1.0 : actual / baseline;
    final onTrack = pct >= 0.9;
    final deltaColor = onTrack ? AppColors.tertiary : (pct >= 0.5 ? AppColors.warning : AppColors.error);
    final deltaText = onTrack ? 'On track' : '${(pct * 100).clamp(0, 999).round()}% of baseline';
    return ListRow(
      icon: icon,
      color: c,
      title: label,
      subtitle: '$value $unit',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(onTrack ? Symbols.trending_up_rounded : Symbols.trending_down_rounded, size: 16, color: deltaColor),
        const SizedBox(width: 4),
        Text(deltaText, style: T.labelMd.c(deltaColor)),
      ]),
      onTap: onTap,
    );
  }

  Widget _assessmentCard() {
    final w = _openWindow!;
    final closes = DateTime.parse(w['closes_at']).toLocal();
    final answered = (_assessment?['answers'] as Map?)?.length ?? 0;
    final progress = answered / assessmentQuestions.length;
    final started = _assessment != null;
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(Symbols.assignment_rounded, fg: AppColors.primary, fill: 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Health assessment is open', style: T.headlineSm),
              const SizedBox(height: 2),
              Text('${w['term']} · closes ${DateFormat('d MMM').format(closes)} · about ${w['estimated_minutes'] ?? 5} min', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ]),
        if (started) ...[
          const SizedBox(height: Sp.md),
          Row(children: [
            Expanded(child: Bar(value: progress, height: 6)),
            const SizedBox(width: 10),
            Text('${(progress * 100).round()}%', style: T.labelMd.tnum.c(AppColors.onSurfaceVariant)),
          ]),
        ],
        const SizedBox(height: Sp.md),
        PrimaryButton(started ? 'Continue assessment' : 'Start assessment', onTap: () => _go('/assessments/run')),
        const SizedBox(height: 4),
        Center(
          child: TextLinkButton('Remind me tonight', onTap: () async {
            final now = DateTime.now();
            var at = DateTime(now.year, now.month, now.day, 20);
            if (at.isBefore(now)) at = now.add(const Duration(hours: 1));
            await Repo.schedule(
              title: 'Health assessment',
              body: 'Your ${w['term']} assessment is open. It takes about five minutes.',
              category: 'milestone',
              label: 'Assessment',
              icon: 'event_upcoming',
              route: '/assessments/run',
              at: at,
            );
            if (mounted) toast(context, "We'll remind you at ${DateFormat('h:mm a').format(at)}");
          }),
        ),
      ]),
    );
  }
}

//// BMI and waist-to-hip ratio, each with its value, status and a zoned scale
/// showing where the student sits.
Widget bodyMetricTiles(Profile? p, void Function(String) go) {
  final bmi = p?.bmi;
  final whr = p?.whr;
  final sex = p?.sex ?? 'female';
  final bmiCat = bmi == null ? null : Calc.bmiCategory(bmi);
  final bmiColor = switch (bmiCat) {
    'Normal Weight' => AppColors.tertiary,
    'Overweight' => AppColors.warning,
    'Obesity' => AppColors.error,
    'Underweight' => AppColors.water,
    _ => AppColors.onSurfaceVariant,
  };
  final whrCat = whr == null ? null : Calc.whrCategory(whr, sex).$1;
  final whrColor = switch (whrCat) {
    'Low Risk' => AppColors.tertiary,
    'Moderate Risk' => AppColors.warning,
    'High Risk' => AppColors.error,
    _ => AppColors.onSurfaceVariant,
  };
  final (wLow, wHigh) = Calc.whrThresholds(sex);
  return ListGroup(dividerIndent: 16, children: [
    _BodyRow(
      label: 'BMI',
      value: bmi?.toStringAsFixed(1),
      status: bmiCat == null ? 'Add height and weight' : (bmiCat == 'Normal Weight' ? 'Healthy weight' : bmiCat),
      color: bmiColor,
      min: 15,
      max: 35,
      stops: [(18.5, AppColors.water), (25, AppColors.tertiary), (30, AppColors.warning), (35, AppColors.error)],
      marker: bmi,
      onTap: () => go('/tools/bmi'),
    ),
    _BodyRow(
      label: 'Waist-to-hip ratio',
      value: whr?.toStringAsFixed(2),
      status: whrCat == null ? 'Add waist and hip' : whrCat.replaceAll('Risk', 'risk'),
      color: whrColor,
      min: 0.65,
      max: 1.1,
      stops: [(wLow, AppColors.tertiary), (wHigh, AppColors.warning), (1.1, AppColors.error)],
      marker: whr,
      onTap: () => go('/tools/whr'),
    ),
  ]);
}

class _BodyRow extends StatelessWidget {
  const _BodyRow({required this.label, required this.value, required this.status, required this.color, required this.min, required this.max, required this.stops, required this.marker, required this.onTap});
  final String label;
  final String? value;
  final String status;
  final Color color;
  final double min;
  final double max;
  final List<(double, Color)> stops;
  final double? marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 14, Sp.md, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: T.labelMd.c(AppColors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value ?? '–', style: T.metric(26)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (value != null) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6)],
                Text(status, style: T.labelMd.c(value == null ? AppColors.primary : color)),
                const SizedBox(width: 2),
                Icon(Symbols.chevron_right_rounded, size: 18, color: AppColors.outline),
              ]),
            ),
          ]),
          if (marker != null) ...[
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              double x(double v) => ((v - min) / (max - min)).clamp(0.0, 1.0) * w;
              final flex = [for (int i = 0; i < stops.length; i++) ((stops[i].$1 - (i == 0 ? min : stops[i - 1].$1)) * 1000).round().clamp(1, 1 << 20)];
              return SizedBox(
                height: 14,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 4,
                    height: 6,
                    child: Row(children: [
                      for (int i = 0; i < stops.length; i++)
                        Expanded(
                          flex: flex[i],
                          child: Container(
                            margin: EdgeInsets.only(right: i == stops.length - 1 ? 0 : 2),
                            decoration: BoxDecoration(color: stops[i].$2.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                    ]),
                  ),
                  Positioned(
                    left: x(marker!) - 7,
                    top: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.onSurface, width: 3),
                      ),
                    ),
                  ),
                ]),
              );
            }),
          ],
        ]),
      ),
    );
  }
}
