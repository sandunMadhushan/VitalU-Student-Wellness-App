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
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// MET values (Compendium of Physical Activities, approximate).
const activityTypes = <(String, IconData, double)>[
  ('Walk', Symbols.directions_walk, 3.5),
  ('Brisk walk', Symbols.hiking, 4.3),
  ('Run', Symbols.sprint, 8.0),
  ('Cycle', Symbols.pedal_bike, 6.0),
  ('Sports', Symbols.sports_cricket, 7.0),
  ('Gym', Symbols.fitness_center, 5.0),
  ('Yoga / Stretch', Symbols.self_improvement, 2.5),
  ('Dance', Symbols.music_note, 5.0),
  ('Stairs', Symbols.stairs, 4.0),
];

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  Rec _today = {'steps': 0, 'minutes': 0, 'kcal': 0, 'km': 0.0, 'logs': <Rec>[]};
  Map<String, int> _week = {};
  DateTime? _lastSync;
  bool _syncing = false;

  int get _goal => AppState.instance.profile?.stepGoal ?? 8000;

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
      final prefs = await SharedPreferences.getInstance();
      final ls = prefs.getString('ped_last_sync');
      _lastSync = ls == null ? null : DateTime.tryParse(ls);
    } catch (_) {}
    if (mounted) setState(() {});
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
      if (mounted) toast(context, 'Synced $steps steps from your phone 👟');
    } on TimeoutException {
      if (mounted) toast(context, 'No step sensor data yet — walk a little and try again.', error: true);
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
            Text('Log Activity', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Every bit of movement counts — walking to lectures included.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in activityTypes) VChip(t.$1, icon: t.$2, selected: type.$1 == t.$1, selectedColor: AppColors.secondary, onTap: () => set(() => type = t)),
            ]),
            const SizedBox(height: Sp.md),
            VTextField(controller: minutes, hint: 'Duration (minutes)', icon: Symbols.schedule, keyboard: TextInputType.number),
            const SizedBox(height: Sp.sm),
            VTextField(controller: steps, hint: 'Steps (optional)', icon: Symbols.footprint, keyboard: TextInputType.number),
            const SizedBox(height: Sp.sm),
            VTextField(controller: km, hint: 'Distance km (optional)', icon: Symbols.near_me, keyboard: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save Activity', color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, onTap: () async {
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
    final maxBar = [_goal * 1.2, ...days.map((d) => (_week[isoDate(d)] ?? 0).toDouble())].reduce((a, b) => a > b ? a : b);
    final weekNo = weekOfYear(now);

    return VPage(
      header: const MainHeader('VitalU Health Tools'),
      nav: NavTab.tools,
      onRefresh: _load,
      children: [
        Row(children: [
          Flexible(child: TagPill('Personal Wellness Vault • Movement', icon: Symbols.lock, bg: AppColors.secondaryFixed.withValues(alpha: 0.5), fg: AppColors.onSecondaryFixedVariant)),
          const SizedBox(width: 8),
          Text('Today, ${DateFormat('MMM d').format(now)}', style: T.labelSm.c(AppColors.outline)),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, onTap: () => goBack(context, '/tools')),
            const SizedBox(width: 10),
            Text('Campus Movement', style: T.headlineMd),
          ]),
          const SizedBox(height: 4),
          Text('Gentle campus strolls, stair climbs between classes, and mindful movement. No workout guilt, just moving at your rhythm.', style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.4)),
        ]),
        VCard(
          radius: Rad.xl,
          clip: true,
          shadow: Shadows.card,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(top: -48, right: -48, child: Glow(color: AppColors.secondaryFixed.withValues(alpha: 0.3), size: 192)),
            Positioned(bottom: -40, left: -40, child: Glow(color: AppColors.primaryFixed.withValues(alpha: 0.3), size: 176)),
            Column(children: [
              SizedBox(
                width: 256,
                height: 256,
                child: Ring(
                  value: pct,
                  size: 256,
                  stroke: 16,
                  gradient: [AppColors.secondaryContainer, AppColors.secondary, AppColors.primaryContainer, AppColors.secondaryContainer],
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.secondaryFixed.withValues(alpha: 0.4), shape: BoxShape.circle),
                      child: ClipOval(child: const AssetImg('sneakers')),
                    ),
                    const SizedBox(height: 4),
                    Text(Fmt.thousands(steps), style: T.headlineXlMobile),
                    Text('of ${Fmt.thousands(_goal)} gentle steps', style: T.labelSm.c(AppColors.onSurfaceVariant).medium),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Pill(
                color: AppColors.secondaryFixed,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${(pct * 100).round()}% of Daily Pace', style: T.labelMd.c(AppColors.onSecondaryFixed)),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.lg)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Symbols.auto_awesome, size: 18, color: AppColors.secondary, fill: 1),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps == 0
                          ? 'Sync your phone steps or log a walk to start today\'s rhythm.'
                          : pct >= 1
                              ? 'Wonderful! You reached your step goal — your heart thanks you.'
                              : 'Great job! You reached ${Fmt.k(steps)} steps just moving around campus.',
                      style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.35),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
        Row(children: [
          _metric(Symbols.schedule, AppColors.secondaryFixedDim.withValues(alpha: 0.3), AppColors.secondary, '${_today['minutes']} min', 'Active Time', 'Walk to class'),
          const SizedBox(width: 10),
          _metric(Symbols.near_me, AppColors.primaryFixed, AppColors.primary, '${(_today['km'] as num).toStringAsFixed(1)} km', 'Distance', 'Campus loops'),
          const SizedBox(width: 10),
          _metric(Symbols.local_fire_department, AppColors.secondaryContainer, AppColors.onSecondaryContainer, '${_today['kcal']} kcal', 'Energy', 'Gentle exertion'),
        ]),
        VCard(
          radius: Rad.xl,
          shadow: Shadows.card,
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("This Week's Rhythm", style: T.headlineSm),
                  Text('Average ${Fmt.thousands(avg)} steps / day', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
              TagPill('Week $weekNo', icon: Symbols.tune),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Stack(children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 32 + 136 * (1 - _goal / maxBar) - 7,
                  child: Row(children: [
                    Expanded(child: CustomPaint(size: const Size(double.infinity, 1), painter: _Dashed())),
                    const SizedBox(width: 4),
                    Text('GOAL (${Fmt.k(_goal)})', style: T.labelSm.s(10).c(AppColors.outline).tracking(0.8)),
                  ]),
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final d in days) Expanded(child: _bar(d, now, maxBar)),
                ]),
              ]),
            ),
          ]),
        ),
        PrimaryButton('Log Activity Manually', leadingIcon: Symbols.add, color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, height: 52, onTap: _logManual),
        if (!kIsWeb)
        Pressable(
          onTap: _syncing ? null : _sync,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Rad.full), boxShadow: Shadows.tiny),
            child: Row(children: [
              IconCircle(Symbols.sync, size: 32, iconSize: 18, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Phone Step Sensor Sync', style: T.labelMd),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: _lastSync != null ? AppColors.tertiary : AppColors.outline, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(
                      _syncing ? 'Syncing…' : (_lastSync == null ? 'Tap to connect' : 'Synced ${_ago(_lastSync!)}'),
                      style: T.labelSm.s(10).c(_lastSync != null ? AppColors.tertiary : AppColors.outline),
                    ),
                  ]),
                ]),
              ),
              _syncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Symbols.chevron_right, color: AppColors.outline, size: 20),
            ]),
          ),
        ),
        if ((_today['logs'] as List).isNotEmpty)
          VCard(
            color: AppColors.surfaceContainerLow,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Today's activities", style: T.labelLg),
              const SizedBox(height: 8),
              for (final l in (_today['logs'] as List).cast<Rec>())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(activityTypes.firstWhere((t) => t.$1 == l['activity_type'], orElse: () => activityTypes.first).$2, size: 18, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${l['activity_type']}${l['source'] == 'sensor' ? ' • phone sensor' : ''}', style: T.bodySm)),
                    Text('${l['active_minutes']} min • ${Fmt.thousands(l['steps'])} steps', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                  ]),
                ),
            ]),
          ),
        const PrivacyNote('Activity data stays private to you. No leaderboards or competitive ranking.'),
      ],
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} mins ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return DateFormat('d MMM').format(t);
  }

  Widget _metric(IconData icon, Color bg, Color fg, String value, String label, String sub) => Expanded(
        child: VCard(
          padding: const EdgeInsets.all(12),
          shadow: Shadows.tiny,
          child: Column(children: [
            IconCircle(icon, size: 36, iconSize: 20, bg: bg, fg: fg),
            const SizedBox(height: 6),
            FittedBox(child: Text(value, style: T.headlineSm)),
            const SizedBox(height: 2),
            Text(label, style: T.labelSm, overflow: TextOverflow.ellipsis),
            Text(sub, style: T.labelSm.s(10).c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  Widget _bar(DateTime d, DateTime now, double maxBar) {
    final isToday = isoDate(d) == isoDate(now);
    final v = (_week[isoDate(d)] ?? 0).toDouble();
    final frac = (v / maxBar).clamp(0.0, 1.0);
    final future = d.isAfter(now);
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      SizedBox(
        height: 22,
        child: isToday && v > 0
            ? Pill(color: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(Fmt.k(v), style: T.labelSm.s(10).c(AppColors.onPrimary)))
            : null,
      ),
      const SizedBox(height: 4),
      Container(
        width: 28,
        height: 144,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isToday ? AppColors.primaryFixed.withValues(alpha: 0.4) : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isToday ? const [BoxShadow(color: Color(0x407459F7), blurRadius: 12)] : null,
        ),
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: future ? 0 : frac,
          child: Container(
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary : (v >= _goal ? AppColors.secondaryFixed : AppColors.secondaryFixedDim),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: isToday ? BoxDecoration(color: AppColors.primaryFixed, borderRadius: BorderRadius.circular(99)) : null,
        child: Text(DateFormat('E').format(d).substring(0, 1), style: T.labelSm.c(isToday ? AppColors.primary : AppColors.onSurfaceVariant).w(isToday ? FontWeight.w700 : FontWeight.w500)),
      ),
    ]);
  }
}

class _Dashed extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), p);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
