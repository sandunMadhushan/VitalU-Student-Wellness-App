import 'dart:async';


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/charts.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../home/breathing.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});
  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  bool _loading = true;
  List<Rec> _week = [];
  Rec? _last;

  int get _goalMin => ((AppState.instance.profile?.sleepGoalHours ?? 8) * 60).round();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final ws = weekStart(now);
      _week = await Repo.sleepBetween(ws, ws.add(const Duration(days: 6)));
      _last = await Repo.sleepLatest();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  (int, int, int, bool) _stages(Rec r) {
    final total = Repo.sleepMinutes(r);
    final d = r['deep_minutes'] as int?, rem = r['rem_minutes'] as int?, l = r['light_minutes'] as int?;
    if (d != null && rem != null && l != null) return (d, rem, l, false);
    final deep = (total * 0.22).round(), remM = (total * 0.25).round();
    return (deep, remM, total - deep - remM, true);
  }

  Future<void> _logSleep({Rec? existing}) async {
    final now = DateTime.now();
    var bed = existing != null ? DateTime.parse(existing['bedtime']).toLocal() : DateTime(now.year, now.month, now.day - 1, 23, 0);
    var wake = existing != null ? DateTime.parse(existing['wake_time']).toLocal() : DateTime(now.year, now.month, now.day, 6, 30);
    int quality = existing?['quality'] as int? ?? 4;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          Future<void> pick(bool isBed) async {
            final base = isBed ? bed : wake;
            final d = await showDatePicker(context: ctx, initialDate: base, firstDate: now.subtract(const Duration(days: 30)), lastDate: now);
            if (d == null || !ctx.mounted) return;
            final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(base));
            if (t == null) return;
            set(() {
              final v = DateTime(d.year, d.month, d.day, t.hour, t.minute);
              if (isBed) {
                bed = v;
              } else {
                wake = v;
              }
            });
          }

          final dur = wake.difference(bed);
          final bad = dur.isNegative || dur.inHours > 16;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Log sleep', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            ListGroup(dividerIndent: 60, children: [
              ListRow(icon: Symbols.bedtime_rounded, color: AppColors.sleep, title: 'Bedtime', value: DateFormat('EEE, h:mm a').format(bed), onTap: () => pick(true)),
              ListRow(icon: Symbols.wb_twilight_rounded, color: AppColors.warning, title: 'Wake-up', value: DateFormat('EEE, h:mm a').format(wake), onTap: () => pick(false)),
            ]),
            const SizedBox(height: Sp.sm),
            Text(bad ? 'Please check the times.' : 'Total ${Fmt.hm(dur.inMinutes)}', style: T.labelLg.c(bad ? AppColors.error : AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Text('How rested do you feel?', style: T.labelLg),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Segmented(
                small: false,
                options: const ['Poor', 'Fair', 'OK', 'Good', 'Great'],
                value: const ['Poor', 'Fair', 'OK', 'Good', 'Great'][quality - 1],
                onChanged: (v) => set(() => quality = const ['Poor', 'Fair', 'OK', 'Good', 'Great'].indexOf(v) + 1),
              ),
            ),
            const SizedBox(height: Sp.lg),
            PrimaryButton('Save', onTap: () async {
              if (dur.isNegative || dur.inMinutes < 30 || dur.inHours > 16) return toast(ctx, 'Sleep should be between 30 minutes and 16 hours.', error: true);
              await Repo.saveSleep(bedtime: bed, wake: wake, quality: quality);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  void _windDown() {
    showVSheet(context, builder: (ctx) => const _WindDown());
  }

  @override
  Widget build(BuildContext context) {
    final last = _last;
    final now = DateTime.now();
    final ws = weekStart(now);
    final days = [for (int i = 0; i < 7; i++) ws.add(Duration(days: i))];
    final byDate = {for (final r in _week) r['sleep_date'] as String: r};
    final avg = _week.isEmpty ? 0 : (_week.map(Repo.sleepMinutes).reduce((a, b) => a + b) / _week.length).round();

    return VPage(
      header: TitleHeader('Sleep', onLeading: () => goBack(context, '/tools')),
      onRefresh: _load,
      children: _loading
          ? [const Loading()]
          : [
              if (last == null)
                EmptyState(
                  icon: Symbols.bedtime_rounded,
                  title: 'No sleep logged yet',
                  text: 'Log last night to see your duration, timing and weekly pattern.',
                  action: PrimaryButton('Log sleep', expand: false, onTap: _logSleep),
                )
              else
                _latest(last),
              const SectionHeader('This week'),
              VCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  MetricValue(_week.isEmpty ? '—' : Fmt.hm(avg), unit: _week.isEmpty ? null : 'a night on average', size: 24),
                  const SizedBox(height: Sp.md),
                  BarChart(
                    values: [for (final d in days) (byDate[isoDate(d)] == null ? 0 : Repo.sleepMinutes(byDate[isoDate(d)]!)) / 60.0],
                    labels: [for (final d in days) DateFormat('E').format(d).substring(0, 1)],
                    color: AppColors.sleep,
                    goal: _goalMin / 60,
                    highlightLast: false,
                    height: 140,
                  ),
                  const SizedBox(height: 8),
                  Text('Dashed line: your ${(_goalMin / 60).toStringAsFixed(_goalMin % 60 == 0 ? 0 : 1)} h goal', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
              if (last != null) PrimaryButton('Log sleep', leadingIcon: Symbols.add_rounded, onTap: _logSleep),
              ListGroup(children: [
                ListRow(icon: Symbols.routine_rounded, color: AppColors.sleep, title: 'Wind-down routine', subtitle: 'A 10-minute checklist before bed', onTap: _windDown),
              ]),
              VCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Symbols.lightbulb_rounded, size: 22, color: AppColors.warning, fill: 1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Tip', style: T.headlineSm),
                      const SizedBox(height: 4),
                      Text('Dimming screens 30 minutes before bed helps your body clock reset after long study sessions.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
                    ]),
                  ),
                ]),
              ),
              const PrivacyNote('A wellness tracker, not a diagnosis of any sleep disorder. Data stays private to you.'),
            ],
    );
  }

  Widget _latest(Rec last) {
    final total = Repo.sleepMinutes(last);
    final pct = total / _goalMin;
    final bed = DateTime.parse(last['bedtime']).toLocal();
    final wake = DateTime.parse(last['wake_time']).toLocal();
    final (d, rem, l, est) = _stages(last);
    final lastNight = isoDate(wake) == isoDate(DateTime.now());
    return VCard(
      onTap: () => _logSleep(existing: last),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CategoryLabel(lastNight ? 'Last night' : DateFormat('EEEE').format(bed), icon: Symbols.bedtime_rounded, color: AppColors.sleep, trailing: 'Edit'),
        const SizedBox(height: 8),
        MetricValue(Fmt.hm(total).replaceAll(' 0', ' '), size: 34),
        Text('${(pct * 100).round()}% of your ${(_goalMin / 60).toStringAsFixed(0)} h goal', style: T.bodySm.c(pct >= 0.9 ? AppColors.tertiary : AppColors.onSurfaceVariant)),
        const SizedBox(height: Sp.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(children: [
              Expanded(flex: d, child: Container(color: AppColors.sleep)),
              const SizedBox(width: 2),
              Expanded(flex: rem, child: Container(color: AppColors.sleep.withValues(alpha: 0.6))),
              const SizedBox(width: 2),
              Expanded(flex: l, child: Container(color: AppColors.sleep.withValues(alpha: 0.3))),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _stage('Deep', AppColors.sleep, d),
          _stage('REM', AppColors.sleep.withValues(alpha: 0.6), rem),
          _stage('Light', AppColors.sleep.withValues(alpha: 0.3), l),
        ]),
        if (est) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Stages are estimated from total time.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
        const SizedBox(height: Sp.md),
        const Divider(height: 1),
        const SizedBox(height: Sp.md),
        Row(children: [
          Expanded(child: _time('Bedtime', bed)),
          Container(width: 1, height: 36, color: AppColors.outlineVariant),
          Expanded(child: _time('Woke up', wake)),
        ]),
      ]),
    );
  }

  Widget _stage(String name, Color c, int minutes) => Expanded(
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Flexible(child: Text('$name ${Fmt.hm(minutes)}', style: T.bodySm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
        ]),
      );

  Widget _time(String label, DateTime t) => Column(children: [
        MetricValue(DateFormat('h:mm').format(t), unit: DateFormat('a').format(t), size: 20),
        const SizedBox(height: 2),
        Text(label, style: T.bodySm.c(AppColors.onSurfaceVariant)),
      ]);
}

