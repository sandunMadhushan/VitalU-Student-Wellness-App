import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
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
  String? _selectedDay;

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
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Log Sleep', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            Row(children: [
              Expanded(child: _timeTile('Bedtime', Symbols.routine, bed, () => pick(true))),
              const SizedBox(width: Sp.sm),
              Expanded(child: _timeTile('Wake-up', Symbols.wb_twilight, wake, () => pick(false))),
            ]),
            const SizedBox(height: Sp.sm),
            Center(child: Text(dur.isNegative || dur.inHours > 16 ? 'Please check the times' : 'Total: ${Fmt.hm(dur.inMinutes)}', style: T.labelLg.c(dur.isNegative ? AppColors.error : AppColors.primary))),
            const SizedBox(height: Sp.md),
            Text('How rested do you feel?', style: T.labelLg),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final q in const [(1, '😫'), (2, '😕'), (3, '😐'), (4, '🙂'), (5, '😴')])
                GestureDetector(
                  onTap: () => set(() => quality = q.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: quality == q.$1 ? AppColors.primaryFixed : AppColors.surfaceContainerLow, shape: BoxShape.circle),
                    child: Text(q.$2, style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ]),
            const SizedBox(height: Sp.lg),
            PrimaryButton('Save Sleep', color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, onTap: () async {
              if (dur.isNegative || dur.inMinutes < 30 || dur.inHours > 16) return toast(ctx, 'Sleep should be between 30 minutes and 16 hours.', error: true);
              await Repo.saveSleep(bedtime: bed, wake: wake, quality: quality);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  Widget _timeTile(String label, IconData icon, DateTime t, VoidCallback onTap) => VCard(
        color: AppColors.surfaceContainerLow,
        onTap: onTap,
        padding: const EdgeInsets.all(Sp.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: 6), Text(label, style: T.labelSm.c(AppColors.onSurfaceVariant))]),
          const SizedBox(height: 6),
          Text(DateFormat('h:mm a').format(t), style: T.headlineSm),
          Text(DateFormat('EEE d MMM').format(t), style: T.labelSm.c(AppColors.outline)),
        ]),
      );

  void _windDown() {
    showVSheet(context, builder: (ctx) => const _WindDown());
  }

  @override
  Widget build(BuildContext context) {
    final last = _last;
    final total = last == null ? 0 : Repo.sleepMinutes(last);
    final pct = total / _goalMin;
    final status = last == null ? 'No data' : (pct >= 0.9 ? 'Optimal' : (pct >= 0.75 ? 'Fair' : 'Short'));
    final now = DateTime.now();
    final ws = weekStart(now);
    final days = [for (int i = 0; i < 7; i++) ws.add(Duration(days: i))];
    final byDate = {for (final r in _week) r['sleep_date'] as String: r};
    final avg = _week.isEmpty ? 0 : (_week.map(Repo.sleepMinutes).reduce((a, b) => a + b) / _week.length).round();

    return VPage(
      header: const MainHeader('Vitalu   Health Tools'),
      nav: NavTab.tools,
      onRefresh: _load,
      children: _loading
          ? [const Loading()]
          : [
              Row(children: [
                CircleButton(Symbols.arrow_back, size: 36, iconSize: 18, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, shadow: Shadows.tiny, onTap: () => goBack(context, '/tools')),
                const SizedBox(width: Sp.xs),
                Flexible(child: TagPill('Rest & Circadian Rhythm', icon: Symbols.bedtime, fill: 1, iconColor: AppColors.primary, bg: AppColors.surfaceContainerHigh.withValues(alpha: 0.8), fg: AppColors.onSurface)),
                const Spacer(),
                TagPill('Private', icon: Symbols.lock, iconColor: AppColors.tertiary, bg: AppColors.surfaceContainerLowest),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Text('Sleep Quality', style: T.headlineLg)),
                  TagPill(status, bg: AppColors.primaryFixed, fg: AppColors.primary),
                ]),
                const SizedBox(height: 4),
                Text('Deep restorative rest between lectures, late-night study sessions, and campus life. No sleep guilt, just gentle rhythm.', style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.35)),
              ]),
              if (last == null)
                EmptyState(
                  icon: Symbols.bedtime,
                  title: 'No sleep logged yet',
                  text: 'Log last night to see your rest, timing and weekly rhythm.',
                  action: SoftButton('Log Sleep', icon: Symbols.add_circle, onTap: _logSleep, expand: false),
                )
              else
                _hero(last, total, pct),
              if (last != null)
                Row(children: [
                  Expanded(child: _timeStat('Bedtime', Symbols.routine, AppColors.primary, DateTime.parse(last['bedtime']).toLocal(), 'Consistent wind-down helps')),
                  const SizedBox(width: Sp.sm),
                  Expanded(child: _timeStat('Wake-up', Symbols.wb_twilight, AppColors.secondary, DateTime.parse(last['wake_time']).toLocal(), 'Natural wake window')),
                ]),
              VCard(
                color: AppColors.surfaceContainerLow,
                shadow: Shadows.tiny,
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Weekly Rhythm', style: T.headlineSm.lh(1.2)),
                        Text(_week.isEmpty ? 'No nights logged this week' : '${Fmt.hm(avg)} avg / night', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                      ]),
                    ),
                    TagPill('Goal: ${Fmt.hm(_goalMin)}', bg: AppColors.surfaceContainerHigh, fg: AppColors.onSurface),
                  ]),
                  const SizedBox(height: Sp.md),
                  SizedBox(
                    height: 150,
                    child: LayoutBuilder(builder: (context, c) {
                      const maxMin = 10 * 60.0;
                      const barArea = 120.0;
                      final goalY = barArea * (1 - _goalMin / maxMin);
                      return Stack(children: [
                        Positioned(
                          top: goalY,
                          left: 0,
                          right: 0,
                          child: Row(children: [
                            Expanded(child: Container(height: 1, color: AppColors.outlineVariant.withValues(alpha: 0.6))),
                            Text(' ${(_goalMin / 60).toStringAsFixed(0)}h', style: T.labelSm.s(9).c(AppColors.outline)),
                          ]),
                        ),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          for (final d in days)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedDay = isoDate(d)),
                                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  _sleepBar(byDate[isoDate(d)], isoDate(d) == isoDate(now) || isoDate(d) == _selectedDay, maxMin, barArea),
                                  const SizedBox(height: 6),
                                  Text(DateFormat('E').format(d).substring(0, d.weekday == 4 || d.weekday == 7 ? 2 : 1),
                                      style: T.labelSm.s(11).c(isoDate(d) == isoDate(now) ? AppColors.primary : AppColors.onSurfaceVariant)),
                                ]),
                              ),
                            ),
                        ]),
                      ]);
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(_dayFeedback(byDate), style: T.labelSm.s(11).c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
                ]),
              ),
              VCard(
                gradient: const LinearGradient(colors: [AppColors.surfaceContainerHigh, AppColors.surfaceContainerLow]),
                shadow: Shadows.tiny,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconCircle(Symbols.light_mode, size: 40, iconSize: 20, bg: AppColors.primaryFixed, fg: AppColors.onPrimaryFixedVariant, radius: 16),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('Hostel Room Wind-Down Tip', style: T.headlineSm.s(15))),
                        Text('Micro-habit', style: T.labelSm.s(10).c(AppColors.primary)),
                      ]),
                      const SizedBox(height: 4),
                      Text('Dimming screens 30 minutes before sleep helps your circadian rhythm reset after intense library screen time.', style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.35)),
                    ]),
                  ),
                ]),
              ),
              Column(children: [
                PrimaryButton('Start Sleep Wind-Down', leadingIcon: Symbols.play_circle, color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, height: 52, onTap: _windDown),
                const SizedBox(height: Sp.xs),
                SoftButton('Log Sleep Manually', icon: Symbols.add_circle, iconColor: AppColors.onSurfaceVariant, height: 46, style: T.labelMd, onTap: _logSleep),
              ]),
              const PrivacyNote('Sleep analytics remain private to you. Never shared with academic departments.'),
            ],
    );
  }

  String _dayFeedback(Map<String, Rec> byDate) {
    if (_selectedDay == null) return 'Tap a day to inspect duration & sleep stage shifts';
    final r = byDate[_selectedDay];
    final label = DateFormat('EEEE').format(DateTime.parse(_selectedDay!));
    if (r == null) return '$label: no sleep logged';
    final (d, rem, l, est) = _stages(r);
    return '$label: ${Fmt.hm(Repo.sleepMinutes(r))} • Deep ${Fmt.hm(d)} • REM ${Fmt.hm(rem)} • Light ${Fmt.hm(l)}${est ? ' (est.)' : ''}';
  }

  Widget _sleepBar(Rec? r, bool highlight, double maxMin, double area) {
    final min = r == null ? 0 : Repo.sleepMinutes(r);
    final h = r == null ? 8.0 : (area * (min / maxMin)).clamp(10.0, area);
    final over = min >= _goalMin;
    return Container(
      width: 28,
      height: h,
      decoration: BoxDecoration(
        color: r == null ? AppColors.surfaceContainerHigh : (highlight ? AppColors.primary : (over ? AppColors.secondaryContainer : AppColors.surfaceContainerHighest)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: highlight && r != null ? Shadows.tinted(AppColors.primary, opacity: 0.35, blur: 12, y: 4, spread: 0) : null,
      ),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 4),
      child: highlight && r != null ? Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle)) : null,
    );
  }

  Widget _timeStat(String label, IconData icon, Color c, DateTime t, String sub) => VCard(
        color: AppColors.surfaceContainerLow,
        padding: const EdgeInsets.all(Sp.sm),
        shadow: Shadows.tiny,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [IconCircle(icon, size: 32, iconSize: 18, fg: c, shadow: Shadows.tiny), const SizedBox(width: Sp.xs), Text(label, style: T.labelSm.c(AppColors.onSurfaceVariant))]),
          const SizedBox(height: 6),
          Text(DateFormat('h:mm a').format(t), style: T.headlineMd),
          Text(sub, style: T.bodySm.s(11).c(AppColors.onSurfaceVariant)),
        ]),
      );

  Widget _hero(Rec last, int total, double pct) {
    final bed = DateTime.parse(last['bedtime']).toLocal();
    final wake = DateTime.parse(last['wake_time']).toLocal();
    final (d, rem, l, est) = _stages(last);
    return VCard(
      clip: true,
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceContainerLow, AppColors.surfaceContainerHigh, AppColors.surfaceContainerHighest]),
      shadow: Shadows.card,
      onTap: () => _logSleep(existing: last),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: -48, right: -48, child: Glow(color: AppColors.primaryFixed.withValues(alpha: 0.4), size: 176)),
        Positioned(bottom: -32, left: -32, child: Glow(color: AppColors.secondaryFixed.withValues(alpha: 0.3), size: 144)),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), boxShadow: Shadows.tinted(AppColors.primary, opacity: 0.12, blur: 16, y: 4, spread: 0)),
              child: const AssetImg('moon_cloud', radius: 14),
            ),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isoDate(wake) == isoDate(DateTime.now()) ? "LAST NIGHT'S REST" : 'LATEST REST', style: T.labelSm.c(AppColors.onSurfaceVariant).tracking(1)),
                Text('${DateFormat('EEEE').format(bed)} Sleep', style: T.headlineSm.lh(1.2)),
              ]),
            ),
            Pill(
              color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shadow: Shadows.tiny,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Symbols.nights_stay, size: 15, color: AppColors.tertiary, fill: 1),
                const SizedBox(width: 4),
                Text(pct >= 0.9 ? 'Restful' : 'Light', style: T.labelSm),
              ]),
            ),
          ]),
          const SizedBox(height: Sp.sm),
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${total ~/ 60}'),
                TextSpan(text: 'h ', style: T.headlineMd.w(FontWeight.w400).c(AppColors.onSurfaceVariant)),
                TextSpan(text: '${total % 60}'),
                TextSpan(text: 'm', style: T.headlineMd.w(FontWeight.w400).c(AppColors.onSurfaceVariant)),
              ]),
              style: T.headlineXlMobile,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('of ${(_goalMin / 60).toStringAsFixed(0)}h gentle target (${(pct * 100).round()}%)', style: T.labelMd.c(AppColors.onSurfaceVariant)),
            ),
          ]),
          const SizedBox(height: Sp.sm),
          Row(children: [
            Text(est ? 'Estimated Sleep Cycles' : 'Stages Waveform', style: T.labelSm.c(AppColors.onSurfaceVariant)),
            const Spacer(),
            Text('${DateFormat('h:mm a').format(bed)} – ${DateFormat('h:mm a').format(wake)}', style: T.labelSm.c(AppColors.primary)),
          ]),
          const SizedBox(height: 4),
          Container(
            height: 96,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Expanded(child: CustomPaint(size: Size.infinite, painter: _Hypnogram(total))),
              const SizedBox(height: 2),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (int i = 0; i < 5; i++)
                  Text(DateFormat('h:mma').format(bed.add(Duration(minutes: (total * i / 4).round()))).toLowerCase().replaceAll('m', ''), style: T.labelSm.s(10).c(AppColors.onSurfaceVariant)),
              ]),
            ]),
          ),
          const SizedBox(height: Sp.sm),
          Row(children: [
            _stage('Deep', AppColors.primary, d),
            const SizedBox(width: 6),
            _stage('REM', AppColors.primaryContainer, rem),
            const SizedBox(width: 6),
            _stage('Light', AppColors.secondaryContainer, l),
          ]),
        ]),
      ]),
    );
  }

  Widget _stage(String name, Color c, int minutes) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(name, style: T.labelSm.s(11).c(AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 2),
            Text(Fmt.hm(minutes), style: T.labelMd),
          ]),
        ),
      );
}

