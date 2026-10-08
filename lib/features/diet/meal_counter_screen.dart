import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/meal_counter_catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'diet_hub_screen.dart' show mealTypes;
import 'meal_log_screen.dart' show defaultMealType;

/// One food added to the meal being built: its name, a human-readable
/// portion ("8 tablespoons") and the estimated kcal for that portion.
typedef _TrayItem = (String name, String portion, int kcal);

String _fmtQty(double q, double step) => step < 1 ? q.toStringAsFixed(1) : q.toStringAsFixed(0);
String _plural(String unit) => unit == 'glass' ? 'glasses' : '${unit}s';

/// Build-a-meal calorie counter: pick foods from a searchable Sri Lankan
/// food database, set the portion in practical units (tablespoons, cups,
/// pieces, servings…), and see the estimated calories per item and for the
/// whole meal. Kept separate from the photo/quick-pick "Log a meal" flow.
class MealCounterScreen extends StatefulWidget {
  const MealCounterScreen({super.key});
  @override
  State<MealCounterScreen> createState() => _MealCounterScreenState();
}

class _MealCounterScreenState extends State<MealCounterScreen> {
  late String _type = defaultMealType();
  String _cat = 'All';
  String _q = '';
  bool _saving = false;
  final List<_TrayItem> _tray = [];

  int get _total => _tray.fold<int>(0, (a, t) => a + t.$3);

  Future<void> _pickPortion(MealCounterFood food) async {
    PortionUnit unit = food.units.first;
    double qty = unit.min;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          final kcal = (unit.kcalPerUnit * qty).round();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(food.name, style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Set the portion you actually had.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            if (food.units.length > 1) ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final u in food.units)
                  VChip(_plural(u.label), selected: u.label == unit.label, selectedColor: AppColors.nutrition, onTap: () => set(() {
                        unit = u;
                        qty = u.min;
                      })),
              ]),
              const SizedBox(height: Sp.md),
            ],
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.outlined(icon: const Icon(Symbols.remove_rounded), onPressed: qty <= unit.min ? null : () => set(() => qty = (qty - unit.step).clamp(unit.min, unit.max))),
              SizedBox(width: 110, child: Center(child: Text('${_fmtQty(qty, unit.step)} ${qty == 1 ? unit.label : _plural(unit.label)}', style: T.labelLg.semi, textAlign: TextAlign.center))),
              IconButton.outlined(icon: const Icon(Symbols.add_rounded), onPressed: qty >= unit.max ? null : () => set(() => qty = (qty + unit.step).clamp(unit.min, unit.max))),
            ]),
            const SizedBox(height: Sp.md),
            Center(child: MetricValue('$kcal', unit: 'kcal', size: 30)),
            const SizedBox(height: Sp.md),
            PrimaryButton('Add to meal', onTap: () {
              Navigator.pop(ctx);
              setState(() => _tray.add((food.name, '${_fmtQty(qty, unit.step)} ${qty == 1 ? unit.label : _plural(unit.label)}', kcal)));
            }),
          ]);
        }));
  }

  Future<void> _logMeal() async {
    if (_tray.isEmpty) return;
    setState(() => _saving = true);
    try {
      final name = _tray.map((t) => '${t.$1} (${t.$2})').join(', ');
      await Repo.addMeal(mealType: _type, name: name, source: 'Meal calorie counter', kcal: _total);
      if (mounted) {
        toast(context, 'Logged ${_tray.length} food${_tray.length == 1 ? '' : 's'} · $_total kcal');
        setState(() => _tray.clear());
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not log your meal. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('Meal calorie counter', onLeading: () => goBack(context, '/diet')),
      bottom: _tray.isEmpty ? null : _totalBar(),
      children: [
        Text('Build your meal from real portions — tablespoons, cups, pieces and more — and see the estimated calories as you go.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        SizedBox(
          width: double.infinity,
          child: Segmented(small: false, options: [for (final t in mealTypes) t.$2], value: mealTypes.firstWhere((t) => t.$1 == _type).$2, onChanged: (v) => setState(() => _type = mealTypes.firstWhere((t) => t.$2 == v).$1)),
        ),
        if (_tray.isNotEmpty) ...[
          SectionHeader('Your meal', trailing: Text('$_total kcal', style: T.labelLg.semi.c(AppColors.nutrition))),
          ListGroup(children: [for (int i = 0; i < _tray.length; i++) _trayRow(i)]),
        ],
        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: T.bodyLg,
          decoration: InputDecoration(prefixIcon: Icon(Symbols.search_rounded, color: AppColors.onSurfaceVariant, size: 20), hintText: 'Search foods'),
        ),
        FullBleed(
          child: ChipRow(children: [
            for (final c in ['All', for (final cat in mealCounterCatalog) cat.name]) VChip(c, selected: _cat == c, onTap: () => setState(() => _cat = c)),
          ]),
        ),
        ..._foodList(),
        const PrivacyNote('Calorie values are estimates based on common recipes and portion sizes.'),
      ],
    );
  }

  List<Widget> _foodList() {
    if (_q.isEmpty && _cat == 'All') {
      return [
        for (final cat in mealCounterCatalog) ...[
          SectionHeader(cat.name),
          ListGroup(children: [for (final f in cat.foods) _foodRow(f, cat.name)]),
        ],
      ];
    }
    final results = <(MealCounterFood, String)>[];
    for (final cat in mealCounterCatalog) {
      if (_cat != 'All' && _cat != cat.name) continue;
      for (final f in cat.foods) {
        if (_q.isNotEmpty && !f.name.toLowerCase().contains(_q.toLowerCase())) continue;
        results.add((f, cat.name));
      }
    }
    if (results.isEmpty) return [Text('No matches. Try a different search or category.', style: T.bodyMd.c(AppColors.onSurfaceVariant))];
    return [ListGroup(children: [for (final r in results) _foodRow(r.$1, r.$2)])];
  }

  Widget _foodRow(MealCounterFood food, String category) => ListRow(
        icon: Symbols.restaurant_rounded,
        color: AppColors.nutrition,
        title: food.name,
        subtitle: category,
        chevron: false,
        trailing: Icon(Symbols.add_circle_rounded, color: AppColors.primary, size: 26),
        onTap: () => _pickPortion(food),
      );

  Widget _trayRow(int i) {
    final (name, portion, kcal) = _tray[i];
    return ListRow(
      icon: Symbols.restaurant_rounded,
      color: AppColors.nutrition,
      title: name,
      subtitle: portion,
      chevron: false,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$kcal kcal', style: T.labelLg.semi.tnum),
        const SizedBox(width: 2),
        IconButton(tooltip: 'Remove', icon: const Icon(Symbols.close_rounded, size: 18), onPressed: () => setState(() => _tray.removeAt(i))),
      ]),
    );
  }

  Widget _totalBar() => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Total meal calories', style: T.labelLg.semi),
            Text('$_total kcal · ${_tray.length} food${_tray.length == 1 ? '' : 's'}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        PrimaryButton('Log ${mealTypes.firstWhere((t) => t.$1 == _type).$2.toLowerCase()}', expand: false, loading: _saving, onTap: _logMeal),
      ]);
}
