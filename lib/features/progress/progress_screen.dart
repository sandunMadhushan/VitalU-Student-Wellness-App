import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../core/health_report.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/charts.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../assessments/assessment_screens.dart';
import '../diet/pdqs_screen.dart' show pdqsBand;
import '../home/vitals_sheet.dart';
import '../diet/diet_science.dart' show diversityByDay;

Future<R> _safe<R>(Future<R> f, R fallback) async {
  try {
    return await f;
  } catch (e) {
    debugPrint('progress: $e');
    return fallback;
  }
}

/// Health progress over time: daily habits, health measures and the
/// periodic assessments.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _tab = 'Habits';
  bool _month = false;
  bool _loading = true;
  Map<String, int> _water = {};
  Map<String, int> _steps = {};
  Map<String, int> _minutes = {};
  List<Rec> _sleep = [];
  List<Rec> _moods = [];
  List<Rec> _diversity = [];
  List<Rec> _assessments = [];
  List<Rec> _stress = [];
  List<Rec> _pdqs = [];
  List<Rec> _bmi = [];
  List<Rec> _whr = [];
  LatestVitals _vitals = const LatestVitals();
  Map<String, DateTime> _earned = {};
  List<Rec> _badges = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final from = dayStart(now).subtract(const Duration(days: 27));
    final r = await Future.wait<Object?>([
      _safe(Repo.waterByDay(28), <String, int>{}),
      _safe(Repo.stepsByDay(from, now), <String, int>{}),
      _safe(Repo.minutesByDay(from, now), <String, int>{}),
      _safe(Repo.sleepBetween(from, now), <Rec>[]),
      _safe(Repo.moodsSince(from), <Rec>[]),
      _safe(Repo.diversityBetween(from, now), <Rec>[]),
      _safe(Repo.assessments(), <Rec>[]),
      _safe(Repo.toolResults('stress', limit: 8), <Rec>[]),
      _safe(Repo.toolResults('pdqs', limit: 8), <Rec>[]),
      _safe(Repo.toolResults('bmi', limit: 8), <Rec>[]),
      _safe(Repo.toolResults('whr', limit: 8), <Rec>[]),
      _safe(Repo.latestVitals(), const LatestVitals()),
      _safe(Repo.earnedBadges(), <String, DateTime>{}),
      _safe(Repo.badges(), <Rec>[]),
    ]);
    _water = r[0] as Map<String, int>;
    _steps = r[1] as Map<String, int>;
    _minutes = r[2] as Map<String, int>;
    _sleep = r[3] as List<Rec>;
    _moods = r[4] as List<Rec>;
    _diversity = r[5] as List<Rec>;
    _assessments = (r[6] as List<Rec>).where((a) => a['status'] == 'completed').toList();
    _stress = r[7] as List<Rec>;
    _pdqs = r[8] as List<Rec>;
    _bmi = r[9] as List<Rec>;
    _whr = r[10] as List<Rec>;
    _vitals = r[11] as LatestVitals;
    _earned = r[12] as Map<String, DateTime>;
    _badges = r[13] as List<Rec>;
    if (mounted) setState(() => _loading = false);
  }

  List<DateTime> _days(int n, {int offset = 0}) {
    final today = dayStart(DateTime.now());
    return [for (int i = n - 1 + offset; i >= offset; i--) today.subtract(Duration(days: i))];
  }

  double _avg(Iterable<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  Map<String, double> get _sleepByDay => {for (final s in _sleep) s['sleep_date'] as String: Repo.sleepMinutes(s) / 60.0};

  static const _moodScore = {'Joyful': 5.0, 'Centered': 4.5, 'Calm': 4.0, 'Tired': 2.5, 'Stressed': 2.0, 'Anxious': 1.5};

  /// Daily values for the last 7 days, or weekly averages for the last 4
  /// weeks, with matching labels. Days with no entry count as zero unless
  /// [skipEmpty] is set (for sleep and mood, where a gap means "not logged").
  (List<double>, List<String>) _series(double Function(DateTime d) valueOf, {bool skipEmpty = false}) {
    if (!_month) {
      final days = _days(7);
      return ([for (final d in days) valueOf(d)], [for (final d in days) DateFormat('E').format(d).substring(0, 1)]);
    }
    final weeks = [for (int i = 3; i >= 0; i--) _days(7, offset: i * 7)];
    return (
      [
        for (final wk in weeks) _avg(skipEmpty ? wk.map(valueOf).where((v) => v > 0) : wk.map(valueOf)),
      ],
      [for (final wk in weeks) DateFormat('d MMM').format(wk.first)],
    );
  }

  String? _trend(double Function(DateTime d) valueOf) {
    final cur = _days(7).map(valueOf).where((v) => v > 0), prev = _days(7, offset: 7).map(valueOf).where((v) => v > 0);
    final a = _avg(cur), b = _avg(prev);
    if (a == 0 || b == 0) return null;
    final p = ((a - b) / b * 100).round();
    if (p.abs() < 3) return 'Steady';
    return p > 0 ? '+$p%' : '$p%';
  }

  /// The Personal Health Report: results, analytics and recommendations.
  Future<void> _export() async {
    try {
      await HealthReport.share();
    } catch (e) {
      if (mounted) toast(context, 'Could not create the PDF.', error: true);
    }
  }

  Future<void> _targets() async {
    final p = AppState.instance.profile;
    double water = (p?.waterGoalMl ?? 2500).toDouble(), sleep = p?.sleepGoalHours ?? 8, steps = (p?.stepGoal ?? 8000).toDouble();
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          Widget row(String t, String v) => Row(children: [Expanded(child: Text(t, style: T.labelLg)), Text(v, style: T.labelLg.c(AppColors.primary))]);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Daily targets', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            row('Daily water', '${Fmt.litres(water)} L'),
            VSlider(value: water, min: 1500, max: 4000, divisions: 25, onChanged: (x) => set(() => water = x)),
            row('Sleep target', '${sleep.toStringAsFixed(1)} h'),
            VSlider(value: sleep, min: 6, max: 10, divisions: 8, onChanged: (x) => set(() => sleep = x)),
            row('Daily steps', Fmt.thousands(steps)),
            VSlider(value: steps, min: 3000, max: 15000, divisions: 24, onChanged: (x) => set(() => steps = x)),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save', onTap: () async {
              await AppState.instance.updateProfile({'water_goal_ml': water.round(), 'sleep_goal_hours': sleep, 'step_goal': steps.round()});
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('My progress', onLeading: () => goBack(context, '/home')),
      onRefresh: _load,
      topPadding: 0,
      children: [
        SizedBox(
          width: double.infinity,
          child: Segmented(small: false, options: const ['Habits', 'Health', 'Assessments'], value: _tab, onChanged: (v) => setState(() => _tab = v)),
        ),
        if (_loading)
          const Loading()
        else
          ...switch (_tab) {
            'Habits' => _habitsView(),
            'Health' => _healthView(),
            _ => _assessmentView(),
          },
        ListGroup(children: [
          ListRow(
            icon: Symbols.emoji_events_rounded,
            color: AppColors.warning,
            title: 'Badges',
            subtitle: _earned.isEmpty ? 'Log a few days to unlock the first one' : 'Earned ${_earned.length} so far',
            value: '${_earned.length}/${_badges.length}',
            onTap: () => context.push('/milestones'),
          ),
          ListRow(icon: Symbols.tune_rounded, color: AppColors.primary, title: 'Adjust targets', subtitle: 'Water, sleep and steps', onTap: _targets),
          ListRow(icon: Symbols.download_rounded, color: AppColors.water, title: 'Personal Health Report (PDF)', subtitle: 'Your results, last 7 days and recommendations', onTap: _export),
        ]),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Habits

  List<Widget> _habitsView() {
    final p = AppState.instance.profile;
    double water(DateTime d) => (_water[isoDate(d)] ?? 0) / 1000.0;
    double steps(DateTime d) => (_steps[isoDate(d)] ?? 0).toDouble();
    double minutes(DateTime d) => (_minutes[isoDate(d)] ?? 0).toDouble();
    double sleep(DateTime d) => _sleepByDay[isoDate(d)] ?? 0;
    double mood(DateTime d) => _avg(_moods.where((x) => isoDate(DateTime.parse(x['logged_at']).toLocal()) == isoDate(d)).map((x) => _moodScore[x['mood']] ?? 3.0));
    final varietyByDay = diversityByDay(_diversity);
    double variety(DateTime d) => (varietyByDay[isoDate(d)]?.length ?? 0).toDouble();

    final (sv, sl) = _series(steps);
    final (wv, wl) = _series(water);
    final (mv, ml) = _series(minutes);
    final (slv, sll) = _series(sleep, skipEmpty: true);
    final (dv, dl) = _series(variety);
    final (mov, mol) = _series(mood, skipEmpty: true);
    final unit = _month ? 'a day, weekly average' : 'a day';

    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Segmented(options: const ['7 days', '4 weeks'], value: _month ? '4 weeks' : '7 days', onChanged: (v) => setState(() => _month = v == '4 weeks')),
      ),
      _chart('Walking and daily steps', 'steps', AppColors.activity, Fmt.thousands(_avg(sv.where((v) => v > 0))), 'steps $unit', _trend(steps), sv, sl,
          goal: (p?.stepGoal ?? 8000).toDouble(), onTap: () => context.push('/tools/activity')),
      _chart('Water intake', 'water', AppColors.water, _avg(wv).toStringAsFixed(1), 'L $unit', _trend(water), wv, wl,
          goal: (p?.waterGoalMl ?? 2500) / 1000, onTap: () => context.push('/tools/water')),
      _chart('Physical activity', 'progress', AppColors.activity, _avg(mv).round().toString(), 'active min $unit', _trend(minutes), mv, ml,
          goal: 150 / 7, onTap: () => context.push('/tools/activity')),
      _chart('Sleep', 'sleep', AppColors.sleep, _avg(slv.where((x) => x > 0)).toStringAsFixed(1), 'h a night', _trend(sleep), slv, sll,
          goal: p?.sleepGoalHours ?? 8, onTap: () => context.push('/tools/sleep')),
      _chart('Food variety', 'diet', AppColors.nutrition, _avg(dv).toStringAsFixed(1), 'of 8 food groups $unit', _trend(variety), dv, dl,
          goal: 5, onTap: () => context.push('/diet/diversity')),
      _chart('Mood', 'stress', AppColors.mind, mov.any((v) => v > 0) ? _avg(mov.where((v) => v > 0)).toStringAsFixed(1) : '-', 'out of 5', null, mov, mol,
          onTap: () => context.push('/home')),
    ];
  }

  Widget _chart(String label, String image, Color color, String value, String? unit, String? trend, List<double> series, List<String> labels, {double? goal, VoidCallback? onTap}) {
    return VCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icons3d/$image.jpg', width: 36, height: 36, fit: BoxFit.cover)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: T.labelLg.w(FontWeight.w700))),
          if (trend != null) TagPill(trend == 'Steady' ? trend : '$trend vs last week', bg: AppColors.surfaceContainer),
        ]),
        const SizedBox(height: 10),
        MetricValue(value, unit: unit, size: 24),
        const SizedBox(height: Sp.md),
        BarChart(values: series, labels: labels, color: color, goal: goal, height: 96),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // Health measures

  List<Widget> _healthView() {
    final p = AppState.instance.profile;
    List<double> vals(List<Rec> rows) => [for (final r in rows.reversed) (r['score'] as num?)?.toDouble() ?? 0];
    List<String> dates(List<Rec> rows) => [for (final r in rows.reversed) DateFormat('d/M').format(DateTime.parse(r['created_at']).toLocal())];
    String when(DateTime d) => DateFormat('d MMM yyyy').format(d);

    Widget history(String title, String image, Color c, List<Rec> rows, String Function(Rec r) headline, String empty, String route, {double? goal}) => VCard(
          onTap: () => context.push(route),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icons3d/$image.jpg', width: 36, height: 36, fit: BoxFit.cover)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: T.labelLg.w(FontWeight.w700))),
              if (rows.isNotEmpty) Text(DateFormat('d MMM').format(DateTime.parse(rows.first['created_at']).toLocal()), style: T.labelSm.c(AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              Text(empty, style: T.bodyMd.c(AppColors.onSurfaceVariant))
            else ...[
              Text(headline(rows.first), style: T.headlineSm),
              if (rows.length > 1) ...[
                const SizedBox(height: Sp.md),
                BarChart(values: vals(rows), labels: dates(rows), color: c, goal: goal, height: 90),
              ],
            ],
          ]),
        );

    final bp = _vitals.bp, fbg = _vitals.fastingGlucose, tg = _vitals.triglycerides;
    return [
      const SectionHeader('Stress and diet'),
      history('Stress level (DASS-21)', 'stress', AppColors.mind, _stress, (r) => '${(r['score'] as num).round()} of 42 · ${r['category']}', 'Take the anxiety tracker to start seeing your stress over time.', '/tools/stress'),
      history('Dietary quality (PDQS)', 'diet', AppColors.nutrition, _pdqs, (r) => '${(r['score'] as num).round()} of 42 · ${pdqsBand(r['score'] as num).$1}', 'A weekly 2-minute check-in. Scored out of 42.', '/diet/pdqs', goal: 28),
      const SectionHeader('Body'),
      history('BMI', 'bmi', AppColors.body, _bmi, (r) => '${(r['score'] as num).toStringAsFixed(1)} · ${r['category']}',
          p?.bmi == null ? 'Add your height and weight.' : 'Current BMI ${p!.bmi!.toStringAsFixed(1)}. Recalculate in the BMI tool to build a history.', '/tools/bmi'),
      history('Waist-to-hip ratio', 'whr', AppColors.water, _whr, (r) => '${(r['score'] as num).toStringAsFixed(2)} · ${r['category'] ?? ''}',
          p?.whr == null ? 'Add your waist and hip measurements.' : 'Current ratio ${p!.whr!.toStringAsFixed(2)}. Recheck in the WHR tool to build a history.', '/tools/whr'),
      SectionHeader('Lab readings', subtitle: 'Your most recent results', trailing: TextLinkButton('Log', leading: Symbols.add_rounded, onTap: () async {
        if (await showVitalsSheet(context)) _load();
      })),
      ListGroup(dividerIndent: 64, children: [
        _vitalRow('bp', 'Blood pressure', bp == null ? null : '${bp.value.round()}/${bp.extra!.round()} mmHg', bp == null ? null : '${VitalBands.bp(bp.value, bp.extra!).$1} · ${when(bp.at)}'),
        _vitalRow('glucose', 'Fasting blood glucose', fbg == null ? null : '${fbg.value.round()} mg/dL', fbg == null ? null : '${VitalBands.fastingGlucose(fbg.value).$1} · ${when(fbg.at)}'),
        _vitalRow('tg', 'Triglycerides', tg == null ? null : '${tg.value.round()} mg/dL', tg == null ? null : '${VitalBands.triglycerides(tg.value).$1} · ${when(tg.at)}'),
      ]),
    ];
  }

  Widget _vitalRow(String image, String title, String? value, String? sub) => InkWell(
        onTap: () async {
          if (await showVitalsSheet(context)) _load();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icons3d/$image.jpg', width: 36, height: 36, fit: BoxFit.cover)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.bodyLg.w(FontWeight.w600)),
                Text(sub ?? 'Not recorded yet', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
            Text(value ?? 'Log', style: T.labelLg.c(value == null ? AppColors.primary : AppColors.onSurface)),
          ]),
        ),
      );

  // ---------------------------------------------------------------------------
  // Periodic assessments

  List<Widget> _assessmentView() {
    if (_assessments.isEmpty) {
      return [
        EmptyState(
          icon: Symbols.assignment_rounded,
          title: 'No assessments yet',
          text: 'Completed six-monthly assessments appear here so you can compare terms.',
          action: SoftButton('View assessments', expand: false, onTap: () => context.push('/assessments')),
        ),
      ];
    }
    final latest = _assessments.first;
    final domains = Map<String, dynamic>.from((latest['scores'] as Map?)?['domains'] ?? {});
    final withOverall = _assessments.reversed.where((a) => (a['scores'] as Map?)?['overall'] != null).toList();
    return [
      if (domains.isNotEmpty)
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Latest snapshot', style: T.headlineSm),
            const SizedBox(height: 2),
            Text('${latest['title'] ?? 'Assessment'} · well-being by area, out of 100', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            DomainBars(domains: domains),
          ]),
        ),
      if (withOverall.length > 1)
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CategoryLabel('Overall well-being', icon: Symbols.monitoring_rounded, color: AppColors.primary),
            const SizedBox(height: Sp.md),
            BarChart(
              values: [for (final a in withOverall) ((a['scores'] as Map)['overall'] as num).toDouble()],
              labels: [for (final a in withOverall) DateFormat("MMM ''yy").format(DateTime.parse(a['completed_at']).toLocal())],
              color: AppColors.primary,
              height: 110,
            ),
          ]),
        ),
      const SectionHeader('History'),
      ListGroup(dividerIndent: 60, children: [
        for (final a in _assessments)
          ListRow(
            icon: Symbols.check_circle_rounded,
            color: AppColors.tertiary,
            title: a['title'] ?? 'Assessment',
            subtitle: '${DateFormat('d MMM yyyy').format(DateTime.parse(a['completed_at']).toLocal())} · ${a['result_label'] ?? ''}',
            onTap: () => showAssessmentSummary(context, a),
          ),
      ]),
    ];
  }
}
