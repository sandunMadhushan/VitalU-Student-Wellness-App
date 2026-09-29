import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

String money(num v) => '${Env.currency} ${Fmt.thousands(v)}';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _week = weekStart(DateTime.now());
  late double _budget = AppState.instance.profile?.weeklyBudget ?? 5000;
  String _filter = 'All Plans';
  bool _loading = true;
  bool _saving = false;
  List<Rec> _items = [];
  Map<String, int> _plan = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _items = (await Repo.foodItems()).where((i) => i['price'] != null).toList();
      _plan = await Repo.budgetItems(_week);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  double get _planned => _items.where((i) => _plan.containsKey(i['id'])).fold(0.0, (a, i) => a + (i['price'] as num) * (_plan[i['id']] ?? 0));

  Future<void> _setBudget(double v) async {
    setState(() => _budget = v.clamp(1500, 15000));
  }

  Future<void> _persistBudget() => AppState.instance.updateProfile({'weekly_food_budget': _budget});

  Future<void> _toggle(Rec i) async {
    final id = i['id'] as String;
    final on = !_plan.containsKey(id);
    setState(() => on ? _plan[id] = 5 : _plan.remove(id));
    try {
      await Repo.setBudgetItem(_week, id, on);
    } catch (_) {
      if (mounted) toast(context, 'Could not update plan.', error: true);
    }
  }

  Future<void> _servings(Rec i, int delta) async {
    final id = i['id'] as String;
    final v = ((_plan[id] ?? 5) + delta).clamp(1, 21);
    setState(() => _plan[id] = v);
    await Repo.setBudgetItem(_week, id, true, servings: v);
  }

  Future<void> _generate() async {
    final chosen = _items.where((i) => _plan.containsKey(i['id'])).toList();
    if (chosen.isEmpty) return toast(context, 'Add a few meals to your plan first 🌿');
    setState(() => _saving = true);
    try {
      await _persistBudget();
      final lines = [
        for (final i in chosen) {'name': i['name'], 'servings': _plan[i['id']], 'price': i['price'], 'total': (i['price'] as num) * _plan[i['id']]!},
      ];
      await Repo.saveGroceryList(_week, _budget, _planned, lines);
      if (!mounted) return;
      final text = StringBuffer('VitalU weekly food plan (${money(_planned)} of ${money(_budget)})\n\n');
      for (final l in lines) {
        text.writeln('• ${l['name']} × ${l['servings']} — ${money(l['total'] as num)}');
      }
      text.writeln('\nShopping list:');
      final groups = <String>{for (final i in chosen) ...List<String>.from(i['food_groups'] ?? const [])};
      for (final g in groups) {
        text.writeln('☐ ${groupByKey(g)?.suggestion ?? g}');
      }
      await showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Your Grocery List', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Saved to your weekly plan.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Symbols.check_box_outline_blank, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${l['name']} × ${l['servings']}', style: T.bodyMd)),
                  Text(money(l['total'] as num), style: T.labelMd),
                ]),
              ),
            const Divider(),
            Text('Ingredients to pick up', style: T.labelLg),
            const SizedBox(height: 6),
            for (final g in groups) Text('• ${groupByKey(g)?.suggestion ?? g}', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            PrimaryButton('Share List', leadingIcon: Symbols.share, onTap: () => SharePlus.instance.share(ShareParams(text: text.toString(), subject: 'VitalU grocery list'))),
          ]));
    } catch (e) {
      if (mounted) toast(context, 'Could not save your plan. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perMeal = _budget / 28; // 3 meals + 1 snack a day
    final list = _items.where((i) {
      if ((i['price'] as num) > perMeal * 2.2) return false;
      return _filter == 'All Plans' || i['budget_category'] == _filter;
    }).toList();
    final planned = _planned;
    final cushion = _budget - planned;
    final under = _budget == 0 ? 0 : ((cushion / _budget) * 100).round();

    return VPage(
      header: const MainHeader('Vitalu   Diet & Nutrition'),
      nav: NavTab.diet,
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, shadow: Shadows.tiny, onTap: () => goBack(context, '/diet')),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Budget Meal Planner', style: T.headlineSm),
              Text('Mindful nourishment on a student budget', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          TagPill('Weekly Safe', icon: Symbols.savings, iconColor: AppColors.tertiary, bg: AppColors.surfaceContainerHighest),
        ]),
        VCard(
          radius: Rad.xl,
          shadow: Shadows.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Rad.lg),
              child: SizedBox(
                height: 176,
                child: Stack(fit: StackFit.expand, children: [
                  const AssetImg('piggy_bank'),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.surfaceContainerLowest.withValues(alpha: 0.8), Colors.transparent]))),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Pill(
                      color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
                      shadow: Shadows.tiny,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.tertiaryFixedDim, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('Guilt-Free Spending', style: T.labelSm),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: Sp.sm),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Weekly Food Allowance', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
                    Text(money(_budget), style: T.headlineXlMobile),
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('(~${money((_budget / 7).round())}/day)', style: T.labelMd.c(AppColors.onSurfaceVariant))),
                  ]),
                ]),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
                child: Row(children: [
                  CircleButton(Symbols.remove, size: 32, iconSize: 18, bg: AppColors.surfaceContainerLowest, fg: AppColors.onSurface, onTap: () {
                    _setBudget(_budget - 250);
                    _persistBudget();
                  }),
                  const SizedBox(width: 4),
                  CircleButton(Symbols.add, size: 32, iconSize: 18, bg: AppColors.surfaceContainerLowest, fg: AppColors.onSurface, onTap: () {
                    _setBudget(_budget + 250);
                    _persistBudget();
                  }),
                ]),
              ),
            ]),
            VSlider(value: _budget, min: 1500, max: 15000, divisions: 54, onChanged: _setBudget),
            Row(children: [
              for (final p in const [3000.0, 5000.0, 7500.0, 10000.0]) ...[
                Expanded(
                  child: Pressable(
                    onTap: () {
                      _setBudget(p);
                      _persistBudget();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _budget == p ? AppColors.primaryFixed : AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
                      child: Text(money(p), style: T.labelSm.c(_budget == p ? AppColors.onPrimaryFixed : AppColors.onSurface)),
                    ),
                  ),
                ),
                if (p != 10000) const SizedBox(width: 6),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Symbols.check_circle, size: 16, color: AppColors.tertiary),
              const SizedBox(width: 6),
              Expanded(child: Text('Based on 3 campus meals + 1 study snack per day. Adjust freely anytime.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Meals Within Budget', style: T.headlineSm)),
            Text('${list.length} Available', style: T.labelSm.c(AppColors.primary)),
          ]),
          Text('Balanced student recipes & canteen options', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: 6),
        ]),
        FullBleed(
          child: ChipRow(children: [
            for (final f in const ['All Plans', 'Dining Hall Sync', '10-Min Dorm Prep', 'Batch Cooking'])
              VChip(f == 'Dining Hall Sync' ? 'Canteen Sync' : (f == '10-Min Dorm Prep' ? '10-Min Hostel Prep' : f),
                  selected: _filter == f, selectedColor: AppColors.inverseSurface, selectedFg: AppColors.inverseOnSurface, height: 36, onTap: () => setState(() => _filter = f)),
          ]),
        ),
        if (_loading) const Loading(),
        for (final i in list) _mealCard(i),
        VCard(
          color: AppColors.surfaceContainer,
          radius: Rad.xl,
          shadow: Shadows.tiny,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconCircle(Symbols.verified, size: 32, iconSize: 18, bg: cushion >= 0 ? AppColors.tertiaryContainer : AppColors.error, fg: AppColors.onTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Plan Status', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                  Text('${money(planned)} planned of ${money(_budget)}', style: T.labelLg),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(cushion >= 0 ? '${money(cushion)} cushion' : '${money(-cushion)} over', style: T.labelSm.c(cushion >= 0 ? AppColors.tertiary : AppColors.error)),
                Text(cushion >= 0 ? 'Tea & treats' : 'Try fewer servings', style: T.bodySm.s(11).c(AppColors.onSurfaceVariant)),
              ]),
            ]),
            const SizedBox(height: Sp.sm),
            Bar(value: _budget == 0 ? 0 : planned / _budget, height: 10, color: cushion >= 0 ? AppColors.primary : AppColors.error, track: AppColors.surfaceContainerHighest),
            const SizedBox(height: Sp.sm),
            Text(
              planned == 0
                  ? 'Add meals to see how your week fits your budget.'
                  : cushion >= 0
                      ? "You're staying $under% under your weekly target. Mindful eating feels effortless when scheduled ahead."
                      : 'Your plan is above budget — swap in a batch-cooked dhal or reduce servings.',
              style: T.bodySm.c(AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: Sp.sm),
            PrimaryButton('Save & Generate Grocery List', icon: Symbols.arrow_forward, color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, height: 52, loading: _saving, onTap: _generate),
          ]),
        ),
      ],
    );
  }

  Widget _mealCard(Rec i) {
    final on = _plan.containsKey(i['id']);
    final c = (i['carbs_g'] as num).toDouble(), p = (i['protein_g'] as num).toDouble(), f = (i['fat_g'] as num).toDouble();
    final tot = (c * 4 + p * 4 + f * 9).clamp(1, 99999);
    return VCard(
      shadow: Shadows.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(iconByName(i['icon']), bg: on ? AppColors.primaryFixed : AppColors.secondaryFixed, fg: AppColors.onSecondaryFixed),
          const SizedBox(width: Sp.xs + 2),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(i['name'], style: T.headlineSm, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Pill(color: AppColors.primaryFixed, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), child: Text(money(i['price']), style: T.labelLg.c(AppColors.primary))),
              ]),
              Text('${i['source']} • ${i['description']}', style: T.bodySm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.base)),
          child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(children: [
                  Expanded(flex: (c * 4 / tot * 100).round().clamp(1, 100), child: Container(color: AppColors.secondaryContainer)),
                  Expanded(flex: (p * 4 / tot * 100).round().clamp(1, 100), child: Container(color: AppColors.primaryContainer)),
                  Expanded(flex: (f * 9 / tot * 100).round().clamp(1, 100), child: Container(color: AppColors.tertiaryFixedDim)),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text('Macros: ${c.round()}g C • ${p.round()}g P • ${f.round()}g F', style: T.labelSm.c(AppColors.onSurfaceVariant))),
              Text('${i['kcal']} kcal', style: T.labelSm.c(AppColors.tertiary)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(i['prep_note'] ?? '', style: T.labelSm.c(AppColors.onSurfaceVariant))),
          if (on) ...[
            CircleButton(Symbols.remove, size: 30, iconSize: 16, bg: AppColors.surfaceContainer, onTap: () => _servings(i, -1)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('×${_plan[i['id']]}/wk', style: T.labelMd)),
            CircleButton(Symbols.add, size: 30, iconSize: 16, bg: AppColors.surfaceContainer, onTap: () => _servings(i, 1)),
            const SizedBox(width: 8),
          ],
          Pressable(
            onTap: () => _toggle(i),
            child: Pill(
              color: on ? AppColors.tertiaryFixed : AppColors.surfaceContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(on ? Symbols.check : Symbols.add, size: 16, color: on ? AppColors.onTertiaryFixed : AppColors.onSurface),
                const SizedBox(width: 4),
                Text(on ? 'Added' : 'Add to Plan', style: T.labelMd.c(on ? AppColors.onTertiaryFixed : AppColors.onSurface)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}
