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
    if (chosen.isEmpty) return toast(context, 'Add a few meals to your plan first.');
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
        text.writeln('- ${groupByKey(g)?.suggestion ?? g}');
      }
      await showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Grocery list', style: T.headlineMd),
            const SizedBox(height: 4),
            Text("Saved to this week's plan.", style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            ListGroup(dividerIndent: 16, children: [
              for (final l in lines) ListRow(title: '${l['name']}', subtitle: '${l['servings']} servings', value: money(l['total'] as num), chevron: false),
            ]),
            const SizedBox(height: Sp.md),
            Text('Ingredients to pick up', style: T.headlineSm),
            const SizedBox(height: 6),
            for (final g in groups) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• ${groupByKey(g)?.suggestion ?? g}', style: T.bodyMd.c(AppColors.onSurfaceVariant))),
            const SizedBox(height: Sp.md),
            PrimaryButton('Share list', leadingIcon: Symbols.share_rounded, onTap: () => SharePlus.instance.share(ShareParams(text: text.toString(), subject: 'VitalU grocery list'))),
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
    final over = cushion < 0;

    return VPage(
      header: TitleHeader('Budget planner', onLeading: () => goBack(context, '/diet')),
      bottom: PrimaryButton('Save and make grocery list', loading: _saving, onTap: _generate),
      children: [
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CategoryLabel('Weekly food budget', icon: Symbols.savings_rounded, color: AppColors.warning),
            const SizedBox(height: 8),
            MetricValue(money(_budget), unit: 'about ${money((_budget / 7).round())} a day', size: 30),
            const SizedBox(height: Sp.sm),
            VSlider(value: _budget, min: 1500, max: 15000, divisions: 54, color: AppColors.warning, onChanged: _setBudget),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in const [3000.0, 5000.0, 7500.0, 10000.0])
                VChip(money(p), selected: _budget == p, selectedColor: AppColors.warning, onTap: () {
                  _setBudget(p);
                  _persistBudget();
                }),
            ]),
            const SizedBox(height: Sp.sm),
            Text('Based on three meals and a snack a day.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('This week', style: T.headlineSm)),
              Text(over ? '${money(-cushion)} over' : '${money(cushion)} left', style: T.labelLg.semi.c(over ? AppColors.error : AppColors.tertiary)),
            ]),
            const SizedBox(height: 4),
            Text('${money(planned)} planned of ${money(_budget)}', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.sm),
            Bar(value: _budget == 0 ? 0 : planned / _budget, height: 8, color: over ? AppColors.error : AppColors.primary),
            if (over) ...[
              const SizedBox(height: Sp.sm),
              Text('Swap in a batch-cooked dhal or reduce servings to get back under budget.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ],
          ]),
        ),
        SectionHeader('Meals within budget', trailing: Text('${list.length}', style: T.labelMd.c(AppColors.onSurfaceVariant))),
        FullBleed(
          child: ChipRow(children: [
            for (final f in const ['All Plans', 'Dining Hall Sync', '10-Min Dorm Prep', 'Batch Cooking'])
              VChip(f == 'All Plans' ? 'All' : (f == 'Dining Hall Sync' ? 'Canteen' : (f == '10-Min Dorm Prep' ? '10-min hostel prep' : 'Batch cooking')),
                  selected: _filter == f, onTap: () => setState(() => _filter = f)),
          ]),
        ),
        if (_loading) const Loading(),
        for (final i in list) _mealCard(i),
      ],
    );
  }

  Widget _mealCard(Rec i) {
    final on = _plan.containsKey(i['id']);
    final c = (i['carbs_g'] as num).toDouble(), p = (i['protein_g'] as num).toDouble(), f = (i['fat_g'] as num).toDouble();
    final tot = (c * 4 + p * 4 + f * 9).clamp(1, 99999);
    Widget legend(String t, Color col) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(t, style: T.labelSm.c(AppColors.onSurfaceVariant)),
        ]);
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(iconByName(i['icon']), size: 40, fg: AppColors.nutrition),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i['name'], style: T.labelLg.semi, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text('${i['source']} · ${i['kcal']} kcal', style: T.bodySm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Text(money(i['price']), style: T.labelLg.semi.tnum),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(children: [
              Expanded(flex: (c * 4 / tot * 100).round().clamp(1, 100), child: Container(color: AppColors.warning)),
              const SizedBox(width: 2),
              Expanded(flex: (p * 4 / tot * 100).round().clamp(1, 100), child: Container(color: AppColors.heart)),
              const SizedBox(width: 2),
              Expanded(flex: (f * 9 / tot * 100).round().clamp(1, 100), child: Container(color: AppColors.water)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 12, children: [
          legend('Carbs ${c.round()} g', AppColors.warning),
          legend('Protein ${p.round()} g', AppColors.heart),
          legend('Fat ${f.round()} g', AppColors.water),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (i['prep_note'] != null) Expanded(child: Text(i['prep_note'], style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis)) else const Spacer(),
          if (on) ...[
            IconButton(tooltip: 'Fewer servings', icon: const Icon(Symbols.remove_rounded, size: 18), onPressed: () => _servings(i, -1)),
            Text('${_plan[i['id']]}× a week', style: T.labelMd.tnum),
            IconButton(tooltip: 'More servings', icon: const Icon(Symbols.add_rounded, size: 18), onPressed: () => _servings(i, 1)),
          ],
          SoftButton(on ? 'Added' : 'Add', icon: on ? Symbols.check_rounded : Symbols.add_rounded, expand: false, height: 40,
              color: on ? AppColors.tertiaryContainer : AppColors.surfaceContainer, fg: on ? AppColors.onTertiaryContainer : AppColors.onSurface, onTap: () => _toggle(i)),
        ]),
      ]),
    );
  }
}
