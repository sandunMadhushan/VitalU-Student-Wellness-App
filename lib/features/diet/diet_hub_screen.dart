import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

const mealTypes = <(String, String, IconData)>[
  ('breakfast', 'Breakfast', Symbols.bakery_dining_rounded),
  ('lunch', 'Lunch', Symbols.rice_bowl_rounded),
  ('dinner', 'Dinner', Symbols.skillet_rounded),
  ('snack', 'Snacks', Symbols.nutrition_rounded),
];

class DietHubScreen extends StatefulWidget {
  const DietHubScreen({super.key});
  @override
  State<DietHubScreen> createState() => _DietHubScreenState();
}

class _DietHubScreenState extends State<DietHubScreen> {
  bool _loading = true;
  List<Rec> _meals = [];

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

  Future<void> _go(String path) async {
    await context.push(path);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final logged = _meals.where((m) => m['status'] == 'logged').toList();
    final kcal = logged.fold<int>(0, (a, m) => a + (m['kcal'] as int));
    final target = AppState.instance.profile?.calorieTarget ?? 2100;
    final over = kcal > target * 1.1;

    return VPage(
      header: const MainHeader('Diet'),
      nav: NavTab.diet,
      onRefresh: _load,
      topPadding: 0,
      children: [
        VCard(
          onTap: () => _go('/diet/today'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Ring(
                value: kcal / target,
                size: 76,
                stroke: 8,
                color: AppColors.nutrition,
                child: Icon(Symbols.local_fire_department_rounded, size: 24, color: AppColors.nutrition, fill: 1),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CategoryLabel('Energy today', icon: Symbols.restaurant_rounded, color: AppColors.nutrition),
                  const SizedBox(height: 6),
                  MetricValue(Fmt.thousands(kcal), unit: 'of ${Fmt.thousands(target)} kcal', size: 26),
                  const SizedBox(height: 2),
                  Text(over ? 'Above your usual target' : '${logged.length} ${logged.length == 1 ? 'meal' : 'meals'} logged', style: T.bodySm.c(over ? AppColors.warning : AppColors.onSurfaceVariant)),
                ]),
              ),
              Icon(Symbols.chevron_right_rounded, color: AppColors.outline),
            ]),
            const SizedBox(height: Sp.md),
            PrimaryButton('Log a meal', leadingIcon: Symbols.photo_camera_rounded, onTap: () => _go('/diet/log')),
          ]),
        ),
        const SectionHeader("Today's meals"),
        if (_loading)
          const Loading()
        else
          ListGroup(children: [for (final t in mealTypes) _mealRow(t)]),
        const SectionHeader('Plan and learn'),
        ListGroup(children: [
          ListRow(icon: Symbols.nutrition_rounded, color: AppColors.nutrition, title: 'Dietary diversity', subtitle: 'Eight food groups this week', onTap: () => _go('/diet/diversity')),
          ListRow(icon: Symbols.pie_chart_rounded, color: AppColors.water, title: 'Healthy plate guide', subtitle: 'Portions without a food scale', onTap: () => _go('/diet/plate')),
          ListRow(icon: Symbols.calendar_month_rounded, color: AppColors.primary, title: 'Meal planner', subtitle: 'Plan the week around lectures', onTap: () => _go('/diet/planner')),
          ListRow(icon: Symbols.savings_rounded, color: AppColors.warning, title: 'Budget planner', subtitle: 'Groceries within your weekly budget', onTap: () => _go('/diet/budget')),
        ]),
        VCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.lightbulb_rounded, size: 22, color: AppColors.warning, fill: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Canteen tip', style: T.headlineSm),
                const SizedBox(height: 4),
                Text('Add a leafy mallum (gotukola or mukunuwenna) and a spoon of dhal to your rice for more fibre, iron and steadier afternoon focus.',
                    style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        const PrivacyNote('Meal logs are private to your account.'),
      ],
    );
  }

  Widget _mealRow((String, String, IconData) t) {
    final list = _meals.where((m) => m['meal_type'] == t.$1).toList();
    final m = list.isEmpty ? null : (list.lastWhere((x) => x['status'] == 'logged', orElse: () => list.last));
    final logged = m?['status'] == 'logged';
    return ListRow(
      icon: t.$3,
      color: AppColors.nutrition,
      title: t.$2,
      subtitle: m == null ? 'Not logged' : '${m['name']}${list.length > 1 ? ' +${list.length - 1}' : ''}',
      trailing: m == null
          ? Icon(Symbols.add_circle_rounded, color: AppColors.primary, size: 24)
          : TagPill(logged ? 'Logged' : 'Planned', bg: logged ? AppColors.tertiaryContainer : AppColors.surfaceContainer, fg: logged ? AppColors.onTertiaryContainer : AppColors.onSurfaceVariant),
      onTap: () => _go(m == null ? '/diet/log?type=${t.$1}' : '/diet/today'),
    );
  }
}
