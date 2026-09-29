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

class _Preset {
  const _Preset(this.ml, this.title, this.sub, this.icon);
  final int ml;
  final String title;
  final String sub;
  final IconData icon;
}

const _presets = [
  _Preset(150, 'Small Cup', 'Plain tea / Small glass', Symbols.coffee),
  _Preset(250, 'Standard Glass', 'Library Desk Mug', Symbols.local_drink),
  _Preset(500, 'Campus Flask', 'Backpack Water Bottle', Symbols.sports_bar),
  _Preset(750, 'Sports Tumbler', 'Gym & Hydro Jug', Symbols.fitness_center),
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
  int _selected = 250;
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
    setState(() => _selected = ml);
    final now = DateTime.now();
    try {
      await Repo.addWater(ml, label: label ?? sipLabel(now), location: location);
      await _load();
      if (_nudge && _total < _goal) {
        await Repo.schedule(
          title: 'Gentle hydration nudge',
          body: 'A glass of water before your next class keeps focus steady. You are at ${Fmt.litres(_total)}L of ${Fmt.litres(_goal)}L.',
          category: 'reminder',
          label: 'Reminder',
          icon: 'water_drop',
          route: '/tools/water',
          at: now.add(const Duration(hours: 2)),
        );
      }
      if (mounted) toast(context, '+$ml ml logged 💧');
    } catch (_) {
      if (mounted) toast(context, 'Could not log water. Check your connection.', error: true);
    }
  }

  Future<void> _custom() async {
    final amount = TextEditingController();
    final place = TextEditingController();
    await showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Custom Amount', style: T.headlineMd),
          const SizedBox(height: Sp.md),
          VTextField(controller: amount, hint: 'Amount in ml (e.g. 330)', icon: Symbols.water_drop, keyboard: TextInputType.number),
          const SizedBox(height: Sp.sm),
          VTextField(controller: place, hint: 'Where? (optional) e.g. Library', icon: Symbols.location_on),
          const SizedBox(height: Sp.md),
          PrimaryButton('Log Sip', onTap: () {
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
        title: const Text('Remove this sip?'),
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
    if (_total >= _goal) return ('Daily goal reached — lovely pacing today!', Symbols.celebration);
    if (_total >= expected * 0.85) return ("You're right on pace for afternoon lectures.", Symbols.schedule);
    return ('A few more sips will get you back on pace.', Symbols.water_drop);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_total / _goal).clamp(0.0, 9.99);
    final pace = _pace;
    final remaining = (_goal - _total).clamp(0, _goal);
    final nextAt = DateTime.now().add(const Duration(hours: 2));

    return VPage(
      header: const MainHeader('VitalU Health Tools'),
      nav: NavTab.tools,
      onRefresh: _load,
      children: [
        Row(children: [
          Flexible(child: TagPill('Campus Hydration • Gentle Pacing', icon: Symbols.water_drop, fill: 1, bg: AppColors.surfaceContainerLow, fg: AppColors.primary)),
          const Spacer(),
          const TagPill('Private', icon: Symbols.lock),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, onTap: () => goBack(context, '/tools')),
            const SizedBox(width: 10),
            Text('Water Intake', style: T.headlineLg),
          ]),
          const SizedBox(height: 4),
          Text('Nourish your mind between lectures and study sessions. No streaks, just mindful sips.', style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.6)),
        ]),
        VCard(
          clip: true,
          shadow: Shadows.card,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(top: -48, right: -48, child: Glow(color: AppColors.primaryFixed.withValues(alpha: 0.4), size: 176)),
            Positioned(bottom: -40, left: -40, child: Glow(color: AppColors.secondaryFixed.withValues(alpha: 0.3), size: 160)),
            Column(children: [
              TagPill('${(pct * 100).round()}% Hydrated', icon: Symbols.check_circle, fill: 1, bg: AppColors.primaryFixed, fg: AppColors.onPrimaryFixed),
              const SizedBox(height: Sp.sm),
              SizedBox(
                width: 224,
                height: 232,
                child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                  Positioned(top: 0, child: Ring(value: pct, size: 224, stroke: 12, color: AppColors.primary)),
                  Positioned(
                    top: 32,
                    child: Container(
                      width: 160,
                      height: 160,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceContainerLow, AppColors.primaryFixed.withValues(alpha: 0.2)]),
                      ),
                      child: ClipOval(child: const AssetImg('water_bottle')),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Pill(
                      color: AppColors.surfaceContainerLowest,
                      shadow: Shadows.soft,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Symbols.eco, size: 15, color: AppColors.tertiary, fill: 1),
                        const SizedBox(width: 4),
                        Text(pct >= 1 ? 'Goal Reached' : 'Optimal Pace', style: T.labelSm.c(AppColors.tertiary)),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Text.rich(TextSpan(text: Fmt.litres(_total), children: [TextSpan(text: 'L', style: T.headlineMd.w(FontWeight.w400).c(AppColors.onSurfaceVariant))]), style: T.headlineXlMobile),
              Text('of ${Fmt.litres(_goal)}L Daily Gentle Goal', style: T.labelMd.c(AppColors.onSurfaceVariant)),
              const SizedBox(height: Sp.sm),
              Pill(
                color: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(pace.$2, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(child: Text(pace.$1, style: T.bodySm.c(AppColors.onSurfaceVariant))),
                ]),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Symbols.local_drink, size: 20, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text('Quick Log Sips', style: T.headlineSm)),
            Text('Tap to add', style: T.labelSm.c(AppColors.onSurfaceVariant)),
          ]),
          const SizedBox(height: Sp.sm),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - Sp.sm) / 2;
            return Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [for (final p in _presets) SizedBox(width: w, child: _preset(p))]);
          }),
          const SizedBox(height: Sp.sm),
          Center(
            child: Pressable(
              onTap: _custom,
              child: Pill(
                color: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shadow: Shadows.tiny,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.add_circle, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Custom Amount', style: T.labelMd),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Symbols.history, size: 20, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text("Today's Intake Timeline", style: T.headlineSm)),
            TagPill('${_logs.length} sip${_logs.length == 1 ? '' : 's'} recorded'),
          ]),
          const SizedBox(height: Sp.sm),
          VCard(
            shadow: Shadows.soft,
            child: _loading
                ? const Loading()
                : Column(children: [
                    if (_logs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No sips yet today — start with a glass of water 💧', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                      ),
                    for (final r in _logs) ...[
                      _entry(r),
                      Padding(padding: const EdgeInsets.only(left: 48, top: 12, bottom: 12), child: Container(height: 1, color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6))),
                    ],
                    if (remaining > 0)
                      Opacity(
                        opacity: 0.6,
                        child: Row(children: [
                          IconCircle(Symbols.alarm, size: 36, iconSize: 18, bg: AppColors.surfaceContainerHigh, fg: AppColors.outline),
                          const SizedBox(width: Sp.sm),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(sipLabel(nextAt), style: T.labelMd)),
                                Text('~${remaining > 350 ? 350 : remaining} ml', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                              ]),
                              Row(children: [
                                Expanded(child: Text('Upcoming • ${DateFormat('h:mm a').format(nextAt)}', style: T.bodySm.c(AppColors.onSurfaceVariant))),
                                Text('Suggested', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                  ]),
          ),
        ]),
        VCard(
          color: _heatBonus > 0 ? AppColors.errorContainer.withValues(alpha: 0.4) : AppColors.surfaceContainerLow,
          shadow: Shadows.tiny,
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconCircle(_heatBonus > 0 ? Symbols.sunny : Symbols.lightbulb,
                  size: 40, iconSize: 20, bg: _heatBonus > 0 ? AppColors.butterWash : AppColors.secondaryFixed, fg: _heatBonus > 0 ? AppColors.butterAccent : AppColors.onSecondaryFixed, fill: 1),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_heatBonus > 0 ? "It's a hot day — drink more" : 'Exam Season Hydration Tip', style: T.labelLg),
                  const SizedBox(height: 4),
                  Text(
                    _heatBonus > 0
                        ? "It's about ${_tempC!.round()}°C right now, so your body loses more water than usual. Try for an extra ${_heatBonus}ml today (around ${Fmt.litres(_goal + _heatBonus)}L total)."
                        : 'Drinking a glass of water before afternoon lectures refreshes focus and keeps headaches at bay far better than another sugary drink.',
                    style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.md),
            Container(
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(Rad.full)),
              child: Row(children: [
                Icon(Symbols.notifications_active, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Gentle nudge before classes', style: T.labelSm.medium)),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _nudge,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) async {
                      setState(() => _nudge = v);
                      await AppState.instance.updateProfile({'water_nudge_enabled': v});
                    },
                  ),
                ),
              ]),
            ),
          ]),
        ),
        Center(child: TextLinkButton('Adjust daily goal (${Fmt.litres(_goal)}L)', leading: Symbols.tune, color: AppColors.primary, onTap: _adjustGoal)),
      ],
    );
  }

  Future<void> _adjustGoal() async {
    double v = _goal.toDouble();
    final suggested = Calc.waterTargetFor(AppState.instance.profile?.weightKg);
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Daily hydration goal', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Suggested for you: ${Fmt.litres(suggested)}L (about 35 ml per kg). Drink more in hot weather or after sport.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Center(child: Text('${Fmt.litres(v)} L', style: T.headlineXlMobile)),
            VSlider(value: v, min: 1500, max: 4000, divisions: 25, onChanged: (x) => set(() => v = x)),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save Goal', onTap: () async {
              await AppState.instance.updateProfile({'water_goal_ml': v.round()});
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            }),
          ]);
        }));
  }

  Widget _preset(_Preset p) {
    final on = _selected == p.ml;
    return Pressable(
      onTap: () => _log(p.ml, label: sipLabel(DateTime.now())),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(Sp.sm),
        decoration: BoxDecoration(
          color: on ? AppColors.primaryFixed : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(Rad.lg),
          boxShadow: on ? Shadows.tinted(AppColors.primary, opacity: 0.2, blur: 24, y: 8) : Shadows.soft,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(p.icon, size: 40, iconSize: 20, bg: on ? AppColors.surfaceContainerLowest : AppColors.surfaceContainerLow, fill: on ? 1 : 0, shadow: on ? Shadows.tiny : null),
            const Spacer(),
            Pill(
              color: on ? AppColors.surfaceContainerLowest : AppColors.surfaceContainer,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text('+${p.ml} ml', style: T.labelSm.c(on ? AppColors.primary : AppColors.onSurfaceVariant).w(on ? FontWeight.w700 : FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(p.title, style: T.labelLg.c(on ? AppColors.onPrimaryFixed : AppColors.onSurface), overflow: TextOverflow.ellipsis),
          Text(p.sub, style: T.bodySm.c(on ? AppColors.onPrimaryFixedVariant : AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _entry(Rec r) {
    final t = DateTime.parse(r['logged_at']).toLocal();
    return GestureDetector(
      onLongPress: () => _delete(r),
      child: Row(children: [
        IconCircle(Symbols.water_drop, size: 36, iconSize: 18, bg: AppColors.primaryFixed, fill: 1, shadow: Shadows.tiny),
        const SizedBox(width: Sp.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r['label'] ?? sipLabel(t), style: T.labelMd, overflow: TextOverflow.ellipsis)),
              Text('${r['amount_ml']} ml', style: T.labelSm.c(AppColors.primary).bold),
            ]),
            Row(children: [
              Expanded(child: Text('${DateFormat('h:mm a').format(t)}${r['location'] != null ? ' • ${r['location']}' : ''}', style: T.bodySm.c(AppColors.onSurfaceVariant))),
              Text('Logged', style: T.labelSm.c(AppColors.tertiary)),
            ]),
          ]),
        ),
        const SizedBox(width: 4),
        GestureDetector(onTap: () => _delete(r), child: Icon(Symbols.more_vert, size: 18, color: AppColors.outline)),
      ]),
    );
  }
}
