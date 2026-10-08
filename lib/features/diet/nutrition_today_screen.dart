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

/// Activity multiplier (PAL) for each of the registration activity-level
/// options, applied to the Mifflin-St Jeor resting estimate.
double _activityMultiplier(String level) => switch (level) {
      'Mostly sitting' => 1.2,
      'Light Walking (Campus)' => 1.375,
      'Active / Sports' => 1.725,
      _ => 1.55, // Moderate Walking (Campus)
    };

/// Mifflin-St Jeor resting estimate × the student's own activity level —
/// the maintenance calories needed to hold their current weight.
int? maintenanceCalories() {
  final p = AppState.instance.profile;
  if (p == null || p.weightKg == null || p.heightCm == null || p.age == null || p.sex == null) return null;
  final bmr = 10 * p.weightKg! + 6.25 * p.heightCm! - 5 * p.age! + (p.sex == 'male' ? 5 : -161);
  return ((bmr * _activityMultiplier(p.activityLevel)) / 50).round() * 50;
}

int? suggestedCalories() => maintenanceCalories();

/// A personalised calorie target and plain-language guidance, adjusted from
/// maintenance calories by BMI category (a moderate gap for weight gain or
/// loss, never a crash number), plus a general, non-compensatory note about
/// staying active day to day.
class CalorieGuidance {
  const CalorieGuidance(this.category, this.target, this.message, this.activityNote);
  final String category;
  final int target;
  final String message;
  final String activityNote;
}

const _activityNote = 'Staying active day to day — walking to lectures, taking the stairs, a short stretch between study sessions — supports your overall health alongside balanced eating. It is a general habit, not something to "earn" or offset against a particular meal.';

CalorieGuidance? calorieGuidance() {
  final p = AppState.instance.profile;
  final maintenance = maintenanceCalories();
  final bmi = p?.bmi;
  if (maintenance == null || bmi == null) return null;
  final category = Calc.bmiCategory(bmi);
  final floor = p!.sex == 'male' ? 1500 : 1300;
  return switch (category) {
    'Underweight' => CalorieGuidance(category, maintenance + 350, 'Your BMI is in the underweight range. A modest surplus of about 350 kcal a day, from nutrient-dense foods, can support healthy weight gain.', _activityNote),
    'Overweight' => CalorieGuidance(category, (maintenance - 400).clamp(floor, 99999), 'Your BMI is in the overweight range. A gentle deficit of about 400 kcal a day supports gradual, sustainable weight loss.', _activityNote),
    'Obesity' => CalorieGuidance(category, (maintenance - 500).clamp(floor, 99999), 'Your BMI is in the obesity range. A deficit of about 500 kcal a day is a safe pace for steady weight loss — consider talking to a campus doctor for extra support.', _activityNote),
    _ => CalorieGuidance(category, maintenance, 'Your BMI is in the healthy range. Eating around your maintenance calories keeps you there.', _activityNote),
  };
}

class NutritionTodayScreen extends StatefulWidget {
  const NutritionTodayScreen({super.key});
  @override
  State<NutritionTodayScreen> createState() => _NutritionTodayScreenState();
}

class _NutritionTodayScreenState extends State<NutritionTodayScreen> {
  bool _loading = true;
  List<Rec> _meals = [];
  bool _details = false;

