import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../tools/tool_widgets.dart';

class _Section {
  const _Section(this.key, this.tab, this.title, this.ratio, this.icon, this.color, this.ruler, this.desc, this.finds, this.groups, this.goal, this.unit);
  final String key;
  final String tab;
  final String title;
  final String ratio;
  final IconData icon;
  final Color Function() color;
  final String ruler;
  final String desc;
  final List<(String, String)> finds;
  final Set<String> groups;
  final double goal;
  final String unit;
}

final _sections = [
  _Section('veggies', 'Vegetables', 'Vegetables and greens', 'Half the plate', Symbols.eco_rounded, () => AppColors.nutrition, 'About two loose fists',
      'Colourful vegetables, leafy mallum, salads and vegetable curries. They bring fibre and micronutrients and keep afternoon energy steady.',
      [('Gotukola mallum', 'Canteen curry counter'), ('Fresh salad', 'Salad or sambol tray'), ('Cucumber sambol', 'Rice and curry line'), ('Stir-fried vegetables', 'Fried rice station')],
      {'greens', 'herbs_spices'}, 2, 'cups'),
  _Section('grains', 'Grains', 'Whole grains', 'A quarter of the plate', Symbols.grain_rounded, () => AppColors.warning, 'About one cupped hand',
      'Red rice, wholewheat roti, string hoppers or oats. Complex carbohydrates release energy slowly, so you avoid the post-lunch slump.',
      [('Red rice', 'Rice and curry line'), ('Wholewheat roti', 'Short-eats counter'), ('Oats or kanji', 'Breakfast counter'), ('String hoppers', 'Evening menu')],
      {'grains'}, 3, 'servings'),
  _Section('protein', 'Protein', 'Protein', 'A quarter of the plate', Symbols.set_meal_rounded, () => AppColors.heart, 'About the size of your palm',
      'Fish, eggs, chicken, dhal, chickpeas or soya keep you full and support muscle repair and concentration.',
      [('Fish curry', 'Rice and curry line'), ('Boiled egg', 'Canteen counter'), ('Dhal curry', 'Every lunch plate'), ('Chicken curry', 'Main line')],
      {'protein', 'legumes_nuts'}, 2, 'servings'),
  _Section('fruit', 'Fruit', 'Fruit on the side', 'Two fruits a day', Symbols.nutrition_rounded, () => AppColors.mind, 'About one fist',
      'Seasonal fruit adds fibre, vitamin C and natural sweetness. A better study snack than biscuits or soft drinks.',
      [('Banana', 'Campus fruit stall'), ('Pineapple', 'Canteen dessert'), ('Mango or papaya', 'Fruit stall'), ('Orange or guava', 'Grab and go')],
      {'fruits'}, 2, 'fruits'),
];

class PlateScreen extends StatefulWidget {
  const PlateScreen({super.key});
  @override
  State<PlateScreen> createState() => _PlateScreenState();
}

class _PlateScreenState extends State<PlateScreen> {
  _Section _sel = _sections.first;
  List<Rec> _today = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      _today = await Repo.diversityBetween(now, now);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  double _progress(_Section s) {
    final n = _today.where((r) => s.groups.contains(r['food_group'])).length;
    return s.key == 'veggies' ? n * 0.5 : n.toDouble();
  }

