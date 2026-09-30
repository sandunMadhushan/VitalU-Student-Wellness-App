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

/// Mifflin-St Jeor estimate × light-moderate activity (1.55).
int? suggestedCalories() {
  final p = AppState.instance.profile;
  if (p == null || p.weightKg == null || p.heightCm == null || p.age == null || p.sex == null) return null;
  final bmr = 10 * p.weightKg! + 6.25 * p.heightCm! - 5 * p.age! + (p.sex == 'male' ? 5 : -161);
  return ((bmr * 1.55) / 50).round() * 50;
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
    final s = suggestedCalories();
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Daily calorie target', style: T.headlineMd),
            const SizedBox(height: 4),
            Text(s == null ? 'Add your age, sex, height and weight in your profile for a personal suggestion.' : 'Suggested for you: about ${Fmt.thousands(s)} kcal a day, based on the Mifflin-St Jeor equation for a moderately active adult.',
                style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Center(child: MetricValue(Fmt.thousands(v), unit: 'kcal', size: 34)),
            VSlider(value: v, min: 1200, max: 3500, divisions: 46, onChanged: (x) => set(() => v = x)),
            if (s != null) Center(child: TextLinkButton('Use suggestion', onTap: () => set(() => v = s.toDouble()))),
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
