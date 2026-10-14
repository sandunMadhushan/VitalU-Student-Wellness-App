import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'diet_science.dart' show LoggedDietQuality, loggedDietQuality;

/// One PDQS food group. Healthy groups score more the more often they are
/// eaten; the others score more the less often they are eaten.
class PdqsGroup {
  const PdqsGroup(this.key, this.label, this.examples, this.icon, {required this.healthy});
  final String key;
  final String label;
  final String examples;
  final IconData icon;
  final bool healthy;
}

/// Prime Diet Quality Score: 21 food groups (14 healthy, 7 less healthy),
/// each scored 0, 1 or 2 by servings in the past week, for a total of 0 to 42.
const pdqsGroups = <PdqsGroup>[
  PdqsGroup('dark_leafy', 'Dark green leafy vegetables', 'Gotukola, mukunuwenna, kankun, spinach', Symbols.eco_rounded, healthy: true),
  PdqsGroup('cruciferous', 'Cabbage-family vegetables', 'Cabbage, cauliflower, broccoli, knol-khol', Symbols.spa_rounded, healthy: true),
  PdqsGroup('carrots', 'Carrots', 'Raw, in salads or in curries', Symbols.nutrition_rounded, healthy: true),
  PdqsGroup('other_veg', 'Other vegetables', 'Beans, brinjal, okra, pumpkin, gourds, tomato', Symbols.grass_rounded, healthy: true),
  PdqsGroup('citrus', 'Whole citrus fruits', 'Orange, mandarin, lime, grapefruit (not juice)', Symbols.brightness_7_rounded, healthy: true),
  PdqsGroup('other_fruit', 'Other whole fruits', 'Banana, papaya, guava, mango, pineapple', Symbols.nutrition_rounded, healthy: true),
  PdqsGroup('legumes', 'Pulses and legumes', 'Dhal, chickpeas (kadala), green gram, cowpea', Symbols.grain_rounded, healthy: true),
  PdqsGroup('nuts', 'Nuts and seeds', 'Peanuts, cashews, sesame', Symbols.psychiatry_rounded, healthy: true),
  PdqsGroup('poultry', 'Poultry', 'Chicken', Symbols.egg_alt_rounded, healthy: true),
  PdqsGroup('fish', 'Fish', 'Fresh fish, sprats, tinned fish', Symbols.set_meal_rounded, healthy: true),
  PdqsGroup('eggs', 'Eggs', 'Boiled, curried or in an omelette', Symbols.egg_rounded, healthy: true),
  PdqsGroup('whole_grains', 'Whole grains', 'Red rice, kurakkan, oats, atta flour', Symbols.rice_bowl_rounded, healthy: true),
  PdqsGroup('veg_oils', 'Liquid vegetable oils', 'Sunflower, soybean, gingelly or olive oil', Symbols.water_drop_rounded, healthy: true),
  PdqsGroup('low_fat_dairy', 'Low-fat dairy', 'Low-fat milk, curd, yoghurt', Symbols.local_cafe_rounded, healthy: true),
  PdqsGroup('red_meat', 'Red meat', 'Beef, pork, mutton', Symbols.kebab_dining_rounded, healthy: false),
  PdqsGroup('processed_meat', 'Processed meat', 'Sausages, meatballs, ham, nuggets', Symbols.lunch_dining_rounded, healthy: false),
  PdqsGroup('refined_grains', 'Refined grains and baked goods', 'White bread, buns, biscuits, pastries', Symbols.bakery_dining_rounded, healthy: false),
  PdqsGroup('ssb', 'Sugar-sweetened drinks', 'Soft drinks, sweet milk tea, packet juice', Symbols.local_drink_rounded, healthy: false),
  PdqsGroup('sweets', 'Desserts and ice cream', 'Cake, kavum, chocolate, ice cream, sweets', Symbols.icecream_rounded, healthy: false),
  PdqsGroup('fried_out', 'Fried food from outside', 'Short eats, rolls, fried rice, kottu, chips', Symbols.fastfood_rounded, healthy: false),
  PdqsGroup('potatoes', 'Potatoes', 'Potato curry, chips, fries', Symbols.restaurant_rounded, healthy: false),
];