/// Stylised hypnogram based on ~90-minute sleep cycles.
class _Hypnogram extends CustomPainter {
  _Hypnogram(this.minutes);
  final int minutes;
  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 0.75;
    for (final y in [0.25, 0.62]) {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, size.height * y), Offset(x + 2, size.height * y), guide);
        x += 5;
      }
    }
    final cycles = math.max(1.0, minutes / 90);
    final pts = <Offset>[];
    const n = 80;
    for (int i = 0; i <= n; i++) {
      final t = i / n;
      final phase = t * cycles * 2 * math.pi;
      final depthDecay = 1 - 0.5 * t; // deep sleep dominates early in the night
      final v = 0.5 + 0.42 * math.cos(phase) * depthDecay; // 0 = awake/REM (top), 1 = deep (bottom)
      pts.add(Offset(t * size.width, size.height * (0.15 + 0.8 * (1 - v))));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1], p1 = pts[i];
      path.quadraticBezierTo(p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
            AppColors.primary.withValues(alpha: 0.55),
            AppColors.primaryContainer.withValues(alpha: 0.25),
            AppColors.primaryFixedDim.withValues(alpha: 0.05),
          ]).createShader(Offset.zero & size));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant _Hypnogram old) => old.minutes != minutes;
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
  static const _steps = ['Dim screens & lights', 'Put your phone on Do Not Disturb', 'Sip some water', 'Stretch gently for 2 minutes', 'Write tomorrow\'s top 3 tasks'];

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
        Text('Sleep Wind-Down', style: T.headlineMd, textAlign: TextAlign.center),
        const SizedBox(height: Sp.md),
        Center(
          child: Ring(
            value: 1 - _left / total,
            size: 150,
            stroke: 10,
            color: AppColors.primary,
            child: Text('${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}', style: T.headlineLg),
          ),
        ),
        const SizedBox(height: Sp.md),
        for (int i = 0; i < _steps.length; i++)
          CheckboxListTile(
            value: _done.contains(i),
            onChanged: (v) => setState(() => v == true ? _done.add(i) : _done.remove(i)),
            title: Text(_steps[i], style: T.bodyMd),
            activeColor: AppColors.tertiary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        const SizedBox(height: Sp.sm),
        SoftButton('Guided breathing', icon: Symbols.air, iconColor: AppColors.primary, onTap: () => showBreathing(context, cta: 'Good night 🌙')),
        const SizedBox(height: Sp.sm),
        PrimaryButton(_left <= 0 ? 'Good night 🌙' : 'Finish early', color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, onTap: () => Navigator.pop(context)),
      ]);
}
