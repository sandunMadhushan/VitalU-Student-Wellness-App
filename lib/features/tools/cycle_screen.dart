import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../core/sfx.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'cycle_data.dart';
import 'cycle_widgets.dart';

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});
  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  bool _loading = true;
  List<Rec> _cycles = [];
  Rec? _today;
  int _year = DateTime.now().year;
  CycleNotifyPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    CalmMusic.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _cycles = await Repo.cycles();
      _today = await Repo.dailyLog(DateTime.now());
      _prefs = await CycleNotifyPrefs.load();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
    _reschedule();
  }

  /// Keeps the phase notifications in step with the latest logs.
  Future<void> _reschedule() async {
    try {
      await rescheduleCycleNotifications(lastStart: _lastStart, cycleLen: _cycleLen, periodLen: _periodLen);
    } catch (_) {}
  }

  DateTime? get _lastStart => _cycles.isEmpty ? null : DateTime.parse(_cycles.first['start_date']);

  List<int> get _lengths {
    final starts = _cycles.map((c) => DateTime.parse(c['start_date'])).toList()..sort();
    return [for (int i = 1; i < starts.length; i++) starts[i].difference(starts[i - 1]).inDays];
  }

  int get _cycleLen {
    final l = _lengths.where((d) => d >= 18 && d <= 60).toList();
    if (l.isEmpty) return 28;
    return (l.reduce((a, b) => a + b) / l.length).round().clamp(21, 45);
  }

  int get _periodLen {
    final withEnd = _cycles.where((c) => c['end_date'] != null).toList();
    if (withEnd.isEmpty) return 5;
    final avg = withEnd.map((c) => DateTime.parse(c['end_date']).difference(DateTime.parse(c['start_date'])).inDays + 1).reduce((a, b) => a + b) / withEnd.length;
    return avg.round().clamp(2, 10);
  }

  bool get _irregular {
    final l = _lengths;
    if (l.length < 2) return false;
    final mx = l.reduce(math.max), mn = l.reduce(math.min);
    return l.any((d) => d > 35 || d < 21) || (mx - mn) > 7;
  }

  /// Soft, non-diagnostic signals that sometimes co-occur with PCOS, drawn
  /// from cycle regularity and the student's profile.
  List<String> get _pcosSignals {
    final p = AppState.instance.profile;
    final signals = <String>[];
    if (_irregular) signals.add('Irregular cycle lengths');
    if (p?.conditions.contains('skin_disease') ?? false) signals.add('A noted skin condition (acne can be linked to hormone shifts)');
    final bmi = p?.bmi;
    if (bmi != null && bmi >= 25) signals.add('BMI above the typical range');
    if (p?.conditions.contains('family_diabetes') ?? false) signals.add('Diabetes in the family');
    return signals;
  }

  bool get _pcosDiagnosed => AppState.instance.profile?.conditions.contains('pcos') ?? false;

  /// The upcoming fertile window (ovulation day minus 5, to ovulation day
  /// plus 1). An estimate from average cycle length, not contraception.
  (DateTime, DateTime)? get _fertileWindow {
    final last = _lastStart;
    if (last == null) return null;
    final cycleStart = dayStart(last);
    final ov = _cycleLen - 14;
    var start = cycleStart.add(Duration(days: ov - 5 - 1));
    var end = cycleStart.add(Duration(days: ov + 1 - 1));
    final today = dayStart(DateTime.now());
    while (end.isBefore(today)) {
      start = start.add(Duration(days: _cycleLen));
      end = end.add(Duration(days: _cycleLen));
    }
    return (start, end);
  }

  /// Logged, predicted and fertile days for the calendar.
  CycleMarks get _marks {
    final period = <DateTime>{}, predicted = <DateTime>{}, fertile = <DateTime>{};
    for (final c in _cycles) {
      final s = dayStart(DateTime.parse(c['start_date']));
      final e = c['end_date'] == null ? s.add(Duration(days: _periodLen - 1)) : dayStart(DateTime.parse(c['end_date']));
      for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
        period.add(DateUtils.dateOnly(d));
      }
    }
    final last = _lastStart;
    if (last != null) {
      final today = dayStart(DateTime.now());
      final until = DateTime(math.max(_year, today.year) + 1, 12, 31);
      final ov = _cycleLen - 14;
      for (var s = dayStart(last); !s.isAfter(until); s = s.add(Duration(days: _cycleLen))) {
        for (int i = ov - 6; i <= ov; i++) {
          final d = DateUtils.dateOnly(s.add(Duration(days: i)));
          if (d.isAfter(today)) fertile.add(d);
        }
        if (s == dayStart(last)) continue;
        for (int i = 0; i < _periodLen; i++) {
          final d = DateUtils.dateOnly(s.add(Duration(days: i)));
          if (d.isAfter(today) && !period.contains(d)) predicted.add(d);
        }
      }
    }
    return CycleMarks(period: period, predicted: predicted, fertile: fertile);
  }

  // ---------------------------------------------------------------------------
  // Logging

  Future<void> _logPeriod({DateTime? initial}) async {
    final now = DateTime.now();
    final open = initial == null && _cycles.isNotEmpty && _cycles.first['end_date'] == null && now.difference(DateTime.parse(_cycles.first['start_date'])).inDays < 12;
    DateTime start = initial ?? now;
    DateTime? end;
    String flow = _today?['flow'] ?? 'medium';
    final c = AppColors.cycle;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          Widget dateTile(String label, DateTime? value, String empty, VoidCallback onTap) => VCard(
                color: AppColors.surfaceContainerLow,
                onTap: onTap,
                child: Row(children: [
                  Icon(Symbols.calendar_today_rounded, color: c),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: T.labelSm.c(AppColors.onSurfaceVariant)),
                      Text(value == null ? empty : DateFormat('EEEE, d MMMM yyyy').format(value), style: T.labelLg),
                    ]),
                  ),
                  const Icon(Symbols.edit_rounded, size: 18),
                ]),
              );
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(open ? 'Your period' : 'Log a period', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            if (open) ...[
              VCard(
                color: AppColors.tint(c),
                child: Row(children: [
                  Icon(Symbols.water_drop_rounded, color: c, fill: 1),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Period started ${DateFormat('d MMM').format(DateTime.parse(_cycles.first['start_date']))}. Has it ended?', style: T.bodyMd)),
                ]),
              ),
              const SizedBox(height: Sp.sm),
              SoftButton('Mark as ended today', icon: Symbols.check_circle_rounded, onTap: () async {
                await Repo.endCycle(_cycles.first['id'], now);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              }),
              const SizedBox(height: Sp.md),
              Text("Today's flow", style: T.labelLg),
            ] else ...[
              dateTile('First day', start, '', () async {
                final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(now.year - 2), lastDate: now);
                if (d != null) set(() => start = d);
              }),
              const SizedBox(height: Sp.sm),
              dateTile('Last day (optional)', end, 'Still going, or not sure', () async {
                final d = await showDatePicker(context: ctx, initialDate: end ?? _typicalEnd(start), firstDate: start, lastDate: now);
                if (d != null) set(() => end = d);
              }),
              const SizedBox(height: Sp.md),
              Text('Flow', style: T.labelLg),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final f in const ['spotting', 'light', 'medium', 'heavy'])
                VChip(f[0].toUpperCase() + f.substring(1), selected: flow == f, selectedColor: c, onTap: () => set(() => flow = f)),
            ]),
            const SizedBox(height: Sp.lg),
            PrimaryButton(open ? 'Save' : 'Save period', color: c, onTap: () async {
              try {
                if (!open) await Repo.addCycle(start, end: end);
                await Repo.upsertDailyLog(open ? now : start, {'flow': flow});
              } catch (_) {
                if (ctx.mounted) toast(ctx, 'Could not save. Check your connection.', error: true);
                return;
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  Future<void> _pickSymptom(String field, String title, List<String> options) async {
    final v = await showVSheet<String>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: T.headlineMd),
          const SizedBox(height: Sp.md),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in options) VChip(o, selected: _today?[field] == o, selectedColor: AppColors.cycle, onTap: () => Navigator.pop(ctx, o)),
          ]),
          const SizedBox(height: Sp.md),
          if (_today?[field] != null) TextLinkButton('Clear', onTap: () => Navigator.pop(ctx, '')),
        ]));
    if (v == null) return;
    await Repo.upsertDailyLog(DateTime.now(), {field: v.isEmpty ? null : v});
    _load();
  }

  Future<void> _moreLog() async {
    bool spotting = _today?['spotting'] == true;
    final notes = TextEditingController(text: _today?['notes'] ?? '');
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('More for today', style: T.headlineMd),
            const SizedBox(height: Sp.sm),
            SwitchListTile(value: spotting, onChanged: (v) => set(() => spotting = v), title: Text('Spotting', style: T.labelLg), contentPadding: EdgeInsets.zero),
            const SizedBox(height: Sp.sm),
            VTextField(controller: notes, hint: 'Notes (headache, bloating, skin, cravings…)', maxLines: 3),
            const SizedBox(height: Sp.sm),
            SoftButton('Log water', icon: Symbols.water_drop_rounded, onTap: () {
              Navigator.pop(ctx);
              context.push('/tools/water');
            }),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save', onTap: () async {
              await Repo.upsertDailyLog(DateTime.now(), {'spotting': spotting, 'notes': notes.text.trim().isEmpty ? null : notes.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  /// A month in detail: the calendar, its logged periods and daily notes.
  Future<void> _openMonth(DateTime month) async {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0);
    List<Rec> logs = [];
    try {
      logs = await Repo.dailyLogsBetween(from, to);
    } catch (_) {}
    if (!mounted) return;
    final marks = _marks;
    final inMonth = _cycles.where((c) {
      final s = DateTime.parse(c['start_date']);
      final e = c['end_date'] == null ? s.add(Duration(days: _periodLen - 1)) : DateTime.parse(c['end_date']);
      return !s.isAfter(to) && !e.isBefore(from);
    }).toList();
    final now = DateTime.now();
    final future = from.isAfter(now);
    final fmt = DateFormat('d MMM');
    await showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(DateFormat('MMMM yyyy').format(month), style: T.headlineMd),
          const SizedBox(height: Sp.md),
          MonthGrid(month: month, marks: marks),
          const SizedBox(height: Sp.sm),
          const CalendarLegend(),
          const SizedBox(height: Sp.md),
          Text('Period log', style: T.headlineSm),
          const SizedBox(height: Sp.sm),
          if (inMonth.isEmpty)
            Text(future ? 'This month is still ahead. Outlined days are predictions.' : 'No period logged this month.', style: T.bodyMd.c(AppColors.onSurfaceVariant))
          else
            for (final c in inMonth)
              Builder(builder: (_) {
                final s = DateTime.parse(c['start_date']);
                final e = c['end_date'] == null ? null : DateTime.parse(c['end_date']);
                final len = e == null ? null : e.difference(s).inDays + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: VCard(
                    color: AppColors.tint(AppColors.cycle),
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    child: Row(children: [
                      Icon(Symbols.water_drop_rounded, color: AppColors.cycle, fill: 1),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e == null ? 'Started ${fmt.format(s)}' : '${fmt.format(s)} to ${fmt.format(e)}', style: T.labelLg),
                          Text(len == null ? 'End date not logged' : '$len days', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                        ]),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: Icon(Symbols.delete_rounded, size: 20, color: AppColors.outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder: (d) => AlertDialog(
                              title: const Text('Remove this period?'),
                              content: Text('Logged from ${fmt.format(s)}.'),
                              actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove'))],
                            ),
                          );
                          if (ok != true) return;
                          await Repo.deleteCycle(c['id']);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        },
                      ),
                    ]),
                  ),
                );
              }),
          if (logs.any((l) => _logSummary(l).isNotEmpty)) ...[
            const SizedBox(height: Sp.sm),
            Text('How you felt', style: T.headlineSm),
            const SizedBox(height: Sp.sm),
            for (final l in logs)
              if (_logSummary(l).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 56, child: Text(fmt.format(DateTime.parse(l['log_date'])), style: T.labelMd)),
                    Expanded(
                      child: Wrap(spacing: 6, runSpacing: 6, children: [for (final t in _logSummary(l)) TagPill(t, bg: AppColors.surfaceContainer)]),
                    ),
                  ]),
                ),
          ],
          const SizedBox(height: Sp.md),
          if (!future)
            PrimaryButton('Log a period in ${DateFormat('MMMM').format(month)}', color: AppColors.cycle, leadingIcon: Symbols.add_rounded, onTap: () {
              Navigator.pop(ctx);
              final initial = month.year == now.year && month.month == now.month ? now : from;
              _logPeriod(initial: initial);
            }),
        ]));
  }

  /// Where a period that started on [start] would usually end, capped at today.
  DateTime _typicalEnd(DateTime start) {
    final e = start.add(Duration(days: _periodLen - 1));
    final now = DateTime.now();
    return e.isAfter(now) ? now : e;
  }

  List<String> _logSummary(Rec l) => [
        if (l['flow'] != null) 'Flow: ${l['flow']}',
        if (l['cramps'] != null && l['cramps'] != 'None') 'Cramps: ${l['cramps']}',
        if (l['mood'] != null) 'Mood: ${l['mood']}',
        if (l['energy'] != null) 'Energy: ${l['energy']}',
        if (l['cravings'] != null && l['cravings'] != 'None') 'Cravings: ${l['cravings']}',
        if (l['spotting'] == true) 'Spotting',
        if (l['notes'] != null) l['notes'] as String,
      ];

  void _history() {
    final starts = _cycles.toList();
    showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Cycle history', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('Average cycle $_cycleLen days · average period $_periodLen days', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          if (starts.isEmpty) Text('No cycles logged yet.', style: T.bodyMd),
          for (int i = 0; i < starts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VCard(
                color: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Symbols.water_drop_rounded, color: AppColors.cycle, fill: 1, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(DateFormat('d MMM yyyy').format(DateTime.parse(starts[i]['start_date'])), style: T.labelLg)),
                  Text(
                    i + 1 < starts.length ? '${DateTime.parse(starts[i]['start_date']).difference(DateTime.parse(starts[i + 1]['start_date'])).inDays}-day cycle' : 'First logged',
                    style: T.labelSm.c(AppColors.onSurfaceVariant),
                  ),
                ]),
              ),
            ),
          if (_irregular) ...[
            const SizedBox(height: Sp.sm),
            Text('Your cycle lengths vary more than usual. Irregular cycles have many causes (stress, weight change, sleep), and can sometimes be associated with conditions such as PCOS. This is not a diagnosis, and a doctor can help if it continues.',
                style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ],
        ]));
  }

  Future<void> _notifySettings() async {
    final prefs = _prefs ?? await CycleNotifyPrefs.load();
    if (!mounted) return;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Phase notifications', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Friendly messages based on your logged dates, so you know what to expect. Predictions are estimates, since every cycle is a little different.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: prefs.master,
              title: Text('All cycle notifications', style: T.labelLg),
              onChanged: (v) => set(() => prefs.on['master'] = v),
            ),
            const Divider(),
            for (final k in CycleNotifyPrefs.keys)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: prefs.on[k.$1] ?? true,
                title: Text(k.$2, style: T.labelLg.c(prefs.master ? AppColors.onSurface : AppColors.outline)),
                subtitle: Text(k.$3, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                onChanged: prefs.master ? (v) => set(() => prefs.on[k.$1] = v) : null,
              ),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save', color: AppColors.cycle, onTap: () async {
              await prefs.save();
              _prefs = prefs;
              if (ctx.mounted) Navigator.pop(ctx);
              await _reschedule();
              if (mounted) {
                setState(() {});
                toast(context, prefs.master ? 'Notifications updated' : 'Cycle notifications turned off');
              }
            }),
          ]);
        }));
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('Cycle tracker', onLeading: () => goBack(context, '/tools')),
      onRefresh: _load,
      children: _loading ? [const Loading()] : _content(),
    );
  }

  List<Widget> _content() {
    final now = DateTime.now();
    final last = _lastStart;
    final day = last == null ? null : now.difference(DateTime(last.year, last.month, last.day)).inDays + 1;
    final cycleDay = day == null ? null : ((day - 1) % _cycleLen) + 1;
    final phase = cycleDay == null ? null : phaseForDay(cycleDay, _cycleLen, _periodLen);
    final next = last?.add(Duration(days: _cycleLen * (((day! - 1) ~/ _cycleLen) + 1)));
    final daysToNext = next?.difference(DateTime(now.year, now.month, now.day)).inDays;
    final c = AppColors.cycle;

    ListRow symptom(String field, String label, IconData icon, List<String> options) => ListRow(
          icon: icon,
          color: c,
          title: label,
          value: _today?[field] ?? 'Log',
          onTap: () => _pickSymptom(field, label, options),
        );

    return [
      _hero(cycleDay, phase, next, daysToNext),
      if (phase != null) _PhaseMessage(phase: phase),
      if (_fertileWindow != null) _fertileCard(),
      if (!_pcosDiagnosed && _pcosSignals.length >= 2) _pcosCard(),
      SectionHeader('Your cycle calendar', subtitle: 'Tap a month to see its log', trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: 'Previous year', icon: const Icon(Symbols.chevron_left_rounded), onPressed: () => setState(() => _year--)),
        Text('$_year', style: T.labelLg),
        IconButton(tooltip: 'Next year', icon: const Icon(Symbols.chevron_right_rounded), onPressed: _year > now.year ? null : () => setState(() => _year++)),
      ])),
      const CalendarLegend(),
      YearCalendar(year: _year, marks: _marks, onMonth: _openMonth),
      VCard(
        color: AppColors.surfaceContainerLow,
        flat: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Symbols.insights_rounded, color: c, fill: 1, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Logging every month helps you spot your own patterns and any irregularities. Over time these records can help a doctor look into conditions such as polycystic ovary syndrome (PCOS). Tracking alone cannot diagnose PCOS.',
              style: T.bodySm.c(AppColors.onSurfaceVariant),
            ),
          ),
        ]),
      ),
      const SectionHeader('Today'),
      ListGroup(children: [
        symptom('cramps', 'Cramps', Symbols.healing_rounded, const ['None', 'Mild', 'Moderate', 'Strong']),
        symptom('cravings', 'Cravings', Symbols.icecream_rounded, const ['None', 'Sweet', 'Salty', 'Carb-heavy', 'Chocolate']),
        symptom('mood', 'Mood', Symbols.mood_rounded, const ['Calm', 'Happy', 'Low', 'Irritable', 'Anxious']),
        symptom('energy', 'Energy', Symbols.bolt_rounded, const ['Low', 'Steady', 'High']),
        symptom('sleep', 'Sleep', Symbols.bedtime_rounded, const ['Restful', 'Okay', 'Restless']),
        ListRow(icon: Symbols.edit_note_rounded, color: c, title: 'Spotting and notes', onTap: _moreLog),
      ]),
      const SectionHeader('What is happening?', subtitle: 'How your body changes through each phase'),
      VCard(child: CycleExplainer(cycleLen: _cycleLen, periodLen: _periodLen, current: phase)),
      ListGroup(children: [
        ListRow(
          icon: Symbols.notifications_active_rounded,
          color: AppColors.warning,
          title: 'Phase notifications',
          subtitle: (_prefs?.master ?? true) ? 'On, based on your logged dates' : 'Off',
          onTap: _notifySettings,
        ),
        ListRow(icon: Symbols.history_rounded, color: c, title: 'Cycle history', value: _lengths.isEmpty ? null : '$_cycleLen-day average', onTap: _history),
      ]),
      const PrivacyNote('A wellness tracker, not a diagnosis of any disease. Phases and dates are estimates. Your cycle data is private to you.'),
    ];
  }

  Widget _hero(int? cycleDay, CyclePhase? phase, DateTime? next, int? daysToNext) {
    final c = AppColors.cycle;
    final dark = AppColors.isDark;
    final copy = phase == null ? null : phaseCopy[phase]!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.xl),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          Color.alphaBlend(c.withValues(alpha: dark ? 0.30 : 0.16), AppColors.surfaceContainerLowest),
          Color.alphaBlend(AppColors.mind.withValues(alpha: dark ? 0.16 : 0.07), AppColors.surfaceContainerLowest),
        ]),
      ),
      padding: const EdgeInsets.all(Sp.md),
      child: Column(children: [
        SizedBox(
          width: 210,
          height: 210,
          child: Stack(alignment: Alignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => CustomPaint(size: const Size(210, 210), painter: _CycleWheel(cycleLen: _cycleLen, periodLen: _periodLen, day: cycleDay, reveal: v)),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (cycleDay == null)
                Icon(Symbols.menstrual_health_rounded, size: 40, color: c)
              else ...[
                Text('Day', style: T.labelMd.c(AppColors.onSurfaceVariant)),
                Text('$cycleDay', style: T.metric(46)),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(Rad.full)),
                  child: Text(copy!.name, style: T.labelSm.c(Colors.white).w(FontWeight.w800)),
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: Sp.sm),
        if (cycleDay == null) ...[
          Text('Start tracking', style: T.headlineSm),
          const SizedBox(height: 4),
          Text('Log the first day of your last period to see your phases, predictions and gentle tips.', textAlign: TextAlign.center, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ] else ...[
          Text.rich(
            TextSpan(text: 'Next period in about ', children: [TextSpan(text: '$daysToNext ${daysToNext == 1 ? 'day' : 'days'}', style: T.bodyLg.w(FontWeight.w800).c(c)), TextSpan(text: ' · ${DateFormat('d MMM').format(next!)}')]),
            textAlign: TextAlign.center,
            style: T.bodyLg.c(AppColors.onSurface),
          ),
          const SizedBox(height: 2),
          Text('An estimate based on your $_cycleLen-day average cycle', style: T.bodySm.c(AppColors.onSurfaceVariant)),
        ],
        const SizedBox(height: Sp.md),
        Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center, children: [
          _legend('Period', c),
          _legend('Follicular', c.withValues(alpha: 0.35)),
          _legend('Fertile', AppColors.mind),
          _legend('Luteal', AppColors.surfaceContainerHighest),
        ]),
        const SizedBox(height: Sp.md),
        PrimaryButton('Log period', leadingIcon: Symbols.water_drop_rounded, color: c, onTap: () => _logPeriod()),
      ]),
    );
  }

  Widget _fertileCard() {
    final (start, end) = _fertileWindow!;
    final fmt = DateFormat('d MMM');
    return VCard(
      color: AppColors.tint(AppColors.mind),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Symbols.egg_rounded, color: AppColors.mind, fill: 1),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Higher chance of pregnancy', style: T.headlineSm),
            const SizedBox(height: 4),
            Text('${fmt.format(start)} to ${fmt.format(end)}, based on your average cycle.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('An estimate, not a method of contraception. If you want to avoid pregnancy, use a reliable method and talk to a doctor about your options.',
                style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }

  Widget _pcosCard() => VCard(
        color: AppColors.warningContainer,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Symbols.info_rounded, color: AppColors.warning, fill: 1),
            const SizedBox(width: 10),
            Expanded(child: Text('A few signs worth discussing', style: T.headlineSm)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Your recent logs show: ${_pcosSignals.join(', ').toLowerCase()}. Together, these are sometimes associated with PCOS, though each has many other causes. Tracking alone cannot diagnose PCOS. Only a doctor can test for it properly.',
            style: T.bodyMd.c(AppColors.onSurface),
          ),
          const SizedBox(height: Sp.sm),
          Text('Gentle habits that can help ease and organise your cycle:', style: T.labelLg.semi),
          const SizedBox(height: 6),
          for (final t in const [
            'Favour whole grains, legumes and vegetables over refined carbs and sugary drinks, to keep blood sugar steadier.',
            'Add omega-3s (fish, flaxseed) and magnesium-rich foods (nuts, leafy greens). Both are linked to easier periods.',
            'A warm compress on the lower abdomen and gentle yoga or stretching can soothe cramps.',
            'Regular sleep and lower caffeine can help settle an irregular rhythm over a few cycles.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: AppColors.warning, shape: BoxShape.circle))),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: T.bodyMd.c(AppColors.onSurface))),
              ]),
            ),
          const SizedBox(height: 4),
          SoftButton('Talk to a professional', icon: Symbols.stethoscope_rounded, onTap: () => context.push('/professionals')),
        ]),
      );

  Widget _legend(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: T.bodySm.c(AppColors.onSurfaceVariant)),
      ]);
}

