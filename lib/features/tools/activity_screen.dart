import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/charts.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// MET values (Compendium of Physical Activities, approximate).
const activityTypes = <(String, IconData, double)>[
  ('Walk', Symbols.directions_walk_rounded, 3.5),
  ('Brisk walk', Symbols.hiking_rounded, 4.3),
  ('Run', Symbols.sprint_rounded, 8.0),
  ('Cycle', Symbols.pedal_bike_rounded, 6.0),
  ('Sports', Symbols.sports_cricket_rounded, 7.0),
  ('Gym', Symbols.fitness_center_rounded, 5.0),
  ('Yoga / Stretch', Symbols.self_improvement_rounded, 2.5),
  ('Dance', Symbols.music_note_rounded, 5.0),
  ('Stairs', Symbols.stairs_rounded, 4.0),
];

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  Rec _today = {'steps': 0, 'minutes': 0, 'kcal': 0, 'km': 0.0, 'logs': <Rec>[]};
  Map<String, int> _week = {};
  Map<String, int> _minutesWeek = {};
  DateTime? _lastSync;
  bool _syncing = false;
  Rec? _ipaq;

  int get _goal => AppState.instance.profile?.stepGoal ?? 8000;

  /// WHO/IPAQ baseline: at least 150 minutes of moderate activity a week.
  static const _weeklyTargetMin = 150;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final ws = weekStart(now);
      _today = await Repo.activityTotals(now);
      _week = await Repo.stepsByDay(ws, ws.add(const Duration(days: 6)));
      _minutesWeek = await Repo.minutesByDay(ws, ws.add(const Duration(days: 6)));
      final prefs = await SharedPreferences.getInstance();
      final ls = prefs.getString('ped_last_sync');
      _lastSync = ls == null ? null : DateTime.tryParse(ls);
      final ipaq = await Repo.toolResults('ipaq', limit: 1);
      _ipaq = ipaq.isEmpty ? null : ipaq.first;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _runIpaq() async {
    int vigDays = 0, vigMin = 20, modDays = 0, modMin = 20, walkDays = 0, walkMin = 20, sitHours = 6;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          Widget days(String label, int value, ValueChanged<int> onChanged) => Row(children: [
                Expanded(child: Text(label, style: T.bodyLg)),
                IconButton.outlined(icon: const Icon(Symbols.remove_rounded), onPressed: value <= 0 ? null : () => set(() => onChanged(value - 1))),
                SizedBox(width: 28, child: Center(child: Text('$value', style: T.labelLg.tnum))),
                IconButton.outlined(icon: const Icon(Symbols.add_rounded), onPressed: value >= 7 ? null : () => set(() => onChanged(value + 1))),
              ]);
          Widget minutes(int value, ValueChanged<int> onChanged) => Row(children: [
                Expanded(child: Text('Minutes per day', style: T.bodySm.c(AppColors.onSurfaceVariant))),
                SizedBox(
                  width: 160,
                  child: VSlider(value: value.toDouble(), min: 0, max: 180, divisions: 18, color: AppColors.activity, onChanged: (v) => set(() => onChanged(v.round()))),
                ),
                SizedBox(width: 36, child: Text('$value', style: T.labelMd.tnum, textAlign: TextAlign.right)),
              ]);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Weekly activity check-in', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('The IPAQ short form: a 7-day recall of your physical activity.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.lg),
            Text('In the last 7 days, on how many days did you do vigorous activity (heavy lifting, aerobics, fast cycling)?', style: T.labelLg),
            const SizedBox(height: 4),
            days('Days', vigDays, (v) => vigDays = v),
            if (vigDays > 0) minutes(vigMin, (v) => vigMin = v),
            const SizedBox(height: Sp.md),
            Text('On how many days did you do moderate activity (light loads, regular-pace cycling, doubles tennis), not counting walking?', style: T.labelLg),
            const SizedBox(height: 4),
            days('Days', modDays, (v) => modDays = v),
            if (modDays > 0) minutes(modMin, (v) => modMin = v),
            const SizedBox(height: Sp.md),
            Text('On how many days did you walk for at least 10 minutes at a time?', style: T.labelLg),
            const SizedBox(height: 4),
            days('Days', walkDays, (v) => walkDays = v),
            if (walkDays > 0) minutes(walkMin, (v) => walkMin = v),
            const SizedBox(height: Sp.md),
            Text('On a typical day, how many hours do you spend sitting?', style: T.labelLg),
            days('Hours', sitHours, (v) => sitHours = v),
            const SizedBox(height: Sp.lg),
            PrimaryButton('See my result', onTap: () async {
              final met = Ipaq.metMinutes(vigDays: vigDays, vigMin: vigMin, modDays: modDays, modMin: modMin, walkDays: walkDays, walkMin: walkMin);
              final cat = Ipaq.category(vigDays: vigDays, vigMin: vigMin, modDays: modDays, modMin: modMin, walkDays: walkDays, walkMin: walkMin);
              try {
                await Repo.saveToolResult('ipaq', score: met, category: cat, data: {
                  'vig_days': vigDays, 'vig_min': vigMin, 'mod_days': modDays, 'mod_min': modMin, 'walk_days': walkDays, 'walk_min': walkMin, 'sit_hours': sitHours,
                });
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  Future<void> _sync() async {
    if (kIsWeb) return; // no step sensor in browsers — manual entry only
    setState(() => _syncing = true);
    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted && !status.isLimited) {
        if (mounted) toast(context, 'Allow physical activity access to count steps automatically.', error: true);
        return;
      }
      final event = await Pedometer.stepCountStream.first.timeout(const Duration(seconds: 8));
      final prefs = await SharedPreferences.getInstance();
      final today = isoDate(DateTime.now());
      var base = prefs.getInt('ped_base') ?? event.steps;
      final baseDate = prefs.getString('ped_date');
      if (baseDate != today || event.steps < base) {
        // New day (or phone restarted): start counting from the current sensor value.
        final carried = baseDate == today ? (prefs.getInt('ped_today') ?? 0) : 0;
        base = event.steps - carried;
        await prefs.setString('ped_date', today);
        await prefs.setInt('ped_base', base);
      }
      final steps = (event.steps - base).clamp(0, 100000);
      await prefs.setInt('ped_today', steps);
      await prefs.setString('ped_last_sync', DateTime.now().toIso8601String());
      await Repo.upsertSensorSteps(steps);
      await _load();
      if (mounted) toast(context, 'Synced $steps steps');
    } on TimeoutException {
      if (mounted) toast(context, 'No step data yet. Walk a little and try again.', error: true);
    } catch (e) {
      if (mounted) toast(context, 'Step sensor not available on this device.', error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _logManual() async {
    var type = activityTypes.first;
    final minutes = TextEditingController(text: '20');
    final steps = TextEditingController();
    final km = TextEditingController();
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Log activity', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Walking to lectures counts too.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in activityTypes) VChip(t.$1, icon: t.$2, selected: type.$1 == t.$1, selectedColor: AppColors.activity, onTap: () => set(() => type = t)),
            ]),
            const SizedBox(height: Sp.md),
            VTextField(controller: minutes, hint: 'Duration (minutes)', icon: Symbols.schedule_rounded, keyboard: TextInputType.number),
            const SizedBox(height: Sp.sm),
            VTextField(controller: steps, hint: 'Steps (optional)', icon: Symbols.footprint_rounded, keyboard: TextInputType.number),
            const SizedBox(height: Sp.sm),
            VTextField(controller: km, hint: 'Distance km (optional)', icon: Symbols.near_me_rounded, keyboard: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save', onTap: () async {
              final m = int.tryParse(minutes.text) ?? 0;
              if (m <= 0 || m > 600) return toast(ctx, 'Enter a duration between 1 and 600 minutes.', error: true);
              final weight = AppState.instance.profile?.weightKg ?? 60;
              final kcal = (type.$3 * weight * (m / 60)).round();
              var s = int.tryParse(steps.text) ?? 0;
              if (s == 0 && (type.$1 == 'Walk' || type.$1 == 'Brisk walk')) s = m * 100;
              if (s == 0 && type.$1 == 'Run') s = m * 160;
              var d = double.tryParse(km.text) ?? 0;
              if (d == 0 && s > 0) d = double.parse((s * 0.00075).toStringAsFixed(2));
              await Repo.addActivity(type: type.$1, minutes: m, steps: s, km: d, kcal: kcal);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final steps = _today['steps'] as int;
    final pct = steps / _goal;
    final now = DateTime.now();
    final ws = weekStart(now);
    final days = [for (int i = 0; i < 7; i++) ws.add(Duration(days: i))];
    final loggedDays = days.where((d) => !d.isAfter(now)).toList();
    final avg = loggedDays.isEmpty ? 0 : (loggedDays.map((d) => _week[isoDate(d)] ?? 0).reduce((a, b) => a + b) / loggedDays.length).round();
    final c = AppColors.activity;
    final logs = (_today['logs'] as List).cast<Rec>();
    final weekMinutes = _minutesWeek.values.fold<int>(0, (a, b) => a + b);
    final minutesDiff = weekMinutes - _weeklyTargetMin;
    final ipaqCat = _ipaq?['category'] as String?;
    final ipaqMet = (_ipaq?['score'] as num?)?.round();

    return VPage(
      header: TitleHeader('Activity tracker', onLeading: () => goBack(context, '/tools')),
      onRefresh: _load,
      children: [
        VCard(
          child: Column(children: [
            Row(children: [
              Ring(value: pct, size: 112, stroke: 12, color: c, child: Text('${(pct * 100).round()}%', style: T.metric(22))),
              const SizedBox(width: Sp.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CategoryLabel('Steps today', icon: Symbols.directions_walk_rounded, color: c),
                  const SizedBox(height: 6),
                  MetricValue(Fmt.thousands(steps), size: 32),
                  Text('Goal ${Fmt.thousands(_goal)}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.md),
            const Divider(height: 1),
            const SizedBox(height: Sp.md),
            Row(children: [
              _stat('${_today['minutes']}', 'min', 'Active time'),
              _vDivider(),
              _stat((_today['km'] as num).toStringAsFixed(1), 'km', 'Distance'),
              _vDivider(),
              _stat('${_today['kcal']}', 'kcal', 'Energy'),
            ]),
          ]),
        ),
        const SectionHeader('This week'),
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MetricValue(Fmt.thousands(avg), unit: 'steps a day on average', size: 24),
            const SizedBox(height: Sp.md),
            BarChart(
              values: [for (final d in days) d.isAfter(now) ? 0 : (_week[isoDate(d)] ?? 0).toDouble()],
              labels: [for (final d in days) DateFormat('E').format(d).substring(0, 1)],
              color: c,
              goal: _goal.toDouble(),
              highlightLast: false,
              height: 140,
            ),
            const Divider(height: 28),
            Row(children: [
              Icon(minutesDiff >= 0 ? Symbols.trending_up_rounded : Symbols.trending_down_rounded, size: 18, color: minutesDiff >= 0 ? AppColors.tertiary : AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$weekMinutes active minutes logged this week — ${minutesDiff >= 0 ? '${minutesDiff}m above' : '${-minutesDiff}m below'} the $_weeklyTargetMin min/week baseline.',
                  style: T.bodySm.c(AppColors.onSurfaceVariant),
                ),
              ),
            ]),
          ]),
        ),
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Symbols.checklist_rounded, size: 20, color: c, fill: 1),
              const SizedBox(width: 8),
              Expanded(child: Text('IPAQ weekly check-in', style: T.headlineSm)),
            ]),
            const SizedBox(height: 6),
            if (ipaqCat == null)
              Text('A short, validated 7-day activity recall (vigorous, moderate, walking and sitting).', style: T.bodyMd.c(AppColors.onSurfaceVariant))
            else ...[
              Row(children: [
                TagPill(ipaqCat, bg: AppColors.tint(_ipaqColor(ipaqCat)), fg: _ipaqColor(ipaqCat)),
                const SizedBox(width: 8),
                Text('$ipaqMet MET-min/week', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              ]),
              const SizedBox(height: 6),
              Text(_ipaqTip(ipaqCat), style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            ],
            const SizedBox(height: Sp.sm),
            SoftButton(ipaqCat == null ? 'Start check-in' : 'Retake check-in', icon: Symbols.edit_rounded, onTap: _runIpaq),
          ]),
        ),
        PrimaryButton('Log activity', leadingIcon: Symbols.add_rounded, onTap: _logManual),
        if (!kIsWeb)
          ListGroup(children: [
            ListRow(
              icon: Symbols.sync_rounded,
              color: AppColors.tertiary,
              title: 'Phone step counter',
              subtitle: _syncing ? 'Syncing…' : (_lastSync == null ? 'Tap to sync steps from your phone' : 'Last synced ${_ago(_lastSync!)}'),
              trailing: _syncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              onTap: _syncing ? null : _sync,
            ),
          ]),
        if (logs.isNotEmpty) ...[
          const SectionHeader('Today'),
          ListGroup(children: [
            for (final l in logs)
              ListRow(
                icon: activityTypes.firstWhere((t) => t.$1 == l['activity_type'], orElse: () => activityTypes.first).$2,
                color: c,
                title: '${l['activity_type']}',
                subtitle: l['source'] == 'sensor' ? 'Phone sensor' : 'Logged manually',
                value: '${l['active_minutes']} min · ${Fmt.thousands(l['steps'])}',
              ),
          ]),
        ],
        const PrivacyNote('A wellness tracker, not a diagnosis of any disease. Activity stays private to you, with no leaderboards.'),
      ],
    );
  }

  Color _ipaqColor(String cat) => switch (cat) {
        'High' => AppColors.tertiary,
        'Moderate' => AppColors.warning,
        _ => AppColors.error,
      };

  String _ipaqTip(String cat) => switch (cat) {
        'High' => 'You are meeting a high activity level. Keep mixing intensities and let your body rest when it needs to.',
        'Moderate' => 'A solid, moderate base. Adding one more vigorous session or a few extra walking days would lift this further.',
        _ => 'Your reported activity is on the low side. Short walks between lectures and taking the stairs are easy ways to add minutes.',
      };

  Widget _stat(String value, String unit, String label) => Expanded(
        child: Column(children: [
          MetricValue(value, unit: unit, size: 20),
          const SizedBox(height: 2),
          Text(label, style: T.bodySm.c(AppColors.onSurfaceVariant)),
        ]),
      );

  Widget _vDivider() => Container(width: 1, height: 36, color: AppColors.outlineVariant);

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return DateFormat('d MMM').format(t);
  }
}