class _WindDown extends StatefulWidget {
  const _WindDown();
  @override
  State<_WindDown> createState() => _WindDownState();
}

class _WindDownState extends State<_WindDown> {
  static const total = 10 * 60;
  int _left = total;
  Timer? _t;
  final _done = <int>{};
  static const _steps = ['Dim screens and lights', 'Turn on Do Not Disturb', 'Drink a little water', 'Stretch for two minutes', "Write tomorrow's top three tasks"];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 0) {
        _t?.cancel();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Wind-down', style: T.headlineMd),
        const SizedBox(height: Sp.lg),
        Center(
          child: Ring(
            value: 1 - _left / total,
            size: 140,
            stroke: 10,
            color: AppColors.sleep,
            child: Text('${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}', style: T.metric(28)),
          ),
        ),
        const SizedBox(height: Sp.md),
        for (int i = 0; i < _steps.length; i++)
          CheckboxListTile(
            value: _done.contains(i),
            onChanged: (v) => setState(() => v == true ? _done.add(i) : _done.remove(i)),
            title: Text(_steps[i], style: T.bodyLg),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        const SizedBox(height: Sp.sm),
        SoftButton('Guided breathing', icon: Symbols.air_rounded, onTap: () => showBreathing(context)),
        const SizedBox(height: Sp.sm),
        PrimaryButton(_left <= 0 ? 'Done' : 'Finish early', onTap: () => Navigator.pop(context)),
      ]);
}
