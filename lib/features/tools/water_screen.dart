import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/weather.dart';
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
  double? _tempC;

  int get _goal => AppState.instance.profile?.waterGoalMl ?? 2500;
  int get _total => _logs.fold<int>(0, (a, r) => a + (r['amount_ml'] as int));
  int get _heatBonus => Calc.heatAdjustmentMl(_tempC);

  @override
  void initState() {
    super.initState();
    _load();
    Weather.currentTempC().then((t) {
      if (mounted) setState(() => _tempC = t);
    });
  }

  Future<void> _load() async {
    try {
      _logs = await Repo.waterOn(DateTime.now());
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _log(int ml, {String? label, String? location}) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    try {
      await Repo.addWater(ml, label: label ?? sipLabel(now), location: location);
      await _load();
      if (_nudge && _total < _goal) {
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
      _load();
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

    return VPage(
      header: TitleHeader('Water intake tracker', onLeading: () => goBack(context, '/tools')),
      onRefresh: _load,
      children: [
        VCard(
          child: Row(children: [
            Column(children: [
              AnimatedWaterBottle(value: pct, color: c),
              const SizedBox(height: 6),
              Text('${(pct * 100).round()}%', style: T.labelMd.tnum.c(AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(width: Sp.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CategoryLabel('Today', icon: Symbols.water_drop_rounded, color: c),
                const SizedBox(height: 6),
                MetricValue(Fmt.litres(_total), unit: 'L', size: 32),
                Text('of ${Fmt.litres(_goal)} L · ${(_total / 250).round()} glasses', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(pace.$2, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(pace.$1, style: T.bodySm.c(AppColors.onSurfaceVariant))),
                ]),
              ]),
            ),
          ]),
        ),
        if (_heatBonus > 0)
          VCard(
            color: AppColors.warningContainer,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Symbols.sunny_rounded, size: 22, color: AppColors.warning, fill: 1),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hot day, about ${_tempC!.round()}°C', style: T.headlineSm),
                  const SizedBox(height: 2),
                  Text('Your body loses more water in the heat. Aim for about $_heatBonus ml extra today, around ${Fmt.litres(_goal + _heatBonus)} L in total.',
                      style: T.bodyMd.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
        const SectionHeader('Add water'),
        TileGrid(children: [for (final p in _presets) _preset(p)]),
        SoftButton('Custom amount', icon: Symbols.add_rounded, onTap: _custom),
        SectionHeader('Today', trailing: Text('${_logs.length} ${_logs.length == 1 ? 'entry' : 'entries'}', style: T.labelMd.c(AppColors.onSurfaceVariant))),
        if (_loading)
          const Loading()
        else if (_logs.isEmpty)
          Text('Nothing logged yet today.', style: T.bodyMd.c(AppColors.onSurfaceVariant))
        else
          ListGroup(children: [for (final r in _logs) _entry(r)]),
        ListGroup(
          header: 'Settings',
          footer: 'Target = body weight (kg) × 35 ml. Tap to update your weight or set a goal yourself.',
          children: [
            ListRow(
              icon: Symbols.monitor_weight_rounded,
              color: c,
              title: 'Body weight',
              value: AppState.instance.profile?.weightKg == null ? 'Add weight' : '${AppState.instance.profile!.weightKg!.round()} kg',
              onTap: _adjustGoal,
            ),
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
                },
              ),
            ),
          ],
        ),
        const PrivacyNote('A wellness tracker, not a diagnosis of any disease.'),
      ],
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
            Text('Drink more in hot weather or after sport — we add a suggestion automatically.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
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
        IconButton(tooltip: 'Remove', icon: Icon(Symbols.delete_rounded, size: 20, color: AppColors.outline), onPressed: () => _delete(r)),
      ]),
    );
  }
}
