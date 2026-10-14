import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'diet_science.dart';

/// Calorie counter: today's target, what has been eaten and what is left,
/// energy in against estimated energy out, a flexible meal split and a plain
/// explanation of how the target was set.
class NutritionTodayScreen extends StatefulWidget {
  const NutritionTodayScreen({super.key});
  @override
  State<NutritionTodayScreen> createState() => _NutritionTodayScreenState();
}

class _NutritionTodayScreenState extends State<NutritionTodayScreen> {
  bool _loading = true;
  List<Rec> _meals = [];
  int _target = 2100;
  (int, int)? _out;
  bool _showMaths = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait<Object?>([Repo.mealsOn(DateTime.now()), effectiveCalorieTarget(), energyOutToday()]);
      _meals = r[0] as List<Rec>;
      _target = r[1] as int;
      _out = r[2] as (int, int)?;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _adjustTarget() async {
    double v = _target.toDouble();
    final plan = energyPlan();
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Daily calorie target', style: T.headlineMd),
            const SizedBox(height: 4),
            Text(plan == null ? 'Add your age, sex, height, weight and activity level in your profile for a personal estimate.' : 'Your personal estimate is about ${Fmt.thousands(plan.target)} kcal a day.',
                style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Center(child: MetricValue(Fmt.thousands(v), unit: 'kcal', size: 34)),
            VSlider(value: v, min: 1200, max: 3500, divisions: 46, color: AppColors.nutrition, onChanged: (x) => set(() => v = x)),
            const SizedBox(height: Sp.sm),
            PrimaryButton('Use this target', color: AppColors.nutrition, onTap: () async {
              await setCustomCalorieTarget(v.round());
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
            if (plan != null)
              Center(
                child: TextLinkButton('Go back to my personal estimate', onTap: () async {
                  await setCustomCalorieTarget(null);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                }),
              ),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final logged = _meals.where((m) => m['status'] == 'logged').toList();
    final kcal = logged.fold<int>(0, (a, m) => a + (m['kcal'] as num).toInt());
    return VPage(
      header: TitleHeader('Calorie counter', onLeading: () => goBack(context, '/diet')),
      onRefresh: _load,
      bottom: PrimaryButton('Log a meal', leadingIcon: Symbols.add_rounded, color: AppColors.nutrition, onTap: () async {
        await context.push('/diet/log');
        _load();
      }),
      children: _loading
          ? [const Loading()]
          : [
              _hero(kcal),
              if (_out != null) _balance(kcal, _out!),
              _split(logged),
              _howCalculated(),
              SectionHeader("Today's meals", trailing: TextLinkButton('Meal diary', onTap: () => context.push('/diet/diary'))),
              if (logged.isEmpty)
                const EmptyState(icon: Symbols.restaurant_rounded, title: 'Nothing logged yet today', text: 'Log breakfast, lunch, dinner or a snack to see your day fill up.')
              else
                ListGroup(children: [for (final m in logged) _mealRow(m)]),
              const PrivacyNote('Calorie values are estimates. They are a guide for awareness, not a rule.'),
            ],
    );
  }

  // The big ring: target, eaten and left, or how far past the estimate.
  Widget _hero(int kcal) {
    final c = AppColors.nutrition;
    final over = kcal > _target;
    final left = (_target - kcal).abs();
    final dark = AppColors.isDark;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.xl),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          Color.alphaBlend(c.withValues(alpha: dark ? 0.26 : 0.14), AppColors.surfaceContainerLowest),
          Color.alphaBlend(AppColors.warning.withValues(alpha: dark ? 0.08 : 0.04), AppColors.surfaceContainerLowest),
        ]),
      ),
      child: Column(children: [
        Row(children: [
          Icon(Symbols.flag_rounded, size: 18, color: c, fill: 1),
          const SizedBox(width: 6),
          Text('Daily target', style: T.labelLg.c(c)),
          const Spacer(),
          TextLinkButton('Adjust', leading: Symbols.tune_rounded, onTap: _adjustTarget),
        ]),
        Text('${Fmt.thousands(_target)} kcal', style: T.metric(30)),
        const SizedBox(height: Sp.md),
        SizedBox(
          width: 190,
          height: 190,
          child: Stack(alignment: Alignment.center, children: [
            Ring(value: math.min(kcal / _target, 1), size: 190, stroke: 16, color: c),
            if (over) Ring(value: math.min((kcal - _target) / _target, 1), size: 160, stroke: 8, color: AppColors.warning, track: Colors.transparent),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(Fmt.thousands(left), style: T.metric(36)),
              Text(over ? 'kcal over' : 'kcal left', style: T.bodyMd.c(over ? AppColors.warning : AppColors.onSurfaceVariant)),
            ]),
          ]),
        ),
        const SizedBox(height: Sp.md),
        Row(children: [
          _stat('Eaten', Fmt.thousands(kcal), c),
          _stat('Target', Fmt.thousands(_target), AppColors.onSurface),
          _stat('Progress', '${(kcal / _target * 100).round()}%', c),
        ]),
        if (over) ...[
          const SizedBox(height: Sp.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.tint(AppColors.warning), borderRadius: BorderRadius.circular(Rad.base)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Symbols.info_rounded, size: 18, color: AppColors.warning, fill: 1),
              const SizedBox(width: 8),
              Expanded(
                child: Text('You have gone past your estimated daily needs. That is okay: one day does not define your habits. A balanced plate tomorrow is all it takes.',
                    style: T.bodySm.c(AppColors.onSurface)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _stat(String label, String value, Color c) => Expanded(
        child: Column(children: [
          Text(value, style: T.metric(20).c(c)),
          Text(label, style: T.bodySm.c(AppColors.onSurfaceVariant)),
        ]),
      );

  // Energy in (food) against estimated energy out (body at rest and daily
  // living, plus logged activity), as two simple bars.
  Widget _balance(int kcalIn, (int, int) out) {
    final (rest, active) = out;
    final totalOut = rest + active;
    final maxV = math.max(math.max(kcalIn, totalOut), 1).toDouble();
    final diff = kcalIn - totalOut;
    final (msg, col) = diff.abs() <= 250
        ? ('Roughly in balance today.', AppColors.tertiary)
        : diff < 0
            ? ('You have eaten less than your body is estimated to use so far. Regular meals keep your energy and focus up.', AppColors.water)
            : ('You have eaten more than your estimated use today. Moving a little more and balanced meals help over the week.', AppColors.warning);
    Widget bar(String label, IconData icon, Color c, List<(int, Color)> parts, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: c, fill: 1),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: T.labelLg)),
              Text(value, style: T.labelLg.tnum.w(FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(children: [
                  for (final (v, pc) in parts) if (v > 0) Expanded(flex: (v / maxV * 1000).round(), child: Container(color: pc)),
                  Expanded(flex: math.max(1, ((maxV - parts.fold(0, (a, p) => a + p.$1)) / maxV * 1000).round()), child: Container(color: AppColors.surfaceContainerHigh)),
                ]),
              ),
            ),
          ]),
        );
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Energy balance', style: T.headlineSm),
        const SizedBox(height: 2),
        Text('Food in, compared with the energy your body is estimated to use today', style: T.bodySm.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: Sp.md),
        bar('Energy in (food)', Symbols.restaurant_rounded, AppColors.nutrition, [(kcalIn, AppColors.nutrition)], '${Fmt.thousands(kcalIn)} kcal'),
        bar('Energy out (estimated)', Symbols.local_fire_department_rounded, AppColors.activity, [(rest, AppColors.activity.withValues(alpha: 0.55)), (active, AppColors.activity)],
            '${Fmt.thousands(totalOut)} kcal'),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _legend(AppColors.activity.withValues(alpha: 0.55), 'Body at rest and daily living ${Fmt.thousands(rest)}'),
          _legend(AppColors.activity, active > 0 ? 'Activity logged ${Fmt.thousands(active)}' : 'No activity logged yet'),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 4, height: 34, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: T.bodyMd)),
        ]),
      ]),
    );
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(t, style: T.labelSm.c(AppColors.onSurfaceVariant)),
      ]);

  // A flexible guide to spreading energy over the day.
  Widget _split(List<Rec> logged) {
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Spreading your energy', style: T.headlineSm),
        const SizedBox(height: 2),
        Text('A flexible guide, not a rule. Eat when you are hungry and fit meals around lectures.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: Sp.md),
        for (final (type, label, share) in mealSplit) ...[
          () {
            final guide = (_target * share / 10).round() * 10;
            final eaten = logged.where((m) => m['meal_type'] == type).fold<int>(0, (a, m) => a + (m['kcal'] as num).toInt());
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('$label · about ${Fmt.thousands(guide)} kcal', style: T.labelMd)),
                  Text(eaten == 0 ? 'Not logged' : '${Fmt.thousands(eaten)} kcal', style: T.labelMd.tnum.c(eaten == 0 ? AppColors.onSurfaceVariant : AppColors.onSurface)),
                ]),
                const SizedBox(height: 5),
                Bar(value: guide == 0 ? 0 : eaten / guide, height: 7, color: eaten > guide * 1.25 ? AppColors.warning : AppColors.nutrition),
              ]),
            );
          }(),
        ],
      ]),
    );
  }

  // Plain-language explanation of the target, with the numbers on request.
  Widget _howCalculated() {
    final p = AppState.instance.profile;
    final plan = energyPlan();
    if (plan == null || p == null) {
      return VCard(
        color: AppColors.surfaceContainerLow,
        flat: true,
        child: Text('Add your date of birth, sex, height, weight and activity level in your profile and VitalU will work out a personal calorie target for you.',
            style: T.bodyMd.c(AppColors.onSurfaceVariant)),
      );
    }
    final custom = plan.target != _target;
    final goalText = switch (plan.category) {
      'Underweight' => 'Because your BMI is in the underweight range, about ${plan.adjustment} kcal is added to help you gain weight gradually with nourishing foods.',
      'Overweight' =>
        'Because your BMI is in the overweight range, your target is about ${-plan.adjustment} kcal below your daily needs. This small gap supports slow, steady weight loss without feeling deprived.',
      'Obesity' =>
        'Because your BMI is in the obesity range, your target is about ${-plan.adjustment} kcal below your daily needs, a safe pace for steady weight loss. A campus doctor can help you plan.',
      _ => 'Your BMI is in the healthy range, so your target matches your daily needs to keep your weight steady.',
    };
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Symbols.calculate_rounded, size: 20, color: AppColors.nutrition, fill: 1),
          const SizedBox(width: 8),
          Expanded(child: Text('How your target was worked out', style: T.headlineSm)),
        ]),
        const SizedBox(height: 8),
        Text(
            'Your daily calorie recommendation is based on your age (${p.age}), sex, height (${p.heightCm!.round()} cm), weight (${p.weightKg!.toStringAsFixed(0)} kg) and activity level (${plan.palLabel}). Together these estimate that your body uses about ${Fmt.thousands(plan.tdee)} kcal a day.',
            style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: 6),
        Text(goalText, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        if (custom) ...[
          const SizedBox(height: 6),
          Text('You have set your own target of ${Fmt.thousands(_target)} kcal, which the counter uses.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ],
        const SizedBox(height: 4),
        TextLinkButton(_showMaths ? 'Hide the numbers' : 'Show the numbers', icon: _showMaths ? Symbols.expand_less_rounded : Symbols.expand_more_rounded, onTap: () => setState(() => _showMaths = !_showMaths)),
        if (_showMaths)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.base)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _maths('Resting energy (BMR)', '${Fmt.thousands(plan.bmr)} kcal'),
              _maths('× activity (${plan.palLabel})', '× ${plan.pal}'),
              _maths('= Daily needs (TDEE)', '${Fmt.thousands(plan.tdee)} kcal'),
              _maths('Goal: ${plan.goal}', '${plan.adjustment >= 0 ? '+' : ''}${plan.adjustment} kcal'),
              const Divider(height: 16),
              _maths('Suggested target', '${Fmt.thousands(plan.target)} kcal', bold: true),
              const SizedBox(height: 6),
              Text('BMR uses the Mifflin-St Jeor equation. Targets never go below ${Fmt.thousands(plan.floor)} kcal.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
      ]),
    );
  }

  Widget _maths(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: T.bodyMd.w(bold ? FontWeight.w700 : FontWeight.w500))),
          Text(v, style: T.bodyMd.tnum.w(bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );

  IconData _icon(String type) => switch (type) {
        'breakfast' => Symbols.bakery_dining_rounded,
        'lunch' => Symbols.rice_bowl_rounded,
        'dinner' => Symbols.skillet_rounded,
        _ => Symbols.nutrition_rounded,
      };

  Widget _mealRow(Rec m) => Dismissible(
        key: ValueKey(m['id']),
        direction: DismissDirection.endToStart,
        background: Container(color: AppColors.errorContainer, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), child: Icon(Symbols.delete_rounded, color: AppColors.onErrorContainer)),
        confirmDismiss: (_) async => await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(title: const Text('Remove this meal?'), actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
          ]),
        ),
        onDismissed: (_) async {
          await Repo.deleteMeal(m['id']);
          _load();
        },
        child: ListRow(
          icon: _icon(m['meal_type']),
          color: AppColors.nutrition,
          title: (m['meal_type'] as String)[0].toUpperCase() + (m['meal_type'] as String).substring(1),
          subtitle: '${m['name']}\n${DateFormat('h:mm a').format(DateTime.parse(m['logged_at']).toLocal())}',
          value: '${m['kcal']} kcal',
          chevron: false,
        ),
      );
}