/// IPAQ Short Form (7-day recall) scoring: continuous MET-minutes/week plus
/// the standard three-level categorical score.
class Ipaq {
  Ipaq._();

  static int metMinutes({required int vigDays, required int vigMin, required int modDays, required int modMin, required int walkDays, required int walkMin}) =>
      (8.0 * vigDays * vigMin + 4.0 * modDays * modMin + 3.3 * walkDays * walkMin).round();

  static String category({required int vigDays, required int vigMin, required int modDays, required int modMin, required int walkDays, required int walkMin}) {
    final total = metMinutes(vigDays: vigDays, vigMin: vigMin, modDays: modDays, modMin: modMin, walkDays: walkDays, walkMin: walkMin);
    final activeDays = (vigDays > 0 ? 1 : 0) + (modDays > 0 ? 1 : 0) + (walkDays > 0 ? 1 : 0);
    final anyDaysCombined = [if (vigDays > 0) vigDays, if (modDays > 0) modDays, if (walkDays > 0) walkDays];
    final combinedDays = anyDaysCombined.isEmpty ? 0 : anyDaysCombined.reduce((a, b) => a > b ? a : b);
    if ((vigDays >= 3 && total >= 1500) || (activeDays >= 3 && combinedDays >= 7 && total >= 3000)) return 'High';
    if ((vigDays >= 3 && vigMin >= 20) || (modDays >= 5 && modMin >= 30) || (walkDays >= 5 && walkMin >= 30) || (activeDays >= 1 && combinedDays >= 5 && total >= 600)) return 'Moderate';
    return 'Low';
  }
}
