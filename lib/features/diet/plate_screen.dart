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
  final Color color;
  final String ruler;
  final String desc;
  final List<(String, String, String)> finds;
  final Set<String> groups;
  final double goal;
  final String unit;
}

const _sections = [
  _Section('veggies', '🥦 Veggies (1/2)', 'Vegetables & Greens — Half Plate', 'Target: ~50% of your plate', Symbols.spa, AppColors.tertiaryContainer, 'Visual Ruler: 2 Loose Fists',
      'Load up on colourful vegetables, leafy mallum, salads and curries. Delivers vibrant micronutrients, sustained focus during long afternoon lectures, and happy gut motility.',
      [('🥬', 'Gotukola Mallum', 'Canteen curry counter'), ('🥗', 'Fresh Salad', 'Salad / sambol tray'), ('🥒', 'Cucumber Sambol', 'Rice & curry line'), ('🫑', 'Stir-fried Veg', 'Fried rice station')],
      {'greens', 'herbs_spices'}, 2, 'cups'),
  _Section('grains', '🌾 Grains (1/4)', 'Whole Grains — Quarter Plate', 'Target: ~25% of your plate', Symbols.grain, AppColors.butterAccent, 'Visual Ruler: 1 Cupped Hand',
      'Choose red rice, whole-wheat roti, string hoppers or oats. Complex carbohydrates release energy slowly so you avoid the post-lunch slump.',
      [('🍚', 'Red Rice', 'Rice & curry line'), ('🫓', 'Wholewheat Roti', 'Short-eats counter'), ('🥣', 'Oats / Kanji', 'Breakfast counter'), ('🍜', 'String Hoppers', 'Evening menu')],
      {'grains'}, 3, 'servings'),
  _Section('protein', '🐟 Protein (1/4)', 'Protein — Quarter Plate', 'Target: ~25% of your plate', Symbols.set_meal, AppColors.secondary, 'Visual Ruler: Palm of Your Hand',
      'Fish, eggs, chicken, dhal, chickpeas or soya keep you full and support muscle repair and concentration.',
      [('🐟', 'Fish Curry', 'Rice & curry line'), ('🥚', 'Boiled Egg', 'Canteen counter'), ('🫘', 'Dhal Curry', 'Every lunch plate'), ('🍗', 'Chicken Curry', 'Main line')],
      {'protein', 'legumes_nuts'}, 2, 'servings'),
  _Section('berries', '🫐 Fruit Side', 'Fruit — A Colourful Side', 'Target: 2 fruits a day', Symbols.nutrition, AppColors.primary, 'Visual Ruler: 1 Fist',
      'Seasonal fruit adds fibre, vitamin C and natural sweetness — a better study snack than biscuits or soft drinks.',
      [('🍌', 'Banana', 'Campus fruit stall'), ('🍍', 'Pineapple Slices', 'Canteen dessert'), ('🥭', 'Mango / Papaya', 'Fruit stall'), ('🍊', 'Orange / Guava', 'Grab & Go')],
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
        name: 'Healthy Plate: ½ veg • ¼ grains • ¼ protein',
        source: 'Healthy Plate Guide',
        kcal: 550,
        carbs: 65,
        protein: 25,
        fat: 15,
        groups: const ['greens', 'grains', 'protein'],
        status: 'planned',
        plannedTime: '12:30',
      );
      if (mounted) toast(context, "Added to today's lunch plan — confirm it when you eat 🍽️");
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prog = _progress(_sel);
    return VPage(
      header: const MainHeader('Vitalu   Diet & Nutrition'),
      nav: NavTab.diet,
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, iconSize: 20, shadow: Shadows.tiny, onTap: () => goBack(context, '/diet')),
          const Spacer(),
          TagPill('Mindful Portions', icon: Symbols.restaurant, fill: 1, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixed),
          const Spacer(),
          CircleButton(Symbols.info, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, iconSize: 20, shadow: Shadows.tiny, onTap: () => showInfoSheet(context, title: 'The Healthy Plate', paragraphs: const [
                'Based on the healthy-plate model used in Sri Lankan and international dietary guidelines: half your plate vegetables, a quarter whole grains, a quarter protein, plus fruit and water.',
                'Use your hand as a portion guide — no scales or calorie counting needed.',
              ])),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Build Your Healthy Plate', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('Visual nourishment for campus canteens. No calorie counting or food scales needed — just balanced, intuitive portions for sustained study energy.',
              style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
        ]),
        VCard(
          clip: true,
          shadow: Shadows.card,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(top: -48, right: -48, child: Glow(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), size: 192)),
            Positioned(bottom: -40, left: -40, child: Glow(color: AppColors.secondaryFixed.withValues(alpha: 0.4), size: 176)),
            Column(children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(children: [
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.surfaceContainerLow, Color(0x99EBE6F7)]),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: ClipOval(child: const AssetImg('healthy_plate')),
                      ),
                      Positioned(top: 8, left: 24, child: _badge('50% Veggies', AppColors.tertiary, AppColors.onTertiary, _sel.key == 'veggies')),
                      Positioned(bottom: 20, left: 20, child: _badge('25% Grains', AppColors.surfaceContainerHighest, AppColors.onSurface, _sel.key == 'grains')),
                      Positioned(bottom: 24, right: 20, child: _badge('25% Protein', AppColors.secondaryFixed, AppColors.onSecondaryFixedVariant, _sel.key == 'protein')),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final s in _sections) ...[
                    VChip(s.tab, selected: _sel == s, selectedColor: AppColors.tertiaryContainer, selectedFg: AppColors.onTertiary, color: AppColors.surfaceContainer, onTap: () => setState(() => _sel = s)),
                    const SizedBox(width: 8),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Symbols.touch_app, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text("Tap categories to adapt for today's canteen run", style: T.labelSm.c(AppColors.onSurfaceVariant)),
              ]),
            ]),
          ]),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: VCard(
            key: ValueKey(_sel.key),
            shadow: Shadows.card,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: _sel.color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_sel.title, style: T.headlineSm)),
                    ]),
                    const SizedBox(height: 2),
                    Text(_sel.ratio, style: T.labelSm.c(AppColors.tertiary)),
                  ]),
                ),
                IconCircle(_sel.icon, size: 40, iconSize: 22, bg: AppColors.surfaceContainerLow, fg: _sel.color),
              ]),
              const SizedBox(height: Sp.sm),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.base)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Symbols.front_hand, size: 18, color: AppColors.tertiary),
                    const SizedBox(width: 8),
                    Text(_sel.ruler, style: T.labelMd),
                  ]),
                  const SizedBox(height: 4),
                  Text(_sel.desc, style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
                ]),
              ),
              const SizedBox(height: Sp.sm),
              Text('CAMPUS CANTEEN FINDS', style: T.labelSm.c(AppColors.onSurfaceVariant).tracking(0.6)),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, c) {
                final w = (c.maxWidth - 8) / 2;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final f in _sel.finds)
                    Container(
                      width: w,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.base)),
                      child: Row(children: [
                        Text(f.$1, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(f.$2, style: T.labelSm, overflow: TextOverflow.ellipsis),
                            Text(f.$3, style: T.bodySm.s(11).c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      ]),
                    ),
                ]);
              }),
              const SizedBox(height: Sp.sm),
              Row(children: [
                Expanded(child: Text('Today\'s ${_sel.key == 'veggies' ? 'colourful' : ''} intake progress', style: T.labelSm.c(AppColors.onSurfaceVariant))),
                Text('${prog % 1 == 0 ? prog.toInt() : prog} / ${_sel.goal.toInt()} ${_sel.unit}', style: T.labelSm.c(AppColors.tertiary)),
              ]),
              const SizedBox(height: 6),
              Container(
                height: 12,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                child: Bar(value: prog / _sel.goal, height: 8, color: AppColors.tertiary, track: Colors.transparent),
              ),
            ]),
          ),
        ),
        VCard(
          color: AppColors.surfaceContainerLow,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IconCircle(Symbols.lightbulb, size: 40, iconSize: 20, bg: AppColors.primaryFixed, fg: AppColors.onPrimaryFixed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('The "Half-Plate First" Rule', style: T.headlineSm),
                const SizedBox(height: 4),
                Text('Serve vegetables and mallum first, then add rice. Filling half your plate with colour leaves room for favourites without sudden energy crashes.',
                    style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
              ]),
            ),
          ]),
        ),
        PrimaryButton("Apply to Today's Lunch", leadingIcon: Symbols.bookmark_add, height: 52, onTap: _apply),
        Text('Private to you • VitalU promotes a restorative, joyful food relationship', textAlign: TextAlign.center, style: T.labelSm.c(AppColors.outline)),
      ],
    );
  }

  Widget _badge(String t, Color bg, Color fg, bool on) => AnimatedScale(
        scale: on ? 1.08 : 1,
        duration: const Duration(milliseconds: 200),
        child: Pill(color: bg, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), shadow: Shadows.tiny, child: Text(t, style: T.labelSm.c(fg))),
      );
}
