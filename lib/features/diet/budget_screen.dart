import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../data/budget_meals.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../tools/tool_widgets.dart';
import 'meal_log_screen.dart' show groupDots;

String money(num v) => '${Env.currency} ${Fmt.thousands(v)}';

const _minBudget = 1500.0;
const _maxBudget = 10000.0;

/// Weekly budget meal planner: balanced, low-cost meal combinations that fit
/// the student's weekly food budget, with a shareable grocery list.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _week = weekStart(DateTime.now());
  late double _budget = (AppState.instance.profile?.weeklyBudget ?? 5000).clamp(_minBudget, _maxBudget).toDouble();
  MealSlot? _slot;
  bool _saving = false;
  Map<String, int> _plan = {};

  String get _key => 'budget_plan_${isoDate(_week)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw != null) _plan = Map<String, int>.from(jsonDecode(raw) as Map)..removeWhere((k, _) => budgetMealById(k) == null);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _store() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(_plan));
    } catch (_) {}
  }

  void _setCount(BudgetMeal m, int n) {
    setState(() => n <= 0 ? _plan.remove(m.id) : _plan[m.id] = n.clamp(1, slotTargets[m.slot]!));
    _store();
  }

  Future<void> _persistBudget() async {
    try {
      await AppState.instance.updateProfile({'weekly_food_budget': _budget});
    } catch (_) {}
  }

  int get _planned => _plan.entries.fold(0, (a, e) => a + (budgetMealById(e.key)?.price ?? 0) * e.value);
  int _count(MealSlot s) => _plan.entries.where((e) => budgetMealById(e.key)?.slot == s).fold(0, (a, e) => a + e.value);

  void _suggest() {
    setState(() => _plan = suggestBudgetPlan(_budget));
    _store();
    _persistBudget();
    toast(context, 'Here is a balanced week within ${money(_budget)}. Adjust it as you like.');
  }

  Future<void> _groceries() async {
    if (_plan.isEmpty) return toast(context, 'Add a few meals, or tap Suggest a plan.');
    setState(() => _saving = true);
    final chosen = [for (final e in _plan.entries) (budgetMealById(e.key)!, e.value)];
    final lines = [for (final (m, n) in chosen) {'name': m.name, 'servings': n, 'price': m.price, 'total': m.price * n}];
    try {
      await _persistBudget();
      await Repo.saveGroceryList(_week, _budget, _planned.toDouble(), lines);
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
    if (!mounted) return;

    final buy = <String, int>{};
    for (final (m, n) in chosen) {
      for (final i in m.ingredients) {
        buy[i] = (buy[i] ?? 0) + n;
      }
    }
    final canteen = chosen.where((c) => c.$1.kind == MealKind.canteen).fold(0, (a, c) => a + c.$1.price * c.$2);
    final home = _planned - canteen;
    final text = StringBuffer('VitalU weekly food plan: ${money(_planned)} of ${money(_budget)}\n\n');
    for (final l in lines) {
      text.writeln('• ${l['name']} × ${l['servings']}: ${money(l['total'] as num)}');
    }
    if (buy.isNotEmpty) {
      text.writeln('\nShopping list (about ${money(home)}):');
      for (final e in buy.entries) {
        text.writeln('- ${e.key} (for ${e.value} ${e.value == 1 ? 'meal' : 'meals'})');
      }
    }
    if (canteen > 0) text.writeln('\nKeep ${money(canteen)} for canteen meals.');

    await showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Grocery list', style: T.headlineMd),
          const SizedBox(height: 4),
          Text("Saved to this week's plan.", style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          if (buy.isNotEmpty) ...[
            Text('To buy for meals you make (about ${money(home)})', style: T.labelLg),
            const SizedBox(height: 8),
            ListGroup(dividerIndent: 16, children: [
              for (final e in buy.entries) ListRow(icon: Symbols.shopping_basket_rounded, color: AppColors.warning, title: e.key, subtitle: 'For ${e.value} ${e.value == 1 ? 'meal' : 'meals'}', chevron: false),
            ]),
            const SizedBox(height: Sp.md),
          ],
          if (canteen > 0)
            VCard(
              flat: true,
              color: AppColors.surfaceContainer,
              child: Row(children: [
                Icon(Symbols.storefront_rounded, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Text('Keep ${money(canteen)} aside for canteen meals this week.', style: T.bodyMd)),
              ]),
            ),
          const SizedBox(height: Sp.md),
          PrimaryButton('Share list', leadingIcon: Symbols.share_rounded, color: AppColors.warning, onTap: () => SharePlus.instance.share(ShareParams(text: text.toString(), subject: 'VitalU grocery list'))),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final planned = _planned;
    // The budget is saved when the student makes a plan or a grocery list.
    final cushion = _budget - planned;
    final over = cushion < 0;
    final meals = budgetMeals.where((m) => _slot == null || m.slot == _slot).toList();
    final chosenGroups = {for (final id in _plan.keys) ...?budgetMealById(id)?.groups};

    return VPage(
      header: TitleHeader('Budget planner', onLeading: () => goBack(context, '/diet')),
      bottom: PrimaryButton('Make my grocery list', leadingIcon: Symbols.receipt_long_rounded, color: AppColors.warning, loading: _saving, onTap: _groceries),
      children: [
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CategoryLabel('Weekly food budget', icon: Symbols.savings_rounded, color: AppColors.warning),
            const SizedBox(height: 8),
            MetricValue(money(_budget), unit: 'about ${money((_budget / 7).round())} a day', size: 30),
            const SizedBox(height: Sp.sm),
            VSlider(
              value: _budget,
              min: _minBudget,
              max: _maxBudget,
              divisions: 34,
              color: AppColors.warning,
              onChanged: (v) => setState(() => _budget = v),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in const [2500.0, 4000.0, 6000.0, 8000.0, 10000.0])
                VChip(money(p), dense: true, selected: _budget == p, selectedColor: AppColors.warning, onTap: () {
                  setState(() => _budget = p);
                  _persistBudget();
                }),
            ]),
            const SizedBox(height: Sp.md),
            SoftButton('Suggest a balanced plan', icon: Symbols.auto_awesome_rounded, onTap: _suggest),
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
            Bar(value: _budget == 0 ? 0 : planned / _budget, height: 8, color: over ? AppColors.error : AppColors.warning),
            const SizedBox(height: Sp.md),
            Row(children: [
              for (final s in MealSlot.values) ...[
                if (s != MealSlot.breakfast) const SizedBox(width: 8),
                Expanded(child: _slotStat(s)),
              ],
            ]),
            const SizedBox(height: Sp.sm),
            Text(
              _plan.isEmpty
                  ? 'Add meals below, or let VitalU suggest a week that fits your budget.'
                  : '${chosenGroups.length} of 10 food groups across your planned meals.${over ? ' Swap a canteen meal for a batch-cooked one to get back under budget.' : ''}',
              style: T.bodySm.c(AppColors.onSurfaceVariant),
            ),
          ]),
        ),
        SectionHeader('Budget meals', trailing: TextLinkButton('Tips', leading: Symbols.lightbulb_rounded, onTap: _tips)),
        FullBleed(
          child: ChipRow(children: [
            VChip('All', selected: _slot == null, selectedColor: AppColors.warning, onTap: () => setState(() => _slot = null)),
            for (final s in MealSlot.values) VChip(slotLabel(s), selected: _slot == s, selectedColor: AppColors.warning, onTap: () => setState(() => _slot = s)),
          ]),
        ),
        for (final m in meals) _mealCard(m),
        const PrivacyNote('Prices are estimates and change by area and season.'),
      ],
    );
  }

  Widget _slotStat(MealSlot s) {
    final n = _count(s), goal = slotTargets[s]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s == MealSlot.main ? 'Main meals' : slotLabel(s), style: T.labelSm.c(AppColors.onSurfaceVariant)),
      Text('$n / $goal', style: T.labelLg.semi.tnum.c(n >= goal ? AppColors.tertiary : AppColors.onSurface)),
    ]);
  }

  Widget _mealCard(BudgetMeal m) {
    final n = _plan[m.id] ?? 0;
    final on = n > 0;
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: T.labelLg.semi),
              const SizedBox(height: 2),
              Text('${slotLabel(m.slot)} · ${kindLabel(m.kind)} · ${m.kcal} kcal', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(money(m.price), style: T.labelLg.semi.tnum),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          groupDots(m.groups.toList(), size: 9),
          const SizedBox(width: 4),
          Text('${m.groups.length} food ${m.groups.length == 1 ? 'group' : 'groups'}', style: T.labelSm.c(AppColors.onSurfaceVariant)),
        ]),
        if (m.note != null) ...[
          const SizedBox(height: 6),
          Text(m.note!, style: T.bodySm.c(AppColors.onSurfaceVariant)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (on) ...[
            IconButton.outlined(tooltip: 'Fewer', icon: const Icon(Symbols.remove_rounded, size: 18), onPressed: () => _setCount(m, n - 1)),
            SizedBox(width: 84, child: Text('$n× a week', textAlign: TextAlign.center, style: T.labelMd.tnum)),
            IconButton.outlined(tooltip: 'More', icon: const Icon(Symbols.add_rounded, size: 18), onPressed: n >= slotTargets[m.slot]! ? null : () => _setCount(m, n + 1)),
            const Spacer(),
            Text(money(m.price * n), style: T.labelLg.semi.tnum.c(AppColors.warning)),
          ] else ...[
            const Spacer(),
            SoftButton('Add to week', icon: Symbols.add_rounded, expand: false, height: 40, onTap: () => _setCount(m, 1)),
          ],
        ]),
      ]),
    );
  }

  void _tips() => showInfoSheet(context, title: 'Eating well on a budget', paragraphs: const [
        'Pulses are the cheapest protein: dhal, chickpeas, green gram and soya cost far less than meat and keep well. Pair them with rice or roti for a complete protein.',
        'Cook in batches. A pot of dhal or a tin of fish curry gives three portions; keep them in a closed box and reheat well.',
        'Buy vegetables and fruit in season from the pola or market. Leafy greens like gotukola and kankun are cheap and among the most nutritious foods you can eat.',
        'Swap soft drinks and packet snacks for plain tea, water, a banana or a handful of peanuts.',
      ]);
}
