import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../tools/tool_widgets.dart';

class DiversityScreen extends StatefulWidget {
  const DiversityScreen({super.key});
  @override
  State<DiversityScreen> createState() => _DiversityScreenState();
}

class _DiversityScreenState extends State<DiversityScreen> {
  bool _loading = true;
  List<Rec> _today = [];
  List<Rec> _week = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      _week = await Repo.diversityBetween(weekStart(now), now);
      _today = _week.where((r) => r['log_date'] == isoDate(now)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logGroup([FoodGroup? preset]) async {
    FoodGroup? g = preset;
    final food = TextEditingController(text: preset?.suggestion.split('/').first.trim());
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Log a food group', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in foodGroups) VChip(x.label, icon: x.icon, selected: g?.key == x.key, selectedColor: AppColors.nutrition, onTap: () => set(() => g = x)),
            ]),
            const SizedBox(height: Sp.md),
            VTextField(controller: food, hint: 'What did you eat? e.g. gotukola sambol', icon: Symbols.restaurant_rounded),
            const SizedBox(height: Sp.md),
            PrimaryButton('Add', onTap: () async {
              if (g == null) return toast(ctx, 'Choose a food group', error: true);
              await Repo.addDiversity(g!.key, food.text.trim().isEmpty ? g!.label : food.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final todayGroups = _today.map((r) => r['food_group'] as String).toSet();
    final missing = foodGroups.where((g) => !todayGroups.contains(g.key)).toList();
    final weekPoints = _week.map((r) => '${r['food_group']}|${(r['food_name'] as String?)?.toLowerCase().trim()}').toSet().length;
    final firstPerGroup = <String, Rec>{};
    for (final r in _today) {
      firstPerGroup.putIfAbsent(r['food_group'], () => r);
    }
    final c = AppColors.nutrition;

    return VPage(
      header: TitleHeader('Dietary diversity', onLeading: () => goBack(context, '/diet')),
      onRefresh: _load,
      children: [
        VCard(
          child: Row(children: [
            Ring(
              value: todayGroups.length / 8,
              size: 104,
              stroke: 11,
              color: c,
              child: Text('${todayGroups.length}/8', style: T.metric(22)),
            ),
            const SizedBox(width: Sp.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CategoryLabel('Today', icon: Symbols.nutrition_rounded, color: c),
                const SizedBox(height: 6),
                MetricValue('${todayGroups.length}', unit: 'of 8 food groups', size: 26),
                const SizedBox(height: 4),
                Text(
                  missing.isEmpty ? 'Every group covered today.' : 'Aim for 5 or more. Try ${missing.first.suggestion.split('/').first.trim().toLowerCase()} next.',
                  style: T.bodySm.c(AppColors.onSurfaceVariant),
                ),
              ]),
            ),
          ]),
        ),
        SectionHeader('Food groups', trailing: TextLinkButton('About', leading: Symbols.info_rounded, onTap: () => showInfoSheet(context, title: 'Dietary diversity', paragraphs: const [
              'Eating from many food groups each day is linked to better micronutrient intake. VitalU tracks 8 groups: whole grains, fruits, leafy greens, healthy fats and seeds, probiotics (curd, yoghurt), nuts and beans, herbs and spices, and eggs, fish or meat.',
              'Aim for at least 5 groups a day. Weekly variety counts the different foods you eat; variety feeds a healthier gut.',
            ]))),
        if (_loading)
          const Loading()
        else
          ListGroup(children: [
            for (final g in foodGroups)
              ListRow(
                icon: g.icon,
                color: Color(g.color),
                title: g.label,
                subtitle: firstPerGroup[g.key]?['food_name'] ?? 'Try ${g.suggestion.toLowerCase()}',
                trailing: todayGroups.contains(g.key)
                    ? Icon(Symbols.check_circle_rounded, color: AppColors.tertiary, fill: 1)
                    : Icon(Symbols.add_circle_rounded, color: AppColors.onSurfaceVariant),
                onTap: () => _logGroup(g),
              ),
          ]),
        const SectionHeader('This week'),
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MetricValue('$weekPoints', unit: 'of 30 different foods', size: 26),
            const SizedBox(height: 10),
            Bar(value: weekPoints / 30, color: c),
            const SizedBox(height: 10),
            Text('Eating 30 different plant foods a week (grains, fruit, vegetables, pulses, nuts, seeds, herbs and spices) supports gut health.',
                style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        PrimaryButton('Log a food group', leadingIcon: Symbols.add_rounded, onTap: () => _logGroup()),
        const PrivacyNote('Food logs are private to your account.'),
      ],
    );
  }
}