/// Servings in the past week: 0 to 1, 2 to 3, or 4 or more.
const pdqsFrequencies = ['0 to 1', '2 to 3', '4 or more'];

int pdqsPoints(PdqsGroup g, int frequency) => g.healthy ? frequency : 2 - frequency;

/// The app's own reading of the score (PDQS has no clinical cut-offs).
(String, Color) pdqsBand(num score) {
  if (score >= 28) return ('Good diet quality', AppColors.tertiary);
  if (score >= 21) return ('Fair diet quality', AppColors.warning);
  return ('Room to improve', AppColors.error);
}

class PdqsScreen extends StatefulWidget {
  const PdqsScreen({super.key});
  @override
  State<PdqsScreen> createState() => _PdqsScreenState();
}

class _PdqsScreenState extends State<PdqsScreen> {
  final _answers = <String, int>{};
  Rec? _last;
  LoggedDietQuality? _logged;
  bool _showResult = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Repo.latestToolResult('pdqs').then((r) {
      if (mounted && r != null) setState(() => _last = r);
    }).catchError((_) {});
    final now = DateTime.now();
    Repo.mealsBetween(dayStart(now).subtract(const Duration(days: 6)), now).then((m) {
      if (mounted) setState(() => _logged = loggedDietQuality(m));
    }).catchError((_) {});
  }

  int get _score => [for (final g in pdqsGroups) if (_answers[g.key] != null) pdqsPoints(g, _answers[g.key]!)].fold(0, (a, b) => a + b);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final (band, _) = pdqsBand(_score);
      await Repo.saveToolResult('pdqs', score: _score, category: band, data: {'answers': _answers});
      if (mounted) setState(() => _showResult = true);
    } catch (_) {
      if (mounted) toast(context, 'Could not save your check-in. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _answers.length == pdqsGroups.length;
    return VPage(
      header: TitleHeader('Diet quality score', onLeading: () => goBack(context, '/diet')),
      bottom: _showResult
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              PrimaryButton(done ? 'See my score' : '${_answers.length} of ${pdqsGroups.length} answered', color: AppColors.nutrition, loading: _saving, onTap: done ? _save : null),
            ]),
      children: _showResult ? _result() : _form(),
    );
  }

  List<Widget> _form() => [
        VCard(
          color: AppColors.tint(AppColors.nutrition),
          flat: true,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/icons3d/diet.jpg', width: 56, height: 56, fit: BoxFit.cover)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your past 7 days', style: T.headlineSm),
                const SizedBox(height: 4),
                Text('For each food group, how many servings did you have this week? This is the Prime Diet Quality Score (PDQS), scored out of 42.',
                    style: T.bodyMd.c(AppColors.onSurfaceVariant)),
                if (_last != null) ...[
                  const SizedBox(height: 6),
                  Text('Last score: ${(_last!['score'] as num).round()} / 42 on ${DateFormat('d MMM').format(DateTime.parse(_last!['created_at']).toLocal())}',
                      style: T.labelMd.c(AppColors.nutrition)),
                ],
              ]),
            ),
          ]),
        ),
        if (_logged != null && _logged!.daysLogged > 0) _loggedCard(_logged!),
        const SectionHeader('Foods to enjoy often', subtitle: 'More servings score higher'),
        for (final g in pdqsGroups.where((g) => g.healthy)) _row(g),
        const SectionHeader('Foods to keep occasional', subtitle: 'Fewer servings score higher'),
        for (final g in pdqsGroups.where((g) => !g.healthy)) _row(g),
        const PrivacyNote('A self-check of eating patterns, not a diagnosis. Only you can see this.'),
      ];

  /// The same score estimated from the last 7 days of meal logs.
  Widget _loggedCard(LoggedDietQuality q) {
    final (band, color) = pdqsBand(q.score);
    final missing = [for (final g in pdqsGroups) if (g.healthy && (q.servings[g.key] ?? 0) == 0) g.label.toLowerCase()];
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Ring(value: q.score / 42, size: 64, stroke: 6, color: color, child: Text('${q.score}', style: T.metric(20))),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CategoryLabel('From your meal logs', icon: Symbols.menu_book_rounded, color: AppColors.nutrition),
              const SizedBox(height: 4),
              Text(band, style: T.headlineSm.c(color)),
              Text('${q.daysLogged} of 7 days logged${q.reliable ? '' : '. Log at least 4 days for a fair estimate'}.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ]),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Not in your logs this week: ${missing.take(4).join(', ')}.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
        ],
        const SizedBox(height: 6),
        Text('Each logged food counts as one serving, so this is an estimate. The check-in below asks you directly.', style: T.labelSm.c(AppColors.onSurfaceVariant)),
      ]),
    );
  }

  Widget _row(PdqsGroup g) {
    final c = g.healthy ? AppColors.nutrition : AppColors.warning;
    final v = _answers[g.key];
    return VCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconCircle(g.icon, size: 34, iconSize: 18, fg: c, radius: 10, fill: 1),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.label, style: T.labelLg.w(FontWeight.w700)),
              Text(g.examples, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          if (v != null) Icon(Symbols.check_circle_rounded, color: c, fill: 1, size: 20),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (int i = 0; i < pdqsFrequencies.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: VChip(
                pdqsFrequencies[i],
                dense: true,
                height: 34,
                selected: v == i,
                selectedColor: c,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _answers[g.key] = i);
                },
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  List<Widget> _result() {
    final score = _score;
    final (band, color) = pdqsBand(score);
    final wins = [for (final g in pdqsGroups) if (pdqsPoints(g, _answers[g.key]!) == 2) g];
    final grow = [for (final g in pdqsGroups) if (pdqsPoints(g, _answers[g.key]!) == 0) g];
    return [
      VCard(
        child: Column(children: [
          Ring(
            value: score / 42,
            size: 150,
            stroke: 12,
            color: color,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$score', style: T.metric(42)),
              Text('of 42', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: Sp.md),
          Text(band, style: T.headlineMd.c(color)),
          const SizedBox(height: 6),
          Text('Higher scores mean more of the foods linked with good long-term health, and fewer of the ones best kept occasional.',
              textAlign: TextAlign.center, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ]),
      ),
      if (wins.isNotEmpty) _list('Going well', Symbols.thumb_up_rounded, AppColors.tertiary, [for (final g in wins) g.healthy ? '${g.label}: 4 or more servings' : '${g.label}: kept to 0 to 1']),
      if (grow.isNotEmpty)
        _list('Easy next steps', Symbols.trending_up_rounded, AppColors.warning, [
          for (final g in grow.take(5)) g.healthy ? 'Add ${g.label.toLowerCase()} a couple of times this week (${g.examples.toLowerCase()}).' : 'Cut back on ${g.label.toLowerCase()} to 2 or 3 times this week.',
        ]),
      SoftButton('Check in again', icon: Symbols.refresh_rounded, onTap: () => setState(() {
            _answers.clear();
            _showResult = false;
          })),
      Center(child: TextLinkButton('Done', color: AppColors.onSurfaceVariant, onTap: () => goBack(context, '/diet'))),
      const PrivacyNote('PDQS bands shown here are a VitalU guide, not clinical cut-offs.'),
    ];
  }

  Widget _list(String title, IconData icon, Color c, List<String> items) => VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: c, fill: 1),
            const SizedBox(width: 8),
            Text(title, style: T.headlineSm),
          ]),
          const SizedBox(height: 10),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle))),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: T.bodyMd)),
              ]),
            ),
        ]),
      );
}