  Future<void> _apply() async {
    try {
      await Repo.addMeal(
        mealType: 'lunch',
        name: 'Healthy plate: ½ vegetables, ¼ grains, ¼ protein',
        source: 'Healthy plate guide',
        kcal: 550,
        carbs: 65,
        protein: 25,
        fat: 15,
        groups: const ['greens', 'grains', 'protein'],
        status: 'planned',
        plannedTime: '12:30',
      );
      if (mounted) toast(context, "Added to today's lunch plan. Confirm it when you eat.");
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prog = _progress(_sel);
    final c = _sel.color();
    return VPage(
      header: TitleHeader('Healthy plate', onLeading: () => goBack(context, '/diet')),
      children: [
        Text('Portions for canteen meals, no scale needed.', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        VCard(
          child: Column(children: [
            SizedBox(
              height: 220,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(width: 200, height: 200, child: CustomPaint(painter: _PlatePainter(_sel.key))),
                const SizedBox(width: 16),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sel.key == 'fruit' ? AppColors.mind : AppColors.mind.withValues(alpha: 0.3),
                    border: Border.all(color: AppColors.outlineVariant, width: 4),
                  ),
                  child: Icon(Symbols.nutrition_rounded, color: _sel.key == 'fruit' ? Colors.white : AppColors.mind, fill: 1),
                ),
              ]),
            ),
            const SizedBox(height: Sp.md),
            SizedBox(
              width: double.infinity,
              child: Segmented(small: false, options: [for (final s in _sections) s.tab], value: _sel.tab, onChanged: (v) => setState(() => _sel = _sections.firstWhere((s) => s.tab == v))),
            ),
          ]),
        ),
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CategoryLabel(_sel.title, icon: _sel.icon, color: c, trailing: _sel.ratio),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Symbols.front_hand_rounded, size: 18, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(_sel.ruler, style: T.labelLg.semi),
            ]),
            const SizedBox(height: 6),
            Text(_sel.desc, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Row(children: [
              Expanded(child: Text('Today', style: T.labelMd.c(AppColors.onSurfaceVariant))),
              Text('${prog % 1 == 0 ? prog.toInt() : prog} of ${_sel.goal.toInt()} ${_sel.unit}', style: T.labelMd.tnum.c(AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 6),
            Bar(value: prog / _sel.goal, color: c),
          ]),
        ),
        ListGroup(header: 'Where to find it', children: [
          for (final f in _sel.finds) ListRow(icon: _sel.icon, color: c, title: f.$1, subtitle: f.$2),
        ]),
        VCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.lightbulb_rounded, size: 22, color: AppColors.warning, fill: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Vegetables first', style: T.headlineSm),
                const SizedBox(height: 4),
                Text('Serve vegetables and mallum first, then add rice. Filling half the plate with vegetables leaves room for favourites without an energy crash.',
                    style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        PrimaryButton("Add to today's lunch plan", onTap: _apply),
        Center(
          child: TextLinkButton('About the healthy plate', leading: Symbols.info_rounded, onTap: () => showInfoSheet(context, title: 'The healthy plate', paragraphs: const [
                'Based on the healthy-plate model in Sri Lankan and international dietary guidelines: half your plate vegetables, a quarter whole grains, a quarter protein, plus fruit and water.',
                'Use your hand as a portion guide. No scales or calorie counting needed.',
              ])),
        ),
      ],
    );
  }
}

/// Plate diagram: half vegetables, a quarter grains, a quarter protein.
class _PlatePainter extends CustomPainter {
  _PlatePainter(this.selected);
  final String selected;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = AppColors.surfaceContainerHigh);
    final inner = Rect.fromCircle(center: c, radius: r - 10);
    Color col(String key, Color base) => selected == key || selected == 'fruit' ? base : base.withValues(alpha: 0.3);
    const gap = 0.03;
    canvas.drawArc(inner, math.pi / 2 + gap, math.pi - 2 * gap, true, Paint()..color = col('veggies', AppColors.nutrition));
    canvas.drawArc(inner, -math.pi / 2 + gap, math.pi / 2 - 2 * gap, true, Paint()..color = col('grains', AppColors.warning));
    canvas.drawArc(inner, gap, math.pi / 2 - 2 * gap, true, Paint()..color = col('protein', AppColors.heart));
    void label(String text, Offset at) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontFamily: T.family, fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    label('½', c + Offset(-r * 0.45, 0));
    label('¼', c + Offset(r * 0.38, -r * 0.38));
    label('¼', c + Offset(r * 0.38, r * 0.38));
  }

  @override
  bool shouldRepaint(covariant _PlatePainter old) => old.selected != selected;
}