/// Warm, phase-specific message: how you might feel, why, and small ways
/// to look after yourself. Always framed as an estimate.
class _PhaseMessage extends StatefulWidget {
  const _PhaseMessage({required this.phase});
  final CyclePhase phase;
  @override
  State<_PhaseMessage> createState() => _PhaseMessageState();
}

class _PhaseMessageState extends State<_PhaseMessage> {
  bool _why = false;

  @override
  Widget build(BuildContext context) {
    final p = phaseCopy[widget.phase]!;
    final c = AppColors.cycle;
    return VCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: AppColors.tint(c),
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(p.icon, size: 16, color: c, fill: 1),
                    const SizedBox(width: 4),
                    Flexible(child: Text('You are probably in: ${p.name.toLowerCase()} phase', style: T.labelSm.c(c).w(FontWeight.w800))),
                  ]),
                  const SizedBox(height: 4),
                  Text(p.greeting, style: T.headlineMd),
                ]),
              ),
            ),
            SizedBox(width: 104, height: 96, child: SvgPicture.asset('assets/illustrations/${p.illustration}.svg', fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(Sp.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.message, style: T.bodyMd),
            const SizedBox(height: Sp.md),
            Text('You might notice', style: T.labelMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final n in p.mayNotice) TagPill(n, bg: AppColors.tint(c), fg: AppColors.onSurface)]),
            const SizedBox(height: Sp.md),
            Text('Try this', style: T.labelMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: 6),
            ValueListenableBuilder<bool>(
              valueListenable: CalmMusic.playing,
              builder: (_, playing, _) => Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in p.tryThis)
                  t.$2 == 'Calm music'
                      ? VChip(playing ? 'Pause calm music' : 'Play calm music', icon: playing ? Symbols.pause_rounded : Symbols.play_arrow_rounded, selected: playing, selectedColor: c, dense: true, onTap: CalmMusic.toggle)
                      : VChip(t.$2, icon: t.$1, dense: true),
              ]),
            ),
            const SizedBox(height: Sp.sm),
            InkWell(
              onTap: () => setState(() => _why = !_why),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text(p.whyTitle, style: T.labelLg.c(c))),
                  Icon(_why ? Symbols.expand_less_rounded : Symbols.expand_more_rounded, color: c),
                ]),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _why ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Text(p.why, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            ),
            const SizedBox(height: 6),
            Text('Phases are estimated from your logged dates. Everyone\'s body is different, so trust how you actually feel.', style: T.bodySm.c(AppColors.outline)),
          ]),
        ),
      ]),
    );
  }
}

