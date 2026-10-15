import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state.dart';
import '../../core/badges.dart';
import '../../core/sfx.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/weather.dart';
import '../../ui/badge_ui.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'tool_widgets.dart';

class _Preset {
  const _Preset(this.ml, this.title, this.sub, this.icon);
  final int ml;
  final String title;
  final String sub;
  final IconData icon;
}

const _presets = [
  _Preset(250, 'Standard glass', 'A regular drinking glass', Symbols.local_drink_rounded),
  _Preset(500, 'Water bottle', '500 ml bottle', Symbols.water_full_rounded),
  _Preset(1000, 'Water bottle', '1 L bottle', Symbols.water_bottle_large_rounded),
  _Preset(750, 'Sports tumbler', '750 ml tumbler', Symbols.sports_rounded),
];

String sipLabel(DateTime t) {
  final h = t.hour;
  if (h < 9) return 'Morning Wake-up';
  if (h < 12) return 'Study Break Sip';
  if (h < 14) return 'Lunch Hydration';
  if (h < 17) return 'Afternoon Lecture Sip';
  if (h < 20) return 'Evening Refresh';
  return 'Night Wind-down';
}

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});
  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  bool _loading = true;
  List<Rec> _logs = [];
  late bool _nudge = AppState.instance.profile?.waterNudge ?? true;
  WeatherNow? _wx;
  bool _wxLoading = true;
  int _streakVersion = 0;

  int get _goal => AppState.instance.profile?.waterGoalMl ?? 2500;
  int get _total => _logs.fold<int>(0, (a, r) => a + (r['amount_ml'] as int));
  int get _heatBonus => Calc.heatAdjustmentMl(_wx?.tempC);

  @override
  void initState() {
    super.initState();
    _load();
    _firstWeather();
  }

  /// Asks for location once, the first time the tracker is opened; later
  /// visits use it silently if allowed and fall back to an estimate if not.
  Future<void> _firstWeather() async {
    var ask = false;
    try {
      final p = await SharedPreferences.getInstance();
      ask = !(p.getBool('wx_location_asked') ?? false);
      if (ask) await p.setBool('wx_location_asked', true);
    } catch (_) {}
    await _loadWeather(ask: ask);
  }

  /// [ask] may show the location prompt; the refresh button always asks, so
  /// the student can switch from an estimate to their real location.
  Future<void> _loadWeather({bool force = false, bool ask = false}) async {
    setState(() => _wxLoading = true);
    final w = await Weather.current(force: force, askPermission: ask);
    if (!mounted) return;
    setState(() {
      _wx = w ?? _wx;
      _wxLoading = false;
    });
    if (ask && force && w != null && w.locationBlocked) {
      toast(context, 'Location is off for VitalU, so this is an estimate. Allow location in your browser or phone settings for your exact area.');
    }
  }

  String _wxPlace(WeatherNow w) {
    final place = switch (w.source) {
      WeatherSource.device => w.place ?? 'Your location',
      WeatherSource.network => w.place == null ? 'Approximate area' : 'Around ${w.place}',
      WeatherSource.campus => 'Kandy area (estimate)',
    };
    final mins = DateTime.now().difference(w.at).inMinutes;
    return '$place · ${mins < 1 ? 'now' : 'updated ${DateFormat.jm().format(w.at)}'}';
  }

  Future<void> _load() async {
    try {
      _logs = await Repo.waterOn(DateTime.now());
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _log(int ml, {String? label, String? location}) async {
    HapticFeedback.lightImpact();
    Sfx.pour();
    final now = DateTime.now();
    final before = _total;
    // Show the new level straight away so the bottle reacts to the tap.
    setState(() => _logs = [..._logs, {'amount_ml': ml, 'logged_at': now.toUtc().toIso8601String(), 'label': label ?? sipLabel(now), 'location': location, 'id': null}]);
    try {
      final earnedBefore = (await Repo.earnedBadges()).containsKey(StreakBadge.water.code);
      await Repo.addWater(ml, label: label ?? sipLabel(now), location: location);
      await _load();
      if (mounted) setState(() => _streakVersion++);
      if (before < _goal && _total >= _goal) {
        final info = await Streaks.of(StreakKind.water);
        // A third day in a row earns the badge: the app-wide badge pop-up
        // celebrates that one, so only show the day pop-up otherwise.
        if (mounted && (earnedBefore || info.streak < info.length)) await showStreakDayPopup(context, StreakKind.water, info);
      }
      if (_total >= _goal) await Repo.clearScheduled('/tools/water');
      if (_nudge && _total < _goal) {
        await Repo.clearScheduled('/tools/water');
        await Repo.schedule(
          title: 'Time for water',
          body: 'A glass now keeps you on track. You are at ${Fmt.litres(_total)}L of ${Fmt.litres(_goal)}L.',
          category: 'reminder',
          label: 'Reminder',
          icon: 'water_drop',
          route: '/tools/water',
          at: now.add(const Duration(hours: 2)),
        );
      }
      if (mounted) toast(context, 'Added $ml ml');
    } catch (_) {
      await _load();
      if (mounted) toast(context, 'Could not log water. Check your connection.', error: true);
    }
  }

  Future<void> _custom() async {
    final amount = TextEditingController();
    final place = TextEditingController();
    await showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Custom amount', style: T.headlineMd),
          const SizedBox(height: Sp.md),
          VTextField(controller: amount, hint: 'Amount in ml (e.g. 330)', icon: Symbols.water_drop_rounded, keyboard: TextInputType.number),
          const SizedBox(height: Sp.sm),
          VTextField(controller: place, hint: 'Where? (optional) e.g. Library', icon: Symbols.location_on_rounded),
          const SizedBox(height: Sp.md),
          PrimaryButton('Add', onTap: () {
            final ml = int.tryParse(amount.text);
            if (ml == null || ml <= 0 || ml > 3000) return toast(ctx, 'Enter an amount between 1 and 3000 ml', error: true);
            Navigator.pop(ctx);
            _log(ml, location: place.text.trim().isEmpty ? null : place.text.trim());
          }),
        ]));
  }

  Future<void> _delete(Rec r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this entry?'),
        content: Text('${r['amount_ml']} ml at ${DateFormat('h:mm a').format(DateTime.parse(r['logged_at']).toLocal())}'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove'))],
      ),
    );
    if (ok == true) {
      await Repo.deleteWater(r['id']);
      await _load();
      if (mounted) setState(() => _streakVersion++);
    }
  }

  (String, IconData) get _pace {
    final now = DateTime.now();
    final startH = 7.0, endH = 22.0;
    final frac = ((now.hour + now.minute / 60 - startH) / (endH - startH)).clamp(0.0, 1.0);
    final expected = _goal * frac;
    if (_total >= _goal) return ('Daily goal reached.', Symbols.celebration_rounded);
    if (_total >= expected * 0.85) return ("You're on pace for today.", Symbols.schedule_rounded);
    return ('A little behind. A glass now helps.', Symbols.water_drop_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_total / _goal).clamp(0.0, 9.99);
    final pace = _pace;
    final c = AppColors.water;
    final weight = AppState.instance.profile?.weightKg;

    return VPage(
      header: TitleHeader('Water intake tracker', onLeading: () => goBack(context, '/tools')),
      onRefresh: () async {
        await _load();
        setState(() => _streakVersion++);
        _loadWeather(force: true);
      },
      children: [
        // 1. Your numbers and reminders.
        ListGroup(children: [
          ListRow(icon: Symbols.monitor_weight_rounded, color: c, title: 'Body weight', value: weight == null ? 'Add weight' : '${weight.round()} kg', onTap: _adjustGoal),
          ListRow(icon: Symbols.flag_rounded, color: c, title: 'Daily goal', value: '${Fmt.litres(_goal)} L', onTap: _adjustGoal),
          ListRow(
            icon: Symbols.notifications_active_rounded,
            color: AppColors.warning,
            title: 'Reminders',
            subtitle: 'A nudge two hours after each log',
            trailing: Switch(
              value: _nudge,
              onChanged: (v) async {
                setState(() => _nudge = v);
                await AppState.instance.updateProfile({'water_nudge_enabled': v});
                if (!v) await Repo.clearScheduled('/tools/water');
              },
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: Sfx.enabled,
            builder: (_, on, _) => ListRow(
              icon: Symbols.volume_up_rounded,
              color: AppColors.mind,
              title: 'Sound effects',
              subtitle: 'Pouring sound and badge fanfare',
              trailing: Switch(value: on, onChanged: Sfx.setEnabled),
            ),
          ),
        ]),
        // 2. How the goal is worked out.
        _goalExplainer(weight),
        // 3. The bottle.
        VCard(
          child: Row(children: [
            Column(children: [
              AnimatedWaterBottle(value: pct, color: c, width: 86, height: 168),
              const SizedBox(height: 6),
              Text('${(pct * 100).round()}%', style: T.labelMd.tnum.c(AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(width: Sp.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CategoryLabel('Today', icon: Symbols.water_drop_rounded, color: c),
                const SizedBox(height: 6),
                MetricValue(Fmt.litres(_total), unit: 'L', size: 34),
                Text('of ${Fmt.litres(_goal)} L · ${(_total / 250).round()} glasses', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                const SizedBox(height: 10),
                Bar(value: pct, color: c),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(pace.$2, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(pace.$1, style: T.bodySm.c(AppColors.onSurfaceVariant))),
                ]),
              ]),
            ),
          ]),
        ),
        _weatherCard(),
        // 4. Add water.
        const SectionHeader('Add water'),
        TileGrid(children: [for (final p in _presets) _preset(p)]),
        SoftButton('Custom amount', icon: Symbols.add_rounded, onTap: _custom),
        // 5. Badge streak.
        StreakBadgeCard(kind: StreakKind.water, version: _streakVersion),
        // 6. Today's logs, newest first.
        SectionHeader('Water log', trailing: Text('${_logs.length} ${_logs.length == 1 ? 'entry' : 'entries'}', style: T.labelMd.c(AppColors.onSurfaceVariant))),
        if (_loading)
          const Loading()
        else if (_logs.isEmpty)
          Text('Nothing logged yet today.', style: T.bodyMd.c(AppColors.onSurfaceVariant))
        else
          ListGroup(children: [for (final r in _logs.reversed) _entry(r)]),
        const PrivacyNote('A wellness tracker, not a diagnosis of any disease.'),
      ],
    );
  }

  /// Today's temperature with suggestions for that kind of day. Always
  /// shown, not only on hot days.
  Widget _weatherCard() {
    final t = _wx?.tempC;
    if (t == null) {
      return VCard(
        color: AppColors.surfaceContainerLow,
        flat: true,
        child: Row(children: [
          Icon(Symbols.thermostat_rounded, size: 22, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(_wxLoading ? 'Checking the temperature near you…' : "Couldn't get today's temperature. Pull down to try again.", style: T.bodyMd.c(AppColors.onSurfaceVariant))),
          if (_wxLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
      );
    }
    final hot = t >= 30, warm = t >= 25;
    final c = hot ? AppColors.activity : (warm ? AppColors.warning : AppColors.water);
    final wx = _wx!;
    final icon = switch (wx.code) {
      0 => wx.isDay ? Symbols.sunny_rounded : Symbols.clear_night_rounded,
      1 || 2 => wx.isDay ? Symbols.partly_cloudy_day_rounded : Symbols.partly_cloudy_night_rounded,
      3 || 45 || 48 => Symbols.cloud_rounded,
      51 || 53 || 55 || 56 || 57 || 61 || 63 || 66 || 80 || 81 => Symbols.rainy_rounded,
      65 || 67 || 82 => Symbols.rainy_heavy_rounded,
      95 || 96 || 99 => Symbols.thunderstorm_rounded,
      _ => hot ? Symbols.sunny_rounded : (warm ? Symbols.partly_cloudy_day_rounded : Symbols.cloud_rounded),
    };
    final (title, text, tips) = hot
        ? (
            'Hot day: drink a little extra',
            'Your body loses more water in the heat. Aim for about $_heatBonus ml extra today, around ${Fmt.litres(_goal + _heatBonus)} L in total.',
            ['Carry a full bottle to every lecture', 'Have a glass after walking between faculties', 'King coconut or plain water beats fizzy drinks'],
          )
        : warm
            ? (
                'Warm day: keep sipping',
                'Your daily goal of ${Fmt.litres(_goal)} L is about right. Spread it out so you are never very thirsty.',
                ['A glass with every meal', 'Refill your bottle at lunch', 'Drink more if you play sport today'],
              )
            : (
                'Cool day: your goal is enough',
                'You may feel less thirsty when it is cool, but your body still needs about ${Fmt.litres(_goal)} L.',
                ['Warm water or plain tea counts too', 'Set a sip reminder for long study blocks', 'Check your urine is pale yellow'],
              );
    final dark = AppColors.isDark;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.lg),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          Color.alphaBlend(c.withValues(alpha: dark ? 0.26 : 0.16), AppColors.surfaceContainerLowest),
          Color.alphaBlend(c.withValues(alpha: dark ? 0.08 : 0.04), AppColors.surfaceContainerLowest),
        ]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 34, color: c, fill: 1),
          const SizedBox(width: 10),
          Text('${t.round()}°C', style: T.metric(32)),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (wx.condition != null) Text(wx.condition!, style: T.labelMd.semi),
                Row(children: [
                  if (wx.source == WeatherSource.device) ...[Icon(Symbols.near_me_rounded, size: 13, fill: 1, color: AppColors.onSurfaceVariant), const SizedBox(width: 3)],
                  Flexible(child: Text(_wxPlace(wx), style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 2)),
                ]),
              ]),
            ),
          ),
          _wxLoading
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  tooltip: 'Refresh for my current location',
                  icon: Icon(Symbols.my_location_rounded, size: 20, color: AppColors.onSurfaceVariant),
                  onPressed: () => _loadWeather(force: true, ask: true),
                ),
        ]),
        const SizedBox(height: 8),
        Text(title, style: T.headlineSm),
        const SizedBox(height: 2),
        Text(text, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: 10),
        for (final tip in tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Symbols.water_drop_rounded, size: 16, color: c, fill: 1),
              const SizedBox(width: 8),
              Expanded(child: Text(tip, style: T.bodyMd)),
            ]),
          ),
      ]),
    );
  }

  /// "60 kg × 35 ml = 2.1 L", spelled out, plus what changes the target.
  Widget _goalExplainer(double? weight) {
    final c = AppColors.water;
    final fromWeight = weight == null ? null : Calc.waterTargetFor(weight);
    final custom = fromWeight != null && fromWeight != _goal;
    Widget term(String value, String label) => Expanded(
          child: Column(children: [
            Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Rad.base)),
              child: Text(value, style: T.metric(18).c(c)),
            ),
            const SizedBox(height: 4),
            Text(label, style: T.labelSm.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          ]),
        );
    Widget op(String o) => Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 18), child: Text(o, style: T.headlineMd.c(AppColors.onSurfaceVariant)));
    return VCard(
      color: AppColors.tint(c),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Symbols.calculate_rounded, size: 20, color: c, fill: 1),
          const SizedBox(width: 8),
          Expanded(child: Text('How your goal is worked out', style: T.headlineSm)),
        ]),
        const SizedBox(height: Sp.md),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          term(weight == null ? '? kg' : '${weight.round()} kg', 'Your weight'),
          op('×'),
          term('35 ml', 'Per kg'),
          op('='),
          term(fromWeight == null ? '?' : '${Fmt.litres(fromWeight)} L', 'Daily water'),
        ]),
        const SizedBox(height: Sp.md),
        Text(
          weight == null
              ? 'Add your body weight above to get a personal target. Until then we use ${Fmt.litres(_goal)} L.'
              : custom
                  ? 'You set your own goal of ${Fmt.litres(_goal)} L, which is what the bottle below tracks.'
                  : 'About ${(_goal / 250).round()} glasses spread through the day. Drink a little more on hot days or after sport.',
          style: T.bodySm.c(AppColors.onSurfaceVariant),
        ),
      ]),
    );
  }

  Future<void> _adjustGoal() async {
    double weight = AppState.instance.profile?.weightKg ?? 60;
    double v = _goal.toDouble();
    bool useWeight = true;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          final suggested = Calc.waterTargetFor(weight);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Daily goal', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Amount of water (ml) = body weight (kg) × 35.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.lg),
            Text('Body weight', style: T.labelLg),
            const SizedBox(height: 8),
            Row(children: [
              IconButton.outlined(icon: const Icon(Symbols.remove_rounded), onPressed: () => set(() => weight = (weight - 1).clamp(35, 150))),
              Expanded(child: Center(child: MetricValue(weight.round().toString(), unit: 'kg', size: 28))),
              IconButton.outlined(icon: const Icon(Symbols.add_rounded), onPressed: () => set(() => weight = (weight + 1).clamp(35, 150))),
            ]),
            const SizedBox(height: Sp.sm),
            Text('Target from weight: ${Fmt.litres(suggested)} L a day.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.lg),
            const Divider(),
            const SizedBox(height: Sp.sm),
            Row(children: [
              Expanded(child: Text('Use this as my goal', style: T.labelLg)),
              Switch(value: useWeight, onChanged: (x) => set(() => useWeight = x)),
            ]),
            if (!useWeight) ...[
              const SizedBox(height: Sp.sm),
              Center(child: MetricValue(Fmt.litres(v), unit: 'L', size: 36)),
              VSlider(value: v, min: 1500, max: 4000, divisions: 25, color: AppColors.water, onChanged: (x) => set(() => v = x)),
            ],
            Text('Drink more in hot weather or after sport. We add a suggestion automatically.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save', onTap: () async {
              final goal = useWeight ? suggested : v.round();
              await AppState.instance.updateProfile({'weight_kg': weight, 'water_goal_ml': goal});
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            }),
          ]);
        }));
  }

  Widget _preset(_Preset p) => VCard(
        onTap: () => _log(p.ml, label: sipLabel(DateTime.now())),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          IconCircle(p.icon, size: 40, iconSize: 20, fg: AppColors.water),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.ml} ml', style: T.labelLg.semi.tnum),
              Text(p.title, style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );

  Widget _entry(Rec r) {
    final t = DateTime.parse(r['logged_at']).toLocal();
    return ListRow(
      icon: Symbols.water_drop_rounded,
      color: AppColors.water,
      title: r['label'] ?? sipLabel(t),
      subtitle: '${DateFormat('h:mm a').format(t)}${r['location'] != null ? ' · ${r['location']}' : ''}',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${r['amount_ml']} ml', style: T.bodyMd.tnum.c(AppColors.onSurfaceVariant)),
        IconButton(tooltip: 'Remove', icon: Icon(Symbols.delete_rounded, size: 20, color: AppColors.outline), onPressed: r['id'] == null ? null : () => _delete(r)),
      ]),
    );
  }
}
