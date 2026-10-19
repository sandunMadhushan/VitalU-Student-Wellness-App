import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../tools/tool_widgets.dart';
import 'diet_science.dart' show diversityByDay;

/// Dietary diversity guide, built on the ten food groups used to measure the
/// dietary diversity of Sri Lankan men and women, with 5 or more in a day
/// counted as minimum dietary diversity.
class DiversityScreen extends StatefulWidget {
  const DiversityScreen({super.key});
  @override
  State<DiversityScreen> createState() => _DiversityScreenState();
}

class _DiversityScreenState extends State<DiversityScreen> {
  bool _loading = true;
  List<Rec> _logs = [];
  Map<String, Set<String>> _byDay = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      _logs = await Repo.diversityBetween(dayStart(now).subtract(const Duration(days: 6)), now);
      _byDay = diversityByDay(_logs);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  /// The food that first counted for [group] today, if any.
  String? _foodFor(String group) {
    final today = isoDate(DateTime.now());
    for (final r in _logs) {
      if (r['log_date'] == today && groupByKey(r['food_group'] as String, food: r['food_name'] as String?)?.key == group) return r['food_name'] as String?;
    }
    return null;
  }

  Future<void> _open(FoodGroup g) async {
    final eaten = _foodFor(g.key);
    final c = Color(g.color);
    await showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(borderRadius: BorderRadius.circular(Rad.lg), child: AspectRatio(aspectRatio: 16 / 9, child: Image.asset(g.image, fit: BoxFit.cover))),
          const SizedBox(height: Sp.md),
          Text(g.label, style: T.headlineMd),
          const SizedBox(height: 4),
          Text(g.meaning, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          Text('Counts when you eat', style: T.labelLg),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final e in g.examples) TagPill(e, bg: c.withValues(alpha: 0.12), fg: AppColors.onSurface)]),
          const SizedBox(height: 8),
          Text('About a tablespoon (15 g) or more counts. A pinch in a curry does not.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          if (eaten != null)
            Row(children: [
              Icon(Symbols.check_circle_rounded, color: AppColors.tertiary, fill: 1),
              const SizedBox(width: 8),
              Expanded(child: Text('Counted today from $eaten', style: T.labelLg.c(AppColors.tertiary))),
            ])
          else
            PrimaryButton('I ate this today', color: c, onTap: () async {
              HapticFeedback.selectionClick();
              try {
                await Repo.addDiversity(g.key, g.label);
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final today = _byDay[isoDate(DateTime.now())] ?? {};
    final n = today.length;
    final adequate = n >= minDietaryDiversity;
    final missing = foodGroups.where((g) => !today.contains(g.key)).toList();
    final c = adequate ? AppColors.tertiary : AppColors.nutrition;

    return VPage(
      header: TitleHeader('Dietary diversity guide',onLeading: () => goBack(context, '/diet')),
      onRefresh: _load,
      bottom: PrimaryButton('Log a meal', leadingIcon: Symbols.add_rounded, color: AppColors.nutrition, onTap: () async {
        await context.push('/diet/log');
        _load();
      }),
      children: [
        VCard(
          child: Row(children: [
            Ring(
              value: n / 10,
              size: 104,
              stroke: 11,
              color: c,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$n', style: T.metric(28)),
                Text('of 10', style: T.labelSm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: Sp.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CategoryLabel("Today's score", icon: Symbols.nutrition_rounded, color: c),
                const SizedBox(height: 6),
                Text(adequate ? 'A varied day' : (n == 0 ? 'Nothing logged yet' : '${minDietaryDiversity - n} more to go'), style: T.headlineSm.c(adequate ? c : AppColors.onSurface)),
                const SizedBox(height: 4),
                Text(
                  adequate
                      ? 'You ate from 5 or more food groups, the level linked with getting enough vitamins and minerals.'
                      : missing.isEmpty
                          ? ''
                          : 'Aim for 5 or more groups. An easy one to add: ${missing.first.examples.first.toLowerCase()}.',
                  style: T.bodySm.c(AppColors.onSurfaceVariant),
                ),
              ]),
            ),
          ]),
        ),
        const SectionHeader('This week', subtitle: 'Food groups eaten each day'),
        VCard(child: _WeekChart(byDay: _byDay)),
        SectionHeader('The 10 food groups', trailing: TextLinkButton('About', leading: Symbols.info_rounded, onTap: _about)),
        if (_loading)
          const Loading()
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: [for (final g in foodGroups) _groupTile(g, today.contains(g.key))],
          ),
        const ToolReference(
          tool: 'a Sri Lankan dietary diversity score',
          citation:
              'Abeywickrama HM, et al. Assessment of nutritional status and dietary pattern of a rural adult population in dry zone, Sri Lanka. Int J Environ Res Public Health. 2020;17(1):150.',
          url: 'https://doi.org/10.3390/ijerph17010150',
          note: 'Ten food groups adapted from FAO for Sri Lankan adults, men and women. The 5-group cut-off follows FAO and has been shown to work for men as well as women (Gómez et al., 2024).',
        ),
        const PrivacyNote('Food groups are counted from the meals you log. Only you can see this.'),
      ],
    );
  }

  Widget _groupTile(FoodGroup g, bool done) {
    final c = Color(g.color);
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(Rad.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(g),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: done ? c : AppColors.outlineVariant, width: done ? 2 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(g.image, fit: BoxFit.cover),
                if (done)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Symbols.check_circle_rounded, color: AppColors.tertiary, fill: 1, size: 26),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.label, style: T.labelLg.w(FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(done ? 'Eaten today' : g.examples.take(2).join(', '), style: T.labelSm.c(done ? c : AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _about() => showInfoSheet(context, title: 'About dietary diversity', paragraphs: const [
        'VitalU counts how many of 10 food groups you ate in a day. The groups are the ones Sri Lankan researchers use to measure dietary diversity in adult men and women, adapted from the Food and Agriculture Organization (FAO): cereals, tubers and starchy vegetables, root and fruit vegetables, green leafy vegetables, fruits, pulses (with nuts and seeds), meat, eggs, fish, and milk.',
        'Oils, sugar, sweets, spices and drinks do not count. Almost everyone in Sri Lanka has them every day, so counting them would make a diet look varied without making it healthier.',
        'Eating from 5 or more groups in a day is called minimum dietary diversity. It is linked with a better chance of getting enough vitamins and minerals, and the same cut-off works for men and women.',
        'A group counts when you eat about a tablespoon (15 g) or more of it. The score shows variety, not quantity or overall diet quality: a day with 6 groups can still include a lot of fried food or sugar. For that, see the Diet quality score.',
      ]);
}

/// Seven bars, one per day, with a guide line at 5 groups.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.byDay});
  final Map<String, Set<String>> byDay;

  @override
  Widget build(BuildContext context) {
    final now = dayStart(DateTime.now());
    final days = [for (int i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const h = 120.0;
    final counts = [for (final d in days) byDay[isoDate(d)]?.length ?? 0];
    final varied = counts.where((n) => n >= 5).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: h + 22,
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: h - h * 5 / 10,
            child: Row(children: [
              Expanded(child: Container(height: 1.5, color: AppColors.tertiary.withValues(alpha: 0.5))),
              const SizedBox(width: 4),
              Text('5', style: T.labelSm.c(AppColors.tertiary)),
            ]),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (int i = 0; i < 7; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (counts[i] > 0) Text('${counts[i]}', style: T.labelSm.tnum.c(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: counts[i] / 10),
                    duration: Duration(milliseconds: 500 + 60 * i),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => Container(
                      width: 22,
                      height: (h - 18) * v + 4,
                      decoration: BoxDecoration(
                        color: counts[i] >= 5 ? AppColors.tertiary : AppColors.nutrition.withValues(alpha: counts[i] == 0 ? 0.2 : 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(i == 6 ? 'Today' : labels[days[i].weekday - 1], style: T.labelSm.c(i == 6 ? AppColors.onSurface : AppColors.onSurfaceVariant)),
                ]),
              ),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      Text(varied == 0 ? 'No varied days yet this week. Five groups in a day is the goal.' : '$varied of 7 days reached 5 or more food groups.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
    ]);
  }
}