class _CycleWheel extends CustomPainter {
  _CycleWheel({required this.cycleLen, required this.periodLen, required this.day, this.reveal = 1});
  final int cycleLen;
  final int periodLen;
  final int? day;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const w = 16.0;
    final r = size.width / 2 - w;
    final rect = Rect.fromCircle(center: c, radius: r);
    const start = -math.pi / 2;
    double a(int d) => 2 * math.pi * d / cycleLen * reveal;
    Paint p(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = color;
    const gap = 0.06;
    final ov = cycleLen - 14;
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = AppColors.surfaceContainerHigh.withValues(alpha: 0.6));
    canvas.drawArc(rect, start + gap, a(periodLen) - 2 * gap, false, p(AppColors.cycle));
    canvas.drawArc(rect, start + a(periodLen) + gap, a(ov - 3 - periodLen) - 2 * gap, false, p(AppColors.cycle.withValues(alpha: 0.35)));
    canvas.drawArc(rect, start + a(ov - 3) + gap, a(5) - 2 * gap, false, p(AppColors.mind));
    canvas.drawArc(rect, start + a(ov + 2) + gap, a(cycleLen - ov - 2) - 2 * gap, false, p(AppColors.surfaceContainerHighest));
    if (day != null && reveal >= 1) {
      final ang = start + a(day!) - a(1) / 2;
      final pt = c + Offset(math.cos(ang), math.sin(ang)) * r;
      canvas.drawCircle(pt, w / 2 + 5, Paint()..color = AppColors.surfaceContainerLowest);
      canvas.drawCircle(pt, w / 2 + 2, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.onSurface);
    }
  }

  @override
  bool shouldRepaint(covariant _CycleWheel old) => old.day != day || old.cycleLen != cycleLen || old.reveal != reveal;
}
