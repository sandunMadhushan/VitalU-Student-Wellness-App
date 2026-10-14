import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../core/push.dart';
import '../../core/step_sync.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/badge_ui.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../diet/pdqs_screen.dart' show pdqsBand;
import 'health_habits.dart';
import 'vitals_sheet.dart';

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

Future<R> _safe<R>(Future<R> f, R fallback) async {
  try {
    return await f;
  } catch (e) {
    debugPrint('home: $e');
    return fallback;
  }
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _loading = true;
  int _water = 0;
  int _steps = 0;
  Rec? _sleep;
  Rec? _mood;
  Rec? _openWindow;
  Rec? _nextWindow;
  Rec? _assessment;
  Rec? _pdqs;
  Rec? _stress;
  LatestVitals _vitals = const LatestVitals();
  List<HabitInsight> _habits = [];
  List<Rec> _badges = [];
  Map<String, DateTime> _earned = {};

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
    final p = AppState.instance.profile;
    // Picks up fresh steps from the phone's sensor so the dashboard is
    // current even if the student never opens the Activity tracker.
    await _safe(StepSync.sync(), null);
    final now = DateTime.now();
    final from = dayStart(now).subtract(const Duration(days: 6));
    final r = await Future.wait<Object?>([
      _safe(Repo.waterTotal(now), 0), // 0
      _safe(Repo.activityTotals(now), <String, dynamic>{'steps': 0}), // 1
      _safe(Repo.sleepLatest(), null), // 2
      _safe(Repo.moodLatest(), null), // 3
      _safe(Repo.currentAndNextWindow(), (null, null)), // 4
      _safe(Repo.waterByDay(7), <String, int>{}), // 5
      _safe(Repo.stepsByDay(from, now), <String, int>{}), // 6
      _safe(Repo.minutesByDay(from, now), <String, int>{}), // 7
      _safe(Repo.sleepBetween(from, now), <Rec>[]), // 8
      _safe(Repo.diversityBetween(from, now), <Rec>[]), // 9
      _safe(Repo.latestToolResult('pdqs'), null), // 10
      _safe(Repo.latestToolResult('stress'), null), // 11
      _safe(Repo.latestVitals(), const LatestVitals()), // 12
      _safe(Repo.badges(), <Rec>[]), // 13
      _safe(Repo.earnedBadges(), <String, DateTime>{}), // 14
      _safe(Repo.assessments(), <Rec>[]), // 15
      (p?.isFemale ?? false) ? _safe(Repo.dailyLogsSince(now.subtract(const Duration(days: 14))), <Rec>[]) : Future.value(<Rec>[]), // 16
    ]);
    _water = r[0] as int;
    _steps = ((r[1] as Rec)['steps'] as num?)?.toInt() ?? 0;
    final s = r[2] as Rec?;
    _sleep = (s != null && now.difference(DateTime.parse(s['sleep_date'])).inDays <= 1) ? s : null;
    final m = r[3] as Rec?;
    _mood = (m != null && now.difference(DateTime.parse(m['logged_at']).toLocal()).inHours < 24) ? m : null;
    final (open, next) = r[4] as (Rec?, Rec?);
    _openWindow = open;
    _nextWindow = next;
    _assessment = open == null ? null : await _safe(Repo.assessmentFor(open['id']), null);
    _pdqs = r[10] as Rec?;
    _stress = r[11] as Rec?;
    _vitals = r[12] as LatestVitals;
    _badges = r[13] as List<Rec>;
    _earned = r[14] as Map<String, DateTime>;
    final completed = (r[15] as List<Rec>).where((a) => a['status'] == 'completed').firstOrNull;
    _habits = healthHabits(HabitSignals(
      waterByDay: r[5] as Map<String, int>,
      waterGoal: p?.waterGoalMl ?? 2500,
      stepsByDay: r[6] as Map<String, int>,
      minutesByDay: r[7] as Map<String, int>,
      stepGoal: p?.stepGoal ?? 8000,
      sleep: r[8] as List<Rec>,
      diversity: r[9] as List<Rec>,
      pdqs: _pdqs,
      assessment: completed,
      cycleLogs: r[16] as List<Rec>,
    ));
    await _safe(AppState.instance.refreshUnread(), null);
    if (mounted) setState(() => _loading = false);
  }

  /// "Good Morning", "Good Afternoon" or "Good Evening", always title case.
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
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
      builder: (context, _) => VPage(
        header: _HomeHeader(greeting: _greeting, name: AppState.instance.profile?.firstName),
        nav: NavTab.home,
        onRefresh: _load,
        topPadding: Sp.xs,
        children: _loading ? [const Loading()] : _children(),
      ),
    );
  }

  List<Widget> _children() {
    final p = AppState.instance.profile;
    final upcoming = _nextWindow == null ? null : DateTime.parse(_nextWindow!['opens_at']).toLocal();
    final soon = upcoming != null && upcoming.difference(DateTime.now()).inDays <= 21;
    return [
      _hero(),
      if (_windowActive) _assessmentOpenCard() else if (soon) _assessmentSoonCard(upcoming),
      SectionHeader('Daily health updates', subtitle: DateFormat('EEEE, d MMMM').format(DateTime.now())),
      TileGrid(gap: 10, children: _indicatorTiles(p)),
      const SectionHeader('Your key habits', subtitle: 'From your recent logs and health assessments'),
      _habitsCard(),
      _consultCard(),
      SectionHeader('Your badges', trailing: TextLinkButton('See all', onTap: () => _go('/milestones'))),
      _badgesRow(),
      _progressCard(),
      if (!_windowActive && !soon && _nextWindow != null)
        ListGroup(children: [
          ListRow(
            icon: Symbols.assignment_rounded,
            color: AppColors.primary,
            title: 'Next periodic health assessment',
            value: DateFormat('d MMM').format(upcoming!),
            onTap: () => _go('/assessments'),
          ),
        ]),
    ];
  }

  // ---------------------------------------------------------------------------
  // Hero

  Widget _hero() {
    final dark = AppColors.isDark;
    final mood = _mood == null ? null : moodInfo(_mood!['mood']);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.xl),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          Color.alphaBlend(AppColors.primary.withValues(alpha: dark ? 0.30 : 0.16), AppColors.surfaceContainerLowest),
          Color.alphaBlend(AppColors.water.withValues(alpha: dark ? 0.12 : 0.06), AppColors.surfaceContainerLowest),
        ]),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 4, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(
                TextSpan(text: 'Take care of\nyour ', children: [TextSpan(text: 'health.', style: TextStyle(color: AppColors.primary))]),
                style: T.headlineLg.lh(1.15),
              ),
              const SizedBox(height: 6),
              Text('Small steps, every day.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              Material(
                color: AppColors.surfaceContainerLowest.withValues(alpha: dark ? 0.6 : 0.9),
                borderRadius: BorderRadius.circular(Rad.full),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.full),
                  onTap: () => showMoodPicker(context, onSaved: _load),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(mood?.$2 ?? Symbols.mood_rounded, size: 18, color: AppColors.mind, fill: 1),
                      const SizedBox(width: 6),
                      Text(mood == null ? 'How are you feeling?' : 'Feeling ${mood.$1.toLowerCase()}', style: T.labelMd),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        SizedBox(height: 168, width: 128, child: Image.asset('assets/images/hero_doctor.webp', fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // Periodic assessment

  Widget _assessmentOpenCard() {
    final w = _openWindow!;
    final closes = DateTime.parse(w['closes_at']).toLocal();
    final started = _assessment != null;
    return _AlertCard(
      image: 'assessment',
      color: AppColors.primary,
      kicker: 'Open until ${DateFormat('d MMM').format(closes)}',
      title: 'Your periodic health assessment is open',
      text: 'About ${w['estimated_minutes'] ?? 6} minutes. Answers are pooled anonymously to plan campus health support.',
      action: started ? 'Continue' : 'Start now',
      onTap: () => _go('/assessments/run'),
    );
  }

  Widget _assessmentSoonCard(DateTime opens) {
    final days = DateTime(opens.year, opens.month, opens.day).difference(dayStart(DateTime.now())).inDays;
    return _AlertCard(
      image: 'assessment',
      color: AppColors.warning,
      kicker: days <= 0 ? 'Opens today' : (days == 1 ? 'Opens tomorrow' : 'Opens in $days days'),
      title: 'Get ready: your next health assessment is coming up',
      text: 'It opens on ${DateFormat('EEEE, d MMMM').format(opens)}. Have your latest height, weight and waist measurements handy.',
      action: 'Remind me',
      onTap: () async {
        await Repo.schedule(
          title: 'Health assessment now open',
          body: 'Your ${_nextWindow!['term']} assessment is open. It takes about 6 minutes.',
          category: 'milestone',
          label: 'Assessment',
          icon: 'event_upcoming',
          route: '/assessments',
          at: opens,
        );
        if (mounted) toast(context, "We'll remind you when it opens.");
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Daily health updates

  List<Widget> _indicatorTiles(Profile? p) {
    final waterGoal = p?.waterGoalMl ?? 2500;
    final stepGoal = p?.stepGoal ?? 8000;
    final sleepGoal = ((p?.sleepGoalHours ?? 8) * 60).round();
    final sleepMin = _sleep == null ? 0 : Repo.sleepMinutes(_sleep!);
    final measured = p?.measuredAt == null ? null : 'Updated ${DateFormat('d MMM').format(p!.measuredAt!.toLocal())}';
    String when(DateTime d) => DateFormat('d MMM').format(d);
    (String, Color) pct(num v, num goal) {
      final f = goal <= 0 ? 0.0 : v / goal;
      return ('${(f * 100).round()}%', f >= 1 ? AppColors.tertiary : (f >= 0.5 ? AppColors.warning : AppColors.onSurfaceVariant));
    }

    Color band(int level) => switch (level) {
          0 => AppColors.tertiary,
          1 => AppColors.warning,
          2 => AppColors.activity,
          _ => AppColors.error,
        };

    final bmi = p?.bmi;
    final bmiCat = bmi == null ? null : Calc.bmiCategory(bmi);
    final whr = p?.whr;
    final whrCat = whr == null ? null : Calc.whrCategory(whr, p?.sex ?? 'female').$1;
    final pdqsScore = (_pdqs?['score'] as num?)?.round();
    final stressScore = (_stress?['score'] as num?)?.round();
    final stressLevel = _stress?['category'] as String?;
    final bp = _vitals.bp, fbg = _vitals.fastingGlucose, tg = _vitals.triglycerides;

    Future<void> logVitals() async {
      if (await showVitalsSheet(context)) _load();
    }

    return [
      _HealthTile(
        image: 'bmi',
        label: 'BMI',
        value: bmi?.toStringAsFixed(1) ?? '–',
        status: bmiCat == null ? null : (bmiCat == 'Normal Weight' ? 'Healthy' : bmiCat),
        statusColor: switch (bmiCat) {
          'Normal Weight' => AppColors.tertiary,
          'Overweight' => AppColors.warning,
          'Obesity' => AppColors.error,
          _ => AppColors.water,
        },
        caption: bmi == null ? 'Add height and weight' : measured,
        onTap: () => _go('/tools/bmi'),
      ),
      _HealthTile(
        image: 'whr',
        label: 'Waist-to-hip ratio',
        value: whr?.toStringAsFixed(2) ?? '–',
        status: whrCat?.replaceAll(' Risk', ' risk'),
        statusColor: switch (whrCat) {
          'Low Risk' => AppColors.tertiary,
          'Moderate Risk' => AppColors.warning,
          _ => AppColors.error,
        },
        caption: whr == null ? 'Add waist and hip' : measured,
        onTap: () => _go('/tools/whr'),
      ),
      _HealthTile(
        image: 'diet',
        label: 'Diet quality (PDQS)',
        value: pdqsScore?.toString() ?? '–',
        unit: pdqsScore == null ? null : '/ 42',
        status: pdqsScore == null ? null : pdqsBand(pdqsScore).$1.replaceAll(' diet quality', ''),
        statusColor: pdqsScore == null ? null : pdqsBand(pdqsScore).$2,
        caption: _pdqs == null ? 'Take the weekly check-in' : 'Checked ${when(DateTime.parse(_pdqs!['created_at']).toLocal())}',
        onTap: () => _go('/diet/pdqs'),
      ),
      _HealthTile(
        image: 'water',
        label: 'Water today',
        value: Fmt.litres(_water),
        unit: 'L',
        status: pct(_water, waterGoal).$1,
        statusColor: pct(_water, waterGoal).$2,
        caption: 'Goal ${Fmt.litres(waterGoal)} L',
        progress: _water / waterGoal,
        progressColor: AppColors.water,
        onTap: () => _go('/tools/water'),
      ),
      _HealthTile(
        image: 'steps',
        label: 'Steps today',
        value: Fmt.thousands(_steps),
        status: pct(_steps, stepGoal).$1,
        statusColor: pct(_steps, stepGoal).$2,
        caption: 'Goal ${Fmt.thousands(stepGoal)}',
        progress: _steps / stepGoal,
        progressColor: AppColors.activity,
        onTap: () => _go('/tools/activity'),
      ),
      _HealthTile(
        image: 'sleep',
        label: 'Sleep last night',
        value: sleepMin == 0 ? '–' : Fmt.hm(sleepMin).replaceAll(' 00m', ''),
        status: sleepMin == 0 ? null : pct(sleepMin, sleepGoal).$1,
        statusColor: pct(sleepMin, sleepGoal).$2,
        caption: sleepMin == 0 ? 'Tap to log your sleep' : 'Goal ${(sleepGoal / 60).round()} h',
        progress: sleepMin == 0 ? null : sleepMin / sleepGoal,
        progressColor: AppColors.sleep,
        onTap: () => _go('/tools/sleep'),
      ),
      _HealthTile(
        image: 'stress',
        label: 'Stress (DASS-21)',
        value: stressScore?.toString() ?? '–',
        unit: stressScore == null ? null : '/ 42',
        status: stressLevel,
        statusColor: switch (stressLevel) {
          'Normal' => AppColors.tertiary,
          'Mild' => AppColors.warning,
          'Moderate' => AppColors.activity,
          _ => AppColors.error,
        },
        caption: _stress == null ? 'Take the 3-minute check' : 'Checked ${when(DateTime.parse(_stress!['created_at']).toLocal())}',
        onTap: () => _go('/tools/stress'),
      ),
      _HealthTile(
        image: 'bp',
        label: 'Blood pressure',
        value: bp == null ? '–' : '${bp.value.round()}/${bp.extra!.round()}',
        unit: bp == null ? null : 'mmHg',
        status: bp == null ? null : VitalBands.bp(bp.value, bp.extra!).$1,
        statusColor: bp == null ? null : band(VitalBands.bp(bp.value, bp.extra!).$2),
        caption: bp == null ? 'Tap to log a reading' : 'Last recorded ${when(bp.at)}',
        onTap: logVitals,
      ),
      _HealthTile(
        image: 'glucose',
        label: 'Fasting blood glucose',
        value: fbg == null ? '–' : fbg.value.round().toString(),
        unit: fbg == null ? null : 'mg/dL',
        status: fbg == null ? null : VitalBands.fastingGlucose(fbg.value).$1,
        statusColor: fbg == null ? null : band(VitalBands.fastingGlucose(fbg.value).$2),
        caption: fbg == null ? 'Tap to log a reading' : 'Last recorded ${when(fbg.at)}',
        onTap: logVitals,
      ),
      _HealthTile(
        image: 'tg',
        label: 'Triglycerides',
        value: tg == null ? '–' : tg.value.round().toString(),
        unit: tg == null ? null : 'mg/dL',
        status: tg == null ? null : VitalBands.triglycerides(tg.value).$1,
        statusColor: tg == null ? null : band(VitalBands.triglycerides(tg.value).$2),
        caption: tg == null ? 'Tap to log a reading' : 'Last recorded ${when(tg.at)}',
        onTap: logVitals,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Habits, consultation, badges, progress

  Widget _habitsCard() {
    if (_habits.isEmpty) {
      return VCard(
        child: Row(children: [
          Icon(Symbols.insights_rounded, color: AppColors.primary, fill: 1),
          const SizedBox(width: 12),
          Expanded(child: Text('Log water, meals, activity and sleep for a few days and VitalU will point out the habits that matter most for you.', style: T.bodyMd.c(AppColors.onSurfaceVariant))),
        ]),
      );
    }
    return ListGroup(dividerIndent: 72, children: [
      for (final h in _habits.take(5))
        InkWell(
          onTap: () => _go(h.route),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/icons3d/${h.image}.jpg', width: 44, height: 44, fit: BoxFit.cover)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(h.good ? Symbols.check_circle_rounded : Symbols.flag_rounded, size: 16, color: h.good ? AppColors.tertiary : AppColors.warning, fill: 1),
                    const SizedBox(width: 6),
                    Expanded(child: Text(h.title, style: T.labelLg.w(FontWeight.w700))),
                  ]),
                  const SizedBox(height: 2),
                  Text(h.detail, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(h.source, style: T.labelSm.c(AppColors.outline)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _consultCard() {
    final dark = AppColors.isDark;
    final c = AppColors.primary;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.xl),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          Color.alphaBlend(c.withValues(alpha: dark ? 0.32 : 0.18), AppColors.surfaceContainerLowest),
          Color.alphaBlend(c.withValues(alpha: dark ? 0.12 : 0.05), AppColors.surfaceContainerLowest),
        ]),
      ),
      padding: const EdgeInsets.all(Sp.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/icons3d/consult.jpg', width: 64, height: 64, fit: BoxFit.cover)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Anonymous consultation', style: T.labelSm.c(c).w(FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Need health advice? Ask the health centre privately', style: T.headlineSm),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        PrimaryButton('Ask anonymously', leadingIcon: Symbols.lock_rounded, onTap: () => _go('/consult')),
        const SizedBox(height: 8),
        Center(
          child: TextLinkButton('Emergency? Call 1990 or get help now', leading: Symbols.emergency_rounded, color: AppColors.error, onTap: () => _go('/help')),
        ),
      ]),
    );
  }

  Widget _badgesRow() {
    final earned = _badges.where((b) => _earned.containsKey(b['code'])).toList()..sort((a, b) => _earned[b['code']]!.compareTo(_earned[a['code']]!));
    if (earned.isEmpty) {
      return VCard(
        onTap: () => _go('/milestones'),
        child: Row(children: [
          const BadgeArt(code: 'aqua_achiever', size: 52, locked: true, ribbon: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No badges yet', style: T.headlineSm),
              const SizedBox(height: 2),
              Text('Reach your water goal three days in a row to earn Aqua Achiever.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ]),
      );
    }
    return FullBleed(
      child: SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Sp.margin),
          itemCount: earned.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final b = earned[i];
            return SizedBox(
              width: 96,
              child: VCard(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
                onTap: () => showBadgePopup(context, code: b['code'], title: b['title'], description: b['description'], icon: b['icon'], category: b['category']),
                child: Column(children: [
                  BadgeArt(code: b['code'], icon: b['icon'], category: b['category'], size: 58, ribbon: false),
                  const SizedBox(height: 6),
                  Text(b['title'], style: T.labelSm.semi, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _progressCard() => VCard(
        onTap: () => _go('/progress'),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/icons3d/progress.jpg', width: 60, height: 60, fit: BoxFit.cover)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My progress', style: T.headlineSm),
              const SizedBox(height: 2),
              Text('Steps, water, activity, sleep, stress and diet quality over time', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          Icon(Symbols.chevron_right_rounded, color: AppColors.outline),
        ]),
      );
}

/// Greeting on the left, notifications and avatar on the same row.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.greeting, this.name});
  final String greeting;
  final String? name;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.margin, 10, 10, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(name == null ? greeting : '$greeting,', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
              if (name != null) Text(name!, style: T.headlineLg, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          CircleButton(Symbols.notifications_rounded, onTap: () => context.push('/notifications'), badge: AppState.instance.unreadCount > 0),
          const SizedBox(width: 4),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Avatar(size: 40, ring: false, onTap: () => context.go('/profile'))),
        ]),
      );
}

/// One daily health indicator: a realistic icon, the value and a status.
class _HealthTile extends StatelessWidget {
  const _HealthTile({
    required this.image,
    required this.label,
    required this.value,
    this.unit,
    this.status,
    this.statusColor,
    this.caption,
    this.progress,
    this.progressColor,
    required this.onTap,
  });
  final String image;
  final String label;
  final String value;
  final String? unit;
  final String? status;
  final Color? statusColor;
  final String? caption;
  final double? progress;
  final Color? progressColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sc = statusColor ?? AppColors.onSurfaceVariant;
    return VCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/icons3d/$image.jpg', width: 44, height: 44, fit: BoxFit.cover)),
          const SizedBox(width: 8),
          Expanded(
            child: status == null
                ? const SizedBox()
                : Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: sc.withValues(alpha: AppColors.isDark ? 0.2 : 0.12), borderRadius: BorderRadius.circular(Rad.full)),
                      child: Text(status!, style: T.labelSm.c(sc).w(FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(label, style: T.labelMd.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        MetricValue(value, unit: unit, size: 22),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!, style: T.bodySm.c(AppColors.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        if (progress != null) ...[
          const SizedBox(height: 8),
          Bar(value: progress!, height: 5, color: progressColor),
        ],
      ]),
    );
  }
}

/// A tinted call-to-action card with a 3D icon, used for assessment alerts.
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.image, required this.color, required this.kicker, required this.title, required this.text, required this.action, required this.onTap});
  final String image;
  final Color color;
  final String kicker;
  final String title;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.xl),
        color: Color.alphaBlend(color.withValues(alpha: dark ? 0.2 : 0.1), AppColors.surfaceContainerLowest),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/icons3d/$image.jpg', width: 54, height: 54, fit: BoxFit.cover)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Symbols.notifications_active_rounded, size: 14, color: color, fill: 1),
                const SizedBox(width: 4),
                Text(kicker, style: T.labelSm.c(color).w(FontWeight.w800)),
              ]),
              const SizedBox(height: 2),
              Text(title, style: T.headlineSm),
              const SizedBox(height: 4),
              Text(text, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        PrimaryButton(action, color: color, height: 46, onTap: onTap),
      ]),
    );
  }
}

/// BMI and waist-to-hip ratio, each with its value, status and a zoned scale
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
