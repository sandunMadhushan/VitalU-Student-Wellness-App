import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/badge_ui.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../home/home_screen.dart';
import '../tools/tool_widgets.dart';

class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen({super.key});
  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  bool _loading = true;
  List<Rec> _badges = [];
  Map<String, DateTime> _earned = {};
  String _cat = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Repo.refreshBadges();
      _badges = await Repo.badges();
      _earned = await Repo.earnedBadges();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _explain() => showInfoSheet(context, title: 'How milestones work', icon: Symbols.military_tech_rounded, paragraphs: const [
        'Milestones unlock automatically as you use VitalU: drinking water, sleeping well, moving, logging meals, reading articles and checking in on your mood.',
        'Some badges, like Aqua Achiever, Rainbow Plate and Move Maker, need a goal met three days in a row. Miss a day and the streak simply starts again.',
        'Badges are private and never compared with anyone else.',
      ]);

  @override
  Widget build(BuildContext context) {
    final shown = _badges.where((b) => _cat == 'all' || b['category'] == _cat).toList()
      ..sort((a, b) {
        final ea = _earned.containsKey(a['code']) ? 0 : 1, eb = _earned.containsKey(b['code']) ? 0 : 1;
        return ea != eb ? ea - eb : (a['sort_order'] as int).compareTo(b['sort_order'] as int);
      });
    final n = _earned.length, total = _badges.isEmpty ? 12 : _badges.length;
    const cats = {'all': 'All', 'nourish': 'Nourish', 'rest': 'Rest', 'milestone': 'Learning'};

    return VPage(
      header: TitleHeader('Milestones', onLeading: () => goBack(context, '/progress'), actions: [
        IconButton(tooltip: 'How milestones work', icon: const Icon(Symbols.info_rounded), onPressed: _explain),
      ]),
      onRefresh: _load,
      children: [
        VCard(
          child: Row(children: [
            Ring(
              value: n / total,
              size: 64,
              stroke: 6,
              color: AppColors.primary,
              child: Icon(Symbols.military_tech_rounded, color: AppColors.primary, fill: 1),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MetricValue('$n', unit: 'of $total earned', size: 28),
                const SizedBox(height: 2),
                Text(n == 0 ? 'Your first one unlocks after a day of tracking.' : 'Keep using the tools that help you most.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        SizedBox(
          width: double.infinity,
          child: Segmented(options: cats.values.toList(), value: cats[_cat]!, onChanged: (v) => setState(() => _cat = cats.entries.firstWhere((e) => e.value == v).key)),
        ),
        if (_loading)
          const Loading()
        else
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 2 * Sp.gutter) / 3;
            return Wrap(spacing: Sp.gutter, runSpacing: Sp.gutter, children: [for (final b in shown) SizedBox(width: w, child: _badge(b))]);
          }),
        ListGroup(children: [
          ListRow(icon: Symbols.mood_rounded, color: AppColors.mind, title: 'Log how you feel', subtitle: 'Daily check-ins count toward milestones', onTap: () => showMoodPicker(context, onSaved: _load)),
        ]),
        const PrivacyNote('Milestones are private and never compared with other students.'),
      ],
    );
  }

  Widget _badge(Rec b) {
    final earned = _earned[b['code']];
    final on = earned != null;
    return VCard(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      radius: Rad.lg,
      onTap: () => on
          ? showBadgePopup(context, code: b['code'], title: b['title'], description: b['description'], icon: b['icon'], category: b['category'])
          : showInfoSheet(context, title: b['title'], icon: iconByName(b['icon']), paragraphs: [
              b['description'] ?? '',
              'Not yet earned. ${b['pending_label'] ?? ''}'.trim(),
            ]),
      child: Column(children: [
        BadgeArt(code: b['code'], icon: b['icon'], category: b['category'], size: 58, locked: !on),
        const SizedBox(height: 8),
        Text(b['title'], style: T.labelMd.semi.c(on ? AppColors.onSurface : AppColors.onSurfaceVariant), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(on ? DateFormat('d MMM').format(earned) : (b['pending_label'] ?? 'Locked'),
            style: T.labelSm.c(AppColors.onSurfaceVariant), maxLines: 1, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