  int get _target => AppState.instance.profile?.calorieTarget ?? 2100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _meals = await Repo.mealsOn(DateTime.now());
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _adjustTarget() async {
    double v = _target.toDouble();
    final g = calorieGuidance();
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Daily calorie target', style: T.headlineMd),
            const SizedBox(height: 4),
            Text(g == null ? 'Add your age, sex, height, weight and activity level in your profile for a personal suggestion.' : 'Suggested for you: about ${Fmt.thousands(g.target)} kcal a day. ${g.message}',
                style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Center(child: MetricValue(Fmt.thousands(v), unit: 'kcal', size: 34)),
            VSlider(value: v, min: 1200, max: 3500, divisions: 46, onChanged: (x) => set(() => v = x)),
            if (g != null) Center(child: TextLinkButton('Use suggestion', onTap: () => set(() => v = g.target.toDouble()))),
            const SizedBox(height: Sp.sm),
            PrimaryButton('Save target', onTap: () async {
              await AppState.instance.updateProfile({'calorie_target': v.round()});
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            }),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final logged = _meals.where((m) => m['status'] == 'logged').toList();
    final planned = _meals.where((m) => m['status'] == 'planned').toList();
    int sum(String k) => logged.fold<int>(0, (a, m) => a + (m[k] as num).toInt());
    final kcal = sum('kcal');
    final remaining = (_target - kcal).clamp(0, 99999);
    final pct = kcal / _target;
    final carbT = (_target * 0.5 / 4).round(), protT = (_target * 0.18 / 4).round(), fatT = (_target * 0.3 / 9).round();
    final guidance = calorieGuidance();

    return VPage(
      header: TitleHeader("Today's nutrition", onLeading: () => goBack(context, '/diet')),
      onRefresh: _load,
      children: [
        VCard(
          child: Column(children: [
            Ring(
              value: pct,
              size: 168,
              stroke: 14,
              color: AppColors.nutrition,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(Fmt.thousands(remaining), style: T.metric(34)),
                Text('kcal left', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(height: Sp.md),
            Row(children: [
              _stat('Eaten', Fmt.thousands(kcal)),
              Container(width: 1, height: 36, color: AppColors.outlineVariant),
              _stat('Target', Fmt.thousands(_target)),
            ]),
          ]),
        ),
        VCard(
          child: Column(children: [
            _macro('Carbohydrates', AppColors.warning, sum('carbs_g'), carbT),
            const Divider(height: 28),
            _macro('Protein', AppColors.heart, sum('protein_g'), protT),
            const Divider(height: 28),
            _macro('Fat', AppColors.water, sum('fat_g'), fatT),
          ]),
        ),
        if (guidance != null)
          VCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Symbols.insights_rounded, size: 22, color: AppColors.nutrition, fill: 1),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${guidance.category} · personalised guidance', style: T.headlineSm),
                  const SizedBox(height: 4),
                  Text(guidance.message, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(guidance.activityNote, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
        SectionHeader('Meals', trailing: logged.isEmpty ? null : TextLinkButton(_details ? 'Hide food groups' : 'Show food groups', onTap: () => setState(() => _details = !_details))),
        if (_loading)
          const Loading()
        else if (_meals.isEmpty)
          const EmptyState(icon: Symbols.restaurant_rounded, title: 'No meals yet today', text: 'Log breakfast, lunch or a snack to see your balance.')
        else
          ListGroup(children: [
            for (final m in logged) _mealRow(m),
            for (final m in planned) _plannedRow(m),
          ]),
        PrimaryButton('Log a snack or drink', leadingIcon: Symbols.add_rounded, onTap: () async {
          await context.push('/diet/log?type=snack');
          _load();
        }),
        Center(child: TextLinkButton('Change calorie target', onTap: _adjustTarget)),
        const PrivacyNote('Nutrition values are estimates. Swipe a meal left to remove it.'),
      ],
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(children: [
          MetricValue(value, unit: 'kcal', size: 20),
          const SizedBox(height: 2),
          Text(label, style: T.bodySm.c(AppColors.onSurfaceVariant)),
        ]),
      );

  Widget _macro(String name, Color c, int value, int target) {
    final p = target == 0 ? 0.0 : value / target;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: T.bodyLg)),
        Text.rich(TextSpan(text: '$value', children: [TextSpan(text: ' / $target g', style: T.bodyMd.c(AppColors.onSurfaceVariant))]), style: T.labelLg.semi.tnum),
      ]),
      const SizedBox(height: 8),
      Bar(value: p, color: c),
    ]);
  }

  IconData _icon(String type) => switch (type) {
        'breakfast' => Symbols.bakery_dining_rounded,
        'lunch' => Symbols.rice_bowl_rounded,
        'dinner' => Symbols.skillet_rounded,
        _ => Symbols.nutrition_rounded,
      };

  String _label(String t) => t[0].toUpperCase() + t.substring(1);

  Widget _mealRow(Rec m) {
    final groups = (m['food_groups'] as List?) ?? const [];
    return Dismissible(
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
        title: m['name'],
        subtitle: [
          '${_label(m['meal_type'])} · ${DateFormat('h:mm a').format(DateTime.parse(m['logged_at']).toLocal())}',
          'C ${m['carbs_g']} g · P ${m['protein_g']} g · F ${m['fat_g']} g',
          if (_details && groups.isNotEmpty) groups.join(', ').replaceAll('_', ' '),
        ].join('\n'),
        value: '${m['kcal']} kcal',
      ),
    );
  }

  Widget _plannedRow(Rec m) => ListRow(
        icon: _icon(m['meal_type']),
        color: AppColors.outline,
        title: m['name'],
        subtitle: 'Planned ${_label(m['meal_type']).toLowerCase()} · about ${m['kcal']} kcal',
        trailing: TextLinkButton('Confirm', onTap: () async {
          await Repo.confirmMeal(m);
          _load();
        }),
      );
}
